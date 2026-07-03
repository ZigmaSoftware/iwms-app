import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Captain theme mode — dark (default) or light — persisted across launches
/// and toggled from the Profile tab. The Captain shell listens to [isDark]
/// and rebuilds its whole subtree, so every token below re-resolves live.
class CaptainThemeStore {
  CaptainThemeStore._();

  static const String _prefsKey = 'captain_dark_mode';
  static final ValueNotifier<bool> isDark = ValueNotifier<bool>(true);

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      isDark.value = prefs.getBool(_prefsKey) ?? true;
    } catch (_) {
      // Keep the default (dark) if prefs are unavailable.
    }
  }

  static Future<void> setDark(bool value) async {
    isDark.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, value);
    } catch (_) {}
  }

  static Future<void> toggle() => setDark(!isDark.value);
}

/// Captain — design tokens for the merged driver + operator experience.
///
/// One phone per vehicle, held by the driver: the "Captain" of the vehicle.
/// DUAL-MODE palette around a fixed royal-blue brand:
///   • DARK (default): true-black canvas, light dot grid, smoked glass with
///     bright edge light and soft shadows.
///   • LIGHT: pure-white canvas, dark visible dot grid, white glass with
///     dark edge light and NO shadows (borders carry the separation).
///   • The luminous royal ultramarine accent is identical in both modes —
///     the brand does not shift with the canvas.
///
/// Tokens are getters (not consts) so they resolve against the current mode;
/// widgets must therefore not capture them inside `const` constructors.
class CaptainTheme {
  CaptainTheme._();

  static bool get _dark => CaptainThemeStore.isDark.value;

  // ── Brand ────────────────────────────────────────────────────────────────
  static const String brandName = 'Captain';
  static const String brandTagline = 'Your vehicle. Your route. Your city.';

  // ── Ink (headers, primary surfaces) — deep royal navy in both modes ──────
  static Color get primary => const Color(0xFF101E3C);
  static Color get primaryAccent => const Color(0xFF070F22);
  static Color get primarySoft => const Color(0xFF1B2F5C);

  /// Ink used ON TOP of blue-filled controls (FAB, filled buttons) — deep
  /// navy reads sharper on the luminous blue than white does.
  static Color get onAccent => const Color(0xFF071033);

  // ── Brand royal blue (identical in both modes — the brand is fixed) ──────
  static Color get accent => const Color(0xFF4D7CFF); // royal ultramarine
  static Color get accentDeep => const Color(0xFF2743D6); // deep cobalt
  static Color get accentSoft =>
      _dark ? const Color(0xFF101A33) : const Color(0xFFE8EEFF);

  // ── Signal amber (attention, "next stop", pending) ───────────────────────
  static Color get gold =>
      _dark ? const Color(0xFFF5B85C) : const Color(0xFFB97207);
  static Color get goldSoft =>
      _dark ? const Color(0xFF2B2114) : const Color(0xFFFBF0DC);

  // ── Canvas ───────────────────────────────────────────────────────────────
  static Color get background =>
      _dark ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
  static Color get surface =>
      _dark ? const Color(0xFF151917) : const Color(0xFFFFFFFF);
  static Color get surfaceMuted =>
      _dark ? const Color(0xFF1E2421) : const Color(0xFFEFF2F7);

  // ── Text (near-black navy on white; off-white on black) ─────────────────
  static Color get strongText =>
      _dark ? const Color(0xFFF2F5F3) : const Color(0xFF0B1220);
  static Color get mutedText =>
      _dark ? const Color(0xFFA3AFA9) : const Color(0xFF515C6E);
  static Color get hairline =>
      _dark ? const Color(0xFF2C3330) : const Color(0xFFD4DAE4);

  // ── Status (brightened on black, deepened on white) ──────────────────────
  static Color get success =>
      _dark ? const Color(0xFF34D399) : const Color(0xFF0E9F6E);
  static Color get warning =>
      _dark ? const Color(0xFFFBBF24) : const Color(0xFFB45309);
  static Color get danger =>
      _dark ? const Color(0xFFF16A6A) : const Color(0xFFDC2626);
  static Color get info =>
      _dark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);

  // ── Gradients ────────────────────────────────────────────────────────────
  static LinearGradient get headerGradient => LinearGradient(
        colors: [primary, primaryAccent],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get accentGradient => LinearGradient(
        colors: [accent, accentDeep],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get goldGradient => const LinearGradient(
        colors: [Color(0xFFF7C97E), Color(0xFFDD8F1F)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  // ── Shadows — glass carries NO shadow in light mode ──────────────────────
  static List<BoxShadow> get softShadow => _dark
      ? const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ]
      : const [];

  static List<BoxShadow> get elevatedShadow => _dark
      ? const [
          BoxShadow(
            color: Color(0x8C000000),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ]
      : const [];

  // ── Shape ────────────────────────────────────────────────────────────────
  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(20));
  static const BorderRadius chipRadius = BorderRadius.all(Radius.circular(13));
  static const EdgeInsets pagePadding =
      EdgeInsets.symmetric(horizontal: 20, vertical: 16);
}

/// The Captain canvas: a dense, evenly spaced dot grid over the mode's base —
/// low-opacity light dots on true black, clearly visible dark dots on pure
/// white. The dots give the glass edge something to lens, and a pair of
/// faint colour glows keeps large empty areas from feeling dead.
class CaptainBackground extends StatelessWidget {
  const CaptainBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = CaptainThemeStore.isDark.value;
    return DecoratedBox(
      decoration: BoxDecoration(color: CaptainTheme.background),
      child: CustomPaint(
        painter: _CaptainAmbientPainter(dark: dark),
        child: child,
      ),
    );
  }
}

class _CaptainAmbientPainter extends CustomPainter {
  const _CaptainAmbientPainter({required this.dark});

  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    void blob(Offset center, double radius, Color color) {
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, paint);
    }

    // Whisper-faint glows only — the canvas must stay pure.
    blob(
      Offset(size.width * 0.10, size.height * 0.06),
      size.width * 0.65,
      CaptainTheme.accent.withValues(alpha: dark ? 0.05 : 0.05),
    );
    blob(
      Offset(size.width * 0.95, size.height * 0.35),
      size.width * 0.55,
      CaptainTheme.gold.withValues(alpha: dark ? 0.04 : 0.04),
    );

    // Dense, evenly spaced dot grid: light dots on black, DARK visible dots
    // on white.
    final dot = Paint()
      ..color = dark
          ? Colors.white.withValues(alpha: 0.055)
          : const Color(0xFF0B1220).withValues(alpha: 0.16);
    const gap = 18.0;
    for (double y = gap / 2; y < size.height; y += gap) {
      for (double x = gap / 2; x < size.width; x += gap) {
        canvas.drawCircle(Offset(x, y), 1.0, dot);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CaptainAmbientPainter oldDelegate) =>
      oldDelegate.dark != dark;
}
