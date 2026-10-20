import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import 'admin_models.dart';
import 'admin_providers.dart';
import 'admin_widgets.dart';

// ------------------------------------------------------------------ donors

class AdminDonorsScreen extends ConsumerStatefulWidget {
  const AdminDonorsScreen({super.key});
  @override
  ConsumerState<AdminDonorsScreen> createState() => _AdminDonorsScreenState();
}

class _AdminDonorsScreenState extends ConsumerState<AdminDonorsScreen> {
  String _group = 'All';
  bool _eligibleOnly = false;
  final _selected = <String>{};
  bool _composing = false;
  final _body = TextEditingController();
  int? _sent;
  bool _sending = false;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _send(List<DonorEntry> all) async {
    final hospital = ref.read(hospitalProvider).value;
    final text = _body.text.trim();
    if (text.isEmpty) return;
    final uids = _selected.toList();
    setState(() => _sending = true);
    try {
      await ref.read(adminRepositoryProvider).sendBulkMessage(
            hospitalName: hospital?.name ?? 'Your hospital',
            uids: uids,
            title: 'Message from ${hospital?.name ?? 'a hospital'}',
            body: text,
          );
      if (mounted) {
        setState(() {
          _sent = uids.length;
          _selected.clear();
          _composing = false;
          _body.clear();
        });
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't send the message. Try again.")));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rc;
    final dir = ref.watch(donorDirectoryProvider);
    final all = dir.value ?? const <DonorEntry>[];
    final visible = all.where((d) => (_group == 'All' || d.group == _group) && (!_eligibleOnly || d.eligible)).toList();

    return AdminPage(
      title: 'Donor directory',
      subtitle: '${all.length} registered donor${all.length == 1 ? '' : 's'}',
      children: [
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          for (final g in ['All', ...bloodGroups]) PickChip(g, selected: g == _group, onTap: () => setState(() => _group = g)),
          PickChip('Eligible only', selected: _eligibleOnly, onTap: () => setState(() => _eligibleOnly = !_eligibleOnly)),
        ]),
        const SizedBox(height: 16),
        if (_sent != null) ...[
          InfoBanner('Message sent to $_sent donor${_sent == 1 ? '' : 's'}. It appears in their Roktora inbox.', icon: TablerIcons.circle_check, bg: c.bgSuccess, fg: c.textSuccess),
          const SizedBox(height: 12),
        ],
        if (_selected.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: c.bgAccent, borderRadius: BorderRadius.circular(RRadius.base)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('${_selected.length} selected', style: TextStyle(fontWeight: FontWeight.w600, color: c.textAccent))),
                AdminButton('Clear', outlined: true, height: 34, onPressed: () => setState(() {
                      _selected.clear();
                      _composing = false;
                    })),
                const SizedBox(width: 8),
                AdminButton('Message', icon: TablerIcons.message, height: 34, onPressed: () => setState(() => _composing = true)),
              ]),
              if (_composing) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _body, minLines: 2, maxLines: 4, maxLength: 300, onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(hintText: 'e.g. We urgently need O− donors this week. Thank you.', filled: true, fillColor: c.surface1, border: OutlineInputBorder(borderRadius: BorderRadius.circular(RRadius.base))),
                ),
                Text('Sent in the Roktora app only. Donors choose whether to respond.', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                const SizedBox(height: 10),
                AdminButton(_sending ? 'Sending…' : 'Send to ${_selected.length}', onPressed: _body.text.trim().isEmpty || _sending ? null : () => _send(all)),
              ],
            ]),
          ),
        Panel(
          padding: EdgeInsets.zero,
          child: dir.isLoading
              ? const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
              : dir.hasError
                  ? Padding(padding: const EdgeInsets.all(20), child: Text("Couldn't load donors. Check your connection and that you have staff access.", style: TextStyle(color: c.textSecondary)))
                  : visible.isEmpty
                      ? Padding(padding: const EdgeInsets.all(20), child: Text('No donors match these filters.', style: TextStyle(color: c.textSecondary)))
                      : Column(children: [
                          for (final (i, d) in visible.indexed)
                            InkWell(
                              onTap: () => setState(() {
                                _sent = null;
                                _selected.contains(d.uid) ? _selected.remove(d.uid) : _selected.add(d.uid);
                                if (_selected.isEmpty) _composing = false;
                              }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(color: _selected.contains(d.uid) ? c.bgBrand : null, border: i == 0 ? null : Border(top: BorderSide(color: c.border))),
                                child: Row(children: [
                                  CheckBoxX(checked: _selected.contains(d.uid)),
                                  const SizedBox(width: 12),
                                  DonorAvatar(d.initials, online: d.eligible, size: 36),
                                  const SizedBox(width: 12),
                                  Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(d.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                    Text('${d.area} · ${d.donations} donation${d.donations == 1 ? '' : 's'}', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                                  ])),
                                  BloodPill(d.group, role: roleForGroup(d.group), height: 24, size: 12),
                                  const SizedBox(width: 12),
                                  SizedBox(width: 90, child: Text(d.lastDonation == null ? '—' : DateFormat('d MMM').format(d.lastDonation!), style: TextStyle(fontSize: 12, color: c.textSecondary))),
                                  SizedBox(
                                    width: 100,
                                    child: Text(d.eligible ? 'Eligible' : (d.daysUntilEligible > 0 ? 'In ${d.daysUntilEligible} d' : 'Not eligible'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: d.eligible ? c.textSuccess : c.textWarning)),
                                  ),
                                ]),
                              ),
                            ),
                        ]),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ reports

