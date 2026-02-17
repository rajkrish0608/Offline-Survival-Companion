import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:offline_survival_companion/presentation/bloc/app_bloc/app_bloc.dart';
import 'package:offline_survival_companion/presentation/screens/home_screen.dart';
import 'package:offline_survival_companion/presentation/screens/onboarding_screen.dart';
import 'package:offline_survival_companion/presentation/screens/emergency_screen.dart';
import 'package:offline_survival_companion/presentation/screens/maps_screen.dart';
import 'package:offline_survival_companion/presentation/screens/vault_screen.dart';
import 'package:offline_survival_companion/presentation/screens/guide_screen.dart';
import 'package:offline_survival_companion/presentation/screens/settings_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final appState = context.read<AppBloc>().state;

      if (appState is AppInitializing) {
        return '/';
      }

      if (appState is AppOnboardingRequired) {
        return '/onboarding';
      }

      if (appState is AppError) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
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
    ],
  );
}
