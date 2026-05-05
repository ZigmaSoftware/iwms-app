// lib/presentation/user_selection/user_selection_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:iwms_citizen_app/router/app_router.dart';
import '../../modules/module1_citizen/citizen/auth_background.dart';

class UserSelectionScreen extends StatefulWidget {
  const UserSelectionScreen({super.key});

  @override
  State<UserSelectionScreen> createState() => _UserSelectionScreenState();
}

class _UserSelectionScreenState extends State<UserSelectionScreen> {
  bool _isCitizen = true; // default selection

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final primaryColor = theme.colorScheme.primary;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AuthBackground(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: screenHeight - 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // TOP RIGHT TOGGLE
                    Align(
                      alignment: Alignment.topRight,
                      child: _buildAnimatedToggle(),
                    ),

                    const SizedBox(height: 40),

                    // LOGO
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Padding(
                        padding: const EdgeInsets.all(25.0),
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // TITLE
                    Text(
                      "Welcome to IWMS",
                      style: textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      "Select your Role",
                      style: textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 30),

                    // MAIN CONTENT SWITCH
                    Container(
                      margin: const EdgeInsets.only(top: 24),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: _isCitizen
                          ? _buildCitizenContent(
                              context,
                              primaryColor,
                              screenHeight,
                            )
                          : _buildOperatorContent(context, primaryColor),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // TOGGLE SWITCH (Final working version)
  // ----------------------------------------------------------

  Widget _buildAnimatedToggle() {
    final bool citizenActive = _isCitizen;
    final bool operatorActive = !_isCitizen;

    return Container(
      height: 50,
      width: 200, // Increased width (no more overflow)
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.5),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Sliding selection pill
          AnimatedPositioned(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            left: citizenActive ? 4 : 104, // FIXED position
            top: 4,
            child: Container(
              width: 92, // Slightly smaller so both sides fit
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(25),
              ),
            ),
          ),

          // Labels
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  if (!_isCitizen) {
                    setState(() => _isCitizen = true);
                  }
                },
                child: SizedBox(
                  width: 92,
                  height: 32,
                  child: Center(
                    child: Text(
                      "Citizen",
                      style: TextStyle(
                        color: Colors.white.withValues(
                          alpha: citizenActive ? 1.0 : 0.7,
                        ),
                        fontWeight:
                            citizenActive ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  if (_isCitizen) {
                    setState(() => _isCitizen = false);
                  }
                },
                child: SizedBox(
                  width: 92,
                  height: 32,
                  child: Center(
                    child: Text(
                      "Operator",
                      style: TextStyle(
                        color: Colors.white.withValues(
                          alpha: operatorActive ? 1.0 : 0.7,
                        ),
                        fontWeight:
                            operatorActive ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // CITIZEN VIEW
  // ----------------------------------------------------------

  Widget _buildCitizenContent(
    BuildContext context,
    Color primaryColor,
    double screenHeight,
  ) {
    final double topSpacing = (screenHeight * 0.12).clamp(60.0, 140.0);

    return Column(
      children: [
        SizedBox(height: topSpacing),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              context.push(AppRoutePaths.citizenIntroSlides);
            },
            child: const Text(
              "Sign in as Citizen",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // ----------------------------------------------------------
  // OPERATOR/DRIVER/ADMIN VIEW
  // ----------------------------------------------------------

  Widget _buildOperatorContent(BuildContext context, Color primaryColor) {
    return Column(
      children: [
        const SizedBox(height: 30),
        _UserRoleCard(
          icon: Icons.build,
          title: "Operator",
          onTap: () => context.push(AppRoutePaths.operatorLogin),
          iconColor: primaryColor,
        ),
        _UserRoleCard(
          icon: Icons.local_shipping_rounded,
          title: "Driver",
          onTap: () => context.push(AppRoutePaths.driverLogin),
          iconColor: primaryColor,
        ),
        _UserRoleCard(
          icon: Icons.admin_panel_settings,
          title: "Admin",
          onTap: () => context.push(AppRoutePaths.operatorLogin),
          iconColor: primaryColor,
        ),
      ],
    );
  }
}

// ----------------------------------------------------------
// ROLE CARD WIDGET (unchanged)
// ----------------------------------------------------------

class _UserRoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color iconColor;

  const _UserRoleCard({
    required this.icon,
    required this.title,
    required this.onTap,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 28),
              const SizedBox(width: 24),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Spacer(),
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
