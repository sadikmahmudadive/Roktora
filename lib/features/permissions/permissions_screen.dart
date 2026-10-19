import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:go_router/go_router.dart';
import '../../core/permissions/permissions.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/widgets.dart';

enum AppPermission { location, notifications }

/// Triggers the right action for a permission: the system dialog if it can still be shown,
/// otherwise the matching system settings page.
Future<void> actOnPermission(WidgetRef ref, AppPermission p, PermSnapshot s) async {
  final notifier = ref.read(permissionsProvider.notifier);
  final api = ref.read(permissionApiProvider);
  switch (p) {
    case AppPermission.location:
      if (s.location == PermStatus.blocked) return api.openAppSettings();
      if (s.location == PermStatus.granted && !s.locationServiceOn) return api.openLocationSettings();
      await notifier.requestLocation();
    case AppPermission.notifications:
      if (s.notifications == PermStatus.blocked) return api.openAppSettings();
      await notifier.requestNotifications();
  }
}

String permissionActionLabel(AppPermission p, PermSnapshot s) {
  switch (p) {
    case AppPermission.location:
      if (s.location == PermStatus.blocked) return 'Open settings';
      if (s.location == PermStatus.granted && !s.locationServiceOn) return 'Turn on location';
      return 'Allow location';
    case AppPermission.notifications:
      return s.notifications == PermStatus.blocked ? 'Open settings' : 'Allow notifications';
  }
}

bool permissionOk(AppPermission p, PermSnapshot s) => p == AppPermission.location
    ? s.location == PermStatus.granted && s.locationServiceOn
    : s.notifications == PermStatus.granted;

