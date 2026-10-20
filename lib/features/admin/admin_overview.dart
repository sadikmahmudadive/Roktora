import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../home/shell_home.dart' show urgencyColor, urgencyLabel, urgencyText;
import 'admin_models.dart';
import 'admin_providers.dart';
import 'admin_widgets.dart';

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

class AdminOverviewScreen extends ConsumerWidget {
  const AdminOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.rc;
    final hospital = ref.watch(hospitalProvider).value;
    final requests = ref.watch(hospitalRequestsProvider).value ?? const <BloodRequest>[];
    final inventory = ref.watch(inventoryProvider).value ?? const <InventoryRow>[];
    final batches = ref.watch(batchesProvider).value ?? const <BloodBatch>[];
    final checkins = ref.watch(checkinsProvider).value ?? const <CheckIn>[];
    final now = DateTime.now();

    final open = requests.where((r) => r.isOpen).toList();
    final critical = open.where((r) => r.urgency == Urgency.critical).toList();
    final today = checkins.where((x) => _sameDay(x.at, now)).toList();
    final inBays = checkins.where((x) => x.status == CheckInStatus.donating).length;
    final weekStart = now.subtract(const Duration(days: 7)), prevStart = now.subtract(const Duration(days: 14));
    final done = checkins.where((x) => x.status == CheckInStatus.done);
    final thisWeek = done.where((x) => x.at.isAfter(weekStart)).length;
    final lastWeek = done.where((x) => x.at.isAfter(prevStart) && !x.at.isAfter(weekStart)).length;
    final weekDelta = lastWeek == 0 ? null : ((thisWeek - lastWeek) * 100 / lastWeek).round();
    final expiring = batches.where((b) => b.expiresAt.difference(now).inHours <= 72).toList();
    final expiringTomorrow = expiring.where((b) => b.daysLeft <= 1).toList();
    final queue = checkins.where((x) => x.status == CheckInStatus.waiting || x.status == CheckInStatus.screening || x.status == CheckInStatus.donating).toList();

    return AdminPage(
      title: 'Dashboard',
      subtitle: '${DateFormat('EEEE, d MMMM').format(now)} · ${hospital?.name ?? 'Your hospital'}',
      children: [
        LayoutBuilder(builder: (context, box) {
          final cols = box.maxWidth >= 900 ? 4 : (box.maxWidth >= 520 ? 2 : 1);
          final w = (box.maxWidth - (cols - 1) * 12) / cols;
          final tiles = [
            StatTile(label: 'Open requests', value: '${open.length}', sub: critical.isEmpty ? 'None critical' : '${critical.length} critical · ${critical.first.bloodGroup}', subColor: critical.isEmpty ? null : c.textDanger),
            StatTile(label: 'Checked in today', value: '${today.length}', sub: '$inBays in bays now'),
            StatTile(label: 'Collected this week', value: '$thisWeek', sub: weekDelta == null ? 'No earlier week to compare' : '${weekDelta >= 0 ? '+' : '−'}${weekDelta.abs()}% vs last week', subColor: weekDelta == null ? null : (weekDelta >= 0 ? c.textSuccess : c.textWarning)),
            StatTile(label: 'Expiring in 72 h', value: '${expiring.length}', sub: expiringTomorrow.isEmpty ? 'Nothing tomorrow' : '${expiringTomorrow.length} expiring tomorrow', subColor: expiring.isEmpty ? null : c.textWarning),
          ];
          return Wrap(spacing: 12, runSpacing: 12, children: [for (final t in tiles) SizedBox(width: w, child: t)]);
        }),
        const SizedBox(height: 16),
        ResponsiveRow(flex: const [3, 2], children: [
          Column(children: [
            Panel(
              title: 'Inventory',
              trailing: TextButton(onPressed: () => context.go('/admin/inventory'), child: const Text('View all')),
              child: inventory.isEmpty
                  ? Text('No stock recorded yet. Open Inventory to set it up.', style: TextStyle(color: c.textSecondary))
                  : LayoutBuilder(builder: (context, box) {
                      final cols = box.maxWidth >= 560 ? 4 : 2;
                      final w = (box.maxWidth - (cols - 1) * 10) / cols;
                      return Wrap(spacing: 10, runSpacing: 10, children: [for (final r in inventory) SizedBox(width: w, child: _StockTile(r))]);
                    }),
            ),
            const SizedBox(height: 16),
            Panel(
              title: 'Open requests',
              padding: EdgeInsets.zero,
              trailing: TextButton(onPressed: () => context.go('/admin/requests'), child: const Text('View all')),
              child: open.isEmpty
                  ? Padding(padding: const EdgeInsets.all(16), child: Text('No open requests. Use Quick post to ask donors for blood.', style: TextStyle(color: c.textSecondary)))
                  : Column(children: [for (final (i, r) in open.take(5).indexed) _RequestRow(r, divider: i > 0, onTap: () => context.go('/admin/requests?id=${r.id}'))]),
            ),
          ]),
          Column(children: [
            Panel(
              title: "Today's queue",
              padding: EdgeInsets.zero,
              trailing: TextButton(onPressed: () => context.go('/admin/checkin'), child: const Text('Check in')),
              child: queue.isEmpty
                  ? Padding(padding: const EdgeInsets.all(16), child: Text('Nobody waiting.', style: TextStyle(color: c.textSecondary)))
                  : Column(children: [for (final (i, x) in queue.take(6).indexed) _QueueRow(x, divider: i > 0)]),
            ),
            const SizedBox(height: 16),
            const _QuickPost(),
          ]),
        ]),
      ],
    );
  }
}

class _StockTile extends StatelessWidget {
  const _StockTile(this.r);
  final InventoryRow r;

