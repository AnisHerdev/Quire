import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        primaryContainer: AppColors.primaryContainer,
        onPrimaryContainer: AppColors.onPrimaryContainer,
        secondary: AppColors.secondary,
        onSecondary: AppColors.onSecondary,
        secondaryContainer: AppColors.secondaryContainer,
        onSecondaryContainer: AppColors.onSecondaryContainer,
        error: AppColors.error,
        onError: AppColors.onError,
        errorContainer: AppColors.errorContainer,
        onErrorContainer: AppColors.onErrorContainer,
        background: AppColors.background,
        onBackground: AppColors.onBackground,
        surface: AppColors.surface,
        onSurface: AppColors.onSurface,
        surfaceVariant: AppColors.surfaceVariant,
        onSurfaceVariant: AppColors.onSurfaceVariant,
        outline: AppColors.outline,
        outlineVariant: AppColors.outlineVariant,
      ),
      scaffoldBackgroundColor: AppColors.background,
      textTheme: AppTypography.textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.onSurface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppTypography.textTheme.headlineMedium,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: AppColors.primaryContainer,
        onPrimary: AppColors.onPrimaryContainer,
        primaryContainer: AppColors.primary,
        onPrimaryContainer: AppColors.onPrimary,
        secondary: AppColors.secondaryContainer,
        onSecondary: AppColors.onSecondaryContainer,
        secondaryContainer: AppColors.secondary,
        onSecondaryContainer: AppColors.onSecondary,
        error: AppColors.errorContainer,
        onError: AppColors.onErrorContainer,
        errorContainer: AppColors.error,
        onErrorContainer: AppColors.onError,
        background: Color(0xFF1B1C19),
        onBackground: Color(0xFFFAF9F4),
        surface: Color(0xFF1B1C19),
        onSurface: Color(0xFFFAF9F4),
        surfaceVariant: Color(0xFF414844),
        onSurfaceVariant: Color(0xFFE3E3DE),
        outline: AppColors.outlineVariant,
        outlineVariant: AppColors.outline,
      ),
      scaffoldBackgroundColor: const Color(0xFF1B1C19),
      textTheme: AppTypography.textTheme.apply(
        bodyColor: const Color(0xFFFAF9F4),
        displayColor: const Color(0xFFFAF9F4),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF1B1C19),
        foregroundColor: const Color(0xFFFAF9F4),
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppTypography.textTheme.headlineMedium?.copyWith(
          color: const Color(0xFFFAF9F4),
        ),
      ),
    );
  }
}
