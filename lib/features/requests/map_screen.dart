import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;
import 'package:url_launcher/url_launcher.dart';
import '../../core/permissions/permissions.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../home/shell_home.dart' show urgencyColor, urgencyLabel, urgencyText;
import '../permissions/permissions_screen.dart';
import 'donor_map.dart';

/// Nearby donors and open requests on a Google Map. Donor pins show an approximate block,
/// never a doorstep. [_FlatMap] is a lightweight stand-in used when the native map isn't
/// available (tests).
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});
  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  String _group = 'All';
  int _radius = 3;
  int _recenter = 0;
  int _tab = 0; // 0 donors, 1 requests
  String? _selected;
  LatLng? _focus;
  int _focusTick = 0;
  final _sheet = DraggableScrollableController();

  bool get _located => ref.read(userLocationProvider).value != null;

  /// The user's real position when allowed, else the area they chose at sign-up.
  LatLng _center() {
    final loc = ref.watch(userLocationProvider).value;
    return loc != null ? LatLng(loc.lat, loc.lng) : centerForArea(ref.watch(profileProvider).value?.area);
  }

  @override
  void dispose() {
    _sheet.dispose();
    super.dispose();
  }

  Future<void> _onLocateTap() async {
    final snap = ref.read(permissionsProvider).value ?? const PermSnapshot();
    if (permissionOk(AppPermission.location, snap)) {
      ref.invalidate(userLocationProvider);
      setState(() => _recenter++);
    } else {
      await actOnPermission(ref, AppPermission.location, snap);
      ref.invalidate(userLocationProvider);
    }
  }

  /// Highlights a pin and moves the camera to it. [fromList] also tucks the sheet away so the
  /// map is visible.
  void _select(String key, LatLng pos, {bool fromList = false}) {
    setState(() {
      _selected = key;
      _focus = pos;
      _focusTick++;
    });
    if (fromList && _sheet.isAttached) {
      _sheet.animateTo(.16, duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
    }
  }

  Future<void> _directions(LatLng to) async {
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${to.latitude},${to.longitude}');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't open Maps on this device.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rc;
    final center = _center();

    final donors = (ref.watch(nearbyDonorsProvider).value ?? const <NearbyDonor>[])
        .where((d) => (_group == 'All' || d.bloodGroup == _group) && d.distanceKm <= _radius)
        .toList()
      ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

    final reqKm = <String, double>{};
    final requests = (ref.watch(requestsProvider).value ?? const <BloodRequest>[]).where((r) {
      if (!r.hasLocation) return false;
      if (_group != 'All' && r.bloodGroup != _group && r.bloodGroup != 'Any') return false;
      final km = kmBetween(center, LatLng(r.lat!, r.lng!));
      reqKm[r.id] = km;
      return km <= _radius;
    }).toList()
      ..sort((a, b) => (reqKm[a.id] ?? 0).compareTo(reqKm[b.id] ?? 0));

    // Resolve the current selection against what's visible, so filtering clears it.
    NearbyDonor? selDonor;
    BloodRequest? selRequest;
    if (_selected != null) {
      if (_selected!.startsWith('d:')) selDonor = donors.where((d) => donorKey(d.uid) == _selected).firstOrNull;
      if (_selected!.startsWith('r:')) selRequest = requests.where((r) => requestKey(r.id) == _selected).firstOrNull;
    }
    final selectedKey = selDonor != null || selRequest != null ? _selected : null;

    return Stack(children: [
      Positioned.fill(
        child: DonorMap(
          donors: donors,
          requests: requests,
          center: center,
          showMyLocation: _located,
          recenterTick: _recenter,
          radiusKm: _radius,
          selectedKey: selectedKey,
          focus: _focus,
          focusTick: _focusTick,
          onSelect: (key) {
            final pos = key.startsWith('d:')
                ? donors.where((d) => donorKey(d.uid) == key).map((d) => approximateDonorPosition(center, d)).firstOrNull
                : requests.where((r) => requestKey(r.id) == key).map((r) => LatLng(r.lat!, r.lng!)).firstOrNull;
            if (pos != null) _select(key, pos);
          },
          onMapTap: () => setState(() => _selected = null),
          fallback: _FlatMap(donors: donors, c: c),
        ),
      ),
      _filterBar(c),
      Positioned(
        right: 16,
        top: 176,
        child: Material(
          color: c.surface1,
          shape: CircleBorder(side: BorderSide(color: c.borderStrong)),
          elevation: 2,
          child: IconButton(
            tooltip: 'My location',
            icon: Icon(_located ? TablerIcons.current_location : TablerIcons.location_off, color: c.textPrimary),
            onPressed: _onLocateTap,
          ),
        ),
      ),
      if (selDonor != null || selRequest != null)
        Positioned(
          left: 16, right: 72, top: 168,
          child: FadeSlideIn(
            key: ValueKey(selectedKey),
            dy: 8,
            child: selDonor != null
                ? _DonorCard(selDonor, onClose: () => setState(() => _selected = null))
                : _RequestCard(
                    selRequest!,
                    km: reqKm[selRequest.id] ?? 0,
                    onClose: () => setState(() => _selected = null),
                    onDirections: () => _directions(LatLng(selRequest!.lat!, selRequest.lng!)),
                    onOpen: () => context.push('/request/${selRequest!.id}'),
                  ),
          ),
        ),
      DraggableScrollableSheet(
        controller: _sheet,
        initialChildSize: .36, minChildSize: .16, maxChildSize: .75,
        snap: true,
        snapSizes: const [.16, .36, .75],
        builder: (context, scroll) => Container(
          decoration: BoxDecoration(color: c.surface3, border: Border(top: BorderSide(color: c.borderStrong)), borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
          child: ListView(controller: scroll, padding: const EdgeInsets.only(bottom: 96), children: [
            Center(child: Container(margin: const EdgeInsets.only(top: 8, bottom: 8), width: 36, height: 4, decoration: BoxDecoration(color: c.borderStrong, borderRadius: BorderRadius.circular(99)))),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: _tabs(c, donors.length, requests.length),
            ),
            if (_tab == 0) ..._donorRows(c, donors, center) else ..._requestRows(c, requests, reqKm),
          ]),
        ),
      ),
    ]);
  }

  Widget _tabs(RColors c, int donors, int requests) {
    Widget tab(int i, String label, int n) => Expanded(
          child: GestureDetector(
            onTap: () => setState(() {
              _tab = i;
              _selected = null;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _tab == i ? c.surface1 : Colors.transparent,
                borderRadius: BorderRadius.circular(99),
                border: _tab == i ? Border.all(color: c.border) : null,
              ),
              child: Text('$label · $n', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: _tab == i ? c.textPrimary : c.textSecondary)),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(99)),
      child: Row(children: [tab(0, 'Donors', donors), tab(1, 'Requests', requests)]),
    );
  }

  List<Widget> _donorRows(RColors c, List<NearbyDonor> donors, LatLng center) {
    if (donors.isEmpty) {
      return [
        _empty(c, 'No donors within $_radius km', "Widen your radius or post a request — we'll alert matching donors as they come online.", _radius < 5 ? 'Search within 5 km' : null),
      ];
    }
    return [
      for (final d in donors)
        InkWell(
          onTap: () => _select(donorKey(d.uid), approximateDonorPosition(center, d), fromList: true),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _selected == donorKey(d.uid) ? c.bgBrand : null,
              border: Border(top: BorderSide(color: c.border)),
            ),
            child: Row(children: [
              DonorAvatar(d.initials, online: d.available),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('${_dist(d.distanceKm)} · ${d.available ? 'Available' : 'Resting'} · ${d.donations} donations', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                ]),
              ),
              BloodPill(d.bloodGroup, height: 24, size: 12),
            ]),
          ),
        ),
    ];
  }

  List<Widget> _requestRows(RColors c, List<BloodRequest> requests, Map<String, double> km) {
    if (requests.isEmpty) {
      return [
        _empty(c, 'No requests within $_radius km', 'Requests with a known location show up here and on the map.', _radius < 5 ? 'Search within 5 km' : null),
      ];
    }
    return [
      for (final r in requests)
        InkWell(
          onTap: () => _select(requestKey(r.id), LatLng(r.lat!, r.lng!), fromList: true),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _selected == requestKey(r.id) ? c.bgBrand : null,
              border: Border(top: BorderSide(color: c.border), left: BorderSide(color: urgencyColor(c, r.urgency), width: 2)),
            ),
            child: Row(children: [
              BloodPill(r.bloodGroup, role: r.urgency == Urgency.routine ? PillRole.neutral : (r.urgency == Urgency.critical ? PillRole.danger : PillRole.warning), height: 24, size: 12),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('${r.place} · ${_dist(km[r.id] ?? 0)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.textSecondary)),
                ]),
              ),
              const SizedBox(width: 8),
              Text(urgencyLabel(r.urgency), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: urgencyText(c, r.urgency))),
            ]),
          ),
        ),
    ];
  }

  Widget _empty(RColors c, String title, String body, String? action) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(body, style: TextStyle(fontSize: 13, color: c.textSecondary)),
          if (action != null) ...[
            const SizedBox(height: 10),
            PillButton(action, height: 44, outlined: true, onPressed: () => setState(() => _radius = 5)),
          ],
        ]),
      );

  String _dist(double km) => km <= 0 ? 'nearby' : (km < 1 ? '${(km * 1000).round()} m' : '$km km');

  Widget _filterBar(RColors c) => Positioned(
        left: 0, right: 0, top: 0,
        child: Container(
          decoration: BoxDecoration(color: c.surface0, border: Border(bottom: BorderSide(color: c.border))),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10, top: 8),
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    Expanded(
                      child: Container(
                        height: 44, padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(color: c.surface1, borderRadius: BorderRadius.circular(RRadius.base), border: Border.all(color: c.borderStrong)),
                        child: Row(children: [Icon(TablerIcons.search, size: 18, color: c.textMuted), const SizedBox(width: 8), Expanded(child: Text(ref.watch(profileProvider).value?.area ?? 'Your area', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textMuted)))]),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(color: c.surface1, borderRadius: BorderRadius.circular(RRadius.base), border: Border.all(color: c.borderStrong)),
                      clipBehavior: Clip.antiAlias,
                      child: Row(children: [
                        for (final r in [1, 3, 5])
                          InkWell(
                            onTap: () => setState(() => _radius = r),
                            child: Container(
                              width: 48, height: 44, alignment: Alignment.center, color: r == _radius ? c.fillPrimary : null,
                              child: Text('$r km', style: TextStyle(fontSize: 13, color: r == _radius ? c.onPrimary : c.textPrimary)),
                            ),
                          ),
                      ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 36,
                  child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
                    for (final g in ['All', ...bloodGroups])
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(g), selected: g == _group, onSelected: (_) => setState(() => _group = g),
                          showCheckmark: false, shape: const StadiumBorder(),
                          backgroundColor: c.surface1, selectedColor: c.bgBrand,
                          side: BorderSide(color: g == _group ? c.fillBrand : c.borderStrong, width: g == _group ? 1.5 : 1),
                          labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: g == _group ? c.textBrand : c.textPrimary),
                        ),
                      ),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      );
}

