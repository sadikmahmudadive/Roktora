import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/providers.dart';
import '../../data/repository.dart';

/// How a permission currently stands, from the app's point of view.
enum PermStatus {
  /// Allowed.
  granted,

  /// Not allowed yet, but the system dialog can still be shown.
  denied,

  /// Refused for good. Only the system settings can change it.
  blocked,

  /// Couldn't be determined (e.g. Firebase not configured in demo mode).
  unknown,
}

class PermSnapshot {
  const PermSnapshot({this.location = PermStatus.unknown, this.notifications = PermStatus.unknown, this.locationServiceOn = true});
  final PermStatus location, notifications;

  /// Device-wide location switch (GPS), separate from the app permission.
  final bool locationServiceOn;

  bool get allGranted => location == PermStatus.granted && notifications == PermStatus.granted;
  bool get anyMissing => location != PermStatus.granted || notifications != PermStatus.granted;

  /// Something the user refused or hasn't answered yet. `unknown` (e.g. demo mode) doesn't count.
  bool get needsPrompt =>
      location == PermStatus.denied || location == PermStatus.blocked || notifications == PermStatus.denied || notifications == PermStatus.blocked;
}

/// Thin wrapper over the platform permission APIs. Every call is guarded so the app keeps
/// working (in demo mode, on emulators without Play services, etc.) when one is unavailable.
class PermissionApi {
  const PermissionApi();

  PermStatus _fromLocation(LocationPermission p) => switch (p) {
        LocationPermission.always || LocationPermission.whileInUse => PermStatus.granted,
        LocationPermission.denied => PermStatus.denied,
        LocationPermission.deniedForever => PermStatus.blocked,
        LocationPermission.unableToDetermine => PermStatus.unknown,
      };

  PermStatus _fromAuth(AuthorizationStatus s) => switch (s) {
        AuthorizationStatus.authorized || AuthorizationStatus.provisional => PermStatus.granted,
        AuthorizationStatus.notDetermined => PermStatus.denied,
        // Android lets the dialog show once more after a first refusal; iOS never re-asks.
        AuthorizationStatus.denied => defaultTargetPlatform == TargetPlatform.iOS ? PermStatus.blocked : PermStatus.denied,
        AuthorizationStatus.deniedPermanently => PermStatus.blocked,
      };

  Future<PermSnapshot> read({required bool messagingAvailable}) async {
    var loc = PermStatus.unknown;
    var serviceOn = true;
    try {
      loc = _fromLocation(await Geolocator.checkPermission());
      serviceOn = await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      debugPrint('location permission check failed: $e');
    }
    var notif = PermStatus.unknown;
    if (messagingAvailable) {
      try {
        notif = _fromAuth((await FirebaseMessaging.instance.getNotificationSettings()).authorizationStatus);
      } catch (e) {
        debugPrint('notification permission check failed: $e');
      }
    }
    return PermSnapshot(location: loc, notifications: notif, locationServiceOn: serviceOn);
  }

  Future<PermStatus> requestLocation() async {
    try {
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      return _fromLocation(p);
    } catch (e) {
      debugPrint('location request failed: $e');
      return PermStatus.unknown;
    }
  }

  Future<PermStatus> requestNotifications() async {
    try {
      final s = await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
      return _fromAuth(s.authorizationStatus);
    } catch (e) {
      debugPrint('notification request failed: $e');
      return PermStatus.unknown;
    }
  }

  Future<void> openAppSettings() => Geolocator.openAppSettings();
  Future<void> openLocationSettings() => Geolocator.openLocationSettings();

  /// One coarse fix for centering the map. Prefers a cached position so it returns fast.
  Future<({double lat, double lng})?> currentPosition() async {
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null && DateTime.now().difference(last.timestamp).inMinutes < 30) {
        return (lat: last.latitude, lng: last.longitude);
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 8)),
      );
      return (lat: p.latitude, lng: p.longitude);
    } catch (e) {
      debugPrint('could not get position: $e');
      return null;
    }
  }
}

final permissionApiProvider = Provider<PermissionApi>((ref) => const PermissionApi());

/// True when Firebase initialised (so FCM calls are safe).
final messagingAvailableProvider = Provider<bool>((ref) => ref.watch(repositoryProvider) is FirebaseRepository);

class PermissionsNotifier extends AsyncNotifier<PermSnapshot> {
  PermissionApi get _api => ref.read(permissionApiProvider);

  @override
  Future<PermSnapshot> build() => _api.read(messagingAvailable: ref.read(messagingAvailableProvider));

  /// Re-reads the real state, e.g. when the app returns from the system settings.
  Future<void> refresh() async {
    state = AsyncData(await _api.read(messagingAvailable: ref.read(messagingAvailableProvider)));
  }

  Future<PermStatus> requestLocation() async {
    final r = await _api.requestLocation();
    await refresh();
    return r;
  }

  Future<PermStatus> requestNotifications() async {
    final r = await _api.requestNotifications();
    await refresh();
    return r;
  }
}

final permissionsProvider = AsyncNotifierProvider<PermissionsNotifier, PermSnapshot>(PermissionsNotifier.new);

/// The user's coarse position when location is allowed, else null (map falls back to their area).
final userLocationProvider = FutureProvider<({double lat, double lng})?>((ref) async {
  final perms = ref.watch(permissionsProvider).value;
  if (perms?.location != PermStatus.granted || perms?.locationServiceOn == false) return null;
  return ref.read(permissionApiProvider).currentPosition();
});

/// Rounds to 2 decimals (~1.1 km) before anything leaves the device.
double coarse(double v) => (v * 100).round() / 100;

/// Hides the Home reminder for the rest of this session once dismissed.
class PermissionReminderDismissed extends Notifier<bool> {
  @override
  bool build() => false;
  void dismiss() => state = true;
}

final permissionReminderDismissedProvider = NotifierProvider<PermissionReminderDismissed, bool>(PermissionReminderDismissed.new);

/// Remembers that the primer was shown so first-run flows don't repeat it.
Future<bool> primerSeen() async => (await SharedPreferences.getInstance()).getBool('permissionPrimerSeen') ?? false;
Future<void> markPrimerSeen() async => (await SharedPreferences.getInstance()).setBool('permissionPrimerSeen', true);
