import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../home/shell_home.dart' show kNavClearance;

const _consents = [
  ('I answered the screening questions honestly', 'Required'),
  ('I agree to a hemoglobin and blood pressure check', 'Required'),
  ('My blood can go to any patient who needs it', 'Required · hospitals may reassign within 35 days'),
  ('Share my first name with the recipient family', 'Optional'),
];

class ConsentScreen extends ConsumerStatefulWidget {
  const ConsentScreen({super.key, required this.requestId});
  final String requestId;
  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  final _on = [false, false, false, false];
  bool get _ok => _on[0] && _on[1] && _on[2];

  @override
  Widget build(BuildContext context) {
    final c = context.rc;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: Align(alignment: Alignment.centerLeft, child: CircleIconButton(icon: TablerIcons.arrow_left, label: 'Back', onPressed: () => context.pop()))),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(24, 16, 24, 24), children: [
              const ScreenHeading('Before you donate', subtitle: 'Three quick confirmations so the hospital can use your blood safely.'),
              const SizedBox(height: 24),
              SurfaceCard(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  for (var i = 0; i < _consents.length; i++)
                    InkWell(
                      onTap: () => setState(() => _on[i] = !_on[i]),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(border: i == 0 ? null : Border(top: BorderSide(color: c.border))),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Container(
                            width: 24, height: 24, margin: const EdgeInsets.only(top: 1),
                            decoration: BoxDecoration(color: _on[i] ? c.fillBrand : Colors.transparent, borderRadius: BorderRadius.circular(8), border: _on[i] ? null : Border.all(color: c.borderStronger)),
                            child: _on[i] ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(_consents[i].$1, style: const TextStyle(fontWeight: FontWeight.w500)),
                              Text(_consents[i].$2, style: TextStyle(fontSize: 12, color: c.textMuted)),
                            ]),
                          ),
                        ]),
                      ),
                    ),
                ]),
              ),
            ]),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(24, 8, 24, 24), child: PillButton('Continue to check-in', onPressed: _ok ? () => context.pushReplacement('/checkin/${widget.requestId}') : null)),
        ]),
      ),
    );
  }
}

class CheckInScreen extends ConsumerWidget {
  const CheckInScreen({super.key, required this.requestId});
  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.rc;
    final uid = ref.read(repositoryProvider).uid ?? '';
    final req = ref.watch(requestProvider(requestId)).value;
    final code = 'RK-${(uid.hashCode.abs() % 9000 + 1000)}';
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: Align(alignment: Alignment.centerLeft, child: CircleIconButton(icon: TablerIcons.x, label: 'Close', onPressed: () => context.go('/home')))),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(24, 16, 24, 24), children: [
              const ScreenHeading('Show this at the desk', subtitle: 'Staff scan it to check you in. No phone number needed.'),
              const SizedBox(height: 24),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), border: Border.all(color: c.border)),
                  child: QrImageView(data: 'roktora:checkin:$requestId:$uid', size: 220, padding: EdgeInsets.zero, eyeStyle: const QrEyeStyle(color: Colors.black, eyeShape: QrEyeShape.square), dataModuleStyle: const QrDataModuleStyle(color: Colors.black, dataModuleShape: QrDataModuleShape.square)),
                ),
              ),
              const SizedBox(height: 16),
              Center(child: Text(code, style: AppTheme.mono(context, size: 18, w: FontWeight.w600, color: c.textPrimary))),
              if (req != null) Center(child: Padding(padding: const EdgeInsets.only(top: 4), child: Text(req.place, style: TextStyle(color: c.textSecondary)))),
              const SizedBox(height: 28),
              Row(children: [
                for (final (i, l) in ['Arrived', 'Screening', 'Donating', 'Rest'].indexed)
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(height: 4, margin: EdgeInsets.only(right: i == 3 ? 0 : 6), decoration: BoxDecoration(color: i == 0 ? c.fillBrand : c.progressTrack, borderRadius: BorderRadius.circular(99))),
                      const SizedBox(height: 8),
                      Text(l, style: TextStyle(fontSize: 12, color: i == 0 ? c.textPrimary : c.textMuted)),
                    ]),
                  ),
              ]),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: PillButton('I have donated', onPressed: () async {
              await ref.read(repositoryProvider).recordDonation(DonationRecord(date: DateTime.now(), place: req?.place ?? 'Blood bank', note: req?.title ?? 'Whole blood', status: 'donated'));
              if (context.mounted) context.pushReplacement('/thanks');
            }),
          ),
        ]),
      ),
    );
  }
}

