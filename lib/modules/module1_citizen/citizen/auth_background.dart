import 'package:flutter/material.dart';
import 'package:iwms_citizen_app/core/ui/app_assets.dart';

/// Shared background used by login-style screens.
class AuthBackground extends StatelessWidget {
  const AuthBackground({
    super.key,
    this.topOverlayOpacity = 0.55,
    this.bottomOverlayOpacity = 0.35,
  });

  final double topOverlayOpacity;
  final double bottomOverlayOpacity;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          AppAssets.authBackground,
          fit: BoxFit.cover,
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: topOverlayOpacity),
                Colors.black.withValues(alpha: bottomOverlayOpacity),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
