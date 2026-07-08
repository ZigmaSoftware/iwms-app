import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:iwms_citizen_app/shared/widgets/brand_logo_badge.dart';

import '../../../router/app_router.dart';

class CitizenIntroSlidesScreen extends StatefulWidget {
  const CitizenIntroSlidesScreen({super.key});

  @override
  State<CitizenIntroSlidesScreen> createState() =>
      _CitizenIntroSlidesScreenState();
}

class _CitizenIntroSlidesScreenState extends State<CitizenIntroSlidesScreen> {
  final PageController _pageController = PageController();
  static const Duration _pageAnimationDuration = Duration(milliseconds: 700);
  int _activeIndex = 0;

  void _handlePageChanged(int index) {
    setState(() {
      _activeIndex = index;
    });
  }

  void _goNext() {
    if (_activeIndex >= _introSlides.length - 1) {
      _openAuthLanding();
      return;
    }
    _pageController.nextPage(
      duration: _pageAnimationDuration,
      curve: Curves.easeInOutCubic,
    );
  }

  void _goPrevious() {
    if (_activeIndex == 0) return;
    _pageController.previousPage(
      duration: _pageAnimationDuration,
      curve: Curves.easeInOutCubic,
    );
  }

  void _openAuthLanding() => context.go(AppRoutePaths.citizenLogin);

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final slide = _introSlides[_activeIndex];
    final textShadows = [
      Shadow(
        color: Colors.black.withOpacity(0.45),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
    ];

    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            onPageChanged: _handlePageChanged,
            itemCount: _introSlides.length,
            itemBuilder: (context, index) {
              return SizedBox.expand(
                child: Image.asset(
                  _introSlides[index].assetPath,
                  fit: BoxFit.cover,
                ),
              );
            },
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.08),
                    Colors.black.withOpacity(0.6),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _goPrevious,
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _goNext,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Container(
                height: 220,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.0),
                      Colors.black.withOpacity(0.6),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                children: [
                  const BrandLogoBadge(
                    size: 60,
                    padding: 12,
                    backgroundOpacity: 0.95,
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _openAuthLanding,
                    child: const Text(
                      'Skip',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 32,
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: List.generate(_introSlides.length, (index) {
                      final bool isActive = index == _activeIndex;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.only(right: 6),
                        height: 6,
                        width: isActive ? 32 : 12,
                        decoration: BoxDecoration(
                          color: isActive
                              ? Colors.white
                              : Colors.white.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                  Animate(
                    key: ValueKey(slide.title),
                    effects: [
                      FadeEffect(duration: 520.ms, curve: Curves.easeOutCubic),
                      SlideEffect(
                        begin: const Offset(0, 0.24),
                        end: Offset.zero,
                        duration: 620.ms,
                        curve: Curves.easeOutCubic,
                      ),
                    ],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          slide.title,
                          textAlign: TextAlign.left,
                          style: textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            shadows: textShadows,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          slide.description,
                          textAlign: TextAlign.left,
                          style: textTheme.bodyLarge?.copyWith(
                            color: Colors.white.withOpacity(0.9),
                            height: 1.5,
                            shadows: textShadows,
                          ),
                        ),
                      ],
                    ),
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

class _IntroSlide {
  final String title;
  final String description;
  final String assetPath;

  const _IntroSlide({
    required this.title,
    required this.description,
    required this.assetPath,
  });
}

const List<_IntroSlide> _introSlides = [
  _IntroSlide(
    title: 'Friendly doorstep pickups',
    description:
        'Hand over your wet, dry and mixed bags with a smile - our crew is here to help on time.',
    assetPath: 'assets/intro/intro1.png',
  ),
  _IntroSlide(
    title: 'Track your progress',
    description:
        'See how much you recycled this month and stay motivated with easy-to-read stats.',
    assetPath: 'assets/intro/intro2.png',
  ),
  _IntroSlide(
    title: 'Smarter recycling plants',
    description:
        'Every sorted bag powers automated recycling lines that turn trash into new materials.',
    assetPath: 'assets/intro/intro3.png',
  ),
  _IntroSlide(
    title: 'Keep our city green',
    description:
        'Rolling hills, bright trees and clean rivers stay beautiful when we segregate waste every day.',
    assetPath: 'assets/intro/intro4.png',
  ),
];
