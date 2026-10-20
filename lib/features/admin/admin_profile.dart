import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import 'admin_models.dart';
import 'admin_providers.dart';
import 'admin_widgets.dart';

class AdminProfileScreen extends ConsumerStatefulWidget {
  const AdminProfileScreen({super.key});
  @override
  ConsumerState<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends ConsumerState<AdminProfileScreen> {
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _about = TextEditingController();
  String? _loadedFor;
  bool _busy = false;
  bool _saved = false;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _phone.dispose();
    _about.dispose();
    super.dispose();
  }

  void _load(HospitalProfile h) {
    if (_loadedFor == h.id) return;
    _loadedFor = h.id;
    _name.text = h.name;
    _address.text = h.address;
    _phone.text = h.phone;
    _about.text = h.about;
  }

  Future<void> _save(HospitalProfile h) async {
    setState(() {
      _busy = true;
      _saved = false;
    });
    try {
      await ref.read(adminRepositoryProvider).saveHospital(HospitalProfile(
            id: h.id, name: _name.text.trim(), address: _address.text.trim(), phone: _phone.text.trim(), about: _about.text.trim(),
            verified: h.verified, steps: h.steps, docs: h.docs, staff: h.staff,
          ));
      if (mounted) setState(() => _saved = true);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't save. Check your connection and try again.")));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rc;
    final h = ref.watch(hospitalProvider).value;
    final canEdit = ref.watch(adminAccessProvider).value?.isAdmin ?? false;
    if (h == null) return const AdminPage(title: 'Hospital profile', children: [Center(child: CircularProgressIndicator())]);
    _load(h);

    InputDecoration dec(String label) => InputDecoration(labelText: label, filled: true, fillColor: c.surface0, border: OutlineInputBorder(borderRadius: BorderRadius.circular(RRadius.base)));

    return AdminPage(
      title: 'Hospital profile',
      subtitle: 'Public details and verification',
      children: [
        ResponsiveRow(flex: const [3, 2], children: [
          Column(children: [
            Panel(
              title: 'Public details',
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(width: 52, height: 52, decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(18)), child: Icon(TablerIcons.building_hospital, color: c.textSecondary, size: 26)),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(h.name, style: AppTheme.display(context, size: 22)),
                    if (h.verified) const VerifiedBadge() else Text('Not verified yet', style: TextStyle(color: c.textMuted)),
                  ])),
                ]),
                const SizedBox(height: 18),
                TextField(controller: _name, enabled: canEdit, decoration: dec('Hospital name')),
                const SizedBox(height: 12),
                TextField(controller: _address, enabled: canEdit, decoration: dec('Address')),
                const SizedBox(height: 12),
                TextField(controller: _phone, enabled: canEdit, keyboardType: TextInputType.phone, decoration: dec('Blood bank phone')),
                const SizedBox(height: 12),
                TextField(controller: _about, enabled: canEdit, minLines: 3, maxLines: 5, decoration: dec('About')),
                const SizedBox(height: 14),
                if (canEdit)
                  Row(children: [
                    AdminButton(_busy ? 'Saving…' : 'Save changes', onPressed: _busy ? null : () => _save(h)),
                    if (_saved) ...[const SizedBox(width: 12), Icon(TablerIcons.circle_check, size: 18, color: c.textSuccess), const SizedBox(width: 6), Text('Saved', style: TextStyle(color: c.textSuccess, fontWeight: FontWeight.w600))],
                  ])
                else
                  Text('Only admins can edit these details.', style: TextStyle(fontSize: 12, color: c.textMuted)),
              ]),
            ),
            const SizedBox(height: 16),
            Panel(
              title: 'Staff',
              padding: EdgeInsets.zero,
              child: h.staff.isEmpty
                  ? Padding(padding: const EdgeInsets.all(16), child: Text('No staff listed.', style: TextStyle(color: c.textSecondary)))
                  : Column(children: [
                      for (final (i, s) in h.staff.indexed)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(border: i == 0 ? null : Border(top: BorderSide(color: c.border))),
                          child: Row(children: [
                            DonorAvatar(s.initials, size: 36),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text(s.role, style: TextStyle(fontSize: 12, color: c.textSecondary)),
                            ])),
                            if (s.twoFa) BloodPill('2FA on', role: PillRole.success, height: 24, size: 12),
                          ]),
                        ),
                    ]),
            ),
          ]),
          Column(children: [
            Panel(
              title: 'Verification',
              child: h.steps.isEmpty
                  ? Text('Verification steps will appear here.', style: TextStyle(color: c.textSecondary))
                  : Column(children: [
                      for (final (i, s) in h.steps.indexed)
                        IntrinsicHeight(
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Column(children: [
                              Container(
                                width: 22, height: 22,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: s.done ? c.fillBrand : Colors.transparent, border: s.done ? null : Border.all(color: c.borderStronger)),
                                child: s.done ? const Icon(Icons.check, size: 13, color: Colors.white) : null,
                              ),
                              if (i != h.steps.length - 1) Expanded(child: Container(width: 2, color: c.borderAccent)),
                            ]),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(s.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  Text(s.when, style: TextStyle(fontSize: 12, color: s.done ? c.textMuted : c.textWarning)),
                                ]),
                              ),
                            ),
                          ]),
                        ),
                    ]),
            ),
            const SizedBox(height: 16),
            Panel(
              title: 'Documents',
              padding: EdgeInsets.zero,
              child: h.docs.isEmpty
                  ? Padding(padding: const EdgeInsets.all(16), child: Text('No documents on file.', style: TextStyle(color: c.textSecondary)))
                  : Column(children: [
                      for (final (i, d) in h.docs.indexed)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(border: i == 0 ? null : Border(top: BorderSide(color: c.border))),
                          child: Row(children: [
                            Expanded(child: Text(d.name, style: const TextStyle(fontWeight: FontWeight.w500))),
                            BloodPill(d.status, role: d.warning ? PillRole.warning : PillRole.success, height: 24, size: 12),
                          ]),
                        ),
                    ]),
            ),
          ]),
        ]),
      ],
    );
  }
}
