import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/home_screen.dart';
import '../screens/file_list_screen.dart';
import '../screens/subject_files_screen.dart';
import '../screens/inbox_screen.dart';
import '../screens/search_results_screen.dart';
import '../screens/pdf_viewer_screen.dart';
import '../screens/offline_files_screen.dart';
import '../screens/profile_screen.dart';
import '../providers/auth_provider.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      // Don't redirect while auth is loading initially
      if (authState.isLoading) return null;

      final isAuth = authState.isAuthenticated;
      final isSplash = state.matchedLocation == '/';
      final isLogin = state.matchedLocation == '/login';
      final isGoingToAuthOrSplash = isSplash || isLogin;

      if (!isAuth && !isGoingToAuthOrSplash) {
        return '/login';
      }
      
      if (isAuth && isGoingToAuthOrSplash) {
        return '/home';
      }

      return null;
    },
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
        path: '/subject/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return SubjectFilesScreen(subjectId: id);
        },
      ),
      GoRoute(
        path: '/inbox',
        builder: (context, state) => const InboxScreen(),
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => const SearchResultsScreen(),
      ),
      GoRoute(
        path: '/pdf-viewer/:fileId',
        builder: (context, state) {
          final fileId = state.pathParameters['fileId']!;
          return PdfViewerScreen(fileId: fileId);
        },
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
});