class ThankYouScreen extends ConsumerWidget {
  const ThankYouScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.rc;
    final p = ref.watch(profileProvider).value;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Spacer(),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1), duration: const Duration(milliseconds: 360), curve: Curves.easeOutBack,
              builder: (_, t, child) => Transform.scale(scale: t, child: child),
              child: Container(width: 88, height: 88, decoration: BoxDecoration(color: c.bgSuccess, shape: BoxShape.circle), child: Center(child: Container(width: 56, height: 56, decoration: BoxDecoration(color: c.fillSuccess, shape: BoxShape.circle), child: Icon(TablerIcons.heart_handshake, color: c.onFill, size: 30)))),
            ),
            const SizedBox(height: 24),
            Text('Thank you${p == null ? '' : ', ${p.name.split(' ').first}'}.', style: AppTheme.display(context, size: 40)),
            const SizedBox(height: 12),
            Text('Your donation can help up to three people. Rest, drink water, and skip heavy lifting today.', style: TextStyle(fontSize: 16, color: c.textSecondary, height: 1.4)),
            const Spacer(),
            PillButton('See my recovery', onPressed: () => context.go('/passport')),
            const SizedBox(height: 10),
            PillButton('Back home', outlined: true, onPressed: () => context.go('/home')),
          ]),
        ),
      ),
    );
  }
}

const _recovery = [
  (0, 'Donated', 'Day 0', '450 ml given. Rest, hydrate, skip heavy lifting today.'),
  (2, 'Plasma volume restored', 'Day 1–2', 'Fluids are back to normal. Most donors feel like themselves.'),
  (28, 'Iron stores rebuilding', 'Week 1–4', 'Iron-rich meals matter most now.'),
  (56, 'Red cells replaced', 'Week 4–8', 'Your body has replaced the cells you gave.'),
  (120, 'Ready to donate again', 'Day 120', "We'll send one reminder. No pressure to come back."),
];

class PassportScreen extends ConsumerStatefulWidget {
  const PassportScreen({super.key});
  @override
  ConsumerState<PassportScreen> createState() => _PassportScreenState();
}

class _PassportScreenState extends ConsumerState<PassportScreen> {
  int _tab = 0;

