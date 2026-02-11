import 'package:flutter/material.dart';

class BannerSlide {
  const BannerSlide({
    required this.chipLabel,
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.icon,
    this.backgroundImage,
    this.subtitleFontSize,
    this.isNetworkImage = false,
  });

  final String chipLabel;
  final String title;
  final String subtitle;
  final List<Color> colors;
  final IconData icon;
  final String? backgroundImage;
  final double? subtitleFontSize;
  final bool isNetworkImage;
}
