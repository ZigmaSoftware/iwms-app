import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:iwms_citizen_app/modules/module2_driver/presentation/theme/captain_theme.dart';

/// Captain liquid-glass primitives — dual-mode.
///
/// DARK: smoked transparent panes over true black; bright edge light (sweep
/// ring, bottom rim), soft drop shadow, press sheen.
/// LIGHT: clear white panes over pure white; the edge light flips DARK so the
/// pane's silhouette stays visible, and shadows are removed entirely —
/// separation comes from the edge, the tint, and the dot grid lensing
/// through the blur.

/// A tappable glass panel. Wrap any content; the glass chrome is painted
/// around it. Use [tint] to wash the glass with a status colour.
class CaptainGlassCard extends StatefulWidget {
  const CaptainGlassCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = CaptainTheme.cardRadius,
    this.tint,
    this.enableSheen = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final Color? tint;
  final bool enableSheen;

  @override
  State<CaptainGlassCard> createState() => _CaptainGlassCardState();
}

class _CaptainGlassCardState extends State<CaptainGlassCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    reverseDuration: const Duration(milliseconds: 460),
  );

  late final Animation<double> _ease = CurvedAnimation(
    parent: _press,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeOutCubic,
  );

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final interactive = widget.onTap != null || widget.onLongPress != null;
    final dark = CaptainThemeStore.isDark.value;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: widget.borderRadius,
        splashColor: dark
            ? Colors.white.withValues(alpha: 0.16)
            : CaptainTheme.accent.withValues(alpha: 0.10),
        highlightColor: dark
            ? Colors.white.withValues(alpha: 0.06)
            : CaptainTheme.accent.withValues(alpha: 0.05),
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onTapDown: interactive ? (_) => _press.forward(from: 0) : null,
        onTapUp: interactive ? (_) => _press.reverse() : null,
        onTapCancel: interactive ? () => _press.reverse() : null,
        child: AnimatedBuilder(
          animation: _ease,
          builder: (context, child) {
            final t = _ease.value;
            final scale = ui.lerpDouble(1, 0.976, t)!;

            return Transform.scale(
              scale: scale,
              // passthrough keeps the parent's constraints flowing to the
              // painted surface — without it the glass shrink-wraps its
              // content and cards inside Expanded/ListView stay narrow.
              child: Stack(
                fit: StackFit.passthrough,
                clipBehavior: Clip.none,
                children: [
                  // Drop shadow only in dark mode — light-mode glass floats
                  // shadow-free by design.
                  if (dark)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _GlassShadowPainter(
                            radius: widget.borderRadius.topLeft.x,
                            progress: t,
                          ),
                        ),
                      ),
                    ),
                  ClipRRect(
                    borderRadius: widget.borderRadius,
                    child: BackdropFilter(
                      // Real lensing: enough blur that the dot grid visibly
                      // refracts through the panel — the "liquid" in liquid
                      // glass. Transparency does the rest; no milky fill.
                      filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                      child: CustomPaint(
                        painter: _GlassSurfacePainter(
                          radius: widget.borderRadius.topLeft.x,
                          progress: t,
                          tint: widget.tint,
                          dark: dark,
                        ),
                        child: Stack(
                          fit: StackFit.passthrough,
                          children: [
                            if (widget.enableSheen)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: CustomPaint(
                                    painter: _GlassSheenPainter(
                                      radius: widget.borderRadius.topLeft.x,
                                      progress: t,
                                      dark: dark,
                                    ),
                                  ),
                                ),
                              ),
                            Padding(padding: widget.padding, child: child),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
          child: widget.child,
        ),
      ),
    );
  }
}

/// Compact glass chip housing an icon. The plate is tinted with the icon's
/// own colour (not a white wash) so the glyph stays bold and legible on
/// either canvas; the glass look comes from the blur + edge ring.
class CaptainGlassChip extends StatelessWidget {
  const CaptainGlassChip({
    super.key,
    required this.icon,
    required this.color,
    this.size = 20,
    this.padding = const EdgeInsets.all(9),
  });

