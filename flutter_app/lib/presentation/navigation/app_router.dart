import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:offline_survival_companion/presentation/bloc/app_bloc/app_bloc.dart';
import 'package:offline_survival_companion/presentation/screens/home_screen.dart';
import 'package:offline_survival_companion/presentation/screens/emergency_screen.dart';
import 'package:offline_survival_companion/presentation/screens/maps_screen.dart';
import 'package:offline_survival_companion/presentation/screens/vault_screen.dart';
import 'package:offline_survival_companion/presentation/screens/guide_screen.dart';
import 'package:offline_survival_companion/presentation/screens/settings_screen.dart';
import 'package:offline_survival_companion/presentation/screens/qr_scanner_screen.dart';
import 'package:offline_survival_companion/presentation/screens/women_safety/women_safety_dashboard.dart';
import 'package:offline_survival_companion/presentation/screens/women_safety/fake_call_screen.dart';
import 'package:offline_survival_companion/presentation/screens/women_safety/safety_timer_screen.dart';
import 'package:offline_survival_companion/presentation/screens/women_safety/self_defense_screen.dart';
import 'package:offline_survival_companion/presentation/screens/women_safety/helpline_directory_screen.dart';
import 'package:offline_survival_companion/presentation/screens/survival/signal_tools_screen.dart';
import 'package:offline_survival_companion/presentation/screens/survival/ar_compass_screen.dart';
import 'package:offline_survival_companion/presentation/screens/emergency_contacts_screen.dart';
import 'package:offline_survival_companion/presentation/screens/webpage_saver_screen.dart';
import 'package:offline_survival_companion/presentation/screens/user_manual_screen.dart';
import 'package:offline_survival_companion/presentation/screens/splash_screen.dart';
import 'package:offline_survival_companion/presentation/screens/admin/admin_dashboard_screen.dart';
import 'package:offline_survival_companion/presentation/screens/auth/login_screen.dart';
import 'package:offline_survival_companion/presentation/screens/auth/register_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final appState = context.read<AppBloc>().state;
      final location = state.uri.path;

      // Emergency route must always be accessible (safety-critical)
      if (location == '/emergency') {
        return null;
      }

      if (appState is AppInitializing) {
        return (location == '/splash') ? null : '/splash';
      }

      if (appState is AppUnauthenticated) {
        if (location != '/login' && location != '/register') {
          return '/login';
        }
        return null; // allow access to login/register
      }

      if (appState is AppReady) {
        if (location == '/login' || location == '/register' || location == '/splash') {
          return '/';
        }
      }

      if (appState is AppError) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/emergency',
        builder: (context, state) => const EmergencyScreen(),
        pageBuilder: (context, state) => MaterialPage(
          fullscreenDialog: true,
          child: const EmergencyScreen(),
        ),
      ),
      GoRoute(path: '/maps', builder: (context, state) => const MapsScreen()),
      GoRoute(path: '/vault', builder: (context, state) => const VaultScreen()),
      GoRoute(path: '/guide', builder: (context, state) => const GuideScreen()),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/qr-scanner',
        builder: (context, state) => const QrScannerScreen(),
      ),
      GoRoute(
        path: '/emergency-contacts',
        builder: (context, state) => const EmergencyContactsScreen(),
      ),
      GoRoute(
        path: '/web-saver',
        builder: (context, state) => const WebpageSaverScreen(),
      ),
      GoRoute(
        path: '/women-safety',
        builder: (context, state) => const WomenSafetyDashboard(),
      ),
      GoRoute(
        path: '/fake-call',
        builder: (context, state) => const FakeCallScreen(),
      ),
      GoRoute(
        path: '/safety-timer',
        builder: (context, state) => const SafetyTimerScreen(),
      ),
      GoRoute(
        path: '/self-defense',
        builder: (context, state) => const SelfDefenseScreen(),
      ),
      GoRoute(
        path: '/helpline-directory',
        builder: (context, state) => const HelplineDirectoryScreen(),
      ),
      GoRoute(
        path: '/signal-tools',
        builder: (context, state) => const SignalToolsScreen(),
      ),
      GoRoute(
        path: '/ar-compass',
        builder: (context, state) => const ARCompassScreen(),
      ),
      GoRoute(
        path: '/user-manual',
        builder: (context, state) => const UserManualScreen(),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminDashboardScreen(),
      ),
    ],
  );
}
