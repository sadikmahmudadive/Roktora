import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:go_router/go_router.dart';
import '../../core/permissions/permissions.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../location/location_picker.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});
  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _name = TextEditingController();
  PickedLocation? _loc;
  String? _group;
  bool _available = true;
  bool _busy = false;

  bool get _valid => _name.text.trim().length >= 2 && _loc != null;

  Future<void> _pickLocation() async {
    final r = await pickLocation(context, title: 'Where are you based?', initial: _loc?.latLng);
    if (r != null && mounted) setState(() => _loc = r);
  }

  Future<void> _create() async {
    final repo = ref.read(repositoryProvider);
    setState(() => _busy = true);
    try {
      await repo.saveProfile(DonorProfile(
        uid: repo.uid!, name: _name.text.trim(), area: _loc!.label, bloodGroup: _group, available: _available,
        lat: _loc!.lat, lng: _loc!.lng,
      ));
      if (mounted) context.go('/eligibility');
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't save your profile. Try again.")));
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rc;
    OutlineInputBorder border(Color col, [double w = 1]) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: col, width: w));
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(24, 8, 24, 24), children: [
              Align(alignment: Alignment.centerLeft, child: CircleIconButton(icon: TablerIcons.arrow_left, label: 'Back', onPressed: () => ref.read(repositoryProvider).signOut())),
              const SizedBox(height: 16),
              const ScreenHeading('Tell us about you', subtitle: 'Four details. Takes about 30 seconds.'),
              const SizedBox(height: 22),
              const Text('Full name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: _name, textCapitalization: TextCapitalization.words, onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  filled: true, fillColor: c.surface1, contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                  enabledBorder: border(c.borderStrong), focusedBorder: border(c.fillBrand, 1.5), hintText: 'e.g. Nusrat Rahman',
                ),
              ),
              const SizedBox(height: 8),
              Text(_name.text.trim().length > 1 ? 'Requesters only see "${DonorProfile(uid: '', name: _name.text, area: '').publicName}"' : 'Requesters only see your first name and last initial',
                  style: TextStyle(fontSize: 12, color: c.textMuted)),
              const SizedBox(height: 22),
              const Text('Your location', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              LocationField(label: _loc?.label, placeholder: 'Set your location on the map', onTap: _pickLocation),
              const SizedBox(height: 6),
              Text('Used to find requests near you. Others only see an approximate area.', style: TextStyle(fontSize: 12, color: c.textMuted)),
              const SizedBox(height: 22),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Blood group', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                Text(_group == null ? 'Not set' : '$_group selected', style: TextStyle(fontSize: 12, color: c.textMuted)),
              ]),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 4, mainAxisSpacing: 8, crossAxisSpacing: 8, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.05,
                children: [for (final g in bloodGroups) _GroupTile(g, selected: g == _group, onTap: () => setState(() => _group = g))],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 46,
                child: OutlinedButton(
                  onPressed: () => setState(() => _group = null),
                  style: OutlinedButton.styleFrom(
                    shape: const StadiumBorder(), foregroundColor: c.textSecondary,
                    backgroundColor: _group == null ? c.bgBrand : null,
                    side: BorderSide(color: _group == null ? c.fillBrand : c.border, width: 1.5),
                  ),
                  child: const Text("I don't know yet — remind me after a test"),
                ),
              ),
              const SizedBox(height: 22),
              SurfaceCard(
                radius: 22,
                child: Row(children: [
                  Container(width: 42, height: 42, decoration: BoxDecoration(color: c.bgSuccess, borderRadius: BorderRadius.circular(14)), child: Icon(TablerIcons.bell_ringing, color: c.textSuccess)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Available to donate', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text('Alerts for your group within 5 km', style: TextStyle(fontSize: 13, color: c.textSecondary)),
                    ]),
                  ),
                  RSwitch(value: _available, onChanged: (v) => setState(() => _available = v), label: 'Available to donate'),
                ]),
              ),
              const SizedBox(height: 22),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(TablerIcons.lock, size: 16, color: c.textSecondary),
                const SizedBox(width: 10),
                Expanded(child: Text('Your exact location and phone stay private. You choose who sees them.', style: TextStyle(fontSize: 13, color: c.textSecondary))),
              ]),
            ]),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
            decoration: BoxDecoration(color: c.glass, border: Border(top: BorderSide(color: c.border))),
            child: PillButton(_busy ? 'Creating…' : 'Create account', onPressed: _valid && !_busy ? _create : null),
          ),
        ]),
      ),
    );
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile(this.label, {required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.rc;
    return Material(
      color: selected ? c.fillBrand : c.surface1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: selected ? c.fillBrand : c.border, width: 1.5)),
      child: InkWell(
        customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        onTap: onTap,
        child: Center(child: Text(label, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: selected ? c.onFill : c.textPrimary))),
      ),
    );
  }
}

class _Step {
  const _Step(this.name, this.q, this.hint, this.opts, this.deferIndex, this.deferText);
  final String name, q, hint, deferText;
  final List<String> opts;
  final int deferIndex;
}

const _steps = [
  _Step('Health', 'Are you feeling well today?', 'No fever, cold, or flu symptoms in the last 7 days.', ['Yes, I feel well', 'Not today'], 1,
      "Rest up first. You can retake this check once you're feeling well."),
  _Step('Last donation', 'When did you last donate blood?', 'Whole-blood donors need at least 4 months between donations.',
      ['Never donated', 'More than 4 months ago', 'Within the last 4 months'], 2, "You'll be ready again 4 months after your last donation. We'll remind you."),
  _Step('Medication', 'Any antibiotics in the last 7 days?', 'Most daily medicines are fine. Antibiotics need a short wait.', ['No', 'Yes'], 1,
      "Wait 7 days after your last dose, then you're good to go."),
  _Step('Procedures', 'Any tattoo, piercing, or surgery in the last 6 months?', 'These need a 6-month wait to keep recipients safe.', ['No', 'Yes'], 1,
      'This needs a 6-month wait. Your passport will show the date.'),
];

