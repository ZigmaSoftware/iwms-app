import 'package:flutter/material.dart';
import 'package:iwms_citizen_app/core/theme/app_colors.dart';

const LinearGradient _qrGradient = LinearGradient(
  colors: [AppColors.primary, AppColors.primaryVariant],
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
);

class OperatorQRButton extends StatelessWidget {
  const OperatorQRButton({
    super.key,
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 180,
        height: 180,
        padding: const EdgeInsets.all(22),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: _qrGradient,
          boxShadow: [
            BoxShadow(
              color: Color(0x332E7D5A),
              blurRadius: 22,
              offset: Offset(0, 16),
            ),
          ],
        ),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(
              Icons.qr_code_scanner_rounded,
              color: AppColors.primary,
              size: 64,
            ),
          ),
        ),
      ),
    );
  }
}
