import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../location/location_picker.dart';

/// Lets donors correct their name, area, blood group and availability after sign-up.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});
  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _name = TextEditingController();
  PickedLocation? _loc;
  String _areaLabel = '';
  String? _group;
  bool _available = true;
  bool _loaded = false;
  bool _busy = false;

  void _load(DonorProfile p) {
    _name.text = p.name;
    _areaLabel = p.area;
    if (p.hasLocation) _loc = PickedLocation(lat: p.lat!, lng: p.lng!, label: p.area);
    _group = p.bloodGroup;
    _available = p.available;
    _loaded = true;
  }

  bool get _valid => _name.text.trim().length >= 2;

  Future<void> _pickLocation() async {
    final r = await pickLocation(context, title: 'Update your location', initial: _loc?.latLng);
    if (r != null && mounted) setState(() => _loc = r);
  }

  Future<void> _save(DonorProfile p) async {
    setState(() => _busy = true);
    try {
      var next = p.copyWith(name: _name.text.trim(), available: _available);
      if (_loc != null) next = next.copyWith(area: _loc!.label, lat: _loc!.lat, lng: _loc!.lng);
      if (_group != null) next = next.copyWith(bloodGroup: _group);
      await ref.read(repositoryProvider).saveProfile(next);
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/profile');
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated.')));
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't save your changes. Try again.")));
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
    final p = ref.watch(profileProvider).value;
    if (p == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (!_loaded) _load(p);

    OutlineInputBorder border(Color col, [double w = 1]) => OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: col, width: w));
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: Align(alignment: Alignment.centerLeft, child: CircleIconButton(icon: TablerIcons.arrow_left, label: 'Back', onPressed: () => context.pop()))),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(24, 16, 24, 24), children: [
              Text('Edit profile', style: AppTheme.display(context, size: 30)),
              const SizedBox(height: 24),
              const Text('Full name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: _name, textCapitalization: TextCapitalization.words, onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                decoration: InputDecoration(filled: true, fillColor: c.surface1, contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18), enabledBorder: border(c.borderStrong), focusedBorder: border(c.fillBrand, 1.5)),
              ),
              const SizedBox(height: 6),
              Text(_name.text.trim().length > 1 ? 'Requesters see "${DonorProfile(uid: '', name: _name.text, area: '').publicName}"' : 'Requesters only see your first name and last initial', style: TextStyle(fontSize: 12, color: c.textMuted)),
              const SizedBox(height: 22),
              const Text('Your location', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              LocationField(label: _loc?.label ?? (_areaLabel.isEmpty ? null : _areaLabel), placeholder: 'Set your location on the map', onTap: _pickLocation),
              const SizedBox(height: 6),
              Text(_loc == null && _areaLabel.isNotEmpty ? 'Tap to pin your exact spot on the map.' : 'Others only see an approximate area.', style: TextStyle(fontSize: 12, color: c.textMuted)),
              const SizedBox(height: 22),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Blood group', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                Text(_group == null ? 'Not set' : '$_group', style: TextStyle(fontSize: 12, color: c.textMuted)),
              ]),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final g in bloodGroups)
                  ChoiceChip(
                    label: Text(g), selected: g == _group, showCheckmark: false, onSelected: (_) => setState(() => _group = g),
                    shape: const StadiumBorder(), selectedColor: c.fillBrand, backgroundColor: c.surface1,
                    side: BorderSide(color: g == _group ? c.fillBrand : c.borderStrong),
                    labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: g == _group ? c.onFill : c.textPrimary),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
              ]),
              if (p.bloodGroup != null && _group != p.bloodGroup) ...[
                const SizedBox(height: 12),
                InfoBanner('Changing your blood group changes which requests reach you. Only change it if it was entered wrong, and confirm it with a blood test.', icon: TablerIcons.alert_triangle, bg: c.bgWarning, fg: c.textWarning),
              ],
              const SizedBox(height: 22),
              SurfaceCard(
                child: Row(children: [
                  Container(width: 42, height: 42, decoration: BoxDecoration(color: c.bgSuccess, borderRadius: BorderRadius.circular(14)), child: Icon(TablerIcons.bell_ringing, color: c.textSuccess)),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Available to donate', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text('Alerts for your group within 5 km', style: TextStyle(fontSize: 13, color: c.textSecondary)),
                  ])),
                  RSwitch(value: _available, onChanged: (v) => setState(() => _available = v), label: 'Available to donate'),
                ]),
              ),
            ]),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(24, 8, 24, 24), child: PillButton(_busy ? 'Saving…' : 'Save changes', onPressed: _valid && !_busy ? () => _save(p) : null)),
        ]),
      ),
    );
  }
}
