import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'data/providers.dart';
import 'features/admin/admin_checkin.dart';
import 'features/admin/admin_donors_reports.dart';
import 'features/admin/admin_inventory.dart';
import 'features/admin/admin_overview.dart';
import 'features/admin/admin_profile.dart';
import 'features/admin/admin_requests.dart';
import 'features/admin/admin_shell.dart';
import 'features/auth/login_screen.dart';
import 'features/inbox/inbox_screen.dart';
import 'features/auth/signup_eligibility.dart';
import 'features/auth/splash_onboarding.dart';
import 'features/home/shell_home.dart';
import 'features/location/location_picker.dart';
import 'features/permissions/permissions_screen.dart';
import 'features/profile/edit_profile.dart';
import 'features/profile/post_donation.dart';
import 'features/profile/profile_settings.dart';
import 'features/requests/map_screen.dart';
import 'features/requests/request_screens.dart';

/// Fade + gentle horizontal slide used for all pushed screens.
CustomTransitionPage<T> _page<T>(GoRouterState state, Widget child) =>
    CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      transitionsBuilder: (context, animation, secondary, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(.06, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );

const _public = {'/', '/onboarding', '/login'};

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authProvider, (_, _) => refresh.value++);
  ref.listen(profileProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      if (auth.isLoading) return null;
      final authed = auth.value != null;
      final loc = state.matchedLocation;
      if (!authed) return _public.contains(loc) ? null : '/login';

      final profile = ref.read(profileProvider);
      if (profile.isLoading) return null;
      final hasProfile = profile.value != null;
      // The map picker is part of sign-up, so it must stay reachable before a profile exists.
      if (!hasProfile) return (loc == '/signup' || loc == '/pick-location' || loc.startsWith('/admin')) ? null : '/signup';
      return _public.contains(loc) ? '/home' : null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SplashScreen()),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (_, s) => _page(s, const OnboardingScreen()),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (_, s) => _page(s, const LoginScreen()),
      ),
      GoRoute(
        path: '/signup',
        pageBuilder: (_, s) => _page(s, const SignUpScreen()),
      ),
      GoRoute(
        path: '/eligibility',
        pageBuilder: (_, s) => _page(s, const EligibilityScreen()),
      ),
      GoRoute(
        path: '/pick-location',
        pageBuilder: (_, s) => _page<PickedLocation>(s, LocationPickerScreen(args: s.extra is PickerArgs ? s.extra as PickerArgs : const PickerArgs())),
      ),
      GoRoute(
        path: '/permissions',
        pageBuilder: (_, s) => _page(s, const PermissionsScreen()),
      ),
      GoRoute(
        path: '/profile/edit',
        pageBuilder: (_, s) => _page(s, const EditProfileScreen()),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (_, s) => _page(s, const SettingsScreen()),
      ),
      GoRoute(
        path: '/request/new',
        pageBuilder: (_, s) => _page(s, const PostRequestScreen()),
      ),
      GoRoute(
        path: '/request/:id',
        pageBuilder: (_, s) =>
            _page(s, RequestDetailScreen(id: s.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/chat/:id',
        pageBuilder: (_, s) =>
            _page(s, ChatScreen(requestId: s.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/consent/:id',
        pageBuilder: (_, s) =>
            _page(s, ConsentScreen(requestId: s.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/checkin/:id',
        pageBuilder: (_, s) =>
            _page(s, CheckInScreen(requestId: s.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/thanks',
        pageBuilder: (_, s) => _page(s, const ThankYouScreen()),
      ),
      GoRoute(
        path: '/inbox',
        pageBuilder: (_, s) => _page(s, const InboxScreen()),
      ),
      // Hospital dashboard: a sidebar shell over seven screens.
      ShellRoute(
        builder: (_, state, child) => AdminShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/admin', builder: (_, _) => const AdminOverviewScreen()),
          GoRoute(path: '/admin/inventory', builder: (_, _) => const AdminInventoryScreen()),
          GoRoute(path: '/admin/requests', builder: (_, s) => AdminRequestsScreen(selectedId: s.uri.queryParameters['id'])),
          GoRoute(path: '/admin/checkin', builder: (_, _) => const AdminCheckInScreen()),
          GoRoute(path: '/admin/donors', builder: (_, _) => const AdminDonorsScreen()),
          GoRoute(path: '/admin/reports', builder: (_, _) => const AdminReportsScreen()),
          GoRoute(path: '/admin/profile', builder: (_, _) => const AdminProfileScreen()),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/map', builder: (_, _) => const MapScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/chats', builder: (_, _) => const ChatsScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/passport',
                builder: (_, _) => const PassportScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (_, _) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
