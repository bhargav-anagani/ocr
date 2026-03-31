import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'providers/auth_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/upload/upload_screen.dart';
import 'screens/result/result_screen.dart';
import 'screens/history/history_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'core/theme/app_theme.dart';

// Provider ref for router redirect access
final _authStateProvider = Provider<AuthState>((ref) => ref.watch(authProvider));

GoRouter buildRouter(WidgetRef ref) {
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: ValueNotifier(0), // placeholder
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
      GoRoute(path: '/upload', builder: (_, __) => const UploadScreen()),
      GoRoute(
        path: '/result/:id',
        builder: (_, state) =>
            ResultScreen(resultId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/history', builder: (_, __) => const HistoryScreen()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
    ],
  );
}

class OcrApp extends ConsumerStatefulWidget {
  const OcrApp({super.key});

  @override
  ConsumerState<OcrApp> createState() => _OcrAppState();
}

class _OcrAppState extends ConsumerState<OcrApp> {
  late final GoRouter _router;
  bool _routerInitialized = false;

  @override
  void initState() {
    super.initState();
    _router = GoRouter(
      initialLocation: '/splash',
      routes: [
        GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
        GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
        GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
        GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
        GoRoute(path: '/upload', builder: (_, __) => const UploadScreen()),
        GoRoute(
          path: '/result/:id',
          builder: (_, state) =>
              ResultScreen(resultId: state.pathParameters['id']!),
        ),
        GoRoute(path: '/history', builder: (_, __) => const HistoryScreen()),
        GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      ],
    );
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen to auth state and navigate accordingly from splash
    ref.listen<AuthState>(authProvider, (prev, next) {
      if (next.status == AuthStatus.authenticated) {
        Future.microtask(() => _router.go('/dashboard'));
      } else if (next.status == AuthStatus.unauthenticated) {
        Future.microtask(() => _router.go('/login'));
      }
    });

    return MaterialApp.router(
      title: 'OcrVision',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      routerConfig: _router,
    );
  }
}