  final IconData icon;
  final Color color;
  final double size;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: CaptainTheme.chipRadius,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: CaptainTheme.chipRadius,
            border: Border.all(color: color.withValues(alpha: 0.55)),
          ),
          child: Padding(
            padding: padding,
            child: Icon(icon, color: color, size: size),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Painters
// ─────────────────────────────────────────────────────────────────────────────

class _GlassSurfacePainter extends CustomPainter {
  const _GlassSurfacePainter({
    required this.radius,
    required this.progress,
    required this.dark,
    this.tint,
  });

  final double radius;
  final double progress;
  final bool dark;
  final Color? tint;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(0.5),
      Radius.circular(radius),
    );
    final press = progress.clamp(0.0, 1.0);

    // Barely-there tint: just enough body that the panel reads as a pane of
    // glass, never a container. Dark mode: smoked. Light mode: white glass —
    // the dot grid stays faintly visible through it.
    final base = Paint()
      ..color = dark
          ? const Color(0xFF151917).withValues(alpha: 0.22)
          : Colors.white.withValues(alpha: 0.58);
    canvas.drawRRect(rrect, base);

    // −75° gradient fill (bottom-left → top-right) — whisper faint; the
    // shine lives on the EDGES, not in the body.
    final glossColor = dark ? Colors.white : const Color(0xFF0B1220);
    final fill = Paint()
      ..shader = LinearGradient(
        begin: const Alignment(-0.95, 0.95),
        end: const Alignment(0.95, -0.95),
        colors: [
          glossColor.withValues(alpha: dark ? 0.015 : 0.010),
          glossColor.withValues(alpha: dark ? 0.05 : 0.03),
          glossColor.withValues(alpha: dark ? 0.015 : 0.010),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect);
    canvas.drawRRect(rrect, fill);

    // Optional status wash.
    if (tint != null) {
      final wash = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tint!.withValues(alpha: dark ? 0.14 : 0.10),
            tint!.withValues(alpha: dark ? 0.04 : 0.03),
          ],
        ).createShader(rect);
      canvas.drawRRect(rrect, wash);
    }

    // Full-perimeter rim — the glass thickness catching light. In dark mode
    // a bright bottom edge; in light mode the rim flips dark on top with a
    // white inner bottom so the pane still reads dimensional.
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: dark
            ? [
                Colors.white.withValues(alpha: 0.10),
                Colors.white.withValues(alpha: 0.0),
                Colors.white.withValues(alpha: 0.55 - press * 0.14),
              ]
            : [
                const Color(0xFF0B1220).withValues(alpha: 0.16),
                const Color(0xFF0B1220).withValues(alpha: 0.0),
                Colors.white.withValues(alpha: 0.85),
              ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(rect);
    canvas.drawRRect(rrect.deflate(0.7), rim);

    final innerRing = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = dark
          ? Colors.white.withValues(alpha: 0.08)
          : const Color(0xFF0B1220).withValues(alpha: 0.04);
    canvas.drawRRect(rrect.deflate(1.8), innerRing);

    // Sweep-gradient border: light travelling around the edge; rotates
    // slightly while pressed. The travelling highlight is white on black,
    // ink on white — either way the edge shine survives the mode flip.
    final edgeLight = dark ? Colors.white : const Color(0xFF23324F);
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15
      ..shader = SweepGradient(
        colors: [
          edgeLight.withValues(alpha: dark ? 0.06 : 0.10),
          Colors.transparent,
          edgeLight.withValues(alpha: dark ? 0.92 : 0.45),
          Colors.transparent,
          edgeLight.withValues(alpha: dark ? 0.06 : 0.10),
        ],
        stops: const [0.0, 0.18, 0.5, 0.82, 1.0],
        startAngle: -math.pi * (0.42 + press * 0.28),
        endAngle: math.pi * (1.58 + press * 0.28),
      ).createShader(rect);
    canvas.drawRRect(rrect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _GlassSurfacePainter oldDelegate) {
    return oldDelegate.radius != radius ||
        oldDelegate.progress != progress ||
        oldDelegate.dark != dark ||
        oldDelegate.tint != tint;
  }
}