  Widget _myRequests(RColors c, List<BloodRequest> list) {
    if (list.isEmpty) {
      return const SurfaceCard(child: EmptyState(icon: TablerIcons.file_text, title: 'No requests yet', message: 'Requests you post for someone will be listed here.'));
    }
    final repo = ref.read(repositoryProvider);
    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(children: [
        for (final (i, r) in list.indexed)
          InkWell(
            onTap: () => context.push('/request/${r.id}'),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
              decoration: BoxDecoration(border: i == 0 ? null : Border(top: BorderSide(color: c.border))),
              child: Row(children: [
                BloodPill(r.bloodGroup, role: roleForGroup(r.bloodGroup), height: 24, size: 12),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('${r.place} · ${r.committed} of ${r.bagsNeeded} committed', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.textSecondary)),
                  ]),
                ),
                const SizedBox(width: 8),
                BloodPill(
                  switch (r.status) { 'fulfilled' => 'Fulfilled', 'closed' => 'Closed', _ => 'Open' },
                  role: switch (r.status) { 'fulfilled' => PillRole.success, 'closed' => PillRole.neutral, _ => PillRole.warning },
                  height: 24, size: 12,
                ),
                PopupMenuButton<String>(
                  tooltip: 'Manage request',
                  icon: Icon(TablerIcons.dots_vertical, size: 20, color: c.textMuted),
                  onSelected: (v) => repo.setRequestStatus(r.id, v),
                  itemBuilder: (_) => [
                    if (r.isOpen) const PopupMenuItem(value: 'fulfilled', child: Text('Mark fulfilled')),
                    if (r.isOpen) const PopupMenuItem(value: 'closed', child: Text('Close request')),
                    if (!r.isOpen) const PopupMenuItem(value: 'open', child: Text('Reopen')),
                  ],
                ),
              ]),
            ),
          ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rc;
    final p = ref.watch(profileProvider).value;
    final history = ref.watch(donationsProvider).value ?? const <DonationRecord>[];
    final last = p?.lastDonation;
    final day = last == null ? null : DateTime.now().difference(last).inDays;
    final curIdx = day == null ? -1 : _recovery.indexWhere((t) => t.$1 > day);

    return SafeArea(
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, kNavClearance), children: [
        Padding(padding: const EdgeInsets.only(left: 4, bottom: 16), child: Text('Passport', style: AppTheme.display(context, size: 26))),
        if (day != null) ...[
          SurfaceCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(day >= 120 ? 'Ready to donate' : 'Day $day of 120', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                Text(day >= 120 ? 'Eligible' : '${120 - day} days left', style: TextStyle(fontSize: 13, color: c.textSecondary)),
              ]),
              const SizedBox(height: 12),
              RProgress(day / 120, color: day >= 120 ? c.fillSuccess : c.fillBrand),
              const SizedBox(height: 16),
              for (final (i, t) in _recovery.indexed)
                IntrinsicHeight(
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Column(children: [
                      Container(
                        width: 22, height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: (curIdx == -1 || i < curIdx) ? c.fillSuccess : i == curIdx ? c.bgBrand : Colors.transparent,
                          border: (curIdx == -1 || i < curIdx) ? null : Border.all(color: i == curIdx ? c.fillBrand : c.borderStronger, width: 1.5),
                        ),
                        child: (curIdx == -1 || i < curIdx) ? const Icon(Icons.check, size: 13, color: Colors.white) : null,
                      ),
                      if (i != _recovery.length - 1) Expanded(child: Container(width: 2, color: (curIdx == -1 || i < curIdx) ? c.borderSuccess : c.border)),
                    ]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [Expanded(child: Text(t.$2, style: TextStyle(fontWeight: FontWeight.w600, color: (curIdx != -1 && i > curIdx) ? c.textMuted : c.textPrimary))), Text(t.$3, style: TextStyle(fontSize: 12, color: c.textMuted))]),
                          Text(t.$4, style: TextStyle(fontSize: 13, color: c.textSecondary)),
                        ]),
                      ),
                    ),
                  ]),
                ),
            ]),
          ),
          const SizedBox(height: 16),
        ],
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(99)),
          child: Row(children: [
            for (final (i, l) in ['Donations', 'Your requests'].indexed)
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _tab = i),
                  child: Container(
                    height: 38, alignment: Alignment.center,
                    decoration: BoxDecoration(color: i == _tab ? c.surface1 : null, borderRadius: BorderRadius.circular(99), border: i == _tab ? Border.all(color: c.border) : null),
                    child: Text(l, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: i == _tab ? c.textPrimary : c.textSecondary)),
                  ),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 12),
        if (_tab == 1)
          _myRequests(c, ref.watch(myRequestsProvider).value ?? const <BloodRequest>[])
        else if (history.isEmpty)
          const SurfaceCard(child: EmptyState(icon: TablerIcons.droplet, title: 'No donations yet', message: 'Your first donation will appear here, with your recovery timeline.'))
        else
          SurfaceCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              for (final (i, h) in history.indexed)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(border: i == 0 ? null : Border(top: BorderSide(color: c.border))),
                  child: Row(children: [
                    SizedBox(width: 40, child: Column(children: [
                      Text(DateFormat('dd').format(h.date), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
                      Text(DateFormat('MMM').format(h.date), style: TextStyle(fontSize: 12, color: c.textMuted)),
                    ])),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(h.place, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(h.note, style: TextStyle(fontSize: 13, color: c.textSecondary)),
                    ])),
                    BloodPill(h.status[0].toUpperCase() + h.status.substring(1), role: h.status == 'deferred' ? PillRole.warning : PillRole.success, height: 24, size: 12),
                  ]),
                ),
            ]),
          ),
      ]),
    );
  }
}
