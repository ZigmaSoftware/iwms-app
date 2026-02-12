import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iwms_citizen_app/core/ui/app_assets.dart';

import 'package:iwms_citizen_app/localization/app_localizations.dart';
import 'package:iwms_citizen_app/router/app_router.dart';

class OnboardingSuccessPage extends StatelessWidget {
  const OnboardingSuccessPage({
    super.key,
    required this.userName,
  });

  final String userName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primaryColor = colorScheme.primary;
    final textColor = colorScheme.onSurface;
    final mutedText = textColor.withValues(alpha: 0.7);
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          localizations.registrationSuccessTitle,
          style: theme.textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/bgd.jpg'),
              fit: BoxFit.cover,
              alignment: Alignment.bottomCenter,
            ),
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                localizations.welcomeMessage(userName),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge!.copyWith(
                  color: primaryColor,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 40),
              Image.asset(
                AppAssets.logo,
                width: 80,
                height: 80,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 20),
              Text(
                localizations.registrationComplete,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                localizations.qrActivatedDescription,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(color: mutedText),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: Icon(Icons.qr_code_2, color: primaryColor),
                  label: Text(
                    localizations.viewMyCollectionQr,
                    style:
                        theme.textTheme.labelLarge?.copyWith(color: primaryColor),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: primaryColor, width: 2),
                    textStyle:
                        theme.textTheme.labelLarge?.copyWith(color: primaryColor),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: Icon(Icons.feedback_outlined, color: primaryColor),
                  label: Text(
                    localizations.raiseGrievance,
                    style:
                        theme.textTheme.labelLarge?.copyWith(color: primaryColor),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: primaryColor, width: 2),
                    textStyle:
                        theme.textTheme.labelLarge?.copyWith(color: primaryColor),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              TextButton(
                onPressed: () => context.go(AppRoutePaths.citizenHome),
              child: Text(
                localizations.skipToDashboard,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: primaryColor,
                  fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
