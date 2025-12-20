import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';
import 'package:iwms_citizen_app/core/constants.dart'; // Import your kPrimaryColor

class AppTheme {
  static const PageTransitionsTheme _cupertinoPageTransitions =
      PageTransitionsTheme(
    builders: {
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
      TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
      TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
    },
  );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      primaryColor: kPrimaryColor,
      fontFamily: AppTextStyles.fontFamily,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: kPrimaryColor,
        primary: kPrimaryColor,
        secondary: AppColors.primaryVariant,
        surface: AppColors.surface,
        surfaceTint: AppColors.surfaceAlt,
        error: AppColors.error,
        onPrimary: AppColors.white,
        onSecondary: AppColors.white,
      ).copyWith(
        onSurface: AppColors.textPrimary,
        onSurfaceVariant: AppColors.textSecondary,
      ),
      textTheme: TextTheme(
        titleLarge: AppTextStyles.titleLarge,
        bodyMedium: AppTextStyles.bodyMedium,
        labelLarge: AppTextStyles.labelLarge,
        headlineMedium: AppTextStyles.heading2,
        titleMedium: AppTextStyles.subTitle,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primary,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: AppTextStyles.heading2.copyWith(color: Colors.white),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimaryColor,
          foregroundColor: AppColors.white,
          textStyle: AppTextStyles.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkOverlay,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kPrimaryColor, width: 2),
        ),
        labelStyle: AppTextStyles.subTitle,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 4,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.primary,
        textColor: AppColors.textPrimary,
      ),
      pageTransitionsTheme: _cupertinoPageTransitions,
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: kPrimaryColor,
      fontFamily: AppTextStyles.fontFamily,
      scaffoldBackgroundColor: AppColors.darkBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: kPrimaryColor,
        brightness: Brightness.dark,
        primary: kPrimaryColor,
        secondary: AppColors.primaryVariant,
        surface: AppColors.darkSurface,
        error: AppColors.error,
        onPrimary: AppColors.white,
        onSecondary: AppColors.white,
      ).copyWith(
        onSurface: AppColors.white,
        onSurfaceVariant: Colors.white70,
        surfaceTint: AppColors.darkCard,
      ),
      textTheme: TextTheme(
        titleLarge: AppTextStyles.titleLarge.copyWith(color: AppColors.white),
        bodyMedium: AppTextStyles.bodyMedium.copyWith(color: AppColors.white),
        labelLarge: AppTextStyles.labelLarge.copyWith(color: AppColors.white),
        headlineMedium: AppTextStyles.heading2.copyWith(color: AppColors.white),
        titleMedium: AppTextStyles.subTitle.copyWith(color: Colors.white70),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.darkOverlay,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: AppTextStyles.heading2.copyWith(color: Colors.white),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimaryColor,
          foregroundColor: AppColors.white,
          textStyle: AppTextStyles.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kPrimaryColor, width: 2),
        ),
        labelStyle:
            AppTextStyles.subTitle.copyWith(color: Colors.white70),
        floatingLabelStyle:
            AppTextStyles.subTitle.copyWith(color: Colors.white),
        hintStyle:
            AppTextStyles.subTitle.copyWith(color: Colors.white70),
        prefixIconColor: Colors.white70,
        suffixIconColor: Colors.white70,
        iconColor: Colors.white70,
      ),
      cardColor: AppColors.darkCard,
      dividerColor: Colors.white12,
      cardTheme: CardThemeData(
        color: AppColors.darkCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: Colors.white70,
        textColor: Colors.white,
      ),
      pageTransitionsTheme: _cupertinoPageTransitions,
    );
  }
}