/// Pre-permission screen: explains why each permission is needed, then triggers the real
/// system dialogs. Reachable after the eligibility check and from the Home reminder.
class PermissionsScreen extends ConsumerStatefulWidget {
  const PermissionsScreen({super.key});
  @override
  ConsumerState<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends ConsumerState<PermissionsScreen> {
  bool _busy = false;

  Future<void> _leave() async {
    await markPrimerSeen();
    if (mounted) context.go('/home');
  }

  Future<void> _allowAll(PermSnapshot s) async {
    setState(() => _busy = true);
    try {
      if (!permissionOk(AppPermission.location, s) && s.location != PermStatus.blocked) {
        await actOnPermission(ref, AppPermission.location, s);
      }
      final now = ref.read(permissionsProvider).value ?? s;
      if (!permissionOk(AppPermission.notifications, now) && now.notifications != PermStatus.blocked) {
        await actOnPermission(ref, AppPermission.notifications, now);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    final after = ref.read(permissionsProvider).value;
    if (after != null && after.allGranted) await _leave();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rc;
    final snap = ref.watch(permissionsProvider).value ?? const PermSnapshot();
    final done = permissionOk(AppPermission.location, snap) && permissionOk(AppPermission.notifications, snap);
    final anyBlocked = snap.location == PermStatus.blocked || snap.notifications == PermStatus.blocked;

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 16, 0),
            child: Row(children: [
              const Spacer(),
              TextButton(
                onPressed: _leave,
                style: TextButton.styleFrom(backgroundColor: c.surface2, foregroundColor: c.textSecondary, shape: const StadiumBorder()),
                child: Text(done ? 'Done' : 'Not now'),
              ),
            ]),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(24, 8, 24, 24), children: [
              FadeSlideIn(
                child: Container(
                  height: 120, width: 120, alignment: Alignment.center,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(color: c.bgBrand, borderRadius: BorderRadius.circular(36)),
                  child: const RoktoraMark(height: 64),
                ),
              ),
              FadeSlideIn(index: 1, child: Text('Reach the right people, fast', style: AppTheme.display(context, size: 32))),
              const SizedBox(height: 12),
              FadeSlideIn(
                index: 2,
                child: Text(
                  'Two permissions make Roktora work. You stay in control and can change them any time in Settings.',
                  style: TextStyle(fontSize: 15, color: c.textSecondary, height: 1.4),
                ),
              ),
              const SizedBox(height: 24),
              FadeSlideIn(
                index: 3,
                child: _PermissionCard(
                  icon: TablerIcons.map_pin,
                  tint: c.bgAccent,
                  tintFg: c.textAccent,
                  title: 'Your location',
                  why: 'See requests and donors near you, and get alerts only when someone close needs your blood group.',
                  privacy: 'Others only see your approximate area (about 1 km), never your exact spot.',
                  ok: permissionOk(AppPermission.location, snap),
                  action: permissionActionLabel(AppPermission.location, snap),
                  blocked: snap.location == PermStatus.blocked,
                  onTap: () => actOnPermission(ref, AppPermission.location, snap),
                ),
              ),
              const SizedBox(height: 12),
              FadeSlideIn(
                index: 4,
                child: _PermissionCard(
                  icon: TablerIcons.bell_ringing,
                  tint: c.bgDanger,
                  tintFg: c.textDanger,
                  title: 'Notifications',
                  why: 'Critical requests are time-sensitive. Alerts tell you the moment a matching patient needs help.',
                  privacy: 'Only your blood group and distance matter. No marketing messages.',
                  ok: permissionOk(AppPermission.notifications, snap),
                  action: permissionActionLabel(AppPermission.notifications, snap),
                  blocked: snap.notifications == PermStatus.blocked,
                  onTap: () => actOnPermission(ref, AppPermission.notifications, snap),
                ),
              ),
              if (anyBlocked) ...[
                const SizedBox(height: 16),
                InfoBanner('You declined one of these earlier, so Android won\'t ask again. Open settings to switch it on.', icon: TablerIcons.info_circle, bg: c.bgWarning, fg: c.textWarning),
              ],
              if (snap.location == PermStatus.granted && !snap.locationServiceOn) ...[
                const SizedBox(height: 16),
                InfoBanner('Location is allowed, but your phone\'s location switch is off. Turn it on to see nearby requests.', icon: TablerIcons.map_pin_off, bg: c.bgWarning, fg: c.textWarning),
              ],
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: PillButton(
              done ? 'Continue' : (_busy ? 'Asking…' : 'Allow all'),
              onPressed: _busy ? null : (done ? _leave : () => _allowAll(snap)),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Dismissible Home card nudging people who skipped or refused a permission.
class PermissionReminder extends ConsumerWidget {
  const PermissionReminder({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.rc;
    final snap = ref.watch(permissionsProvider).value;
    final dismissed = ref.watch(permissionReminderDismissedProvider);
    if (snap == null || !snap.needsPrompt || dismissed) return const SizedBox.shrink();
    final both = snap.location != PermStatus.granted && snap.notifications != PermStatus.granted;
    final what = both ? 'location and notifications' : (snap.location != PermStatus.granted ? 'location' : 'notifications');
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SurfaceCard(
        stripe: c.borderWarning,
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        onTap: () => context.push('/permissions'),
        child: Row(children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: c.bgWarning, borderRadius: BorderRadius.circular(12)), child: Icon(TablerIcons.bell_ringing, size: 20, color: c.textWarning)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Turn on alerts and nearby search', style: TextStyle(fontWeight: FontWeight.w600)),
              Text('Allow $what so we can reach you when it matters.', style: TextStyle(fontSize: 12, color: c.textSecondary)),
            ]),
          ),
          IconButton(
            tooltip: 'Dismiss',
            icon: Icon(TablerIcons.x, size: 18, color: c.textMuted),
            onPressed: () => ref.read(permissionReminderDismissedProvider.notifier).dismiss(),
          ),
        ]),
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.icon, required this.tint, required this.tintFg, required this.title, required this.why,
    required this.privacy, required this.ok, required this.action, required this.blocked, required this.onTap,
  });
  final IconData icon;
  final Color tint, tintFg;
  final String title, why, privacy, action;
  final bool ok, blocked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.rc;
    return SurfaceCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: tintFg)),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17))),
          if (ok)
            Container(
              height: 26, padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(color: c.bgSuccess, borderRadius: BorderRadius.circular(99)),
              child: Row(children: [Icon(TablerIcons.check, size: 14, color: c.textSuccess), const SizedBox(width: 4), Text('Allowed', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.textSuccess))]),
            ),
        ]),
        const SizedBox(height: 12),
        Text(why, style: TextStyle(color: c.textSecondary, height: 1.4)),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(TablerIcons.lock, size: 14, color: c.textMuted),
          const SizedBox(width: 6),
          Expanded(child: Text(privacy, style: TextStyle(fontSize: 12, color: c.textMuted, height: 1.4))),
        ]),
        if (!ok) ...[
          const SizedBox(height: 14),
          SizedBox(
            height: 46,
            child: PillButton(action, height: 46, outlined: true, danger: false, onPressed: onTap, icon: blocked ? TablerIcons.settings : null),
          ),
        ],
      ]),
    );
  }
}
