import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:geocoding/geocoding.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/permissions/permissions.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/providers.dart';
import '../permissions/permissions_screen.dart';
import '../requests/donor_map.dart';

/// A place chosen on the map.
class PickedLocation {
  const PickedLocation({required this.lat, required this.lng, required this.label});
  final double lat, lng;

  /// Human-readable name, e.g. "Dhanmondi, Dhaka".
  final String label;

  LatLng get latLng => LatLng(lat, lng);
}

class PickerArgs {
  const PickerArgs({this.initial, this.title = 'Set your location', this.confirmLabel = 'Confirm location', this.hint});
  final LatLng? initial;
  final String title, confirmLabel;
  final String? hint;
}

/// Opens the map picker and resolves to the chosen place, or null if dismissed.
Future<PickedLocation?> pickLocation(
  BuildContext context, {
  LatLng? initial,
  String title = 'Set your location',
  String confirmLabel = 'Confirm location',
  String? hint,
}) =>
    context.push<PickedLocation>('/pick-location', extra: PickerArgs(initial: initial, title: title, confirmLabel: confirmLabel, hint: hint));

/// Reverse-geocodes to a short place name, falling back to coordinates when no geocoder is available.
Future<String> describePlace(double lat, double lng) async {
  try {
    final marks = await Geocoding().placemarkFromCoordinates(lat, lng);
    if (marks.isNotEmpty) {
      final m = marks.first;
      final parts = <String>[
        for (final v in [m.subLocality, m.thoroughfare, m.locality, m.subAdministrativeArea])
          if (v != null && v.trim().isNotEmpty) v.trim(),
      ];
      final unique = <String>[];
      for (final p in parts) {
        if (!unique.contains(p)) unique.add(p);
      }
      if (unique.isNotEmpty) return unique.take(2).join(', ');
    }
  } catch (_) {
    // No geocoder on this device (or offline). The coordinates still work.
  }
  return '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
}

/// A form field that shows the chosen place and opens the picker when tapped.
class LocationField extends StatelessWidget {
  const LocationField({super.key, required this.label, required this.placeholder, required this.onTap, this.error = false});
  final String? label;
  final String placeholder;
  final VoidCallback onTap;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final c = context.rc;
    final has = label != null && label!.isNotEmpty;
    return Semantics(
      button: true,
      label: has ? 'Location: $label. Tap to change.' : placeholder,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: c.surface1,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: error ? c.borderDanger : c.borderStrong),
          ),
          child: Row(children: [
            Icon(TablerIcons.map_pin, color: has ? c.textBrand : c.textMuted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                has ? label! : placeholder,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: has ? c.textPrimary : c.textMuted),
              ),
            ),
            Icon(TablerIcons.chevron_right, size: 18, color: c.textMuted),
          ]),
        ),
      ),
    );
  }
}

class LocationPickerScreen extends ConsumerStatefulWidget {
  const LocationPickerScreen({super.key, this.args = const PickerArgs()});
  final PickerArgs args;

