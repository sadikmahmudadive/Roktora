import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import 'donor_map.dart';

/// Nearby donors on a Google Map. Pins show an approximate block, not a doorstep.
/// [_FlatMap] is a lightweight stand-in used when the native map isn't available (tests).
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});
  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  String _group = 'All';
  int _radius = 3;

  @override
  Widget build(BuildContext context) {
    final c = context.rc;
    final donors = ref.watch(nearbyDonorsProvider);
    final all = donors.value ?? const <NearbyDonor>[];
    final vis = all.where((d) => (_group == 'All' || d.bloodGroup == _group) && d.distanceKm <= _radius).toList()
      ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

    return Stack(children: [
      Positioned.fill(
        child: DonorMap(
          donors: vis,
          center: centerForArea(ref.watch(profileProvider).value?.area),
          radiusKm: _radius,
          fallback: _FlatMap(donors: vis, c: c),
        ),
      ),
      Positioned(
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
      ),
      DraggableScrollableSheet(
        initialChildSize: .36, minChildSize: .16, maxChildSize: .75,
        builder: (context, scroll) => Container(
          decoration: BoxDecoration(color: c.surface3, border: Border(top: BorderSide(color: c.borderStrong)), borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
          child: ListView(controller: scroll, padding: const EdgeInsets.only(bottom: 96), children: [
            Center(child: Container(margin: const EdgeInsets.only(top: 8, bottom: 4), width: 36, height: 4, decoration: BoxDecoration(color: c.borderStrong, borderRadius: BorderRadius.circular(99)))),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Flexible(child: Text('${vis.length} donors within $_radius km', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16))),
                const SizedBox(width: 8),
                Text('Updated just now', style: TextStyle(fontSize: 12, color: c.textMuted)),
              ]),
            ),
            for (final d in vis)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: c.border))),
                child: Row(children: [
                  DonorAvatar(d.initials, online: d.available),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(d.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text('${d.distanceKm < 1 ? '${(d.distanceKm * 1000).round()} m' : '${d.distanceKm} km'} · ${d.available ? 'Available' : 'Resting'} · ${d.donations} donations', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                    ]),
                  ),
                  BloodPill(d.bloodGroup, height: 24, size: 12),
                  const SizedBox(width: 8),
                  CircleIconButton(icon: TablerIcons.message_circle, label: 'Message donor', filled: false, onPressed: () {}),
                ]),
              ),
            if (vis.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text("Widen your radius or post a request — we'll alert matching donors as they come online.", style: TextStyle(fontSize: 13, color: c.textSecondary)),
                  const SizedBox(height: 10),
                  PillButton('Search within 5 km', height: 44, outlined: true, onPressed: () => setState(() => _radius = 5)),
                ]),
              ),
          ]),
        ),
      ),
    ]);
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
