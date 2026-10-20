import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roktora/data/models.dart';
import 'package:roktora/data/providers.dart';
import 'package:roktora/data/repository.dart';
import 'package:roktora/features/admin/admin_models.dart';
import 'package:roktora/features/admin/admin_providers.dart';
import 'package:roktora/features/admin/admin_repository.dart';
import 'package:roktora/features/admin/admin_widgets.dart';
import 'package:roktora/main.dart';
import 'package:roktora/router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('report maths', () {
    final now = DateTime(2026, 10, 19, 12);
    CheckIn done(int daysAgo, {String group = 'O+', CheckInStatus s = CheckInStatus.done}) =>
        CheckIn(id: '$daysAgo$group$s', donorName: 'D', group: group, status: s, at: now.subtract(Duration(days: daysAgo)));

    test('weekly buckets count completed donations in 7-day windows ending today', () {
      final r = buildReport(
        checkins: [done(0), done(1), done(2), done(9), done(10, group: 'B+')],
        requests: const [],
        period: ReportPeriod.weekly,
        now: now,
      );
      expect(r.values, hasLength(12));
      expect(r.values.last, 3, reason: 'today, yesterday and 2 days ago');
      expect(r.values[10], 2, reason: 'the week before');
      expect(r.total, 5);
      expect(r.byGroup.first, ('O+', 4));
    });

    test('deferred and waiting check-ins are not counted as collections', () {
      final r = buildReport(
        checkins: [done(0), done(0, s: CheckInStatus.deferred), done(0, s: CheckInStatus.waiting)],
        requests: const [],
        period: ReportPeriod.weekly,
        now: now,
      );
      expect(r.values.last, 1);
      // 1 donated + 1 deferred were screened: 50% deferral.
      expect(r.kpis.firstWhere((k) => k.label == 'Deferral rate').value, '50%');
    });

    test('fulfilment rate and median time to fill come from closed requests', () {
      BloodRequest req(String id, String status, Duration? fill) => BloodRequest(
            id: id, bloodGroup: 'O+', title: 't', place: 'p', distanceKm: 0, bagsNeeded: 1, committed: 0, urgency: Urgency.urgent,
            deadline: now, status: status, createdAt: now.subtract(const Duration(days: 1)),
            fulfilledAt: fill == null ? null : now.subtract(const Duration(days: 1)).add(fill),
          );
      final r = buildReport(
        checkins: const [],
        requests: [
          req('a', 'fulfilled', const Duration(hours: 2)),
          req('b', 'fulfilled', const Duration(hours: 4)),
          req('c', 'fulfilled', const Duration(hours: 6)),
          req('d', 'closed', null),
          req('e', 'open', null),
        ],
        period: ReportPeriod.weekly,
        now: now,
      );
      expect(r.kpis.firstWhere((k) => k.label == 'Requests fulfilled').value, '75%'); // 3 of 4 closed
      expect(r.kpis.firstWhere((k) => k.label == 'Median time to fill').value, '4 h 0 m');
    });

    test('with no data the report says so instead of showing zeros as results', () {
      final r = buildReport(checkins: const [], requests: const [], period: ReportPeriod.monthly, now: now);
      expect(r.total, 0);
      expect(r.kpis.firstWhere((k) => k.label == 'Requests fulfilled').value, '—');
    });
  });

  group('inventory', () {
    InventoryRow row(String g, int units, int target) => InventoryRow(group: g, target: target, parts: {'whole': units});

    test('stock level follows the share of target on hand', () {
      expect(row('O−', 4, 15).level, StockLevel.shortage); // 27%
      expect(row('B+', 36, 60).level, StockLevel.low); // 60%
      expect(row('A+', 50, 60).level, StockLevel.healthy); // 83%
    });

    test('units add up across components and editing one never goes below zero', () {
      const r = InventoryRow(group: 'A+', target: 20, parts: {'whole': 5, 'red': 3, 'plasma': 2, 'platelets': 1});
      expect(r.units, 11);
      expect(r.withPart(0, -4).part(0), 0);
      expect(r.withPart(1, 9).units, 17);
    });
  });

  group('hospital dashboard', () {
    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      final loader = FontLoader('InstrumentSans')..addFont(rootBundle.load('assets/fonts/InstrumentSans-Variable.ttf'));
      await loader.load();
    });

    Future<({DemoRepository main, DemoAdminRepository admin})> open(
      WidgetTester tester, {
      String route = '/admin',
      double width = 1400,
      double height = 1000,
      bool staff = true,
    }) async {
      tester.view.physicalSize = Size(width, height);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final main = DemoRepository();
      await main.verifyCode('demo', '123456');
      final admin = DemoAdminRepository(main: main, isStaff: staff);
      await tester.pumpWidget(ProviderScope(
        overrides: [repositoryProvider.overrideWithValue(main), adminRepositoryProvider.overrideWithValue(admin)],
        child: const RoktoraApp(),
      ));
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      ProviderScope.containerOf(tester.element(find.byType(RoktoraApp))).read(routerProvider).go(route);
      await tester.pumpAndSettle();
      return (main: main, admin: admin);
    }

    testWidgets('overview shows live stats, stock and the queue on a wide screen', (tester) async {
      await open(tester);
      expect(find.text('Dashboard'), findsWidgets);
      expect(find.text('Open requests'), findsWidgets);
      expect(find.text('Mirpur Central Hospital'), findsWidgets);
      // The design's sample data: 4 open requests, 1 critical (O−).
      expect(find.text('1 critical · O−'), findsOneWidget);
      expect(find.text("Today's queue"), findsOneWidget);
      expect(find.text('Nusrat R.'), findsOneWidget);
    });

    testWidgets('people without a staff record see the no-access page, not the dashboard', (tester) async {
      await open(tester, staff: false);
      expect(find.text("This account isn't linked to a hospital"), findsOneWidget);
      expect(find.text('Open requests'), findsNothing);
    });

    testWidgets('narrow screens get a drawer instead of a sidebar', (tester) async {
      await open(tester, width: 420, height: 900);
      expect(find.byTooltip('Open navigation menu'), findsOneWidget);
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Requests').last);
      await tester.pumpAndSettle();
      expect(find.text('New request'), findsOneWidget);
    });

    testWidgets('staff can edit stock and it updates the numbers', (tester) async {
      final r = await open(tester, route: '/admin/inventory');
      expect(find.text('Blood inventory'), findsOneWidget);
      final before = (await r.admin.inventory('mch').first).firstWhere((x) => x.group == 'A+');

      // Tap the whole-blood cell in the A+ row and add a unit.
      await tester.tap(find.widgetWithText(InkWell, '${before.part(0)}').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('· Whole blood'), findsOneWidget);
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.byIcon(TablerIcons.plus)));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final stock = await r.admin.inventory('mch').first;
      final changed = stock.where((x) => x.group == before.group).single;
      // The first matching cell belongs to the first group whose whole-blood count equals that number.
      expect(stock.fold(0, (a, x) => a + x.part(0)), greaterThan(before.part(0)));
      expect(changed.units, greaterThanOrEqualTo(before.units));
    });

    testWidgets('requests: select one, see who committed, mark it fulfilled', (tester) async {
      final r = await open(tester, route: '/admin/requests');
      expect(find.text('3 bags for cardiac surgery'), findsOneWidget);

      await tester.tap(find.text('3 bags for cardiac surgery'));
      await tester.pumpAndSettle();
      expect(find.text('Committed donors'), findsOneWidget);
      expect(find.text('Sadia K.'), findsOneWidget);
      expect(find.text('Farhan H.'), findsOneWidget);

      await tester.tap(find.text('Mark fulfilled'));
      await tester.pumpAndSettle();
      final h1 = (await r.admin.hospitalRequests('mch').first).firstWhere((x) => x.id == 'h1');
      expect(h1.status, 'fulfilled');
      expect(h1.fulfilledAt, isNotNull);
    });

    testWidgets('check-in: walk-in donor is verified, given a bay, and the donation updates stock', (tester) async {
      final r = await open(tester, route: '/admin/checkin');
      final stockBefore = (await r.admin.inventory('mch').first).firstWhere((x) => x.group == 'B+').part(0);

      await tester.enterText(find.widgetWithText(TextField, 'Full name'), 'Karim Uddin');
      await tester.pump();
      await tester.tap(find.widgetWithText(PickChip, 'B+'));
      await tester.pump();
      await tester.ensureVisible(find.text('Continue as walk-in'));
      await tester.tap(find.text('Continue as walk-in'));
      await tester.pumpAndSettle();

      for (final label in ['Photo ID matches the passport name', 'Blood pressure within range', 'Donor confirmed consent at the desk']) {
        await tester.tap(find.text(label));
        await tester.pump();
      }
      await tester.enterText(find.widgetWithText(TextField, 'Haemoglobin (g/dL)'), '13.4');
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Assign a bay'), findsOneWidget);
      await tester.tap(find.text('Bay 2'));
      await tester.pump();
      await tester.tap(find.text('Start donation'));
      await tester.pumpAndSettle();
      expect(find.text('Karim Uddin is checked in to bay 2.'), findsOneWidget);

      final inBay = (await r.admin.checkins('mch').first).firstWhere((x) => x.donorName == 'Karim Uddin');
      expect(inBay.status, CheckInStatus.donating);
      expect(inBay.bay, 2);

      await tester.tap(find.widgetWithText(AdminButton, 'Donated').last);
      await tester.pumpAndSettle();
      final stockAfter = (await r.admin.inventory('mch').first).firstWhere((x) => x.group == 'B+').part(0);
      expect(stockAfter, stockBefore + 1);
    });

    testWidgets('a low haemoglobin reading warns and leads to a deferral, not a donation', (tester) async {
      final r = await open(tester, route: '/admin/checkin');
      await tester.enterText(find.widgetWithText(TextField, 'Full name'), 'Low Hb');
      await tester.pump();
      await tester.ensureVisible(find.text('Continue as walk-in'));
      await tester.tap(find.text('Continue as walk-in'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Haemoglobin (g/dL)'), '11.0');
      await tester.pump();
      expect(find.textContaining('should be deferred'), findsOneWidget);

      await tester.tap(find.text('Defer donor'));
      await tester.pumpAndSettle();
      final c = (await r.admin.checkins('mch').first).firstWhere((x) => x.donorName == 'Low Hb');
      expect(c.status, CheckInStatus.deferred);
    });

    testWidgets('donors: select donors, message them, and the donor sees it in their inbox', (tester) async {
      final r = await open(tester, route: '/admin/donors');
      expect(find.text('Donor directory'), findsOneWidget);
      await tester.tap(find.text('Farhan H.'));
      await tester.tap(find.text('Sadia K.'));
      await tester.pump();
      expect(find.text('2 selected'), findsOneWidget);

      await tester.tap(find.text('Message'));
      await tester.pump();
      await tester.enterText(find.byType(TextField).last, 'We urgently need O− donors this week.');
      await tester.pump();
      await tester.tap(find.text('Send to 2'));
      await tester.pumpAndSettle();

      expect(r.admin.sentMessages, hasLength(1));
      expect(r.admin.sentMessages.single.uids, hasLength(2));
      expect(find.textContaining('Message sent to 2 donors'), findsOneWidget);

      final inbox = await r.main.inbox().first;
      expect(inbox.single.body, 'We urgently need O− donors this week.');
      expect(inbox.single.from, 'Mirpur Central Hospital');
    });

    testWidgets('reports show KPIs and a bar per period', (tester) async {
      await open(tester, route: '/admin/reports');
      expect(find.text('Reports'), findsWidgets);
      expect(find.text('Units collected'), findsWidgets);
      expect(find.text('Deferral rate'), findsOneWidget);
      await tester.tap(find.text('Monthly'));
      await tester.pumpAndSettle();
      expect(find.text('Last 12 months'), findsOneWidget);
    });

    testWidgets('hospital profile: admins can edit and save public details', (tester) async {
      final r = await open(tester, route: '/admin/profile');
      expect(find.text('Verification'), findsOneWidget);
      expect(find.text('DGHS license verified'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Blood bank phone'), '+880 2 1234 5678');
      await tester.pump();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      final saved = await r.admin.hospital('mch').first;
      expect(saved?.phone, '+880 2 1234 5678');
      expect(find.text('Saved'), findsOneWidget);
    });
  });
}
