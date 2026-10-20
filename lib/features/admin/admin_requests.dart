import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../home/shell_home.dart' show urgencyColor, urgencyLabel, urgencyText;
import 'admin_models.dart';
import 'admin_providers.dart';
import 'admin_widgets.dart';

class AdminRequestsScreen extends ConsumerStatefulWidget {
  const AdminRequestsScreen({super.key, this.selectedId});
  final String? selectedId;
  @override
  ConsumerState<AdminRequestsScreen> createState() => _AdminRequestsScreenState();
}

class _AdminRequestsScreenState extends ConsumerState<AdminRequestsScreen> {
  String? _sel;
  bool _showClosed = false;

  @override
  void initState() {
    super.initState();
    _sel = widget.selectedId;
  }

  @override
  void didUpdateWidget(AdminRequestsScreen old) {
    super.didUpdateWidget(old);
    if (widget.selectedId != old.selectedId) _sel = widget.selectedId;
  }

  Future<void> _create() async {
    final access = ref.read(adminAccessProvider).value;
    final hospital = ref.read(hospitalProvider).value;
    if (access == null) return;
    final r = await showDialog<BloodRequest>(context: context, builder: (_) => _NewRequestDialog(hospitalName: hospital?.name ?? 'Hospital'));
    if (r == null) return;
    await ref.read(adminRepositoryProvider).postHospitalRequest(access.hospitalId, hospital?.name ?? 'Hospital', r);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request posted.')));
  }

  void _select(BloodRequest r, bool sideBySide) {
    setState(() => _sel = r.id);
    if (!sideBySide) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: context.rc.surface3,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        builder: (_) => DraggableScrollableSheet(
          expand: false, initialChildSize: .8, maxChildSize: .95,
          builder: (ctx, scroll) => Consumer(builder: (ctx, ref, _) {
            final current = (ref.watch(hospitalRequestsProvider).value ?? const <BloodRequest>[]).where((x) => x.id == r.id).firstOrNull ?? r;
            return SingleChildScrollView(controller: scroll, padding: const EdgeInsets.all(20), child: RequestDetail(current, onClose: () => Navigator.pop(ctx)));
          }),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rc;
    final all = ref.watch(hospitalRequestsProvider).value ?? const <BloodRequest>[];
    final open = all.where((r) => r.isOpen).toList();
    final closed = all.where((r) => !r.isOpen).toList();
    final list = _showClosed ? closed : open;
    final critical = open.where((r) => r.urgency == Urgency.critical).length;
    final selected = all.where((r) => r.id == _sel).firstOrNull;

    return LayoutBuilder(builder: (context, box) {
      final sideBySide = box.maxWidth >= 1100;
      final listPanel = Panel(
        padding: EdgeInsets.zero,
        child: list.isEmpty
            ? Padding(padding: const EdgeInsets.all(20), child: Text(_showClosed ? 'No closed requests yet.' : 'No open requests. Post one to ask donors for blood.', style: TextStyle(color: c.textSecondary)))
            : Column(children: [for (final (i, r) in list.indexed) _Row(r, selected: r.id == _sel, divider: i > 0, onTap: () => _select(r, sideBySide))]),
      );
      return AdminPage(
        title: 'Requests',
        subtitle: '${open.length} open · $critical critical',
        actions: [
          Segmented<bool>(options: const [(false, 'Open'), (true, 'Closed')], value: _showClosed, onChanged: (v) => setState(() => _showClosed = v)),
          AdminButton('New request', icon: TablerIcons.plus, onPressed: _create),
        ],
        children: [
          if (sideBySide)
            ResponsiveRow(flex: const [3, 2], breakpoint: 0, children: [
              listPanel,
              selected == null
                  ? Panel(child: Padding(padding: const EdgeInsets.symmetric(vertical: 40), child: Center(child: Text('Select a request to see who has committed.', style: TextStyle(color: c.textSecondary)))))
                  : Panel(child: RequestDetail(selected, onClose: () => setState(() => _sel = null))),
            ])
          else
            listPanel,
        ],
      );
    });
  }
}

class _Row extends StatelessWidget {
  const _Row(this.r, {required this.selected, required this.divider, required this.onTap});
  final BloodRequest r;
  final bool selected, divider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.rc;
    final role = r.urgency == Urgency.critical ? PillRole.danger : (r.urgency == Urgency.urgent ? PillRole.warning : PillRole.neutral);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? c.bgBrand : null,
          border: Border(left: BorderSide(color: urgencyColor(c, r.urgency), width: 2), top: divider ? BorderSide(color: c.border) : BorderSide.none),
        ),
        child: Row(children: [
          BloodPill(r.bloodGroup, role: role, height: 26),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('${r.note.isEmpty ? r.place : r.note} · by ${DateFormat('d MMM, h:mm a').format(r.deadline)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.textSecondary)),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${r.committed} of ${r.bagsNeeded} committed', style: TextStyle(fontSize: 12, color: c.textSecondary)),
              const SizedBox(height: 4),
              RProgress(r.progress),
            ]),
          ),
          const SizedBox(width: 12),
          SizedBox(width: 64, child: Text(r.isOpen ? urgencyLabel(r.urgency) : (r.status == 'fulfilled' ? 'Fulfilled' : 'Closed'), textAlign: TextAlign.right, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: r.isOpen ? urgencyText(c, r.urgency) : c.textMuted))),
        ]),
      ),
    );
  }
}

