import 'package:flutter/material.dart';
import 'package:iwms_citizen_app/core/ui/app_assets.dart';
import 'package:iwms_citizen_app/core/ui/app_ui_tokens.dart';

class BrandLogoBadge extends StatelessWidget {
  const BrandLogoBadge({
    super.key,
    this.size = 72,
    this.padding = 14,
    this.backgroundOpacity = 0.9,
    this.assetPath = AppAssets.logo,
    this.shadow = AppUiTokens.softLogoShadow,
  });

  final double size;
  final double padding;
  final double backgroundOpacity;
  final String assetPath;
  final BoxShadow shadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: backgroundOpacity),
        shape: BoxShape.circle,
        boxShadow: [shadow],
      ),
      child: Image.asset(assetPath),
    );
  }
}

