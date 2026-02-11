import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';

import '../../common/theme_tokens.dart';
import '../models/banner_slide.dart';

class BannerPager extends StatelessWidget {
  const BannerPager({
    super.key,
    required this.controller,
    required this.slides,
    required this.currentIndex,
    required this.isDarkMode,
    this.pageViewHeight,
    this.onPageChanged,
  });

  final PageController controller;
  final List<BannerSlide> slides;
  final int currentIndex;
  final bool isDarkMode;
  final double? pageViewHeight;
  final ValueChanged<int>? onPageChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    const double indicatorHeight = 10;
    const double indicatorActiveWidth = 26;
    const double indicatorInactiveWidth = 10;
    const double indicatorSpacing = DashboardThemeTokens.spacing6;

    final double pagerHeight = (pageViewHeight ?? 180);

    return SizedBox(
      // Reserve enough height for pager + indicators to avoid tiny overflows.
      // Add a small buffer to avoid fractional overflows in tight layouts.
      height: pagerHeight + indicatorHeight + (indicatorSpacing * 2) + 6,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: pagerHeight,
            child: PageView.builder(
              controller: controller,
              itemCount: slides.length,
              physics: const BouncingScrollPhysics(),
              onPageChanged: onPageChanged,
              itemBuilder: (context, index) {
                final slide = slides[index];
                final bool isFocused = index == currentIndex;
                final ImageProvider? backgroundProvider =
                    slide.backgroundImage == null
                        ? null
                        : slide.isNetworkImage
                            ? NetworkImage(slide.backgroundImage!)
                            : AssetImage(slide.backgroundImage!)
                                as ImageProvider;
                final bool hasImage = backgroundProvider != null;
                const animationDuration = DashboardThemeTokens.animationNormal;

                return AnimatedScale(
                  duration: animationDuration,
                  curve: Curves.easeOutCubic,
                  scale: isFocused ? 1 : 0.94,
                  child: AnimatedOpacity(
                    duration: animationDuration,
                    curve: Curves.easeOutCubic,
                    opacity: isFocused ? 1 : 0.85,
                    child: AnimatedContainer(
                      duration: animationDuration,
                      curve: Curves.easeOutCubic,
                      decoration: BoxDecoration(
                        gradient: hasImage
                            ? null
                            : LinearGradient(
                                colors: slide.colors,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                        image: backgroundProvider == null
                            ? null
                            : DecorationImage(
                                image: backgroundProvider,
                                fit: BoxFit.cover,
                                colorFilter: ColorFilter.mode(
                                  Colors.black.withOpacity(0.35),
                                  BlendMode.darken,
                                ),
                              ),
                        borderRadius: BorderRadius.circular(
                          DashboardThemeTokens.radiusXL,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: slide.colors.last.withValues(alpha: 0.25),
                            blurRadius: isFocused ? 30 : 10,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (hasImage)
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.black
                                        .withOpacity(isFocused ? 0.35 : 0.45),
                                    Colors.black.withOpacity(0.15),
                                  ],
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                ),
                              ),
                            ),
                          Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: DashboardThemeTokens.spacing16,
                            vertical: DashboardThemeTokens.spacing12,
                          ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: DashboardThemeTokens.spacing12,
                                    vertical: DashboardThemeTokens.spacing4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(
                                      DashboardThemeTokens.radiusMedium,
                                    ),
                                  ),
                                  child: Text(
                                    slide.chipLabel.toUpperCase(),
                                    style: textTheme.labelSmall?.copyWith(
                                      color: Colors.white,
                                      letterSpacing: 0.6,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(
                                  height: DashboardThemeTokens.spacing10,
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          AutoSizeText(
                                            slide.title,
                                            style:
                                                textTheme.titleLarge?.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                            ),
                                            maxLines: 2,
                                            minFontSize: 18,
                                            maxFontSize: 28,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(
                                            height:
                                                DashboardThemeTokens.spacing8,
                                          ),
                                          AutoSizeText(
                                            slide.subtitle,
                                            style: textTheme.bodySmall?.copyWith(
                                              color: Colors.white
                                                  .withValues(alpha: 0.85),
                                              fontWeight: FontWeight.w600,
                                              fontSize:
                                                  slide.subtitleFontSize ?? 12,
                                            ),
                                            maxLines: 2,
                                            minFontSize: 10,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(
                                      width: DashboardThemeTokens.spacing16,
                                    ),
                                    Icon(
                                      slide.icon,
                                      color: Colors.white,
                                      size: 38,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: indicatorSpacing),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(slides.length, (index) {
              final bool isActive = currentIndex == index;
              final Color activeColor =
                  isDarkMode ? Colors.white : Colors.black87;
              final Color inactiveColor =
                  isDarkMode ? Colors.white24 : Colors.black26;
              return AnimatedContainer(
                duration: DashboardThemeTokens.animationFast,
                margin: const EdgeInsets.symmetric(
                  horizontal: indicatorSpacing,
                ),
                height: indicatorHeight,
                width: isActive ? indicatorActiveWidth : indicatorInactiveWidth,
                decoration: BoxDecoration(
                  color: isActive ? activeColor : inactiveColor,
                  borderRadius: BorderRadius.circular(indicatorHeight * 2),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