/// Who has committed to a request, with actions to fulfil or close it.
class RequestDetail extends ConsumerWidget {
  const RequestDetail(this.r, {super.key, required this.onClose});
  final BloodRequest r;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.rc;
    final repo = ref.read(adminRepositoryProvider);
    final checkins = ref.watch(checkinsProvider).value ?? const <CheckIn>[];
    final role = r.urgency == Urgency.critical ? PillRole.danger : (r.urgency == Urgency.urgent ? PillRole.warning : PillRole.neutral);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        BloodPill(r.bloodGroup, role: role, height: 28, size: 14),
        const SizedBox(width: 8),
        Text(r.isOpen ? urgencyLabel(r.urgency) : (r.status == 'fulfilled' ? 'Fulfilled' : 'Closed'), style: TextStyle(fontWeight: FontWeight.w600, color: r.isOpen ? urgencyText(c, r.urgency) : c.textMuted)),
        const Spacer(),
        IconButton(tooltip: 'Close panel', icon: const Icon(TablerIcons.x, size: 18), onPressed: onClose),
      ]),
      Text(r.title, style: AppTheme.display(context, size: 24)),
      const SizedBox(height: 4),
      Text('${r.note.isEmpty ? r.place : r.note}${r.createdAt == null ? '' : ' · posted ${DateFormat('d MMM, h:mm a').format(r.createdAt!)}'}', style: TextStyle(color: c.textSecondary)),
      const SizedBox(height: 16),
      Row(children: [
        _Fact('Needed by', DateFormat('d MMM, h:mm a').format(r.deadline)),
        const SizedBox(width: 24),
        _Fact('Committed', '${r.committed} of ${r.bagsNeeded}'),
      ]),
      const SizedBox(height: 10),
      RProgress(r.progress),
      const SizedBox(height: 20),
      const Text('Committed donors', style: TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      if (r.committedUids.isEmpty)
        Text('Nobody has committed yet.', style: TextStyle(color: c.textSecondary))
      else
        FutureBuilder<List<DonorEntry>>(
          future: repo.donorLookup(r.committedUids),
          builder: (context, snap) {
            final donors = snap.data ?? const <DonorEntry>[];
            if (snap.connectionState != ConnectionState.done) return const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator());
            if (donors.isEmpty) return Text('${r.committedUids.length} donor${r.committedUids.length == 1 ? '' : 's'} committed.', style: TextStyle(color: c.textSecondary));
            return Column(children: [
              for (final (i, d) in donors.indexed)
                Builder(builder: (context) {
                  final ci = checkins.where((x) => (x.donorUid.isNotEmpty && x.donorUid == d.uid) || x.donorName == d.name).firstOrNull;
                  final (label, bg, fg) = switch (ci?.status) {
                    CheckInStatus.done => ('Donated', c.bgSuccess, c.textSuccess),
                    CheckInStatus.donating => ('Donating', c.bgBrand, c.textBrand),
                    CheckInStatus.screening || CheckInStatus.waiting => ('Checked in', c.bgSuccess, c.textSuccess),
                    CheckInStatus.deferred => ('Deferred', c.bgWarning, c.textWarning),
                    null => ('Committed', c.surface2, c.textSecondary),
                  };
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(border: i == 0 ? null : Border(top: BorderSide(color: c.border))),
                    child: Row(children: [
                      DonorAvatar(d.initials, size: 36),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(d.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text('${d.group} · ${d.area}', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                      ])),
                      Container(height: 24, padding: const EdgeInsets.symmetric(horizontal: 10), alignment: Alignment.center, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)), child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg))),
                    ]),
                  );
                }),
            ]);
          },
        ),
      const SizedBox(height: 20),
      Wrap(spacing: 8, runSpacing: 8, children: [
        if (r.isOpen) ...[
          AdminButton('Mark fulfilled', icon: TablerIcons.check, onPressed: () => repo.setRequestStatus(r.id, 'fulfilled')),
          AdminButton('Close request', outlined: true, onPressed: () => repo.setRequestStatus(r.id, 'closed')),
        ] else
          AdminButton('Reopen', outlined: true, onPressed: () => repo.setRequestStatus(r.id, 'open')),
      ]),
    ]);
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 12, color: context.rc.textMuted)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ]);
}

