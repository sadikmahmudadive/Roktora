import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:roktora/data/models.dart';
import 'package:roktora/data/providers.dart';
import 'package:roktora/data/repository.dart';
import 'package:roktora/main.dart';
import 'package:roktora/router.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    final loader = FontLoader('InstrumentSans')..addFont(rootBundle.load('assets/fonts/InstrumentSans-Variable.ttf'));
    await loader.load();
  });

  Future<DemoRepository> open(WidgetTester tester, String route) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final repo = DemoRepository();
    await repo.verifyCode('demo', '123456');
    await repo.saveProfile(const DonorProfile(uid: 'demo-user', name: 'Nusrat Rahman', area: 'Dhanmondi, Dhaka', bloodGroup: 'O-'));
    await repo.setCommitment('r1', true);
    await tester.pumpWidget(ProviderScope(overrides: [repositoryProvider.overrideWithValue(repo)], child: const RoktoraApp()));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    ProviderScope.containerOf(tester.element(find.byType(RoktoraApp))).read(routerProvider).go(route);
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('chat shows who said what and sends a message', (tester) async {
    await open(tester, '/chat/r1');
    expect(find.text('Tanvir A.'), findsWidgets); // sender name above their message
    expect(find.text("Thank you for committing. He's in surgery prep now."), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);

    // Send stays disabled until there is text.
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    await tester.tap(find.byIcon(TablerIcons.send));
    await tester.pumpAndSettle();
    expect(find.text('No messages yet'), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '   '); // nothing was sent, nothing cleared

    await tester.enterText(find.byType(TextField), 'On my way, 15 minutes');
    await tester.pump();
    await tester.tap(find.byIcon(TablerIcons.send));
    await tester.pumpAndSettle();
    expect(find.text('On my way, 15 minutes'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
  });

  testWidgets('a quick reply is sent as a message', (tester) async {
    await open(tester, '/chat/r1');
    await tester.tap(find.text("I'm on my way"));
    await tester.pumpAndSettle();
    expect(find.text("I'm on my way"), findsNWidgets(2)); // the chip and the new message
  });

  testWidgets('the Chats tab previews the latest message and clears the unread dot once opened', (tester) async {
    final semantics = tester.ensureSemantics();
    final repo = await open(tester, '/chats');
    expect(find.textContaining("Tanvir: Thank you for committing"), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Unread')), findsOneWidget);

    await tester.tap(find.textContaining('2 bags for cardiac surgery'));
    await tester.pumpAndSettle();
    expect(find.text("Thank you for committing. He's in surgery prep now."), findsOneWidget);

    ProviderScope.containerOf(tester.element(find.byType(RoktoraApp))).read(routerProvider).go('/chats');
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp('Unread')), findsNothing);
    expect(repo, isNotNull);
    semantics.dispose();
  });
}
