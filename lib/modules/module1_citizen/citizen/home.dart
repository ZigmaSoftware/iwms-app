import 'package:flutter/material.dart';

import 'package:iwms_citizen_app/modules/module1_citizen/citizen/dashboard/pages/citizen_dashboard_page.dart';
import 'package:iwms_citizen_app/modules/module1_citizen/citizen/dashboard/pages/onboarding_success_page.dart';

/// Wrapper to keep the existing route intact for the onboarding success screen.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.userName,
  });

  final String userName;

  @override
  Widget build(BuildContext context) {
    return OnboardingSuccessPage(userName: userName);
  }
}

/// Wrapper to keep the existing CitizenDashboard class name but delegate
/// to the modularized dashboard page.
class CitizenDashboard extends StatelessWidget {
  const CitizenDashboard({super.key, required this.userName});

  final String userName;

  @override
  Widget build(BuildContext context) {
    return CitizenDashboardPage(userName: userName);
  }
}