  @override
  Widget build(BuildContext context) {
    final c = context.rc;
    final role = stockRole(r);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.surface0, borderRadius: BorderRadius.circular(RRadius.base), border: Border.all(color: c.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          BloodPill(r.group, role: role, height: 24, size: 12),
          const Spacer(),
          Text(stockLabel(r), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: roleColor(c, role))),
        ]),
        const SizedBox(height: 10),
        Text('${r.units} units', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        Text('target ${r.target}', style: TextStyle(fontSize: 11, color: c.textMuted)),
        const SizedBox(height: 8),
        RProgress(r.ratio, color: roleColor(c, role)),
      ]),
    );
  }
}

class _RequestRow extends StatelessWidget {
  const _RequestRow(this.r, {required this.divider, required this.onTap});
  final BloodRequest r;
  final bool divider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.rc;
    final role = r.urgency == Urgency.critical ? PillRole.danger : (r.urgency == Urgency.urgent ? PillRole.warning : PillRole.neutral);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(border: Border(left: BorderSide(color: urgencyColor(c, r.urgency), width: 2), top: divider ? BorderSide(color: c.border) : BorderSide.none)),
        child: Row(children: [
          BloodPill(r.bloodGroup, role: role, height: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('${r.committed} of ${r.bagsNeeded} committed${r.note.isEmpty ? '' : ' · ${r.note}'}', style: TextStyle(fontSize: 12, color: c.textSecondary)),
            ]),
          ),
          Text(urgencyLabel(r.urgency), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: urgencyText(c, r.urgency))),
        ]),
      ),
    );
  }
}

class _QueueRow extends StatelessWidget {
  const _QueueRow(this.x, {required this.divider});
  final CheckIn x;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final c = context.rc;
    final (label, bg, fg) = switch (x.status) {
      CheckInStatus.waiting => ('Waiting', c.surface2, c.textSecondary),
      CheckInStatus.screening => ('Screening', c.bgWarning, c.textWarning),
      CheckInStatus.donating => ('Donating', c.bgBrand, c.textBrand),
      CheckInStatus.done => ('Done', c.bgSuccess, c.textSuccess),
      CheckInStatus.deferred => ('Deferred', c.bgWarning, c.textWarning),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(border: divider ? Border(top: BorderSide(color: c.border)) : null),
      child: Row(children: [
        DonorAvatar(x.donorName.isEmpty ? '?' : x.donorName.substring(0, 1), size: 36),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(x.donorName, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('${x.group} · ${x.bay != null ? 'bay ${x.bay}' : DateFormat('h:mm a').format(x.at)}', style: TextStyle(fontSize: 12, color: c.textSecondary)),
          ]),
        ),
        Container(
          height: 24, padding: const EdgeInsets.symmetric(horizontal: 10), alignment: Alignment.center,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
          child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
        ),
      ]),
    );
  }
}

/// Post the common case in a few taps; complex requests go through the Requests screen.
class _QuickPost extends ConsumerStatefulWidget {
  const _QuickPost();
  @override
  ConsumerState<_QuickPost> createState() => _QuickPostState();
}

class _QuickPostState extends ConsumerState<_QuickPost> {
  String _group = 'B−';
  int _units = 4;
  Urgency _urgency = Urgency.urgent;
  String? _posted;
  bool _busy = false;

  Future<void> _post() async {
    final access = ref.read(adminAccessProvider).value;
    final hospital = ref.read(hospitalProvider).value;
    if (access == null) return;
    setState(() => _busy = true);
    try {
      final hours = switch (_urgency) { Urgency.critical => 6, Urgency.urgent => 24, Urgency.routine => 72 };
      await ref.read(adminRepositoryProvider).postHospitalRequest(
            access.hospitalId,
            hospital?.name ?? 'Hospital',
            BloodRequest(
              id: '', bloodGroup: _group, title: '$_units bag${_units == 1 ? '' : 's'} of $_group', place: hospital?.name ?? 'Hospital',
              distanceKm: 0, bagsNeeded: _units, committed: 0, urgency: _urgency, deadline: DateTime.now().add(Duration(hours: hours)),
            ),
          );
      if (mounted) setState(() => _posted = '$_units bag${_units == 1 ? '' : 's'} of $_group');
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't post the request. Try again.")));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rc;
    return Panel(
      title: 'Quick post',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final g in bloodGroups) PickChip(g, selected: g == _group, onTap: () => setState(() {
                _group = g;
                _posted = null;
              })),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          const Expanded(child: Text('Units needed', style: TextStyle(fontWeight: FontWeight.w500))),
          CircleIconButton(icon: TablerIcons.minus, size: 36, label: 'Fewer', onPressed: _units > 1 ? () => setState(() => _units--) : null),
          SizedBox(width: 44, child: Center(child: Text('$_units', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)))),
          CircleIconButton(icon: TablerIcons.plus, size: 36, label: 'More', onPressed: _units < 20 ? () => setState(() => _units++) : null),
        ]),
        const SizedBox(height: 14),
        Segmented<Urgency>(
          options: const [(Urgency.routine, 'Routine'), (Urgency.urgent, 'Urgent'), (Urgency.critical, 'Critical')],
          value: _urgency,
          onChanged: (v) => setState(() => _urgency = v),
        ),
        const SizedBox(height: 14),
        AdminButton(_busy ? 'Posting…' : 'Post request', onPressed: _busy ? null : _post),
        if (_posted != null) ...[
          const SizedBox(height: 12),
          InfoBanner('Request posted for $_posted. Donors with a matching blood group will see it in the app.', icon: TablerIcons.circle_check, bg: c.bgSuccess, fg: c.textSuccess),
        ],
      ]),
    );
  }
}
