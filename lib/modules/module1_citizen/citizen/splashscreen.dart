import 'package:flutter/material.dart';
import 'package:iwms_citizen_app/core/ui/app_assets.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Logo and Title
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    AppAssets.logo,
                    width: 150,
                    height: 150,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "Integrated Waste Management Suite",
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: const Color(0xFF0D47A1), // primaryBlue
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          
          // --- THIS IS THE FIX ---
          // Positioned MUST be the direct child of the Stack.
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            // The FadeTransition goes INSIDE the Positioned.
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: _buildPoweredByColumn(), // Call the refactored method
            ),
          ),
        ],
      ),
    );
  }

  // Refactored to only return the Column, not the Positioned
  Widget _buildPoweredByColumn() {
    return Column(
      children: [
        Text(
          "powered by",
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/zigma.png',
              height: 30,
            ),
            const SizedBox(width: 24),
            Image.asset(
              'assets/images/blueplanet.png',
              height: 30,
            ),
          ],
        ),
      ],
    );
  }
}
