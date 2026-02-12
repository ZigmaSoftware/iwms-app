import 'package:flutter/material.dart';
import 'package:iwms_citizen_app/core/constants.dart';
import 'package:iwms_citizen_app/core/ui/app_ui_tokens.dart';

class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.backgroundColor = kAccentColor,
    this.verticalPadding = 16,
    this.borderRadius = AppUiTokens.radiusLarge,
    this.expand = true,
    this.textStyle,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final double verticalPadding;
  final double borderRadius;
  final bool expand;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final button = ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        padding: EdgeInsets.symmetric(vertical: verticalPadding),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
      child: Text(
        label,
        style: textStyle ??
            const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
      ),
    );

    if (!expand) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}

