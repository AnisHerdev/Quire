import 'dart:io' show Platform;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'routes/app_router.dart';
import 'theme/app_theme.dart';
import 'providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    const apiKey = String.fromEnvironment('FIREBASE_API_KEY_QUIRE');
    const appId = String.fromEnvironment('FIREBASE_APP_ID_QUIRE');
    const senderId = String.fromEnvironment('FIREBASE_SENDER_ID_QUIRE');
    const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID_QUIRE');

    if (apiKey.isEmpty || appId.isEmpty || senderId.isEmpty || projectId.isEmpty) {
      throw ArgumentError(
        'Desktop builds require --dart-define flags: '
        'FIREBASE_API_KEY_QUIRE, FIREBASE_APP_ID_QUIRE, FIREBASE_SENDER_ID_QUIRE, FIREBASE_PROJECT_ID_QUIRE',
      );
    }

    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: senderId,
        projectId: projectId,
      ),
    );
  } else {
    await Firebase.initializeApp();
  }

  runApp(
    const ProviderScope(
      child: QuireApp(),
    ),
  );
}

class QuireApp extends ConsumerWidget {
  const QuireApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeProvider);
    
    return MaterialApp.router(
      title: 'Quire',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}

