import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/permissions/permissions.dart';
import '../../core/theme/app_theme.dart';
import '../permissions/permissions_screen.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/providers.dart';
import '../admin/admin_providers.dart';
import '../home/shell_home.dart' show kNavClearance;

/// Device-local preference toggles (privacy, notifications), persisted with shared_preferences.
class PrefsNotifier extends Notifier<Map<String, bool>> {
  static const defaults = {'showOnMap': true, 'approxOnly': true, 'critical': true, 'nearby': true, 'quiet': true};

  @override
  Map<String, bool> build() {
    SharedPreferences.getInstance().then((p) {
      state = {for (final k in defaults.keys) k: p.getBool(k) ?? defaults[k]!};
    });
    return defaults;
  }

  Future<void> toggle(String key) async {
    final v = !(state[key] ?? true);
    state = {...state, key: v};
    (await SharedPreferences.getInstance()).setBool(key, v);
  }
}

final prefsProvider = NotifierProvider<PrefsNotifier, Map<String, bool>>(PrefsNotifier.new);

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.rc;
    final p = ref.watch(profileProvider).value;
    if (p == null) return const Center(child: CircularProgressIndicator());
    Widget stat(String v, String l) => Expanded(
          child: Column(children: [Text(v, style: AppTheme.display(context, size: 24)), Text(l, style: TextStyle(fontSize: 12, color: c.textSecondary))]),
        );
    return SafeArea(
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, kNavClearance), children: [
        Padding(padding: const EdgeInsets.only(left: 4, bottom: 16), child: Text('Profile', style: AppTheme.display(context, size: 26))),
        SurfaceCard(
          child: Column(children: [
            Row(children: [
              DonorAvatar(p.initials, size: 64, online: p.available),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
                  Text(p.area, style: TextStyle(fontSize: 13, color: c.textSecondary)),
                  const SizedBox(height: 6),
                  if (p.bloodGroup != null) BloodPill(p.bloodGroup!, role: roleForGroup(p.bloodGroup!), height: 24, size: 12) else Text('Blood group not set', style: TextStyle(fontSize: 12, color: c.textMuted)),
                ]),
              ),
            ]),
            const SizedBox(height: 16),
            Divider(color: c.border, height: 1),
            const SizedBox(height: 16),
            Row(children: [stat('${p.donations}', 'Donations'), stat('${p.donations * 3}', 'Lives helped (up to)'), stat(p.eligible ? 'Now' : 'Soon', 'Next donation')]),
          ]),
        ),
        const SizedBox(height: 16),
        SurfaceCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            _MenuRow(TablerIcons.user_edit, 'Edit profile', onTap: () => context.push('/profile/edit')),
            _MenuRow(TablerIcons.heartbeat, 'Eligibility check', divider: true, onTap: () => context.push('/eligibility')),
            if (ref.watch(adminAccessProvider).value != null)
              _MenuRow(TablerIcons.layout_dashboard, 'Hospital dashboard', divider: true, onTap: () => context.go('/admin')),
            _MenuRow(TablerIcons.settings, 'Settings', divider: true, onTap: () => context.push('/settings')),
          ]),
        ),
        const SizedBox(height: 16),
        PillButton('Sign out', outlined: true, height: 52, onPressed: () => _confirmSignOut(context, ref)),
      ]),
    );
  }
}

Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Sign out?'),
      content: const Text("You'll stop getting alerts on this phone until you sign in again."),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Stay signed in')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign out')),
      ],
    ),
  );
  if (ok == true) await ref.read(repositoryProvider).signOut();
}

Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
  final repo = ref.read(repositoryProvider);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete your account?'),
      content: const Text(
        'This permanently removes your profile, donation history and sign-in. '
        'Requests you posted stay visible until they expire or you close them first.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep my account')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(foregroundColor: ctx.rc.textDanger),
          child: const Text('Delete forever'),
        ),
      ],
    ),
  );
  if (ok != true) return;
  try {
    await repo.deleteAccount(); // the auth stream then sends the router back to login
  } on FirebaseAuthException catch (e) {
    if (!context.mounted) return;
    if (e.code == 'requires-recent-login') {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Sign in again first'),
          content: const Text('For your security, deleting an account needs a recent sign-in. Sign out, sign back in, then try again.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                repo.signOut();
              },
              child: const Text('Sign out'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't delete the account. Try again.")));
    }
  } catch (_) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't delete the account. Check your connection and try again.")));
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow(this.icon, this.label, {required this.onTap, this.divider = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool divider;
  @override
  Widget build(BuildContext context) {
    final c = context.rc;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(border: divider ? Border(top: BorderSide(color: c.border)) : null),
        child: Row(children: [Icon(icon, size: 20, color: c.textSecondary), const SizedBox(width: 14), Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500))), Icon(TablerIcons.chevron_right, size: 18, color: c.textMuted)]),
      ),
    );
  }
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.rc;
    final prefs = ref.watch(prefsProvider);
    final mode = ref.watch(themeModeProvider);

    Widget section(String title, List<Widget> rows) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.fromLTRB(4, 20, 4, 8), child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16))),
          SurfaceCard(padding: EdgeInsets.zero, child: Column(children: rows)),
        ]);
    Widget toggle(String key, String label, String note, {bool divider = true}) => Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(border: divider ? Border(top: BorderSide(color: c.border)) : null),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontWeight: FontWeight.w500)), Text(note, style: TextStyle(fontSize: 12, color: c.textSecondary))])),
            RSwitch(value: prefs[key] ?? true, onChanged: (_) => ref.read(prefsProvider.notifier).toggle(key), label: label),
          ]),
        );

    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
          Align(alignment: Alignment.centerLeft, child: CircleIconButton(icon: TablerIcons.arrow_left, label: 'Back', onPressed: () => context.pop())),
          const SizedBox(height: 12),
          Padding(padding: const EdgeInsets.only(left: 4), child: Text('Settings', style: AppTheme.display(context, size: 30))),
          section('Privacy', [
            toggle('showOnMap', 'Show me on the donor map', 'Requesters see your block, not your address', divider: false),
            toggle('approxOnly', 'Share approximate location only', 'Rounded to about 300 m'),
          ]),
          section('Notifications', [
            toggle('critical', 'Critical requests', 'Your group, within 5 km — even in quiet hours', divider: false),
            toggle('nearby', 'Other nearby requests', 'Batched, at most twice a day'),
            toggle('quiet', 'Quiet hours', '11 pm to 7 am'),
          ]),
          section('Permissions', [
            _PermissionRow(permission: AppPermission.location, icon: TablerIcons.map_pin, label: 'Location', note: 'Nearby requests and donors', divider: false),
            const _PermissionRow(permission: AppPermission.notifications, icon: TablerIcons.bell_ringing, label: 'Notifications', note: 'Alerts for matching requests'),
          ]),
          section('Appearance', [
            for (final (i, m) in [(ThemeMode.system, 'Match system'), (ThemeMode.light, 'Light'), (ThemeMode.dark, 'Dark')].indexed)
              InkWell(
                onTap: () => ref.read(themeModeProvider.notifier).set(m.$1),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(border: i == 0 ? null : Border(top: BorderSide(color: c.border))),
                  child: Row(children: [Expanded(child: Text(m.$2, style: const TextStyle(fontWeight: FontWeight.w500))), if (mode == m.$1) Icon(TablerIcons.check, color: c.textBrand)]),
                ),
              ),
          ]),
          section('Account', [
            InkWell(
              onTap: () => _deleteAccount(context, ref),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Icon(TablerIcons.trash, size: 20, color: c.textDanger),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Delete account', style: TextStyle(fontWeight: FontWeight.w500, color: c.textDanger)),
                      Text('Removes your profile and history', style: TextStyle(fontSize: 12, color: c.textSecondary)),
                    ]),
                  ),
                ]),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _PermissionRow extends ConsumerWidget {
  const _PermissionRow({required this.permission, required this.icon, required this.label, required this.note, this.divider = true});
  final AppPermission permission;
  final IconData icon;
  final String label, note;
  final bool divider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.rc;
    final snap = ref.watch(permissionsProvider).value ?? const PermSnapshot();
    final ok = permissionOk(permission, snap);
    final status = permission == AppPermission.location ? snap.location : snap.notifications;
    final known = status != PermStatus.unknown;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: divider ? Border(top: BorderSide(color: c.border)) : null),
      child: Row(children: [
        Icon(icon, size: 20, color: c.textSecondary),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            Text(ok ? '$note · On' : (known ? '$note · Off' : note), style: TextStyle(fontSize: 12, color: c.textSecondary)),
          ]),
        ),
        if (ok)
          Icon(TablerIcons.circle_check_filled, color: c.textSuccess, size: 22)
        else if (known)
          TextButton(
            onPressed: () => actOnPermission(ref, permission, snap),
            style: TextButton.styleFrom(backgroundColor: c.bgBrand, foregroundColor: c.textBrand, shape: const StadiumBorder()),
            child: Text(status == PermStatus.blocked || (permission == AppPermission.location && snap.location == PermStatus.granted) ? 'Open settings' : 'Allow'),
          ),
      ]),
    );
  }
}
