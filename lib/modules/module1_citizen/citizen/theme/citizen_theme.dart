import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:iwms_citizen_app/core/theme/app_text_styles.dart';
import 'package:iwms_citizen_app/core/ui/app_ui_tokens.dart';

/// Royal premium blue palette for the Citizen module ONLY.
///
/// The rest of the app (driver / operator / admin / supervisor) keeps the
/// shared green brand in `AppColors`. These tokens intentionally mirror the
/// `AppColors` API so citizen widgets can swap green -> blue with a 1:1 rename.
class CitizenColors {
  const CitizenColors._();

  // Core royal blue ramp
  static const Color primary = Color(0xFF25408F); // Royal blue core
  static const Color primaryVariant = Color(0xFF3556B5); // Brighter royal accent
  static const Color primaryMid = Color(0xFF2F51AD); // Mid royal
  static const Color primaryBright = Color(0xFF5B84EF); // Light royal
  static const Color primaryStrong = Color(0xFF3B5FD9); // Vivid royal

  static const Color deep = Color(0xFF1B2F72); // Deep navy-royal
  static const Color deeper = Color(0xFF15275F);
  static const Color deepest = Color(0xFF1E3A85);

  static const Color accentLight = Color(0xFFE9EEFC); // Soft blue wash
  static const Color accentMuted = Color(0xFFD5E0F8);

  static const Color textPrimary = Color(0xFF14224D);
  static const Color textSecondary = Color(0xFF546089);
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);

  static const Color background = Color(0xFFF2F5FD);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFE8EEFB);

  static const Color error = Color(0xFFEF5350);
  static const Color success = Color(0xFF1ABC9C);
  static const Color warning = Color(0xFFFFB74D);

  // Dark palette tuned to the royal blue brand
  static const Color darkBackground = Color(0xFF060A1C);
  static const Color darkSurface = Color(0xFF10193B);
  static const Color darkOverlay = Color(0xFF152250);
  static const Color darkCard = Color(0xFF1E2C5A);
}

/// Theme override applied to the citizen navigation subtree so that all
/// theme-inherited surfaces (app bars, buttons, color scheme) render blue.
class CitizenTheme {
  const CitizenTheme._();

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

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      primaryColor: CitizenColors.primary,
      fontFamily: AppTextStyles.fontFamily,
      scaffoldBackgroundColor: CitizenColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: CitizenColors.primary,
        primary: CitizenColors.primary,
        secondary: CitizenColors.primaryVariant,
        surface: CitizenColors.surface,
        surfaceTint: CitizenColors.surfaceAlt,
        error: CitizenColors.error,
        onPrimary: CitizenColors.white,
        onSecondary: CitizenColors.white,
      ).copyWith(
        onSurface: CitizenColors.textPrimary,
        onSurfaceVariant: CitizenColors.textSecondary,
      ),
      textTheme: TextTheme(
        titleLarge: AppTextStyles.titleLarge,
        bodyMedium: AppTextStyles.bodyMedium,
        labelLarge: AppTextStyles.labelLarge,
        headlineMedium: AppTextStyles.heading2,
        titleMedium: AppTextStyles.subTitle,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: CitizenColors.primary,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: AppTextStyles.heading2.copyWith(color: Colors.white),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: CitizenColors.primary,
          foregroundColor: CitizenColors.white,
          textStyle: AppTextStyles.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppUiTokens.radiusMedium),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: CitizenColors.surfaceAlt,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppUiTokens.radiusMedium),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppUiTokens.radiusMedium),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppUiTokens.radiusMedium),
          borderSide: const BorderSide(color: CitizenColors.primary, width: 2),
        ),
        labelStyle: AppTextStyles.subTitle,
      ),
      cardTheme: CardThemeData(
        color: CitizenColors.surface,
        elevation: 4,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppUiTokens.spacing20),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: CitizenColors.primary,
        textColor: CitizenColors.textPrimary,
      ),
      pageTransitionsTheme: _cupertinoPageTransitions,
    );
  }

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: CitizenColors.primary,
      fontFamily: AppTextStyles.fontFamily,
      scaffoldBackgroundColor: CitizenColors.darkBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: CitizenColors.primary,
        brightness: Brightness.dark,
        primary: CitizenColors.primaryBright,
        secondary: CitizenColors.primaryVariant,
        surface: CitizenColors.darkSurface,
        error: CitizenColors.error,
        onPrimary: CitizenColors.white,
        onSecondary: CitizenColors.white,
      ).copyWith(
        onSurface: CitizenColors.white,
        onSurfaceVariant: Colors.white70,
        surfaceTint: CitizenColors.darkCard,
      ),
      textTheme: TextTheme(
        titleLarge: AppTextStyles.titleLarge.copyWith(color: CitizenColors.white),
        bodyMedium: AppTextStyles.bodyMedium.copyWith(color: CitizenColors.white),
        labelLarge: AppTextStyles.labelLarge.copyWith(color: CitizenColors.white),
        headlineMedium:
            AppTextStyles.heading2.copyWith(color: CitizenColors.white),
        titleMedium: AppTextStyles.subTitle.copyWith(color: Colors.white70),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: CitizenColors.darkOverlay,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: AppTextStyles.heading2.copyWith(color: Colors.white),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: CitizenColors.primaryStrong,
          foregroundColor: CitizenColors.white,
          textStyle: AppTextStyles.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppUiTokens.radiusMedium),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: CitizenColors.darkSurface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppUiTokens.radiusMedium),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppUiTokens.radiusMedium),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppUiTokens.radiusMedium),
          borderSide:
              const BorderSide(color: CitizenColors.primaryBright, width: 2),
        ),
        labelStyle: AppTextStyles.subTitle.copyWith(color: Colors.white70),
        floatingLabelStyle:
            AppTextStyles.subTitle.copyWith(color: Colors.white),
        hintStyle: AppTextStyles.subTitle.copyWith(color: Colors.white70),
        prefixIconColor: Colors.white70,
        suffixIconColor: Colors.white70,
        iconColor: Colors.white70,
      ),
      cardColor: CitizenColors.darkCard,
      dividerColor: Colors.white12,
      cardTheme: CardThemeData(
        color: CitizenColors.darkCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppUiTokens.spacing20),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: Colors.white70,
        textColor: Colors.white,
      ),
      pageTransitionsTheme: _cupertinoPageTransitions,
    );
  }

  /// Wraps [child] so the citizen subtree renders with the blue theme while
  /// inheriting the active brightness from the ancestor [MaterialApp].
  static Widget wrap(BuildContext context, Widget child) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Theme(data: isDark ? dark : light, child: child);
  }
}
