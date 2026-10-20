import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:intl/intl.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import 'admin_models.dart';
import 'admin_providers.dart';
import 'admin_widgets.dart';

/// Minimum haemoglobin (g/dL) for a whole-blood donation.
const double minHaemoglobin = 12.5;

class _Donor {
  const _Donor({required this.name, required this.group, this.uid = '', this.entry});
  final String name, group, uid;
  final DonorEntry? entry;
}

/// Desk flow: find the donor, verify on the spot, assign a bay.
class AdminCheckInScreen extends ConsumerStatefulWidget {
  const AdminCheckInScreen({super.key});
  @override
  ConsumerState<AdminCheckInScreen> createState() => _AdminCheckInScreenState();
}

class _AdminCheckInScreenState extends ConsumerState<AdminCheckInScreen> {
  int _step = 0;
  _Donor? _donor;
  final _code = TextEditingController();
  final _walkIn = TextEditingController();
  String _walkInGroup = 'O+';
  final _hb = TextEditingController();
  final _checks = [false, false, false];
  int? _bay;
  String? _lookupError;
  bool _busy = false;
  String? _doneMessage;

  static const _checkLabels = ['Photo ID matches the passport name', 'Blood pressure within range', 'Donor confirmed consent at the desk'];

  @override
  void dispose() {
    _code.dispose();
    _walkIn.dispose();
    _hb.dispose();
    super.dispose();
  }

  void _reset() => setState(() {
        _step = 0;
        _donor = null;
        _bay = null;
        _code.clear();
        _walkIn.clear();
        _hb.clear();
        _checks.fillRange(0, 3, false);
        _lookupError = null;
        _doneMessage = null;
      });

  double? get _hbValue => double.tryParse(_hb.text.trim().replaceAll(',', '.'));
  bool get _verified => _checks.every((x) => x) && (_hbValue ?? 0) >= minHaemoglobin;

  Future<void> _lookupCode() async {
    final raw = _code.text.trim();
    if (raw.isEmpty) return;
    // Passport QR payload: roktora:checkin:<requestId>:<donorUid>
    final uid = raw.startsWith('roktora:checkin:') ? raw.split(':').last : raw;
    final found = await ref.read(adminRepositoryProvider).donorLookup([uid]);
    if (!mounted) return;
    if (found.isEmpty) {
      setState(() => _lookupError = 'No donor found for that code. Check it, or add them as a walk-in below.');
    } else {
      final d = found.first;
      setState(() {
        _lookupError = null;
        _donor = _Donor(name: d.name, group: d.group, uid: d.uid, entry: d);
        _step = 1;
      });
    }
  }

  void _pick(DonorEntry d) => setState(() {
        _donor = _Donor(name: d.name, group: d.group, uid: d.uid, entry: d);
        _step = 1;
      });

