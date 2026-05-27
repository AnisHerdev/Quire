import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/home_screen.dart';
import '../screens/file_list_screen.dart';
import '../screens/search_results_screen.dart';
import '../screens/pdf_viewer_screen.dart';
import '../screens/offline_files_screen.dart';
import '../screens/profile_screen.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/folder/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return FileListScreen(folderId: id);
        },
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => const SearchResultsScreen(),
      ),
      GoRoute(
        path: '/viewer',
        builder: (context, state) => const PdfViewerScreen(),
      ),
      GoRoute(
        path: '/offline',
        builder: (context, state) => const OfflineFilesScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
    ],
  );
}
