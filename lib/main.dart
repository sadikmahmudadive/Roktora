import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/tokens.dart';
import 'data/providers.dart';
import 'data/repository.dart';
import 'firebase_options.dart';
import 'router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Falls back to an in-memory demo backend if Firebase can't initialize
  // (e.g. a platform that `flutterfire configure` didn't cover).
  RoktoraRepository repo;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    repo = FirebaseRepository();
  } catch (e) {
    debugPrint('Firebase not configured, running in demo mode: $e');
    repo = DemoRepository();
  }

  runApp(
    ProviderScope(
      overrides: [repositoryProvider.overrideWithValue(repo)],
      child: const RoktoraApp(),
    ),
  );
}

class RoktoraApp extends ConsumerWidget {
  const RoktoraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Roktora',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) =>
          ResponsiveFrame(child: child ?? const SizedBox.shrink()),
    );
  }
}

/// Keeps the phone-sized layouts centered on wide screens (foldables, tablets,
/// landscape) instead of stretching them edge to edge, and caps text scaling.
class ResponsiveFrame extends StatelessWidget {
  const ResponsiveFrame({super.key, required this.child});
  final Widget child;

  static const double maxWidth = 480;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final c = context.rc;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: dark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: c.surface0,
        systemNavigationBarIconBrightness: dark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: ColoredBox(
        color: c.surface0,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: maxWidth),
            child: MediaQuery(
              data: mq.copyWith(
                textScaler: mq.textScaler.clamp(
                  minScaleFactor: .9,
                  maxScaleFactor: 1.3,
                ),
              ),
              child: ClipRect(child: child),
            ),
          ),
        ),
      ),
    );
  }
}
