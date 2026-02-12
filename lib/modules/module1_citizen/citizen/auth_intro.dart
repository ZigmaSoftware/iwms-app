import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iwms_citizen_app/core/ui/app_copy.dart';
import 'package:iwms_citizen_app/core/ui/app_ui_tokens.dart';
import 'package:iwms_citizen_app/shared/widgets/app_primary_button.dart';
import 'package:iwms_citizen_app/shared/widgets/brand_logo_badge.dart';

import '../../../router/app_router.dart';
import 'auth_background.dart';

class CitizenAuthIntroScreen extends StatelessWidget {
  const CitizenAuthIntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(
            child: AuthBackground(
              topOverlayOpacity: 0.65,
              bottomOverlayOpacity: 0.45,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: AppUiTokens.authScreenPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const BrandLogoBadge(),
                  const Spacer(),
                  Text(
                    AppCopy.authIntroHeadline,
                    style: textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: AppUiTokens.spacing16),
                  Text(
                    AppCopy.authIntroSubtitle,
                    style: textTheme.bodyLarge?.copyWith(
                      color: Colors.white70,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: AppUiTokens.spacing32),
                  AppPrimaryButton(
                    label: AppCopy.signIn,
                    onPressed: () => context.go(AppRoutePaths.citizenLogin),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
