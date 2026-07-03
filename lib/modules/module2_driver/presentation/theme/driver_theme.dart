import 'package:flutter/material.dart';
import 'package:iwms_citizen_app/modules/module2_driver/presentation/theme/captain_theme.dart';

/// Legacy driver design tokens, now forwarding to [CaptainTheme].
///
/// The driver module was rebranded "Captain" when the operator app was merged
/// into it (one phone per vehicle, held by the driver). Existing screens keep
/// importing `DriverTheme`; every token below resolves to the Captain palette
/// so the whole module re-skins in one place — and, since Captain gained a
/// light/dark toggle, these are getters that resolve against the live mode.
/// They can no longer be captured inside `const` constructors. New code
/// should import [CaptainTheme] directly.
class DriverTheme {
  DriverTheme._();

  // Core palette — forwarded to CaptainTheme (mode-aware)
  static Color get primary => CaptainTheme.primary;
  static Color get primaryAccent => CaptainTheme.primaryAccent;
  static Color get primarySoft => CaptainTheme.primarySoft;

  static Color get accent => CaptainTheme.accent;
  static Color get accentDeep => CaptainTheme.accentDeep;
  static Color get accentSoft => CaptainTheme.accentSoft;

  static Color get background => CaptainTheme.background;
  static Color get surface => CaptainTheme.surface;
  static Color get surfaceMuted => CaptainTheme.surfaceMuted;

  static Color get strongText => CaptainTheme.strongText;
  static Color get mutedText => CaptainTheme.mutedText;
  static Color get hairline => CaptainTheme.hairline;

  static Color get success => CaptainTheme.success;
  static Color get warning => CaptainTheme.warning;
  static Color get danger => CaptainTheme.danger;
  static Color get info => CaptainTheme.info;

  // Gradients
  static LinearGradient get headerGradient => CaptainTheme.headerGradient;
  static LinearGradient get accentGradient => CaptainTheme.accentGradient;

  // Shadows
  static List<BoxShadow> get softShadow => CaptainTheme.softShadow;
  static List<BoxShadow> get elevatedShadow => CaptainTheme.elevatedShadow;

  // Radii
  static const BorderRadius cardRadius = CaptainTheme.cardRadius;
  static const BorderRadius chipRadius = CaptainTheme.chipRadius;

  static const EdgeInsets pagePadding = CaptainTheme.pagePadding;
}
