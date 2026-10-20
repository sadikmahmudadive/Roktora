import 'dart:io' show Platform;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' show Geolocator;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/theme/tokens.dart';
import '../../data/models.dart';
import 'map_markers.dart';

/// Approximate centers for the areas offered at sign-up.
const _areaCenters = <String, LatLng>{
  'Dhanmondi, Dhaka': LatLng(23.7461, 90.3742),
  'Mirpur, Dhaka': LatLng(23.8223, 90.3654),
  'Uttara, Dhaka': LatLng(23.8759, 90.3795),
  'Agrabad, Chattogram': LatLng(22.3293, 91.8128),
};
const _fallbackCenter = LatLng(23.7806, 90.4000); // central Dhaka

LatLng centerForArea(String? area) => _areaCenters[area] ?? _fallbackCenter;

/// Straight-line distance in km, rounded to 0.1.
double kmBetween(LatLng a, LatLng b) => (Geolocator.distanceBetween(a.latitude, a.longitude, b.latitude, b.longitude) / 100).round() / 10;

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

/// Keys used to identify map selections: `d:<donor uid>` and `r:<request id>`.
String donorKey(String uid) => 'd:$uid';
String requestKey(String id) => 'r:$id';

double _zoomForRadius(int km) => switch (km) { 1 => 14.6, 3 => 13.4, _ => 12.6 };

const mapDarkStyle = '''[
{"elementType":"geometry","stylers":[{"color":"#282724"}]},
{"elementType":"labels.text.fill","stylers":[{"color":"#9a978f"}]},
{"elementType":"labels.text.stroke","stylers":[{"color":"#1d1c1b"}]},
{"featureType":"road","elementType":"geometry","stylers":[{"color":"#33322e"}]},
{"featureType":"water","elementType":"geometry","stylers":[{"color":"#1b2740"}]},
{"featureType":"poi","stylers":[{"visibility":"off"}]}
]''';

const mapLightStyle = '''[
{"featureType":"poi","stylers":[{"visibility":"off"}]},
{"featureType":"transit","stylers":[{"visibility":"off"}]}
]''';

class DonorMap extends StatefulWidget {
  const DonorMap({
    super.key,
    required this.donors,
    required this.requests,
    required this.center,
    required this.radiusKm,
    required this.fallback,
    this.showMyLocation = false,
    this.recenterTick = 0,
    this.selectedKey,
    this.focus,
    this.focusTick = 0,
    this.onSelect,
    this.onMapTap,
  });

  final List<NearbyDonor> donors;
  final List<BloodRequest> requests;
  final LatLng center;
  final int radiusKm;

  /// Draws the blue 'you are here' dot (only when location is allowed).
  final bool showMyLocation;

  /// Bump to animate the camera back to [center].
  final int recenterTick;

  /// `d:<uid>` or `r:<id>` of the highlighted pin.
  final String? selectedKey;

  /// Camera target for [focusTick] changes, e.g. when a list row is tapped.
  final LatLng? focus;
  final int focusTick;

  final ValueChanged<String>? onSelect;
  final VoidCallback? onMapTap;

  /// Shown in tests and anywhere the native map can't be created.
  final Widget fallback;

  @override
  State<DonorMap> createState() => _DonorMapState();
}

class _DonorMapState extends State<DonorMap> {
  GoogleMapController? _ctrl;
  Set<Marker> _markers = const {};
  double _dpr = 3;
  int _buildToken = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final dpr = MediaQuery.devicePixelRatioOf(context);
    if (dpr != _dpr || _markers.isEmpty) {
      _dpr = dpr;
      _rebuildMarkers();
    }
  }

  @override
  void didUpdateWidget(DonorMap old) {
    super.didUpdateWidget(old);
    if (old.radiusKm != widget.radiusKm || old.center != widget.center || old.recenterTick != widget.recenterTick) {
      _ctrl?.animateCamera(CameraUpdate.newLatLngZoom(widget.center, _zoomForRadius(widget.radiusKm)));
    }
    if (old.focusTick != widget.focusTick && widget.focus != null) {
      _ctrl?.animateCamera(CameraUpdate.newLatLngZoom(widget.focus!, max(14.8, _zoomForRadius(widget.radiusKm))));
    }
    if (old.donors != widget.donors || old.requests != widget.requests || old.selectedKey != widget.selectedKey || old.center != widget.center) {
      _rebuildMarkers();
    }
  }

  Future<void> _rebuildMarkers() async {
    final token = ++_buildToken;
    final c = context.rc;
    final next = <Marker>{};
    for (final d in widget.donors) {
      final key = donorKey(d.uid);
      final icon = await MarkerFactory.donor(
        label: d.bloodGroup,
        color: d.available ? c.fillSuccess : c.fillWarning,
        pixelRatio: _dpr,
        selected: key == widget.selectedKey,
      );
      next.add(Marker(
        markerId: MarkerId(key),
        position: approximateDonorPosition(widget.center, d),
        icon: icon,
        anchor: const Offset(.5, .5),
        zIndexInt: key == widget.selectedKey ? 3 : 1,
        onTap: () => widget.onSelect?.call(key),
      ));
    }
    for (final r in widget.requests.where((r) => r.hasLocation)) {
      final key = requestKey(r.id);
      final icon = await MarkerFactory.request(
        label: r.bloodGroup,
        color: c.fillBrand,
        pixelRatio: _dpr,
        selected: key == widget.selectedKey,
      );
      next.add(Marker(
        markerId: MarkerId(key),
        position: LatLng(r.lat!, r.lng!),
        icon: icon,
        anchor: const Offset(.5, .5),
        zIndexInt: key == widget.selectedKey ? 4 : 2,
        onTap: () => widget.onSelect?.call(key),
      ));
    }
    // A newer rebuild started while icons were drawing; drop this one.
    if (!mounted || token != _buildToken) return;
    setState(() => _markers = next);
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
    return GoogleMap(
      initialCameraPosition: CameraPosition(target: widget.center, zoom: _zoomForRadius(widget.radiusKm)),
      style: dark ? mapDarkStyle : mapLightStyle,
      markers: _markers,
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
      myLocationEnabled: widget.showMyLocation,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
      onTap: (_) => widget.onMapTap?.call(),
      // Leave room for the top filters and the bottom sheet.
      padding: const EdgeInsets.only(top: 150, bottom: 200),
      onMapCreated: (ctrl) {
        _ctrl = ctrl;
        // The real position can arrive before the native map exists, in which case the earlier
        // camera animation had no controller. Sync once now.
        ctrl.moveCamera(CameraUpdate.newLatLngZoom(widget.center, _zoomForRadius(widget.radiusKm)));
      },
    );
  }
}
