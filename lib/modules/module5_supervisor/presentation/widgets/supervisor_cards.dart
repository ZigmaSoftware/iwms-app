import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/data/supervisor_models.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/presentation/theme/supervisor_theme.dart';

/// Dashboard KPI tile — a compact number + label card with a tinted icon chip.
class SupervisorKpiCard extends StatefulWidget {
  const SupervisorKpiCard({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  State<SupervisorKpiCard> createState() => _SupervisorKpiCardState();
}

class _SupervisorKpiCardState extends State<SupervisorKpiCard>
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

  void _down(TapDownDetails _) {
    _press.forward(from: 0);
  }

  void _up(TapUpDetails _) {
    _press.reverse();
  }

  void _cancel() {
    _press.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: SupervisorTheme.cardRadius,
        splashColor: Colors.white.withValues(alpha: 0.16),
        highlightColor: Colors.white.withValues(alpha: 0.06),
        onTap: widget.onTap,
        onTapDown: _down,
        onTapUp: _up,
        onTapCancel: _cancel,
        child: AnimatedBuilder(
          animation: _ease,
          builder: (context, child) {
            final t = _ease.value;
            final scale = ui.lerpDouble(1, 0.975, t)!;
            // Matches the reference CSS: backdrop-filter blur is clamped to 4px
            // at rest (clamp(1px, 0.125em, 4px)) and drops to ~0 on :hover.
            // A light blur is what keeps the dotted background crisp so the card
            // reads as clear glass instead of a milky frosted panel.
            final blur = ui.lerpDouble(0.5, 0.5, t)!;
            final lift = ui.lerpDouble(8, 3, t)!;

            return Transform.scale(
              scale: scale,
              child: SizedBox.expand(
                child: Stack(
                  fit: StackFit.expand,
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Transform.translate(
                          offset: Offset(-4 + (2 * t), lift),
                          child: CustomPaint(
                            painter: _LiquidGlassShadowPainter(
                              radius: SupervisorTheme.cardRadius.topLeft.x,
                              progress: t,
                            ),
                          ),
                        ),
                      ),
                    ),
                    ClipRRect(
                      borderRadius: SupervisorTheme.cardRadius,
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(
                          sigmaX: blur,
                          sigmaY: blur,
                        ),
                        child: CustomPaint(
                          painter: _LiquidGlassSurfacePainter(
                            radius: SupervisorTheme.cardRadius.topLeft.x,
                            progress: t,
                            compact: false,
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: CustomPaint(
                                    painter: _LiquidGlassSheenPainter(
                                      radius:
                                          SupervisorTheme.cardRadius.topLeft.x,
                                      progress: t,
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 16, 16, 15),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _LiquidIconChip(
                                      icon: widget.icon,
                                      color: widget.color,
                                      progress: t,
                                    ),
                                    const Spacer(),
                                    Text(
                                      widget.value,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w800,
                                        color: SupervisorTheme.strongText,
                                        height: 1,
                                        shadows: [
                                          Shadow(
                                            color: const ui.Color.fromARGB(
                                                    255, 48, 48, 48)
                                                .withValues(
                                              alpha: 0.08 + t * 0.05,
                                            ),
                                            blurRadius: 7,
                                            offset: Offset(0, 3 - (2 * t)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 7),
                                    Text(
                                      widget.label,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        height: 1.15,
                                        fontWeight: FontWeight.w700,
                                        color: SupervisorTheme.mutedText,
                                      ),
                                    ),
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
            );
          },
        ),
      ),
    );
  }
}

class _LiquidIconChip extends StatelessWidget {
  const _LiquidIconChip({
    required this.icon,
    required this.color,
    required this.progress,
  });

  final IconData icon;
  final Color color;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: SupervisorTheme.chipRadius,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: ui.lerpDouble(12, 2, progress)!,
          sigmaY: ui.lerpDouble(12, 2, progress)!,
        ),
        child: CustomPaint(
          painter: _LiquidGlassSurfacePainter(
            radius: SupervisorTheme.chipRadius.topLeft.x,
            progress: progress,
            compact: true,
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              icon,
              color: color,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }
}

class _LiquidGlassSurfacePainter extends CustomPainter {
  const _LiquidGlassSurfacePainter({
    required this.radius,
    required this.progress,
    this.compact = false,
  });

  final double radius;
  final double progress;
  final bool compact;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(0.5),
      Radius.circular(radius),
    );

    final press = progress.clamp(0.0, 1.0);

    // Reference CSS fill:
    //   background: linear-gradient(-75deg,
    //     rgba(255,255,255,0.05), rgba(255,255,255,0.2), rgba(255,255,255,0.05));
    // A -75deg gradient runs bottom-left → top-right. The small icon chip keeps
    // a slightly heavier tint so the coloured icon reads against a solid plate.
    final fill = Paint()
      ..shader = LinearGradient(
        begin: const Alignment(-0.95, 0.95),
        end: const Alignment(0.95, -0.95),
        colors: [
          Colors.white.withValues(alpha: compact ? 0.12 : 0.02),
          Colors.white.withValues(alpha: compact ? 0.34 : 0.09),
          Colors.white.withValues(alpha: compact ? 0.10 : 0.02),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect);
    canvas.drawRRect(rrect, fill);

    // The reference button has no radial white wash — its dimensionality comes
    // from the inset edge highlights below. Keep a faint wash only on the chip.
    if (compact) {
      final softWash = Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.55, -0.65),
          radius: 1.1,
          colors: [
            Colors.white.withValues(alpha: 0.30),
            Colors.white.withValues(alpha: 0.04),
            Colors.transparent,
          ],
          stops: const [0.0, 0.48, 1.0],
        ).createShader(rect);
      canvas.drawRRect(rrect, softWash);
    }

    /*
      Important fix:
      The original topInset, bottomInset and innerRing were drawn for both
      the main KPI card and the small icon chip.

      On the full rounded-square KPI card, those arcs become the odd inner
      curved lining visible inside the card.

      So, keep those inner glass lines only for compact chips.
      For the large KPI card, only the outer border remains.
    */
    if (compact) {
      final topInset = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = Colors.black.withValues(alpha: 0.04);
      canvas.drawArc(
        Rect.fromLTWH(6, 2, size.width - 12, size.height * 0.55),
        math.pi,
        math.pi,
        false,
        topInset,
      );

      final bottomInset = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.56 - (press * 0.16));
      canvas.drawArc(
        Rect.fromLTWH(
          5,
          size.height * 0.44,
          size.width - 10,
          size.height * 0.6,
        ),
        0,
        math.pi,
        false,
        bottomInset,
      );

      final innerRing = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = Colors.white.withValues(alpha: 0.34);
      canvas.drawRRect(rrect.deflate(1.2), innerRing);
    } else {
      // Reference box-shadow, mapped for the large card as full-perimeter
      // insets instead of the arcs that used to look wrong here:
      //   inset 0  0.125em ... rgba(0,0,0,0.05)   -> dark top inner edge
      //   inset 0 -0.125em ... rgba(255,255,255,0.5) -> bright bottom inner edge
      // A single vertical-gradient rim stroke captures both at once.
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

      //   0 0 0.1em 0.25em inset rgba(255,255,255,0.2) -> faint inner ring
      final innerRing = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.18);
      canvas.drawRRect(rrect.deflate(1.8), innerRing);
    }

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = compact ? 0.9 : 1.15
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
  bool shouldRepaint(covariant _LiquidGlassSurfacePainter oldDelegate) {
    return oldDelegate.radius != radius ||
        oldDelegate.progress != progress ||
        oldDelegate.compact != compact;
  }
}

class _LiquidGlassSheenPainter extends CustomPainter {
  const _LiquidGlassSheenPainter({
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

    // Reference sheen (span::after):
    //   linear-gradient(-45deg, white 0%, white 0.5 @40-50%, white 0 @55%)
    //   with mix-blend-mode: screen.
    // BlendMode.screen brightens without adding opaque white, so the streak
    // reads as a light reflection rather than milky paint.
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
    // No bottom glow — the reference gets its bottom brightness from the inset
    // edge highlight, not a broad wash (which is what made the card look milky).
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LiquidGlassSheenPainter oldDelegate) {
    return oldDelegate.radius != radius || oldDelegate.progress != progress;
  }
}

class _LiquidGlassShadowPainter extends CustomPainter {
  const _LiquidGlassShadowPainter({
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
  bool shouldRepaint(covariant _LiquidGlassShadowPainter oldDelegate) {
    return oldDelegate.radius != radius || oldDelegate.progress != progress;
  }
}

/// A single row in the activity / alerts feed.
class SupervisorAlertTile extends StatelessWidget {
  const SupervisorAlertTile({super.key, required this.alert});

  final SupervisorAlert alert;

  Color get _color {
    switch (alert.severity) {
      case SupervisorAlertSeverity.danger:
        return SupervisorTheme.danger;
      case SupervisorAlertSeverity.warning:
        return SupervisorTheme.warning;
      case SupervisorAlertSeverity.info:
        return SupervisorTheme.info;
    }
  }

  IconData get _icon {
    switch (alert.severity) {
      case SupervisorAlertSeverity.danger:
        return Icons.error_outline_rounded;
      case SupervisorAlertSeverity.warning:
        return Icons.warning_amber_rounded;
      case SupervisorAlertSeverity.info:
        return Icons.info_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SupervisorTheme.surface,
        borderRadius: SupervisorTheme.cardRadius,
        border: Border.all(color: SupervisorTheme.hairline),
        boxShadow: SupervisorTheme.softShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _color.withValues(alpha: 0.12),
              borderRadius: SupervisorTheme.chipRadius,
            ),
            child: Icon(_icon, color: _color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: SupervisorTheme.strongText,
                  ),
                ),
                if (alert.subtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    alert.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: SupervisorTheme.mutedText,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A quick-action tile rendered on the SAME liquid-glass surface as
/// [SupervisorKpiCard] (identical surface / sheen / shadow painters), holding
/// a raster image icon and a label. Used in the dashboard "Quick actions" grid.
class SupervisorGlassActionTile extends StatefulWidget {
  const SupervisorGlassActionTile({
    super.key,
    required this.iconAsset,
    required this.label,
    this.onTap,
  });

  final String iconAsset;
  final String label;
  final VoidCallback? onTap;

  @override
  State<SupervisorGlassActionTile> createState() =>
      _SupervisorGlassActionTileState();
}

class _SupervisorGlassActionTileState extends State<SupervisorGlassActionTile>
    with SingleTickerProviderStateMixin {
  static const double _radius = 16;
  static const Duration _pressHold = Duration(milliseconds: 200);

  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 90),
    reverseDuration: const Duration(milliseconds: 120),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(_radius),
        splashColor: Colors.white.withValues(alpha: 0.16),
        highlightColor: Colors.white.withValues(alpha: 0.06),
        onTap: _handleTap,
        onTapDown: (_) => _press.forward(from: 0),
        onTapCancel: () => _press.reverse(),
        child: AnimatedBuilder(
          animation: _ease,
          builder: (context, child) {
            final t = _ease.value;
            final scale = ui.lerpDouble(1, 0.97, t)!;
            final lift = ui.lerpDouble(6, 2, t)!;
            const blur = 0.1;

            return Transform.scale(
              scale: scale,
              child: SizedBox.expand(
                child: Stack(
                  fit: StackFit.expand,
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Transform.translate(
                          offset: Offset(-3 + (1.5 * t), lift),
                          child: CustomPaint(
                            painter: _LiquidGlassShadowPainter(
                              radius: _radius,
                              progress: t,
                            ),
                          ),
                        ),
                      ),
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(_radius),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                        child: CustomPaint(
                          painter: _LiquidGlassSurfacePainter(
                            radius: _radius,
                            progress: t,
                            compact: false,
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: CustomPaint(
                                    painter: _LiquidGlassSheenPainter(
                                      radius: _radius,
                                      progress: t,
                                    ),
                                  ),
                                ),
                              ),
                              child!,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    widget.iconAsset,
                    width: 34,
                    height: 34,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: SupervisorTheme.strongText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleTap() async {
    final onTap = widget.onTap;
    if (onTap == null) return;

    await Future.delayed(_pressHold);
    if (!mounted) return;

    onTap();
    if (mounted) {
      await _press.reverse();
    }
  }
}

/// A solid-WHITE "today at a glance" stat card. A tinted icon chip, big number
/// and label sit at the left over an optional full-bleed illustration; a
/// left→right white scrim keeps the text crisp while the artwork bleeds to the
/// right edge. The base stays opaque white (deliberately NOT glass).
class SupervisorGlanceCard extends StatelessWidget {
  const SupervisorGlanceCard({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    this.imageAsset,
    this.onTap,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final String? imageAsset;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: SupervisorTheme.cardRadius,
        onTap: onTap,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: SupervisorTheme.surface,
            borderRadius: SupervisorTheme.cardRadius,
            border: Border.all(
              color: SupervisorTheme.hairline.withValues(alpha: 0.5),
            ),
            boxShadow: SupervisorTheme.softShadow,
          ),
          child: Stack(
            children: [
              if (imageAsset != null) ...[
                Positioned.fill(
                  child: Image.asset(
                    imageAsset!,
                    fit: BoxFit.cover,
                    alignment: Alignment.centerRight,
                  ),
                ),
                // Left→right white scrim so the number/label read cleanly over
                // the artwork while it bleeds to the right edge.
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.white,
                          Colors.white.withValues(alpha: 0.86),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                        stops: const [0.0, 0.34, 0.74],
                      ),
                    ),
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: SupervisorTheme.chipRadius,
                      ),
                      child: Icon(icon, color: color, size: 16),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: SupervisorTheme.strongText,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: SupervisorTheme.mutedText,
                          ),
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
  }
}

/// Generic info card matching OperatorInfoCard's look (20px radius, soft
/// shadow), used on the profile screen.
class SupervisorInfoCard extends StatelessWidget {
  const SupervisorInfoCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: SupervisorTheme.surface,
        borderRadius: SupervisorTheme.cardRadius,
        border: Border.all(color: SupervisorTheme.hairline),
        boxShadow: SupervisorTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: SupervisorTheme.strongText,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
