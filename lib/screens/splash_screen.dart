import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: -10, end: 10).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _checkFirstLaunchAndNavigate();
  }

  Future<void> _checkFirstLaunchAndNavigate() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirstLaunch = prefs.getBool('is_first_launch') ?? true;

    if (isFirstLaunch) {
      // First time using the app: let the premium Flutter animation play
      await prefs.setBool('is_first_launch', false);
      await Future.delayed(const Duration(milliseconds: 2500));
    }

    if (!mounted) return;

    // Check auth state and navigate immediately when loading finishes
    ref.listenManual(
      authProvider,
      (previous, next) {
        if (!next.isLoading && mounted) {
          if (next.isAuthenticated) {
            context.go('/home');
          } else {
            context.go('/login');
          }
        }
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: colorScheme.primaryContainer,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _animation.value),
                  child: child,
                );
              },
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.secondaryContainer.withOpacity(0.15),
                      blurRadius: 40,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 48),
            Text(
              'Quire',
              style: textTheme.displayLarge?.copyWith(
                color: colorScheme.onPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your notes, everywhere',
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onPrimaryContainer.withOpacity(0.9),
              ),
            ),
            const SizedBox(height: 64),
            SizedBox(
              width: 150,
              child: LinearProgressIndicator(
                backgroundColor: colorScheme.onPrimaryContainer.withOpacity(0.2),
                color: colorScheme.secondaryContainer,
                minHeight: 4,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
