import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:roktora/core/permissions/permissions.dart';
import 'package:roktora/data/models.dart';
import 'package:roktora/data/providers.dart';
import 'package:roktora/data/repository.dart';
import 'package:roktora/main.dart';
import 'package:roktora/router.dart';

void main() {
  testWidgets('app boots to splash', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [repositoryProvider.overrideWithValue(DemoRepository())],
      child: const RoktoraApp(),
    ));
    await tester.pump();
    expect(find.text('Roktora'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('content stays centered and phone-width on a wide screen', (tester) async {
    tester.view.physicalSize = const Size(1840, 2208);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [repositoryProvider.overrideWithValue(DemoRepository())],
      child: const RoktoraApp(),
    ));
    await tester.pump();
    // 1840 / 2 = 920 logical px wide; the wordmark must sit on the screen's center line.
    expect(tester.getCenter(find.text('Roktora')).dx, closeTo(460, 1));
    final frame = tester.getSize(find.descendant(of: find.byType(ResponsiveFrame), matching: find.byType(ConstrainedBox)).first);
    expect(frame.width, lessThanOrEqualTo(ResponsiveFrame.maxWidth));
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('splash and onboarding are centered at phone width', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532); // 390 x 844 logical
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [repositoryProvider.overrideWithValue(DemoRepository())],
      child: const RoktoraApp(),
    ));
    await tester.pump();
    expect(tester.getCenter(find.text('Roktora')).dx, closeTo(195, 1));
    expect(tester.getCenter(find.text('Blood, a short walk away.')).dx, closeTo(195, 1));

    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 500));
    // First onboarding slide: the "3 donors within 1 km" card spans the art frame.
    expect(find.text('Donors within walking distance'), findsOneWidget);
    // The art frame spans the screen width, so its right-aligned "Live" label sits near the right edge.
    final live = tester.getRect(find.text('Live'));
    expect(live.right, greaterThan(320));
  });

  group('collapsible nav', () {
    // Flutter's default test font is much wider than the app font; load the real one.
    setUpAll(() async {
      final loader = FontLoader('InstrumentSans')..addFont(rootBundle.load('assets/fonts/InstrumentSans-Variable.ttf'));
      await loader.load();
    });

    Future<DemoRepository> signedIn(WidgetTester tester, {double height = 2532}) async {
      tester.view.physicalSize = Size(1170, height);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final repo = DemoRepository();
      await repo.verifyCode('demo', '123456');
      await repo.saveProfile(const DonorProfile(uid: 'demo-user', name: 'Nusrat Rahman', area: 'Dhanmondi, Dhaka', bloodGroup: 'O-'));
      await tester.pumpWidget(ProviderScope(overrides: [repositoryProvider.overrideWithValue(repo)], child: const RoktoraApp()));
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      return repo;
    }

    double navWidth(WidgetTester tester) =>
        tester.getSize(find.ancestor(of: find.bySemanticsLabel('Open navigation'), matching: find.byType(AnimatedContainer)).first).width;

    testWidgets('rests as a drop, opens on tap, closes after picking a tab', (tester) async {
      await signedIn(tester);
      expect(navWidth(tester), 60);
      // Collapsed drop sits at the bottom-right, inside the 16px page gutter (390px wide screen).
      final drop = tester.getRect(find.ancestor(of: find.bySemanticsLabel('Open navigation'), matching: find.byType(AnimatedContainer)).first);
      expect(drop.right, closeTo(374, 1));
      expect(drop.bottom, greaterThan(780));

      await tester.tap(find.bySemanticsLabel('Open navigation'));
      await tester.pumpAndSettle();
      expect(navWidth(tester), closeTo(358, 1));

      await tester.tap(find.text('Map'));
      await tester.pumpAndSettle();
      expect(navWidth(tester), 60);
    });

    testWidgets('expands when the page is scrolled to the bottom', (tester) async {
      await signedIn(tester, height: 1500); // short viewport so Home actually scrolls
      expect(navWidth(tester), 60);
      await tester.drag(find.byType(ListView).first, const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(navWidth(tester), closeTo(358, 1));
    });
  });

  group('map screen', () {
    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      final loader = FontLoader('InstrumentSans')..addFont(rootBundle.load('assets/fonts/InstrumentSans-Variable.ttf'));
      await loader.load();
    });

    testWidgets('lists donors and requests, and previews a request with directions', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final repo = DemoRepository();
      await repo.verifyCode('demo', '123456');
      await repo.saveProfile(const DonorProfile(uid: 'demo-user', name: 'Nusrat Rahman', area: 'Dhanmondi, Dhaka', bloodGroup: 'O-'));
      await tester.pumpWidget(ProviderScope(overrides: [repositoryProvider.overrideWithValue(repo)], child: const RoktoraApp()));
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      ProviderScope.containerOf(tester.element(find.byType(RoktoraApp))).read(routerProvider).go('/map');
      await tester.pumpAndSettle();

      // Within 3 km of Dhanmondi: six donors and the one nearby hospital request.
      expect(find.text('Donors · 6'), findsOneWidget);
      expect(find.text('Requests · 1'), findsOneWidget);
      expect(find.text('Farhan H.'), findsOneWidget);

      await tester.tap(find.text('Requests · 1'));
      await tester.pumpAndSettle();
      expect(find.text('2 bags for cardiac surgery'), findsOneWidget);
      expect(find.text('Directions'), findsNothing);

      await tester.tap(find.text('2 bags for cardiac surgery'));
      await tester.pumpAndSettle();
      // Selecting shows the preview card with its actions.
      expect(find.text('Directions'), findsOneWidget);
      expect(find.text('View'), findsOneWidget);

      // Widening the filter to a group with no requests hides the selection.
      await tester.tap(find.widgetWithText(ChoiceChip, 'A+'));
      await tester.pumpAndSettle();
      expect(find.text('Directions'), findsNothing);
    });
  });

  group('permissions primer', () {
    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      final loader = FontLoader('InstrumentSans')..addFont(rootBundle.load('assets/fonts/InstrumentSans-Variable.ttf'));
      await loader.load();
    });

    Future<_FakePermissions> pumpPrimer(WidgetTester tester, {PermStatus loc = PermStatus.denied, PermStatus notif = PermStatus.denied}) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final fake = _FakePermissions(loc, notif);
      final repo = DemoRepository();
      await repo.verifyCode('demo', '123456');
      await repo.saveProfile(const DonorProfile(uid: 'demo-user', name: 'Nusrat Rahman', area: 'Dhanmondi, Dhaka', bloodGroup: 'O-'));
      await tester.pumpWidget(ProviderScope(
        overrides: [repositoryProvider.overrideWithValue(repo), permissionApiProvider.overrideWithValue(fake)],
        child: const RoktoraApp(),
      ));
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(tester.element(find.byType(RoktoraApp)));
      container.read(routerProvider).go('/permissions');
      await tester.pumpAndSettle();
      return fake;
    }

    testWidgets('explains each permission and asks for both via Allow all', (tester) async {
      final fake = await pumpPrimer(tester);
      expect(find.text('Your location'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Allow location'), findsOneWidget);
      expect(find.text('Allow notifications'), findsOneWidget);

      await tester.tap(find.text('Allow all'));
      await tester.pumpAndSettle();
      expect(fake.calls, ['location', 'notifications']);
      // Everything granted: the primer closes and Home shows.
      expect(find.text('Reach the right people, fast'), findsNothing);
    });

    testWidgets('a refused permission offers Open settings instead of asking again', (tester) async {
      final fake = await pumpPrimer(tester, loc: PermStatus.blocked, notif: PermStatus.granted);
      expect(find.text('Open settings'), findsOneWidget);
      await tester.tap(find.text('Open settings'));
      await tester.pump();
      expect(fake.calls, ['settings']);
    });
  });
}

/// Records which permission actions the UI triggers, without touching the platform.
class _FakePermissions extends PermissionApi {
  _FakePermissions(this.loc, this.notif);
  PermStatus loc, notif;
  final calls = <String>[];

  @override
  Future<PermSnapshot> read({required bool messagingAvailable}) async => PermSnapshot(location: loc, notifications: notif);

  @override
  Future<PermStatus> requestLocation() async {
    calls.add('location');
    return loc = PermStatus.granted;
  }

  @override
  Future<PermStatus> requestNotifications() async {
    calls.add('notifications');
    return notif = PermStatus.granted;
  }

  @override
  Future<void> openAppSettings() async => calls.add('settings');

  @override
  Future<({double lat, double lng})?> currentPosition() async => null;
}
