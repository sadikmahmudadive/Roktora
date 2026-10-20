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

group('eligibility cooldown', () {
    DonorProfile donor(int daysAgo, {bool screened = true}) => DonorProfile(
          uid: 'u', name: 'Test Donor', area: 'Dhanmondi, Dhaka', eligible: screened,
          lastDonation: DateTime.now().subtract(Duration(days: daysAgo)),
        );

    test('a recent donation rests the donor until the cooldown ends', () {
      final p = donor(10);
      expect(p.isEligibleNow, isFalse);
      expect(p.daysUntilEligible, closeTo(110, 1));
    });

    test('eligibility comes back on its own after the cooldown', () {
      final p = donor(DonorProfile.cooldownDays + 1);
      expect(p.daysUntilEligible, 0);
      expect(p.isEligibleNow, isTrue);
    });

    test('a failed screening stays ineligible even after the cooldown', () {
      expect(donor(400, screened: false).isEligibleNow, isFalse);
    });

    test('someone who never donated is eligible', () {
      expect(const DonorProfile(uid: 'u', name: 'New Donor', area: 'x').isEligibleNow, isTrue);
    });
  });

  group('managing your own requests and profile', () {
    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      final loader = FontLoader('InstrumentSans')..addFont(rootBundle.load('assets/fonts/InstrumentSans-Variable.ttf'));
      await loader.load();
    });

    Future<DemoRepository> signedInApp(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
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

    testWidgets('the poster can mark a request fulfilled and reopen it', (tester) async {
      final repo = await signedInApp(tester);
      await repo.postRequest(BloodRequest(
        id: '', bloodGroup: 'O-', title: 'Two bags for my father', place: 'Square Hospital', distanceKm: 0, bagsNeeded: 2, committed: 0,
        urgency: Urgency.urgent, deadline: DateTime.now().add(const Duration(hours: 12)), postedBy: 'Nusrat R.',
      ));
      final mine = await repo.myRequests().first;
      expect(mine, hasLength(1));
      expect(mine.single.status, 'open');

      ProviderScope.containerOf(tester.element(find.byType(RoktoraApp))).read(routerProvider).go('/request/${mine.single.id}');
      await tester.pumpAndSettle();

      // Owners get management actions instead of "Commit to donate".
      expect(find.text('Commit to donate'), findsNothing);
      expect(find.text('Mark fulfilled'), findsOneWidget);

      await tester.tap(find.text('Mark fulfilled'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark fulfilled').last); // dialog confirm
      await tester.pumpAndSettle();

      expect((await repo.myRequests().first).single.status, 'fulfilled');
      expect(find.text('This request was fulfilled. Thank you to everyone who helped.'), findsOneWidget);
      // Fulfilled requests leave the shared feed...
      expect((await repo.requests().first).any((r) => r.id == mine.single.id), isFalse);

      await tester.tap(find.text('Reopen request'));
      await tester.pumpAndSettle();
      expect((await repo.myRequests().first).single.status, 'open');
    });

    testWidgets('editing the profile saves the new name and area', (tester) async {
      final repo = await signedInApp(tester);
      ProviderScope.containerOf(tester.element(find.byType(RoktoraApp))).read(routerProvider).go('/profile/edit');
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Nusrat Jahan Rahman');
      await tester.pump();
      expect(find.text('Requesters see "Nusrat R."'), findsOneWidget);

      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      final saved = await repo.profile().first;
      expect(saved?.name, 'Nusrat Jahan Rahman');
      expect(saved?.bloodGroup, 'O-');
    });
  });

  group('location through the map picker', () {
    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      final loader = FontLoader('InstrumentSans')..addFont(rootBundle.load('assets/fonts/InstrumentSans-Variable.ttf'));
      await loader.load();
    });

    Future<DemoRepository> launch(WidgetTester tester, {bool withProfile = true}) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final repo = DemoRepository();
      await repo.verifyCode('demo', '123456');
      if (withProfile) {
        await repo.saveProfile(const DonorProfile(uid: 'demo-user', name: 'Nusrat Rahman', area: 'Dhanmondi, Dhaka', bloodGroup: 'O-'));
      }
      await tester.pumpWidget(ProviderScope(overrides: [repositoryProvider.overrideWithValue(repo)], child: const RoktoraApp()));
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('sign-up needs a location chosen on the map before the account can be created', (tester) async {
      final repo = await launch(tester, withProfile: false);
      expect(find.text('Tell us about you'), findsOneWidget);
      expect(find.text('Set your location on the map'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Sadik Mahmud');
      await tester.pump();
      // Name alone isn't enough: the button stays disabled until a place is pinned.
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();
      expect(await repo.profile().first, isNull);

      await tester.ensureVisible(find.text('Set your location on the map'));
      await tester.tap(find.text('Set your location on the map'));
      await tester.pumpAndSettle();
      expect(find.text('Where are you based?'), findsOneWidget);
      await tester.tap(find.text('Confirm location'));
      await tester.pumpAndSettle();

      // Back on the form, the chosen place is shown in the field.
      expect(find.text('Set your location on the map'), findsNothing);
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();
      final saved = await repo.profile().first;
      expect(saved, isNotNull);
      expect(saved!.hasLocation, isTrue);
      expect(saved.lat, closeTo(23.78, 0.01)); // default Dhaka centre of the preview map
    });

    testWidgets('a donor can move their saved location from the profile editor', (tester) async {
      final repo = await launch(tester);
      ProviderScope.containerOf(tester.element(find.byType(RoktoraApp))).read(routerProvider).go('/profile/edit');
      await tester.pumpAndSettle();
      expect(find.text('Dhanmondi, Dhaka'), findsOneWidget);
      expect(find.text('Tap to pin your exact spot on the map.'), findsOneWidget);

      await tester.tap(find.text('Dhanmondi, Dhaka'));
      await tester.pumpAndSettle();
      expect(find.text('Update your location'), findsOneWidget);
      await tester.tap(find.text('Confirm location'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      final saved = await repo.profile().first;
      expect(saved?.hasLocation, isTrue);
    });

    testWidgets('a request must be pinned on the map before it can be posted', (tester) async {
      final repo = await launch(tester);
      ProviderScope.containerOf(tester.element(find.byType(RoktoraApp))).read(routerProvider).go('/request/new');
      await tester.pumpAndSettle();

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Two bags for surgery');
      await tester.enterText(fields.at(1), 'Square Hospital');
      await tester.pump();
      await tester.ensureVisible(find.text('Post request'));
      await tester.tap(find.text('Post request'));
      await tester.pumpAndSettle();
      expect((await repo.myRequests().first), isEmpty, reason: 'no location pinned yet');

      await tester.ensureVisible(find.text('Pin the location on the map'));
      await tester.tap(find.text('Pin the location on the map'));
      await tester.pumpAndSettle();
      expect(find.text('Where is the blood needed?'), findsOneWidget);
      await tester.tap(find.text('Use this location'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Post request'));
      await tester.tap(find.text('Post request'));
      await tester.pumpAndSettle();
      final mine = await repo.myRequests().first;
      expect(mine, hasLength(1));
      expect(mine.single.hasLocation, isTrue);
    });
  });

  group('email and Google sign-in', () {
    setUpAll(() async {
      SharedPreferences.setMockInitialValues({'seen': true});
      final loader = FontLoader('InstrumentSans')..addFont(rootBundle.load('assets/fonts/InstrumentSans-Variable.ttf'));
      await loader.load();
    });

    Future<DemoRepository> atLogin(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final repo = DemoRepository();
      await tester.pumpWidget(ProviderScope(overrides: [repositoryProvider.overrideWithValue(repo)], child: const RoktoraApp()));
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      ProviderScope.containerOf(tester.element(find.byType(RoktoraApp))).read(routerProvider).go('/login');
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('the login screen offers phone, email and Google', (tester) async {
      await atLogin(tester);
      expect(find.text('Phone'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Google'), findsOneWidget);
    });

    testWidgets('email sign-in needs a valid email and a 6+ character password, then signs in', (tester) async {
      final repo = await atLogin(tester);
      await tester.tap(find.text('Email'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome back'), findsOneWidget);

      // Disabled until both fields are acceptable.
      await tester.tap(find.text('Sign in'));
      await tester.pump();
      expect(repo.uid, isNull);

      await tester.enterText(find.widgetWithText(TextField, 'Email'), 'sadik@example.com');
      await tester.enterText(find.widgetWithText(TextField, 'Password'), '123');
      await tester.pump();
      await tester.tap(find.text('Sign in'));
      await tester.pump();
      expect(repo.uid, isNull, reason: 'password too short');

      await tester.enterText(find.widgetWithText(TextField, 'Password'), 'secret123');
      await tester.pump();
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(repo.uid, isNotNull);
      // New account, no donor profile yet: the router sends them to sign-up.
      expect(find.text('Tell us about you'), findsOneWidget);
    });

    testWidgets('creating an account and resetting a password are separate modes', (tester) async {
      await atLogin(tester);
      await tester.tap(find.text('Email'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();
      expect(find.text('Reset your password'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Password'), findsNothing);
      await tester.enterText(find.widgetWithText(TextField, 'Email'), 'sadik@example.com');
      await tester.pump();
      await tester.tap(find.text('Send reset link'));
      await tester.pumpAndSettle();
      expect(find.textContaining('a reset link is on its way'), findsOneWidget);

      await tester.tap(find.text('Back to sign in'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();
      expect(find.text('Create your account'), findsOneWidget);
    });

    testWidgets('Google button signs in', (tester) async {
      final repo = await atLogin(tester);
      await tester.ensureVisible(find.text('Google'));
      await tester.tap(find.text('Google'));
      await tester.pumpAndSettle();
      expect(repo.uid, isNotNull);
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
