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
        primary: AppColors.onPrimaryContainer, // Light green
        onPrimary: AppColors.primary, // Dark green
        primaryContainer: AppColors.primaryContainer, // Dark green
        onPrimaryContainer: AppColors.onPrimary, // White
        secondary: AppColors.secondaryContainer, // Light yellow
        onSecondary: AppColors.onSecondaryContainer, // Dark yellow
        secondaryContainer: AppColors.secondary, // Brownish
        onSecondaryContainer: AppColors.onSecondary, // White
        error: AppColors.errorContainer,
        onError: AppColors.onErrorContainer,
        errorContainer: AppColors.error,
        onErrorContainer: AppColors.onError,
        background: Color(0xFF111111), // Deep dark background
        onBackground: Color(0xFFF1F1F1),
        surface: Color(0xFF1A1A1A), // Slightly lighter surface
        onSurface: Color(0xFFF1F1F1),
        surfaceVariant: Color(0xFF2C2C2C), // Cards and containers
        onSurfaceVariant: Color(0xFFB3B3B3), // Subtitle text
        outline: Color(0xFF8F9791),
        outlineVariant: Color(0xFF717973),
      ),
      scaffoldBackgroundColor: const Color(0xFF111111),
      textTheme: AppTypography.textTheme.apply(
        bodyColor: const Color(0xFFF1F1F1),
        displayColor: const Color(0xFFF1F1F1),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF111111),
        foregroundColor: const Color(0xFFF1F1F1),
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppTypography.textTheme.headlineMedium?.copyWith(
          color: const Color(0xFFF1F1F1),
        ),
      ),
    );
  }
}
