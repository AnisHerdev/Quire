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
        primary: Color(0xFFB2DF22), // Much brighter neon-ish green for high contrast titles/icons
        onPrimary: AppColors.primary, 
        primaryContainer: AppColors.primaryContainer, 
        onPrimaryContainer: Colors.white, 
        secondary: Color(0xFFFFD54F), // Brighter yellow
        onSecondary: AppColors.onSecondaryContainer, 
        secondaryContainer: AppColors.secondary, 
        onSecondaryContainer: Colors.white, 
        error: AppColors.errorContainer,
        onError: AppColors.onErrorContainer,
        errorContainer: AppColors.error,
        onErrorContainer: AppColors.onError,
        background: Color(0xFF0F100F), // Very dark background
        onBackground: Colors.white, // Pure white for max contrast
        surface: Color(0xFF161716), // Slightly lighter surface
        onSurface: Colors.white, // Pure white text
        surfaceVariant: Color(0xFF2A2B2A), // Cards and containers
        onSurfaceVariant: Color(0xFFD0D0D0), // Much brighter subtitle text
        outline: Color(0xFFA0A0A0), // Lighter outlines
        outlineVariant: Color(0xFF707070),
      ),
      scaffoldBackgroundColor: const Color(0xFF0F100F),
      textTheme: AppTypography.textTheme.apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF0F100F),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppTypography.textTheme.headlineMedium?.copyWith(
          color: Colors.white,
        ),
      ),
    );
  }
}
