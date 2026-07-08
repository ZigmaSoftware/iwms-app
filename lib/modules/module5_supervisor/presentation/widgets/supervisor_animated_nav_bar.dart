import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/presentation/theme/supervisor_theme.dart';

/// Supervisor bottom navigation — a FLOATING rounded-rectangle bar (App Store
/// style: detached from the screen edges, big corner radius, soft shadow, and
/// a frosted-glass fill) with 4 evenly-spaced tabs. Mirrors the driver's
/// [CaptainNavBar] visual treatment exactly — the glass card, 28px radius,
/// backdrop blur, animated indicator pill, scaled icon and always-visible
/// label — adapted to the supervisor's light theme tokens.
///
/// There is no centered FAB (the supervisor has no scan/today action), so the
/// four slots are simply distributed evenly across the width.
/// Layout: [tab0][tab1][tab2][tab3].
class SupervisorAnimatedNavBar extends StatelessWidget {
  const SupervisorAnimatedNavBar({
    super.key,
    required this.activeIndex,
    required this.onTabSelected,
    required this.items,
    this.height = 68,
  });

  final int activeIndex;
  final ValueChanged<int> onTabSelected;
  final List<SupervisorNavItem> items;
  final double height;

  static const double _radius = 28;

  @override
  Widget build(BuildContext context) {
    assert(
        items.length == 4, 'SupervisorAnimatedNavBar expects exactly 4 tabs');

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
          height: height,
          child: Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: Transform.translate(
                    offset: const Offset(-3, 6),
                    child: CustomPaint(
                      painter: const _NavLiquidGlassShadowPainter(
                        radius: _radius,
                        progress: 0,
                      ),
                    ),
                  ),
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(_radius),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 0.1, sigmaY: 0.1),
                  child: CustomPaint(
                    painter: const _NavLiquidGlassSurfacePainter(
                      radius: _radius,
                      progress: 0,
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        const Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _NavLiquidGlassSheenPainter(
                                radius: _radius,
                                progress: 0,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Row(
                            children: [
                              for (var i = 0; i < items.length; i++)
                                Expanded(child: _slot(i)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _slot(int index) => _AnimatedNavTab(
        item: items[index],
        selected: index == activeIndex,
        onTap: () => onTabSelected(index),
      );
}

class SupervisorNavItem {
  const SupervisorNavItem({
    required this.icon,
    required this.label,
    this.iconAsset,
  });

  final IconData icon;
  final String label;

  /// Optional raster icon. When set, the image is rendered in place of [icon]
  /// (used for the Profile tab's avatar).
  final String? iconAsset;
}

class _AnimatedNavTab extends StatelessWidget {
  const _AnimatedNavTab({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final SupervisorNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color =
        selected ? const ui.Color.fromARGB(255, 0, 94, 175) : SupervisorTheme.strongText;

    return InkResponse(
      onTap: onTap,
      radius: 38,
      highlightColor: Colors.white.withValues(alpha: 0.12),
      splashColor: SupervisorTheme.accent.withValues(alpha: 0.12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Active indicator pill above the icon (slides in on select)
          AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            width: selected ? 22 : 0,
            height: 3,
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: SupervisorTheme.accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          AnimatedScale(
            scale: selected ? 1.12 : 1,
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutBack,
            child: item.iconAsset != null
                ? Opacity(
                    opacity: selected ? 1 : 0.86,
                    child: Image.asset(
                      item.iconAsset!,
                      width: 26,
                      height: 26,
                      fit: BoxFit.contain,
                    ),
                  )
                : Icon(item.icon, color: color, size: 24),
          ),
          const SizedBox(height: 3),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
              letterSpacing: 0.2,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavLiquidGlassSurfacePainter extends CustomPainter {
  const _NavLiquidGlassSurfacePainter({
    required this.radius,
    required this.progress,
  });

  final double radius;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(0.5),
      Radius.circular(radius),
    );

    final press = progress.clamp(0.0, 1.0);

    // Mostly-opaque frosted base — enough tint to keep icons/labels sharp,
    // while still reading as translucent glass (not a flat white bar).
    final base = Paint()
      ..color = const Color(0xFFFBFAF7).withValues(alpha: 0.82);
    canvas.drawRRect(rrect, base);

    final fill = Paint()
      ..shader = LinearGradient(
        begin: const Alignment(-0.95, 0.95),
        end: const Alignment(0.95, -0.95),
        colors: [
          Colors.white.withValues(alpha: 0.05),
          Colors.white.withValues(alpha: 0.16),
          Colors.white.withValues(alpha: 0.05),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect);
    canvas.drawRRect(rrect, fill);

    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.black.withValues(alpha: 0.06),
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.5 - press * 0.14),
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(rect);
    canvas.drawRRect(rrect.deflate(0.7), rim);

    final innerRing = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.18);
    canvas.drawRRect(rrect.deflate(1.8), innerRing);

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15
      ..shader = SweepGradient(
        colors: [
          Colors.black.withValues(alpha: 0.48),
          Colors.transparent,
          Colors.white.withValues(alpha: 0.82),
          Colors.transparent,
          Colors.black.withValues(alpha: 0.48),
        ],
        stops: const [0.0, 0.18, 0.5, 0.82, 1.0],
        startAngle: -math.pi * (0.42 + press * 0.28),
        endAngle: math.pi * (1.58 + press * 0.28),
      ).createShader(rect);

    canvas.drawRRect(rrect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _NavLiquidGlassSurfacePainter oldDelegate) {
    return oldDelegate.radius != radius || oldDelegate.progress != progress;
  }
}

class _NavLiquidGlassSheenPainter extends CustomPainter {
  const _NavLiquidGlassSheenPainter({
    required this.radius,
    required this.progress,
  });

  final double radius;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(1),
      Radius.circular(radius),
    );

    canvas.save();
    canvas.clipRRect(rrect);

    final travel = ui.lerpDouble(-0.35, 0.45, progress)!;
    final sheenRect = Rect.fromLTWH(
      -size.width * 0.35 + size.width * travel,
      -size.height * 0.25,
      size.width * 1.35,
      size.height * 1.55,
    );

    final sheen = Paint()
      ..blendMode = BlendMode.screen
      ..shader = LinearGradient(
        begin: const Alignment(-1, -1),
        end: const Alignment(1, 1),
        colors: [
          Colors.transparent,
          Colors.white.withValues(alpha: 0.04),
          Colors.white.withValues(alpha: 0.42 + progress * 0.12),
          Colors.white.withValues(alpha: 0.04),
          Colors.transparent,
        ],
        stops: const [0.0, 0.4, 0.5, 0.55, 1.0],
        transform: const GradientRotation(-math.pi / 4),
      ).createShader(sheenRect);

    canvas.drawRect(sheenRect, sheen);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _NavLiquidGlassSheenPainter oldDelegate) {
    return oldDelegate.radius != radius || oldDelegate.progress != progress;
  }
}

class _NavLiquidGlassShadowPainter extends CustomPainter {
  const _NavLiquidGlassShadowPainter({
    required this.radius,
    required this.progress,
  });

  final double radius;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(1),
      Radius.circular(radius),
    );

    final shadow = Paint()
      ..maskFilter = MaskFilter.blur(
        BlurStyle.normal,
        ui.lerpDouble(12, 6, progress)!,
      )
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.black.withValues(alpha: 0.10),
          Colors.black.withValues(alpha: 0.18 - progress * 0.06),
        ],
      ).createShader(rect);

    canvas.drawRRect(
      rrect.shift(Offset(0, 5 - (3 * progress))),
      shadow,
    );

    final rimShadow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3)
      ..color = Colors.black.withValues(alpha: 0.16 - progress * 0.05);

    canvas.drawRRect(
      rrect.shift(const Offset(1, 1)),
      rimShadow,
    );
  }

  @override
  bool shouldRepaint(covariant _NavLiquidGlassShadowPainter oldDelegate) {
    return oldDelegate.radius != radius || oldDelegate.progress != progress;
  }
}
