import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:iwms_citizen_app/core/di.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/data/supervisor_models.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/data/supervisor_repository.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/presentation/theme/supervisor_theme.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/presentation/widgets/supervisor_visuals.dart';

/// Zoom level for the waste-collected chart. Day = each bar is one day
/// (scrollable), Week/Month aggregate to coarser buckets.
enum WasteRange { day, week, month }

/// A collected-waste bar chart backed by the supervisor's daily trip logs.
/// Horizontally scrollable — each bar is a period (day → week → month via the
/// range chips). Each bar stacks bin vs household weight. Self-loading.
class SupervisorWasteChart extends StatefulWidget {
  const SupervisorWasteChart({super.key});

  @override
  State<SupervisorWasteChart> createState() => _SupervisorWasteChartState();
}

class _SupervisorWasteChartState extends State<SupervisorWasteChart> {
  final SupervisorRepository _repo = getIt<SupervisorRepository>();
  final ScrollController _scroll = ScrollController();

  bool _loading = true;
  String? _error;
  List<SupervisorWastePoint> _raw = const [];

  WasteRange _range = WasteRange.day;
  int? _selected; // selected bucket index (for the header detail)
  bool _wave = false; // false = bar view, true = double-layered wave view

  static const double _plotHeight = 150;
  static const double _slot = 46; // per-bar horizontal slot
  static const double _barWidth = 24;
  static const double _waveSlot = 56; // per-bucket slot in the wave view
  static const double _axisWidth = 30;
  static const double _axisGap = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _repo.fetchWasteSeries();
      if (!mounted) return;
      setState(() {
        _raw = data;
        _loading = false;
        _selected = null;
      });
      _jumpToEnd();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load waste data';
        _loading = false;
      });
    }
  }

  void _jumpToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final maxExtent = _scroll.position.maxScrollExtent;
      // Snap to a slot boundary instead of the raw max extent — otherwise the
      // viewport's left edge lands mid-slot, cropping the leftmost date
      // label and reading as an oversized gap before the next full label.
      final slot = _wave ? _waveSlot : _slot;
      final aligned = (maxExtent / slot).floor() * slot;
      _scroll.jumpTo(aligned.clamp(0, maxExtent));
    });
  }

  // --------------------------------------------------------------- bucketing

  DateTime _bucketStart(DateTime d, WasteRange range) {
    switch (range) {
      case WasteRange.day:
        return DateTime(d.year, d.month, d.day);
      case WasteRange.week:
        final monday = d.subtract(Duration(days: d.weekday - 1));
        return DateTime(monday.year, monday.month, monday.day);
      case WasteRange.month:
        return DateTime(d.year, d.month);
    }
  }

  String _label(DateTime start, WasteRange range) {
    switch (range) {
      case WasteRange.day:
        return DateFormat('d MMM').format(start);
      case WasteRange.week:
        return DateFormat('d MMM').format(start);
      case WasteRange.month:
        return DateFormat('MMM').format(start);
    }
  }

  List<_Bucket> _buckets() {
    final map = <DateTime, _Bucket>{};
    for (final p in _raw) {
      final key = _bucketStart(p.date, _range);
      final b = map.putIfAbsent(key, () => _Bucket(key, _label(key, _range)));
      b.bin += p.binKg;
      b.household += p.householdKg;
    }
    final list = map.values.toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    return list;
  }

  String _fmt(double kg) {
    if (kg >= 1000) return '${(kg / 1000).toStringAsFixed(1)} t';
    return '${kg.round()} kg';
  }

  // ------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: SupervisorTheme.surface,
        borderRadius: SupervisorTheme.cardRadius,
        border:
            Border.all(color: SupervisorTheme.hairline.withValues(alpha: 0.5)),
        boxShadow: SupervisorTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          const SizedBox(height: 12),
          _rangeChips(),
          const SizedBox(height: 16),
          SizedBox(height: _plotHeight + 26, child: _chartBody()),
          const SizedBox(height: 12),
          _legend(),
        ],
      ),
    );
  }

  Widget _header() {
    final buckets = _buckets();
    _Bucket? focus;
    if (buckets.isNotEmpty) {
      final idx =
          (_selected ?? buckets.length - 1).clamp(0, buckets.length - 1);
      focus = buckets[idx];
    }
    final total = buckets.fold<double>(0, (s, b) => s + b.total);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Waste collected',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: SupervisorTheme.strongText,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                focus == null
                    ? 'No data yet'
                    : '${focus.label} · ${_fmt(focus.total)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: SupervisorTheme.mutedText,
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _fmt(total),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: SupervisorTheme.accentDeep,
              ),
            ),
            const Text(
              'total',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: SupervisorTheme.mutedText,
              ),
            ),
          ],
        ),
        const SizedBox(width: 6),
        // Eye toggle: switch between the bar view and the double-layered
        // wave view (both render the same collected-waste series).
        Tooltip(
          message: _wave ? 'Bar view' : 'Wave view',
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () {
              setState(() => _wave = !_wave);
              // Bar/wave use different per-bucket slot widths, so the old
              // scroll offset would point at the wrong day — resync to the
              // latest bucket like a fresh load does.
              _jumpToEnd();
            },
            child: Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: SupervisorTheme.accentSoft,
                border: Border.all(
                  color: SupervisorTheme.accent.withValues(alpha: 0.35),
                ),
              ),
              child: Icon(
                _wave ? Icons.bar_chart_rounded : Icons.waves_rounded,
                size: 18,
                color: SupervisorTheme.accentDeep,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _rangeChips() {
    Widget chip(String label, WasteRange r) => Expanded(
          child: SupervisorTimeChip(
            label: label,
            selected: _range == r,
            onTap: () {
              setState(() {
                _range = r;
                _selected = null;
              });
              _jumpToEnd();
            },
          ),
        );
    return Row(
      children: [
        chip('Day', WasteRange.day),
        const SizedBox(width: 8),
        chip('Week', WasteRange.week),
        const SizedBox(width: 8),
        chip('Month', WasteRange.month),
      ],
    );
  }

  Widget _chartBody() {
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: SupervisorTheme.accent,
          ),
        ),
      );
    }
    if (_error != null) {
      return _placeholder(_error!, retry: true);
    }
    final buckets = _buckets();
    if (buckets.isEmpty) {
      return _placeholder('No collected-waste data yet.');
    }

    final maxTotal = buckets.fold<double>(1, (m, b) => math.max(m, b.total));
    final axisMax = _niceCeil(maxTotal);

    if (_wave) return _waveBody(buckets, axisMax);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _yAxis(axisMax),
        const SizedBox(width: _axisGap),
        Expanded(
          child: SingleChildScrollView(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: SizedBox(
              width: math.max(buckets.length * _slot, 1),
              child: Stack(
                children: [
                  Positioned.fill(
                    bottom: 26,
                    child: CustomPaint(painter: _GridPainter()),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (int i = 0; i < buckets.length; i++)
                        _bar(buckets[i], i, axisMax),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _yAxis(double axisMax) {
    Widget lbl(double v) => Text(
          v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}t' : '${v.round()}',
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: SupervisorTheme.mutedText,
          ),
        );
    return SizedBox(
      height: _plotHeight,
      width: _axisWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          lbl(axisMax),
          lbl(axisMax * 2 / 3),
          lbl(axisMax / 3),
          lbl(0),
        ],
      ),
    );
  }

  Widget _bar(_Bucket b, int index, double axisMax) {
    final selected = (_selected ?? -1) == index;
    final totalH = (b.total / axisMax) * _plotHeight;
    final binH = (b.bin / axisMax) * _plotHeight;
    final hhH = (b.household / axisMax) * _plotHeight;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _selected = index),
      child: SizedBox(
        width: _slot,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            SizedBox(
              height: _plotHeight,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (totalH < 2) const SizedBox(height: 2),
                  // Bin (top segment)
                  Container(
                    width: _barWidth,
                    height: binH,
                    decoration: BoxDecoration(
                      color: SupervisorTheme.chartFillDeep.withValues(
                        alpha: selected ? 1 : 0.92,
                      ),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6),
                      ),
                    ),
                  ),
                  // Household (bottom segment)
                  Container(
                    width: _barWidth,
                    height: hhH,
                    decoration: BoxDecoration(
                      color: SupervisorTheme.chartFill.withValues(
                        alpha: selected ? 1 : 0.9,
                      ),
                      borderRadius: binH < 1
                          ? const BorderRadius.vertical(top: Radius.circular(6))
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: _slot,
              child: Text(
                b.label,
                maxLines: 1,
                overflow: TextOverflow.clip,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected
                      ? SupervisorTheme.accentDeep
                      : SupervisorTheme.mutedText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Double-layered smooth area (wave) view of the same buckets: the back
  /// layer is total waste, the front layer is the bin portion — the gap
  /// between them reads as household. Horizontally scrollable — each bucket
  /// gets a fixed pixel slot, same scroll controller as the bar view, so
  /// switching views keeps your scroll position and both can reveal the
  /// full history instead of just what fits on screen.
  Widget _waveBody(List<_Bucket> buckets, double axisMax) {
    final totals = buckets.map((b) => b.total).toList();
    final bins = buckets.map((b) => b.bin).toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _yAxis(axisMax),
        const SizedBox(width: _axisGap),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = math.max(
                buckets.length * _waveSlot,
                constraints.maxWidth,
              );
              return SingleChildScrollView(
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: SizedBox(
                  width: width,
                  child: Column(
                    children: [
                      SizedBox(
                        height: _plotHeight,
                        width: width,
                        child: CustomPaint(
                          painter: _WaveAreaPainter(
                            totals: totals,
                            bins: bins,
                            axisMax: axisMax,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      _waveAxisLabels(buckets, width),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _waveAxisLabels(List<_Bucket> buckets, double width) {
    if (buckets.isEmpty) return const SizedBox(height: 14);
    final slot = width / buckets.length;
    TextStyle style(bool selected) => TextStyle(
          fontSize: 9.5,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          color:
              selected ? SupervisorTheme.accentDeep : SupervisorTheme.mutedText,
        );
    return SizedBox(
      height: 14,
      width: width,
      child: Row(
        children: [
          for (int i = 0; i < buckets.length; i++)
            SizedBox(
              width: slot,
              child: Text(
                buckets[i].label,
                maxLines: 1,
                overflow: TextOverflow.clip,
                textAlign: TextAlign.center,
                style: style((_selected ?? -1) == i),
              ),
            ),
        ],
      ),
    );
  }

  Widget _legend() {
    Widget dot(Color c, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: SupervisorTheme.mutedText,
              ),
            ),
          ],
        );
    return Row(
      children: [
        dot(SupervisorTheme.chartFillDeep, 'Bin'),
        const SizedBox(width: 18),
        dot(SupervisorTheme.chartFill, 'Household'),
      ],
    );
  }

  Widget _placeholder(String message, {bool retry = false}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bar_chart_rounded,
              size: 30, color: SupervisorTheme.hairline),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: SupervisorTheme.mutedText,
            ),
          ),
          if (retry) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _load,
              child: const Text('Retry',
                  style: TextStyle(
                    color: SupervisorTheme.accent,
                    fontWeight: FontWeight.w700,
                  )),
            ),
          ],
        ],
      ),
    );
  }

  double _niceCeil(double v) {
    if (v <= 0) return 1;
    final mag = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
    final n = (v / mag).ceil() * mag;
    return n.toDouble();
  }
}

class _Bucket {
  _Bucket(this.start, this.label);
  final DateTime start;
  final String label;
  double bin = 0;
  double household = 0;
  double get total => bin + household;
}

/// Faint horizontal guide lines behind the bars (thirds of the plot).
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = SupervisorTheme.hairline.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    for (final f in [0.0, 1 / 3, 2 / 3, 1.0]) {
      final y = size.height * f;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) => false;
}