class _DonorCard extends StatelessWidget {
  const _DonorCard(this.d, {required this.onClose});
  final NearbyDonor d;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final c = context.rc;
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      child: Row(children: [
        DonorAvatar(d.initials, online: d.available),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
              const SizedBox(width: 8),
              BloodPill(d.bloodGroup, height: 22, size: 12),
            ]),
            Text('${d.available ? 'Available' : 'Resting'} · ${d.donations} donations${d.distanceKm > 0 ? ' · ${d.distanceKm} km' : ''}', style: TextStyle(fontSize: 12, color: c.textSecondary)),
            Text('Approximate area only', style: TextStyle(fontSize: 11, color: c.textMuted)),
          ]),
        ),
        IconButton(tooltip: 'Close', icon: Icon(TablerIcons.x, size: 18, color: c.textMuted), onPressed: onClose),
      ]),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard(this.r, {required this.km, required this.onClose, required this.onDirections, required this.onOpen});
  final BloodRequest r;
  final double km;
  final VoidCallback onClose, onDirections, onOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.rc;
    return SurfaceCard(
      stripe: urgencyColor(c, r.urgency),
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          BloodPill(r.bloodGroup, role: r.urgency == Urgency.critical ? PillRole.danger : PillRole.warning, height: 22, size: 12),
          const SizedBox(width: 8),
          Expanded(
            child: Ticker(builder: (_) => Text('${urgencyLabel(r.urgency)} · ${timeLeft(r.deadline)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: urgencyText(c, r.urgency)))),
          ),
          IconButton(visualDensity: VisualDensity.compact, tooltip: 'Close', icon: Icon(TablerIcons.x, size: 18, color: c.textMuted), onPressed: onClose),
        ]),
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            Text('${r.place} · ${km <= 0 ? 'nearby' : '$km km'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.textSecondary)),
            const SizedBox(height: 8),
            RProgress(r.progress),
            const SizedBox(height: 4),
            Text('${r.committed} of ${r.bagsNeeded} donors committed', style: TextStyle(fontSize: 11, color: c.textMuted)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: PillButton('Directions', height: 40, outlined: true, onPressed: onDirections, icon: TablerIcons.route)),
              const SizedBox(width: 8),
              Expanded(child: PillButton('View', height: 40, onPressed: onOpen)),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _FlatMap extends StatelessWidget {
  const _FlatMap({required this.donors, required this.c});
  final List<NearbyDonor> donors;
  final RColors c;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth, h = box.maxHeight;
      Widget road(Rect r) => Positioned(left: r.left, top: r.top, width: r.width, height: r.height, child: ColoredBox(color: c.mapRoad));
      Widget block(double l, double t, double bw, double bh) => Positioned(
            left: l, top: t, width: bw, height: bh,
            child: Container(decoration: BoxDecoration(color: c.surface1, borderRadius: BorderRadius.circular(22), border: Border.all(color: c.border))),
          );
      final cx = w / 2, cy = h * .4;
      return ColoredBox(
        color: c.mapBlock,
        child: Stack(children: [
          road(Rect.fromLTWH(0, h * .30, w, 14)),
          road(Rect.fromLTWH(0, h * .55, w, 10)),
          road(Rect.fromLTWH(w * .30, 0, 12, h)),
          road(Rect.fromLTWH(w * .72, 0, 8, h)),
          block(w * .38, h * .34, 110, 150),
          block(20, h * .12, 80, 170),
          block(w * .78, h * .6, 70, 90),
          Positioned(left: cx - 60, top: cy - 60, child: Container(width: 120, height: 120, decoration: BoxDecoration(shape: BoxShape.circle, color: c.bgAccent.withValues(alpha: .7), border: Border.all(color: c.borderAccent)))),
          Positioned(left: cx - 9, top: cy - 9, child: Container(width: 18, height: 18, decoration: BoxDecoration(shape: BoxShape.circle, color: c.fillAccent, border: Border.all(color: c.surface1, width: 3)))),
          for (var i = 0; i < donors.length; i++) _pin(donors[i], i, cx, cy, w, h),
        ]),
      );
    });
  }

  /// Deterministic approximate position around the user: bearing from index, radius from distance.
  Widget _pin(NearbyDonor d, int i, double cx, double cy, double w, double h) {
    final angle = (i * 2.399963) + d.uid.hashCode % 7; // golden angle spread
    final r = (24 + d.distanceKm * 38).clamp(24, w * .45).toDouble();
    final x = (cx + r * cos(angle)).clamp(24.0, w - 24);
    final y = (cy + r * sin(angle)).clamp(130.0, h - 24);
    return Positioned(
      left: x - 15, top: y - 15,
      child: Container(
        width: 30, height: 30, alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, color: d.available ? c.fillSuccess : c.fillWarning, border: Border.all(color: c.surface1, width: 2)),
        child: Text(d.bloodGroup, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: c.onFill)),
      ),
    );
  }
}
