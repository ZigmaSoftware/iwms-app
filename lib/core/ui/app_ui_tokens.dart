import 'package:flutter/material.dart';

/// Global UI tokens so spacing/radius/shadow tweaks can be done in one place.
class AppUiTokens {
  const AppUiTokens._();

  static const double radiusSmall = 12;
  static const double radiusMedium = 18;
  static const double radiusLarge = 30;
  static const double radiusPill = 999;

  static const double spacing8 = 8;
  static const double spacing12 = 12;
  static const double spacing16 = 16;
  static const double spacing20 = 20;
  static const double spacing24 = 24;
  static const double spacing32 = 32;

  static const EdgeInsets authScreenPadding =
      EdgeInsets.symmetric(horizontal: 32, vertical: 24);

  static const BoxShadow softLogoShadow = BoxShadow(
    color: Color(0x26000000),
    blurRadius: 20,
    offset: Offset(0, 10),
  );

  static const BoxShadow elevatedCardShadow = BoxShadow(
    color: Color(0x33000000),
    blurRadius: 30,
    offset: Offset(0, 12),
  );
}

