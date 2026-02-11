import 'package:flutter/material.dart';

class QuickAction {
  const QuickAction({
    required this.label,
    required this.assetPath,
    required this.onTap,
  });

  final String label;
  final String assetPath;
  final VoidCallback onTap;
}