  @override
  ConsumerState<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends ConsumerState<LocationPickerScreen> {
  late LatLng _center;
  GoogleMapController? _ctrl;
  final _search = TextEditingController();
  String _label = '';
  bool _moving = false;
  bool _resolving = false;
  bool _searching = false;
  String? _searchError;
  Timer? _debounce;
  int _resolveToken = 0;

  bool get _inTest => Platform.environment['FLUTTER_TEST'] == 'true';

  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileProvider).value;
    _center = widget.args.initial ??
        (profile != null && profile.hasLocation ? LatLng(profile.lat!, profile.lng!) : centerForArea(profile?.area));
    _resolve();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _ctrl?.dispose();
    super.dispose();
  }

  Future<void> _resolve() async {
    final token = ++_resolveToken;
    setState(() => _resolving = true);
    final text = await describePlace(_center.latitude, _center.longitude);
    if (!mounted || token != _resolveToken) return;
    setState(() {
      _label = text;
      _resolving = false;
    });
  }

  void _onCameraMove(CameraPosition pos) {
    _center = pos.target;
    if (!_moving) setState(() => _moving = true);
  }

  void _onCameraIdle() {
    if (_moving) setState(() => _moving = false);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), _resolve);
  }

  Future<void> _goTo(LatLng p, {double zoom = 16}) async {
    _center = p;
    await _ctrl?.animateCamera(CameraUpdate.newLatLngZoom(p, zoom));
    if (_inTest || _ctrl == null) _resolve();
  }

  Future<void> _runSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final geo = Geocoding();
      var found = await geo.locationFromAddress(q);
      if (found.isEmpty && !q.toLowerCase().contains('bangladesh')) found = await geo.locationFromAddress('$q, Bangladesh');
      if (!mounted) return;
      if (found.isEmpty) {
        setState(() => _searchError = 'No place found for "$q". Try a nearby landmark or road.');
      } else {
        await _goTo(LatLng(found.first.latitude, found.first.longitude));
      }
    } catch (_) {
      if (mounted) setState(() => _searchError = "Couldn't search right now. Move the map to place the pin instead.");
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _useMyLocation() async {
    var snap = ref.read(permissionsProvider).value ?? const PermSnapshot();
    if (!permissionOk(AppPermission.location, snap)) {
      await actOnPermission(ref, AppPermission.location, snap);
      snap = ref.read(permissionsProvider).value ?? snap;
      if (!permissionOk(AppPermission.location, snap)) return;
    }
    final pos = await ref.read(permissionApiProvider).currentPosition();
    if (!mounted) return;
    if (pos == null) {
      setState(() => _searchError = "Couldn't get your position. Check that location is switched on.");
      return;
    }
    await _goTo(LatLng(pos.lat, pos.lng));
  }

  void _confirm() {
    context.pop(PickedLocation(lat: _center.latitude, lng: _center.longitude, label: _label.isEmpty ? 'Pinned location' : _label));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rc;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final located = ref.watch(permissionsProvider).value?.location == PermStatus.granted;

    return Scaffold(
      body: Stack(children: [
        Positioned.fill(
          child: _inTest
              ? ColoredBox(color: c.mapBlock, child: const Center(child: Text('Map preview')))
              : GoogleMap(
                  initialCameraPosition: CameraPosition(target: _center, zoom: 15.5),
                  style: dark ? mapDarkStyle : mapLightStyle,
                  myLocationEnabled: located,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  compassEnabled: false,
                  onMapCreated: (ctrl) => _ctrl = ctrl,
                  onCameraMove: _onCameraMove,
                  onCameraIdle: _onCameraIdle,
                ),
        ),
        // The pin stays fixed on screen; the map moves underneath it.
        IgnorePointer(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 48),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOut,
                  transform: Matrix4.translationValues(0, _moving ? -14 : 0, 0),
                  child: Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: c.fillBrand, shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .25), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: const Center(child: RoktoraMark(height: 24, color: Colors.white)),
                  ),
                ),
                Container(width: 3, height: 14, color: c.fillBrand),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: _moving ? 6 : 12, height: _moving ? 3 : 5,
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: .25), borderRadius: BorderRadius.circular(99)),
                ),
              ]),
            ),
          ),
        ),
        // Top bar: back + search.
        Positioned(
          left: 16, right: 16, top: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(children: [
                Row(children: [
                  CircleIconButton(icon: TablerIcons.arrow_left, label: 'Back', onPressed: () => context.pop()),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.only(left: 14, right: 4),
                      decoration: BoxDecoration(
                        color: c.surface1, borderRadius: BorderRadius.circular(99), border: Border.all(color: c.borderStrong),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 12, offset: const Offset(0, 3))],
                      ),
                      child: Row(children: [
                        Icon(TablerIcons.search, size: 18, color: c.textMuted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _search,
                            textInputAction: TextInputAction.search,
                            onSubmitted: _runSearch,
                            decoration: InputDecoration(border: InputBorder.none, hintText: 'Search a place or road', hintStyle: TextStyle(color: c.textMuted)),
                          ),
                        ),
                        if (_searching)
                          const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                        else
                          IconButton(tooltip: 'Search', icon: Icon(TablerIcons.arrow_right, size: 18, color: c.textBrand), onPressed: () => _runSearch(_search.text)),
                      ]),
                    ),
                  ),
                ]),
                if (_searchError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: InfoBanner(_searchError!, icon: TablerIcons.info_circle, bg: c.bgWarning, fg: c.textWarning),
                  ),
              ]),
            ),
          ),
        ),
        // Locate button.
        Positioned(
          right: 16,
          bottom: 250,
          child: Material(
            color: c.surface1,
            shape: CircleBorder(side: BorderSide(color: c.borderStrong)),
            elevation: 2,
            child: IconButton(
              tooltip: 'Use my current location',
              icon: Icon(located ? TablerIcons.current_location : TablerIcons.location_off, color: c.textPrimary),
              onPressed: _useMyLocation,
            ),
          ),
        ),
        // Bottom card.
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            decoration: BoxDecoration(
              color: c.surface3,
              border: Border(top: BorderSide(color: c.borderStrong)),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.args.title, style: AppTheme.display(context, size: 22)),
                  const SizedBox(height: 10),
                  Row(children: [
                    Container(width: 36, height: 36, decoration: BoxDecoration(color: c.bgBrand, borderRadius: BorderRadius.circular(12)), child: Icon(TablerIcons.map_pin, size: 18, color: c.textBrand)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 150),
                        child: Text(
                          _resolving || _label.isEmpty ? 'Finding the place name…' : _label,
                          key: ValueKey(_label + _resolving.toString()),
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  Text(
                    widget.args.hint ?? 'Move the map to place the pin. Others only ever see an approximate area, never your exact spot.',
                    style: TextStyle(fontSize: 12, color: c.textMuted, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  PillButton(widget.args.confirmLabel, height: 54, onPressed: _moving ? null : _confirm),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
