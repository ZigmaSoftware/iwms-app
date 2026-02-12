import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iwms_citizen_app/core/constants.dart';
import 'package:iwms_citizen_app/core/theme/app_colors.dart';
import 'package:iwms_citizen_app/core/ui/app_copy.dart';
import 'package:iwms_citizen_app/core/ui/app_ui_tokens.dart';
import 'package:iwms_citizen_app/shared/widgets/app_primary_button.dart';

import '../../../../router/app_router.dart';

const Color _driverPrimary = kPrimaryColor;
const Color _driverAccent = AppColors.driverAccent;

class DriverLoginScreen extends StatelessWidget {
  const DriverLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_driverPrimary, _driverAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Container(
                  width: 400,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppUiTokens.radiusMedium),
                    boxShadow: const [AppUiTokens.softLogoShadow],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _driverPrimary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.local_shipping_rounded,
                            color: _driverPrimary, size: 32),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        AppCopy.driverConsoleTitle,
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppCopy.driverConsoleSubtitle,
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium?.copyWith(
                          color: Colors.black.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 20),
                      AppPrimaryButton(
                        label: AppCopy.enterDriverDashboard,
                        onPressed: () => context.go(AppRoutePaths.driverHome),
                        backgroundColor: _driverPrimary,
                        verticalPadding: 14,
                        borderRadius: 14,
                        textStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