class _GlassSheenPainter extends CustomPainter {
  const _GlassSheenPainter({
    required this.radius,
    required this.progress,
    required this.dark,
  });

  final double radius;
  final double progress;
  final bool dark;

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

    // Dark: BlendMode.screen brightens without opaque paint. Light: screen
    // does nothing over white, so shade instead — a faint travelling shadow
    // reads as the reflection moving across the pane.
    final sheen = Paint()
      ..blendMode = dark ? BlendMode.screen : BlendMode.multiply
      ..shader = LinearGradient(
        begin: const Alignment(-1, -1),
        end: const Alignment(1, 1),
        colors: dark
            ? [
                Colors.transparent,
                Colors.white.withValues(alpha: 0.02),
                // Quiet at rest, flashes across on press — the shine is an
                // event, not a permanent wash.
                Colors.white.withValues(alpha: 0.10 + progress * 0.22),
                Colors.white.withValues(alpha: 0.02),
                Colors.transparent,
              ]
            : [
                Colors.transparent,
                const Color(0xFF23324F).withValues(alpha: 0.01),
                Color(0xFF23324F)
                    .withValues(alpha: 0.03 + progress * 0.06),
                const Color(0xFF23324F).withValues(alpha: 0.01),
                Colors.transparent,
              ],
        stops: const [0.0, 0.4, 0.5, 0.55, 1.0],
        transform: const GradientRotation(-math.pi / 4),
      ).createShader(sheenRect);

    canvas.drawRect(sheenRect, sheen);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GlassSheenPainter oldDelegate) {
    return oldDelegate.radius != radius ||
        oldDelegate.progress != progress ||
        oldDelegate.dark != dark;
  }
}

class _GlassShadowPainter extends CustomPainter {
  const _GlassShadowPainter({required this.radius, required this.progress});

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
          Colors.black.withValues(alpha: 0.08),
          Colors.black.withValues(alpha: 0.16 - progress * 0.06),
        ],
      ).createShader(rect);

    canvas.drawRRect(rrect.shift(Offset(0, 5 - (3 * progress))), shadow);
  }

  @override
  bool shouldRepaint(covariant _GlassShadowPainter oldDelegate) {
    return oldDelegate.radius != radius || oldDelegate.progress != progress;
  }
}

/// Circular trip-progress ring with a sweep-gradient stroke and centred label.
class CaptainProgressRing extends StatelessWidget {
  const CaptainProgressRing({
    super.key,
    required this.fraction,
    required this.label,
    required this.sublabel,
    this.size = 92,
    this.completed = false,
  });

  final double fraction;
  final String label;
  final String sublabel;
  final double size;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: fraction.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => CustomPaint(
              painter: _ProgressRingPainter(
                fraction: value,
                color: completed ? CaptainTheme.success : CaptainTheme.accent,
                trackColor: CaptainTheme.hairline.withValues(alpha: 0.55),
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: CaptainTheme.strongText,
                  height: 1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                sublabel,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: CaptainTheme.mutedText,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  const _ProgressRingPainter({
    required this.fraction,
    required this.color,
    required this.trackColor,
  });

  final double fraction;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) / 2) - 5;
    const stroke = 8.0;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = trackColor;
    canvas.drawCircle(center, radius, track);

    if (fraction <= 0) return;

    final sweep = 2 * math.pi * fraction;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: -math.pi / 2 + 2 * math.pi,
        colors: [color.withValues(alpha: 0.55), color],
        stops: const [0.0, 1.0],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) {
    return oldDelegate.fraction != fraction ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor;
  }
}