class AdminReportsScreen extends ConsumerWidget {
  const AdminReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.rc;
    final period = ref.watch(reportPeriodProvider);
    final report = buildReport(
      checkins: ref.watch(checkinsProvider).value ?? const <CheckIn>[],
      requests: ref.watch(hospitalRequestsProvider).value ?? const <BloodRequest>[],
      period: period,
    );

    return AdminPage(
      title: 'Reports',
      subtitle: 'Collections and fulfilment · aggregate only',
      actions: [
        Segmented<ReportPeriod>(
          options: const [(ReportPeriod.weekly, 'Weekly'), (ReportPeriod.monthly, 'Monthly')],
          value: period,
          onChanged: (p) => ref.read(reportPeriodProvider.notifier).set(p),
        ),
      ],
      children: [
        LayoutBuilder(builder: (context, box) {
          final cols = box.maxWidth >= 900 ? 4 : (box.maxWidth >= 520 ? 2 : 1);
          final w = (box.maxWidth - (cols - 1) * 12) / cols;
          return Wrap(spacing: 12, runSpacing: 12, children: [
            for (final k in report.kpis)
              SizedBox(
                width: w,
                child: StatTile(label: k.label, value: k.value.split(' · ').first, sub: k.value.contains(' · ') ? k.value.split(' · ').last : (k.positive == null ? ' ' : (k.positive! ? 'On track' : 'Needs attention')), subColor: k.positive == null ? null : (k.positive! ? c.textSuccess : c.textWarning)),
              ),
          ]);
        }),
        const SizedBox(height: 16),
        ResponsiveRow(flex: const [3, 2], children: [
          Panel(
            title: 'Units collected',
            trailing: Text(report.rangeLabel, style: TextStyle(fontSize: 12, color: c.textMuted)),
            child: SizedBox(
              height: 230,
              child: report.total == 0
                  ? Center(child: Text('No completed donations in this period yet.', style: TextStyle(color: c.textSecondary)))
                  : Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      for (final (i, v) in report.values.indexed)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                              Text('$v', style: TextStyle(fontSize: 11, color: c.textMuted)),
                              const SizedBox(height: 4),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 260),
                                curve: Curves.easeOutCubic,
                                height: (v / report.max * 160).clamp(2, 160).toDouble(),
                                decoration: BoxDecoration(color: i == report.values.length - 1 ? c.fillBrand : c.progressTrack, borderRadius: BorderRadius.circular(6)),
                              ),
                              const SizedBox(height: 6),
                              Text(report.labels[i], style: TextStyle(fontSize: 10, color: c.textMuted)),
                            ]),
                          ),
                        ),
                    ]),
            ),
          ),
          Panel(
            title: 'By blood group',
            child: report.byGroup.isEmpty
                ? Text('Nothing to show yet.', style: TextStyle(color: c.textSecondary))
                : Column(children: [
                    for (final g in report.byGroup)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(children: [
                          SizedBox(width: 48, child: BloodPill(g.$1, role: roleForGroup(g.$1), height: 22, size: 12)),
                          const SizedBox(width: 10),
                          Expanded(child: RProgress(g.$2 / report.byGroup.first.$2, color: c.fillAccent)),
                          SizedBox(width: 36, child: Text('${g.$2}', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                        ]),
                      ),
                  ]),
          ),
        ]),
        const SizedBox(height: 16),
        Text('Reports are aggregate by design: no per-donor figures leave this screen.', style: AppTheme.mono(context, size: 11)),
      ],
    );
  }
}