class _NewRequestDialog extends StatefulWidget {
  const _NewRequestDialog({required this.hospitalName});
  final String hospitalName;
  @override
  State<_NewRequestDialog> createState() => _NewRequestDialogState();
}

class _NewRequestDialogState extends State<_NewRequestDialog> {
  final _title = TextEditingController();
  final _note = TextEditingController();
  String _group = 'O−';
  int _units = 2;
  Urgency _urgency = Urgency.urgent;

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final valid = _title.text.trim().length > 3;
    return AlertDialog(
      title: const Text('New blood request'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(controller: _title, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'What is it for?', hintText: 'e.g. 3 bags for cardiac surgery')),
            const SizedBox(height: 12),
            TextField(controller: _note, decoration: const InputDecoration(labelText: 'Ward or department (optional)')),
            const SizedBox(height: 16),
            const Text('Blood group', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [for (final g in bloodGroups) PickChip(g, selected: g == _group, onTap: () => setState(() => _group = g))]),
            const SizedBox(height: 16),
            Row(children: [
              const Expanded(child: Text('Units needed', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
              CircleIconButton(icon: TablerIcons.minus, size: 36, label: 'Fewer', onPressed: _units > 1 ? () => setState(() => _units--) : null),
              SizedBox(width: 40, child: Center(child: Text('$_units', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)))),
              CircleIconButton(icon: TablerIcons.plus, size: 36, label: 'More', onPressed: _units < 30 ? () => setState(() => _units++) : null),
            ]),
            const SizedBox(height: 16),
            Segmented<Urgency>(
              options: const [(Urgency.routine, 'Routine'), (Urgency.urgent, 'Urgent'), (Urgency.critical, 'Critical')],
              value: _urgency,
              onChanged: (v) => setState(() => _urgency = v),
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          onPressed: !valid
              ? null
              : () {
                  final hours = switch (_urgency) { Urgency.critical => 6, Urgency.urgent => 24, Urgency.routine => 72 };
                  Navigator.pop(
                    context,
                    BloodRequest(
                      id: '', bloodGroup: _group, title: _title.text.trim(), place: widget.hospitalName, note: _note.text.trim(), distanceKm: 0,
                      bagsNeeded: _units, committed: 0, urgency: _urgency, deadline: DateTime.now().add(Duration(hours: hours)),
                    ),
                  );
                },
          child: const Text('Post request'),
        ),
      ],
    );
  }
}