class EligibilityScreen extends ConsumerStatefulWidget {
  const EligibilityScreen({super.key});
  @override
  ConsumerState<EligibilityScreen> createState() => _EligibilityScreenState();
}

class _EligibilityScreenState extends ConsumerState<EligibilityScreen> {
  int _step = 0;
  final List<int?> _ans = [null, null, null, null];

  bool get _asking => _step < 4;
  bool get _deferred => [for (var i = 0; i < 4; i++) _ans[i] == _steps[i].deferIndex].any((x) => x);

  Future<void> _next() async {
    if (_step < 4) return setState(() => _step++);
    final p = ref.read(profileProvider).value;
    if (p != null) await ref.read(repositoryProvider).saveProfile(p.copyWith(eligible: !_deferred));
    if (!mounted) return;
    // Ask for location + notifications once, right after onboarding; later retakes go straight home.
    final perms = ref.read(permissionsProvider).value;
    final skip = (perms?.allGranted ?? false) || await primerSeen();
    if (mounted) context.go(skip ? '/home' : '/permissions');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rc;
    final s = _asking ? _steps[_step] : null;
    final a = _asking ? _ans[_step] : null;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(children: [
              CircleIconButton(icon: TablerIcons.arrow_left, label: 'Back', onPressed: () => _step > 0 ? setState(() => _step--) : context.go('/signup')),
              const SizedBox(width: 12),
              Expanded(
                child: Row(children: [
                  for (var i = 0; i < 5; i++)
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220), height: 6, margin: EdgeInsets.only(right: i == 4 ? 0 : 5),
                        decoration: BoxDecoration(color: i <= _step ? c.fillBrand : c.progressTrack, borderRadius: BorderRadius.circular(99)),
                      ),
                    ),
                ]),
              ),
              const SizedBox(width: 12),
              CircleIconButton(icon: TablerIcons.x, label: 'Close', onPressed: () => context.go('/home')),
            ]),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(24, 24, 24, 24), children: [
              if (s != null) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: c.bgBrand, borderRadius: BorderRadius.circular(99)),
                    child: Text('${_step + 1} of 5 · ${s.name}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.textBrand)),
                  ),
                ),
                const SizedBox(height: 12),
                Text(s.q, style: AppTheme.display(context, size: 30)),
                const SizedBox(height: 12),
                Text(s.hint, style: TextStyle(fontSize: 15, color: c.textSecondary, height: 1.4)),
                const SizedBox(height: 24),
                for (var i = 0; i < s.opts.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _OptionCard(s.opts[i], selected: a == i, onTap: () => setState(() => _ans[_step] = i)),
                  ),
                if (a != null && a == s.deferIndex) ...[const SizedBox(height: 14), InfoBanner(s.deferText, icon: TablerIcons.clock_pause, bg: c.bgWarning, fg: c.textWarning)],
              ] else ...[
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(color: _deferred ? c.bgWarning : c.bgSuccess, borderRadius: BorderRadius.circular(24)),
                  child: Icon(_deferred ? TablerIcons.clock_pause : TablerIcons.check, size: 36, color: _deferred ? c.textWarning : c.textSuccess),
                ),
                const SizedBox(height: 14),
                Text(_deferred ? "You can't donate just yet" : "You're eligible to donate", style: AppTheme.display(context, size: 30)),
                const SizedBox(height: 14),
                Text(
                  _deferred
                      ? "Nothing's wrong — some answers need a short wait. Your passport shows when you're ready."
                      : 'Your passport is updated. Requests for your blood group nearby will now reach you.',
                  style: TextStyle(fontSize: 15, color: c.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 24),
                SurfaceCard(
                  padding: EdgeInsets.zero,
                  child: Column(children: [
                    for (var i = 0; i < 4; i++)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(border: i == 0 ? null : Border(top: BorderSide(color: c.border))),
                        child: Row(children: [
                          Icon(_ans[i] == _steps[i].deferIndex ? TablerIcons.clock_pause : TablerIcons.circle_check_filled, size: 20,
                              color: _ans[i] == _steps[i].deferIndex ? c.textWarning : c.textSuccess),
                          const SizedBox(width: 12),
                          Expanded(child: Text(_steps[i].name, style: TextStyle(fontSize: 14, color: c.textSecondary))),
                          Text(_ans[i] == null ? '—' : _steps[i].opts[_ans[i]!], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                  ]),
                ),
                const SizedBox(height: 24),
                Text('This is a pre-check. Staff confirm eligibility with a short exam at the hospital.', style: TextStyle(fontSize: 12, color: c.textMuted)),
              ],
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: PillButton(
              _asking ? (_step == 3 ? 'See result' : 'Continue') : 'Save to passport',
              onPressed: _asking && a == null ? null : _next,
            ),
          ),
        ]),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard(this.label, {required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.rc;
    return Material(
      color: selected ? c.bgBrand : c.surface1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: selected ? c.fillBrand : c.border, width: 1.5)),
      child: InkWell(
        customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(children: [
              Expanded(child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500))),
              Container(
                width: 26, height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle, color: selected ? c.fillBrand : Colors.transparent,
                  border: selected ? null : Border.all(color: c.borderStronger, width: 1.5),
                ),
                child: selected ? const Icon(Icons.check, size: 15, color: Colors.white) : null,
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