/// Double-layered smooth area chart of the collected-waste series. Back layer
/// = total (bin + household), front layer = bin. Ported from the original
/// dashboard wave aesthetic but driven by real bucket values.
class _WaveAreaPainter extends CustomPainter {
  _WaveAreaPainter({
    required this.totals,
    required this.bins,
    required this.axisMax,
  });

  final List<double> totals;
  final List<double> bins;
  final double axisMax;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);

    final base = size.height - 2;
    final top = 10.0;
    final usable = base - top;

    _drawGuides(canvas, size);
    _drawGrain(canvas, size);

    List<Offset> pointsFor(List<double> values) {
      final n = values.length;
      if (n == 1) {
        final y = base - (values[0] / axisMax) * usable;
        return [Offset(0, y), Offset(size.width, y)];
      }
      return List<Offset>.generate(n, (i) {
        final x = size.width * (i / (n - 1));
        final y = (base - (values[i] / axisMax) * usable).clamp(top, base);
        return Offset(x, y.toDouble());
      });
    }

    _drawArea(
      canvas,
      pointsFor(totals),
      base,
      LinearGradient(
        colors: [
          SupervisorTheme.chartFill.withValues(alpha: 0.82),
          SupervisorTheme.chartFill.withValues(alpha: 0.35),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      SupervisorTheme.chartFill,
      size,
    );
    _drawArea(
      canvas,
      pointsFor(bins),
      base,
      LinearGradient(
        colors: [
          SupervisorTheme.chartFillDeep.withValues(alpha: 0.82),
          SupervisorTheme.chartFillDeep.withValues(alpha: 0.34),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      SupervisorTheme.chartFillDeep,
      size,
    );

    canvas.restore();
  }

  void _drawGuides(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = SupervisorTheme.hairline.withValues(alpha: 0.9)
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    final n = totals.length;
    if (n <= 1) {
      canvas.drawLine(const Offset(0, 4), Offset(0, size.height), paint);
      return;
    }
    // One guide per bucket (matches pointsFor's x spacing) instead of a fixed
    // number of segments, so each day gets its own line regardless of how
    // many days are in the series.
    for (var i = 0; i < n; i++) {
      final x = size.width * i / (n - 1);
      canvas.drawLine(Offset(x, 4), Offset(x, size.height), paint);
    }
  }

  void _drawGrain(Canvas canvas, Size size) {
    final rng = math.Random(27);
    final speckPaint = Paint();
    final count = (size.width * size.height / 42).round().clamp(150, 380);
    for (var i = 0; i < count; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final bottomWeight = Curves.easeIn.transform(y / size.height);
      if (bottomWeight < 0.1) continue;
      final opacity = (0.015 + bottomWeight * 0.07).clamp(0.01, 0.085);
      final radius =
          (0.25 + bottomWeight * 0.75) * (0.7 + rng.nextDouble() * 0.8);
      speckPaint.color = const Color(0xFF111111).withValues(alpha: opacity);
      canvas.drawCircle(Offset(x, y), radius, speckPaint);
    }
  }

  void _drawArea(
    Canvas canvas,
    List<Offset> points,
    double base,
    Gradient gradient,
    Color strokeColor,
    Size size,
  ) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final current = points[i];
      final controlX = (previous.dx + current.dx) / 2;
      path.cubicTo(
        controlX,
        previous.dy,
        controlX,
        current.dy,
        current.dx,
        current.dy,
      );
    }
    final area = Path.from(path)
      ..lineTo(points.last.dx, base)
      ..lineTo(points.first.dx, base)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = gradient.createShader(Offset.zero & size)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
  }

  @override
  bool shouldRepaint(covariant _WaveAreaPainter old) =>
      old.totals != totals || old.bins != bins || old.axisMax != axisMax;
}
