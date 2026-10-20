import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/providers.dart';
import '../../features/profile/profile_settings.dart' show prefsProvider;
import '../../router.dart';
import '../permissions/permissions.dart';

final rootMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Runs when a push arrives while the app is in the background or closed. Notification
/// messages are shown by the system tray, so there is nothing to do here yet.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {}

/// Wraps the app to keep permission state fresh and wire up push + coarse location
/// once the user is signed in and has allowed them.
class AppBootstrap extends ConsumerStatefulWidget {
  const AppBootstrap({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends ConsumerState<AppBootstrap> with WidgetsBindingObserver {
  String? _tokenUid;
  String? _locationKey;
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The user may have changed a permission in system settings.
    if (state == AppLifecycleState.resumed) ref.read(permissionsProvider.notifier).refresh();
  }

  Future<void> _registerPush(String uid) async {
    if (_tokenUid == uid) return;
    _tokenUid = uid;
    try {
      final fm = FirebaseMessaging.instance;
      await fm.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);
      final repo = ref.read(repositoryProvider);
      // ignore: deprecated_member_use
      final token = await fm.getToken();
      if (token != null) await repo.saveFcmToken(token);
      // ignore: deprecated_member_use
      fm.onTokenRefresh.listen(repo.saveFcmToken);
      if (!_listening) {
        _listening = true;
        FirebaseMessaging.onMessage.listen(_showInApp);
        FirebaseMessaging.onMessageOpenedApp.listen(_open);
        final initial = await fm.getInitialMessage();
        if (initial != null) _open(initial);
      }
    } catch (e) {
      debugPrint('push registration failed: $e');
      _tokenUid = null;
    }
  }

  /// Foreground pushes don't reach the system tray, so show them in the app.
  void _showInApp(RemoteMessage m) {
    final n = m.notification;
    if (n == null) return;
    final messenger = rootMessengerKey.currentState;
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 6),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (n.title != null) Text(n.title!, style: const TextStyle(fontWeight: FontWeight.w600)),
        if (n.body != null) Text(n.body!),
      ]),
      action: m.data['requestId'] == null ? null : SnackBarAction(label: 'View', onPressed: () => _open(m)),
    ));
  }

  void _open(RemoteMessage m) {
    final id = m.data['requestId'];
    if (id is String && id.isNotEmpty) ref.read(routerProvider).go('/request/$id');
  }

  /// Publishes the location the user set on the map, rounded to ~1 km. It's re-sent only when it changes.
  Future<void> _syncLocation(String uid, double lat, double lng) async {
    final key = '$uid|${coarse(lat)}|${coarse(lng)}';
    if (_locationKey == key) return;
    _locationKey = key; // set first so a failing write (e.g. rules not deployed) isn't retried on every rebuild
    try {
      await ref.read(repositoryProvider).saveApproxLocation(coarse(lat), coarse(lng));
    } catch (e) {
      debugPrint('saving approximate location failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authProvider).value;
    final perms = ref.watch(permissionsProvider).value;
    final profile = ref.watch(profileProvider).value;
    final showOnMap = ref.watch(prefsProvider)['showOnMap'] ?? true;

    if (uid == null) {
      _tokenUid = null;
      _locationKey = null;
    } else {
      if (perms != null && ref.read(messagingAvailableProvider) && perms.notifications == PermStatus.granted) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _registerPush(uid));
      }
      // Location comes from the map the user pinned, not from the phone's GPS.
      if (profile != null && profile.hasLocation && showOnMap) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _syncLocation(uid, profile.lat!, profile.lng!));
      }
    }
    return widget.child;
  }
}
