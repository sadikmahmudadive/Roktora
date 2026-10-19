import 'dart:io' show Platform;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/theme/tokens.dart';
import '../../data/models.dart';

/// Approximate centers for the areas offered at sign-up.
const _areaCenters = <String, LatLng>{
  'Dhanmondi, Dhaka': LatLng(23.7461, 90.3742),
  'Mirpur, Dhaka': LatLng(23.8223, 90.3654),
  'Uttara, Dhaka': LatLng(23.8759, 90.3795),
  'Agrabad, Chattogram': LatLng(22.3293, 91.8128),
};
const _fallbackCenter = LatLng(23.7806, 90.4000); // central Dhaka

LatLng centerForArea(String? area) => _areaCenters[area] ?? _fallbackCenter;

/// Places a donor around [center] at their stated distance. The bearing is stable per donor
/// and the result is snapped to a ~200 m grid, so a pin never reveals a doorstep.
LatLng approximateDonorPosition(LatLng center, NearbyDonor d) {
  final bearing = (d.uid.hashCode % 360) * pi / 180;
  final km = d.distanceKm <= 0 ? 0.4 + (d.uid.hashCode.abs() % 12) / 10 : d.distanceKm;
  final dLat = km * cos(bearing) / 111.0;
  final dLng = km * sin(bearing) / (111.0 * cos(center.latitude * pi / 180));
  double snap(double v) => (v / .002).round() * .002;
  return LatLng(snap(center.latitude + dLat), snap(center.longitude + dLng));
}

double _zoomForRadius(int km) => switch (km) { 1 => 14.6, 3 => 13.4, _ => 12.6 };

const _darkStyle = '''[
{"elementType":"geometry","stylers":[{"color":"#282724"}]},
{"elementType":"labels.text.fill","stylers":[{"color":"#9a978f"}]},
{"elementType":"labels.text.stroke","stylers":[{"color":"#1d1c1b"}]},
{"featureType":"road","elementType":"geometry","stylers":[{"color":"#33322e"}]},
{"featureType":"water","elementType":"geometry","stylers":[{"color":"#1b2740"}]},
{"featureType":"poi","stylers":[{"visibility":"off"}]}
]''';

const _lightStyle = '''[
{"featureType":"poi","stylers":[{"visibility":"off"}]},
{"featureType":"transit","stylers":[{"visibility":"off"}]}
]''';

class DonorMap extends StatefulWidget {
  const DonorMap({super.key, required this.donors, required this.center, required this.radiusKm, required this.fallback});
  final List<NearbyDonor> donors;
  final LatLng center;
  final int radiusKm;

  /// Shown in tests and anywhere the native map can't be created.
  final Widget fallback;

  @override
  State<DonorMap> createState() => _DonorMapState();
}

class _DonorMapState extends State<DonorMap> {
  GoogleMapController? _ctrl;

  @override
  void didUpdateWidget(DonorMap old) {
    super.didUpdateWidget(old);
    if (old.radiusKm != widget.radiusKm || old.center != widget.center) {
      _ctrl?.animateCamera(CameraUpdate.newLatLngZoom(widget.center, _zoomForRadius(widget.radiusKm)));
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.environment['FLUTTER_TEST'] == 'true') return widget.fallback;
    final c = context.rc;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final markers = <Marker>{
      for (final d in widget.donors)
        Marker(
          markerId: MarkerId(d.uid),
          position: approximateDonorPosition(widget.center, d),
          icon: BitmapDescriptor.defaultMarkerWithHue(d.available ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueOrange),
          infoWindow: InfoWindow(title: '${d.name} · ${d.bloodGroup}', snippet: d.available ? 'Available' : 'Resting'),
        ),
    };
    return GoogleMap(
      initialCameraPosition: CameraPosition(target: widget.center, zoom: _zoomForRadius(widget.radiusKm)),
      style: dark ? _darkStyle : _lightStyle,
      markers: markers,
      circles: {
        Circle(
          circleId: const CircleId('radius'),
          center: widget.center,
          radius: widget.radiusKm * 1000.0,
          fillColor: c.fillAccent.withValues(alpha: .08),
          strokeColor: c.fillAccent.withValues(alpha: .6),
          strokeWidth: 1,
        ),
      },
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
      // Leave room for the top filters and the bottom sheet.
      padding: const EdgeInsets.only(top: 150, bottom: 200),
      onMapCreated: (ctrl) => _ctrl = ctrl,
    );
  }
}
