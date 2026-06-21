import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,

      colorScheme: const ColorScheme.light(
        primary: AppColors.lpmNavy,
        onPrimary: Colors.white,
        secondary: AppColors.lpmOrange,
        onSecondary: Colors.white,
        surface: AppColors.paperCream,
        onSurface: AppColors.inkBrown,
        error: AppColors.error,
        onError: Colors.white,
      ),

      scaffoldBackgroundColor: AppColors.paperCream,

      // === APP BAR ===
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.lpmNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: Colors.white, size: 24),
      ),

      // === NÚT BẤM ===
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.lpmOrange,
          foregroundColor: Colors.white,
          textStyle: AppTextStyles.buttonLarge,
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.lpmNavy,
          textStyle: AppTextStyles.buttonMedium,
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          side: const BorderSide(color: AppColors.lpmNavy, width: 2),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.lpmOrange,
          textStyle: AppTextStyles.buttonMedium,
          minimumSize: const Size(48, 44),
        ),
      ),

      // === FAB ===
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.lpmOrange,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // === CARD — Bóng rõ hơn ===
      cardTheme: CardThemeData(
        color: AppColors.paperAged,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(
            color: AppColors.paperBorder,
            width: 1.5,
          ),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      ),

      // === INPUT ===
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        labelStyle: AppTextStyles.label.copyWith(color: AppColors.inkLight),
        hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.inkFaded),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.paperBorder, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.paperBorder, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.lpmNavy, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
      ),

      // === DIVIDER ===
      dividerTheme: const DividerThemeData(
        color: AppColors.paperBorder,
        thickness: 1,
        space: 1,
      ),

      // === ICON ===
      iconTheme: const IconThemeData(
        color: AppColors.inkBrown,
        size: 24,
      ),

      // === DIALOG ===
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.paperCream,
        titleTextStyle: AppTextStyles.headlineSmall.copyWith(
          color: AppColors.inkBrown,
        ),
        contentTextStyle: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.inkBrown,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 8,
      ),

      // === SNACKBAR ===
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.lpmNavy,
        contentTextStyle: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),

      // === TAB BAR ===
      tabBarTheme: const TabBarThemeData(
        indicatorColor: Colors.white,
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white60,
        labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w400, fontSize: 14),
      ),
    );
  }
}