  Future<void> _start({required bool defer}) async {
    final access = ref.read(adminAccessProvider).value;
    final d = _donor;
    if (access == null || d == null) return;
    setState(() => _busy = true);
    try {
      final repo = ref.read(adminRepositoryProvider);
      final ci = await repo.startCheckIn(access.hospitalId, donorName: d.name, group: d.group, donorUid: d.uid);
      await repo.updateCheckIn(access.hospitalId, defer ? ci.copyWith(status: CheckInStatus.deferred) : ci.copyWith(status: CheckInStatus.donating, bay: _bay));
      if (mounted) {
        setState(() {
          _doneMessage = defer ? '${d.name} was deferred. No donation recorded.' : '${d.name} is checked in to bay $_bay.';
          _step = 3;
        });
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't save the check-in. Try again.")));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rc;
    final checkins = ref.watch(checkinsProvider).value ?? const <CheckIn>[];
    final inBays = checkins.where((x) => x.status == CheckInStatus.donating).toList();
    final busyBays = {for (final x in inBays) if (x.bay != null) x.bay!};

    return AdminPage(
      title: 'Donor check-in',
      subtitle: 'Find the donor, verify, assign a bay',
      children: [
        ResponsiveRow(flex: const [3, 2], children: [
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                for (final (i, l) in ['Find', 'Verify', 'Assign bay'].indexed)
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(height: 4, margin: EdgeInsets.only(right: i == 2 ? 0 : 6), decoration: BoxDecoration(color: i <= _step.clamp(0, 2) ? c.fillBrand : c.progressTrack, borderRadius: BorderRadius.circular(99))),
                      const SizedBox(height: 8),
                      Text('${i + 1}. $l', style: TextStyle(fontSize: 12, color: i == _step ? c.textPrimary : c.textMuted, fontWeight: i == _step ? FontWeight.w600 : FontWeight.w400)),
                    ]),
                  ),
              ]),
              const SizedBox(height: 20),
              if (_step == 0) _find(c),
              if (_step == 1) _verify(c),
              if (_step == 2) _bays(c, busyBays),
              if (_step == 3) _done(c),
            ]),
          ),
          Panel(
            title: 'In bays now · ${inBays.length}',
            padding: EdgeInsets.zero,
            child: inBays.isEmpty
                ? Padding(padding: const EdgeInsets.all(16), child: Text('No one is donating right now.', style: TextStyle(color: c.textSecondary)))
                : Column(children: [
                    for (final (i, x) in inBays.indexed)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(border: i == 0 ? null : Border(top: BorderSide(color: c.border))),
                        child: Row(children: [
                          DonorAvatar(x.donorName.isEmpty ? '?' : x.donorName.substring(0, 1), size: 36),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(x.donorName, style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text('${x.group} · bay ${x.bay ?? '—'} · since ${DateFormat('h:mm a').format(x.at)}', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                          ])),
                          AdminButton('Donated', height: 34, onPressed: () async {
                            final access = ref.read(adminAccessProvider).value;
                            if (access == null) return;
                            await ref.read(adminRepositoryProvider).completeDonation(access.hospitalId, x);
                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Donation recorded for ${x.donorName}. Stock updated.')));
                          }),
                        ]),
                      ),
                  ]),
          ),
        ]),
      ],
    );
  }

  Widget _find(RColors c) {
    final requests = ref.watch(hospitalRequestsProvider).value ?? const <BloodRequest>[];
    final expected = {for (final r in requests.where((r) => r.isOpen)) ...r.committedUids}.toList();
    final repo = ref.read(adminRepositoryProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text("Scan or enter the donor's passport code", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
      const SizedBox(height: 4),
      Text('Paste the code shown under the donor\'s QR, or the full QR text.', style: TextStyle(fontSize: 13, color: c.textSecondary)),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
          child: TextField(
            controller: _code,
            onSubmitted: (_) => _lookupCode(),
            decoration: InputDecoration(
              hintText: 'Donor ID or roktora:checkin:…', filled: true, fillColor: c.surface0,
              suffixIcon: IconButton(icon: const Icon(TablerIcons.clipboard, size: 18), tooltip: 'Paste', onPressed: () async {
                final data = await Clipboard.getData(Clipboard.kTextPlain);
                if (data?.text != null) setState(() => _code.text = data!.text!);
              }),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(RRadius.base)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        AdminButton('Find', onPressed: _lookupCode),
      ]),
      if (_lookupError != null) ...[const SizedBox(height: 10), InfoBanner(_lookupError!, icon: TablerIcons.info_circle, bg: c.bgWarning, fg: c.textWarning)],
      const SizedBox(height: 20),
      const Text('Committed donors', style: TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      if (expected.isEmpty)
        Text('Donors who commit to your requests appear here.', style: TextStyle(color: c.textSecondary))
      else
        FutureBuilder<List<DonorEntry>>(
          future: repo.donorLookup(expected),
          builder: (context, snap) {
            final donors = snap.data ?? const <DonorEntry>[];
            if (donors.isEmpty) return Text(snap.connectionState == ConnectionState.done ? 'No donor details available.' : 'Loading…', style: TextStyle(color: c.textSecondary));
            return Wrap(spacing: 8, runSpacing: 8, children: [
              for (final d in donors.take(8))
                ActionChip(
                  avatar: DonorAvatar(d.initials, size: 24),
                  label: Text('${d.name} · ${d.group}'),
                  onPressed: () => _pick(d),
                  shape: const StadiumBorder(),
                  side: BorderSide(color: c.borderStrong),
                  backgroundColor: c.surface1,
                ),
            ]);
          },
        ),
      const SizedBox(height: 20),
      const Text('Walk-in donor', style: TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      TextField(controller: _walkIn, onChanged: (_) => setState(() {}), textCapitalization: TextCapitalization.words, decoration: InputDecoration(hintText: 'Full name', filled: true, fillColor: c.surface0, border: OutlineInputBorder(borderRadius: BorderRadius.circular(RRadius.base)))),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [for (final g in bloodGroups) PickChip(g, selected: g == _walkInGroup, onTap: () => setState(() => _walkInGroup = g))]),
      const SizedBox(height: 12),
      AdminButton('Continue as walk-in', outlined: true, onPressed: _walkIn.text.trim().length < 2 ? null : () => setState(() {
            _donor = _Donor(name: _walkIn.text.trim(), group: _walkInGroup);
            _step = 1;
          })),
    ]);
  }

  Widget _verify(RColors c) {
    final d = _donor!;
    final e = d.entry;
    final hb = _hbValue;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(RRadius.base)),
        child: Row(children: [
          DonorAvatar(d.name.isEmpty ? '?' : d.name.substring(0, 1), size: 44),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(d.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            Text(e == null ? 'Walk-in · no Roktora passport' : '${e.area} · ${e.donations} donation${e.donations == 1 ? '' : 's'}${e.lastDonation == null ? '' : ' · last ${DateFormat('d MMM yyyy').format(e.lastDonation!)}'}', style: TextStyle(fontSize: 13, color: c.textSecondary)),
          ])),
          BloodPill(d.group, role: roleForGroup(d.group), height: 28, size: 14),
        ]),
      ),
      if (e != null && !e.eligible) ...[
        const SizedBox(height: 12),
        InfoBanner('The app says this donor is not eligible yet${e.daysUntilEligible > 0 ? ' (${e.daysUntilEligible} more days)' : ''}. Confirm at the desk before continuing.', icon: TablerIcons.clock_pause, bg: c.bgWarning, fg: c.textWarning),
      ],
      const SizedBox(height: 16),
      Text('Verify at the desk', style: const TextStyle(fontWeight: FontWeight.w600)),
      for (final (i, label) in _checkLabels.indexed)
        InkWell(
          onTap: () => setState(() => _checks[i] = !_checks[i]),
          child: Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Row(children: [CheckBoxX(checked: _checks[i]), const SizedBox(width: 12), Expanded(child: Text(label))])),
        ),
      const SizedBox(height: 8),
      SizedBox(
        width: 240,
        child: TextField(
          controller: _hb, onChanged: (_) => setState(() {}),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: 'Haemoglobin (g/dL)', hintText: 'e.g. 13.2', filled: true, fillColor: c.surface0, border: OutlineInputBorder(borderRadius: BorderRadius.circular(RRadius.base))),
        ),
      ),
      if (hb != null && hb < minHaemoglobin) ...[
        const SizedBox(height: 10),
        InfoBanner('Below $minHaemoglobin g/dL. This donor should be deferred.', icon: TablerIcons.alert_triangle, bg: c.bgDanger, fg: c.textDanger),
      ],
      const SizedBox(height: 16),
      Wrap(spacing: 8, runSpacing: 8, children: [
        AdminButton('Back', outlined: true, onPressed: () => setState(() => _step = 0)),
        AdminButton('Defer donor', outlined: true, danger: true, onPressed: _busy ? null : () => _start(defer: true)),
        AdminButton('Continue', onPressed: _verified ? () => setState(() => _step = 2) : null),
      ]),
    ]);
  }

  Widget _bays(RColors c, Set<int> busy) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Assign a bay', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
      const SizedBox(height: 12),
      LayoutBuilder(builder: (context, box) {
        final cols = box.maxWidth >= 420 ? 3 : 2;
        final w = (box.maxWidth - (cols - 1) * 10) / cols;
        return Wrap(spacing: 10, runSpacing: 10, children: [
          for (var n = 1; n <= 6; n++)
            SizedBox(
              width: w,
              child: Semantics(
                button: true, label: 'Bay $n, ${busy.contains(n) ? 'busy' : 'free'}',
                child: InkWell(
                  onTap: busy.contains(n) ? null : () => setState(() => _bay = n),
                  borderRadius: BorderRadius.circular(RRadius.base),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: busy.contains(n) ? c.surface2 : (_bay == n ? c.bgBrand : c.surface1),
                      borderRadius: BorderRadius.circular(RRadius.base),
                      border: Border.all(color: _bay == n ? c.fillBrand : c.border, width: _bay == n ? 1.5 : 1),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Bay $n', style: TextStyle(fontWeight: FontWeight.w600, color: busy.contains(n) ? c.textMuted : (_bay == n ? c.textBrand : c.textPrimary))),
                      const SizedBox(height: 4),
                      Row(children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: busy.contains(n) ? c.fillBrand : c.fillSuccess)),
                        const SizedBox(width: 6),
                        Text(busy.contains(n) ? 'Donating' : 'Free', style: TextStyle(fontSize: 12, color: busy.contains(n) ? c.textMuted : c.textSuccess)),
                      ]),
                    ]),
                  ),
                ),
              ),
            ),
        ]);
      }),
      const SizedBox(height: 16),
      Wrap(spacing: 8, runSpacing: 8, children: [
        AdminButton('Back', outlined: true, onPressed: () => setState(() => _step = 1)),
        AdminButton(_busy ? 'Saving…' : 'Start donation', onPressed: _bay == null || _busy ? null : () => _start(defer: false)),
      ]),
    ]);
  }

  Widget _done(RColors c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 56, height: 56, decoration: BoxDecoration(color: c.bgSuccess, borderRadius: BorderRadius.circular(18)), child: Icon(TablerIcons.check, color: c.textSuccess, size: 28)),
        const SizedBox(height: 14),
        Text(_doneMessage ?? 'Done', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
        const SizedBox(height: 4),
        Text('Mark the donation as done from "In bays now" when the bag is collected.', style: TextStyle(color: c.textSecondary)),
        const SizedBox(height: 16),
        AdminButton('Check in another donor', onPressed: _reset),
      ]);
}
