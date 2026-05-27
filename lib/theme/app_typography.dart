import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTypography {
  static TextTheme get textTheme {
    return TextTheme(
      displayLarge: GoogleFonts.lora(
        fontSize: 48,
        height: 56 / 48,
        letterSpacing: -0.02 * 48,
        fontWeight: FontWeight.w700,
        color: AppColors.onSurface,
      ),
      headlineLarge: GoogleFonts.lora(
        fontSize: 32,
        height: 40 / 32,
        fontWeight: FontWeight.w600,
        color: AppColors.onSurface,
      ),
      headlineMedium: GoogleFonts.lora(
        fontSize: 24,
        height: 32 / 24,
        fontWeight: FontWeight.w600,
        color: AppColors.onSurface,
      ),
      // In flutter, 'titleLarge' is often used where 'headline-lg-mobile' would be used, but we can stick to standard names.
      bodyLarge: GoogleFonts.inter(
        fontSize: 18,
        height: 28 / 18,
        fontWeight: FontWeight.w400,
        color: AppColors.onSurface,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 16,
        height: 24 / 16,
        fontWeight: FontWeight.w400,
        color: AppColors.onSurface,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        height: 20 / 14,
        letterSpacing: 0.01 * 14,
        fontWeight: FontWeight.w600,
        color: AppColors.onSurface,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 12,
        height: 16 / 12,
        fontWeight: FontWeight.w500,
        color: AppColors.onSurface,
      ),
    );
  }
}
