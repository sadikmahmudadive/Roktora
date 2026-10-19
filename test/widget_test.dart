import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roktora/data/models.dart';
import 'package:roktora/data/providers.dart';
import 'package:roktora/data/repository.dart';
import 'package:roktora/main.dart';

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
}
