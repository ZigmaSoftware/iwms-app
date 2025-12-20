import 'package:flutter/material.dart';
import 'package:iwms_citizen_app/localization/app_localizations.dart';

import '../../common/theme_tokens.dart';
import '../controllers/track_controller.dart';
import '../models/waste_period.dart';
import '../models/waste_summary.dart';
import '../widgets/waste_stat_card.dart';

enum WasteMetric { total, wet, dry, mixed }

class TrackTab extends StatefulWidget {
  const TrackTab({
    super.key,
    required this.controller,
    required this.highlightColor,
    required this.textColor,
    required this.onPickDate,
  });

  final TrackController controller;
  final Color highlightColor;
  final Color textColor;
  final Future<void> Function() onPickDate;

  @override
  State<TrackTab> createState() => _TrackTabState();
}

class _TrackTabState extends State<TrackTab> {
  WasteMetric _activeMetric = WasteMetric.total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        final summary =
            controller.currentSummary ?? WasteSummary.zero(controller.selectedDate);
        final periodLabel = _periodDescription(controller);

        return RefreshIndicator(
          onRefresh: () => controller.refresh(force: true),
          color: widget.highlightColor,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              DashboardThemeTokens.spacing20,
              DashboardThemeTokens.spacing20,
              DashboardThemeTokens.spacing20,
              DashboardThemeTokens.spacing32,
            ),
            children: [
              _buildTrackHeader(theme, localizations),
              const SizedBox(height: 16),
              _buildTrackSummarySection(
                theme,
                summary,
                periodLabel,
                localizations,
              ),
              const SizedBox(height: 20),
              Text(
                localizations.trackShowingPeriod(periodLabel),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: screenWidth * 0.032,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTrackHeader(ThemeData theme, AppLocalizations localizations) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final titleStyle = theme.textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.w900,
      color: widget.textColor,
      fontSize: screenWidth * 0.06,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          localizations.trackHeaderTitle,
          style: titleStyle,
        ),
        const SizedBox(height: 8),
        Text(
          localizations.trackLiveDescription,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: screenWidth * 0.035,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          localizations.trackChoosePeriod,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<WastePeriod>(
                    isExpanded: true,
                    value: widget.controller.selectedPeriod,
                    items: WastePeriod.values
                        .map(
                          (p) => DropdownMenuItem(
                            value: p,
                            child: Text(_periodLabel(p, localizations)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          widget.controller.setPeriod(value);
                        });
                      }
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            _CalendarChip(
              highlightColor: widget.highlightColor,
              label: _calendarLabel(localizations),
              enabled: widget.controller.selectedPeriod != WastePeriod.total,
              onTap: widget.onPickDate,
            ),
          ],
        ),
      ],
    );
  }

  String _calendarLabel(AppLocalizations localizations) {
    switch (widget.controller.selectedPeriod) {
      case WastePeriod.daily:
        return widget.controller.shortDisplayFormat
            .format(widget.controller.selectedDate);
      case WastePeriod.monthly:
        return widget.controller.monthFormat
            .format(widget.controller.selectedDate);
      case WastePeriod.total:
        return localizations.allTime;
    }
  }

  Widget _buildTrackSummarySection(
    ThemeData theme,
    WasteSummary summary,
    String periodLabel,
    AppLocalizations localizations,
  ) {
    if (widget.controller.loading) {
      return _buildTrackStatusCard(
        message: localizations.trackLoading,
        accentColor: widget.highlightColor,
        showLoading: true,
      );
    }

    if (widget.controller.error != null) {
      return _buildTrackStatusCard(
        message: widget.controller.error!,
        accentColor: widget.highlightColor,
        actionLabel: localizations.trackRetry,
        onAction: () => widget.controller.refresh(force: true),
      );
    }

    final cards = <({
      String asset,
      String label,
      double weight,
      Color color,
      WasteMetric metric,
    })>[
      (
        asset: 'assets/cards/wetwaste.png',
        label: localizations.wetWaste,
        weight: summary.wetWeight,
        color: const Color(0xFF1976D2),
        metric: WasteMetric.wet
      ),
      (
        asset: 'assets/cards/drywaste.png',
        label: localizations.dryWaste,
        weight: summary.dryWeight,
        color: const Color(0xFF2E7D32),
        metric: WasteMetric.dry
      ),
      (
        asset: 'assets/cards/mixedwaste.png',
        label: localizations.mixedWaste,
        weight: summary.mixWeight,
        color: const Color(0xFFF57F17),
        metric: WasteMetric.mixed
      ),
    ];

    final bool hasData = summary.totalNetWeight > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!hasData)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
        child: _buildTrackStatusCard(
          message: localizations.trackNoData,
          accentColor: widget.highlightColor,
        ),
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            final available = constraints.maxWidth;
            final itemWidth = available > 0 ? (available - 24) / 3 : available;
        return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: cards
                  .map(
                    (card) => SizedBox(
                      width: itemWidth,
                      child: WasteStatCard(
                        assetPath: card.asset,
                        label: card.label,
                        weight: card.weight,
                        accentColor: card.color,
                        formatter: widget.controller.weightFormatter,
                        isSelected: _activeMetric == card.metric,
                        onTap: () => _toggleMetric(card.metric),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 16),
        _buildMetricDetailCard(theme, summary, localizations),
        const SizedBox(height: 16),
        _buildTrendSection(theme),
      ],
    );
  }

  Widget _buildMetricDetailCard(
    ThemeData theme,
    WasteSummary summary,
    AppLocalizations localizations,
  ) {
    final metric = _activeMetric;
    final double weight = _metricWeight(summary, metric);
    final Color accent = _metricAccent(metric);
    final String weightLabel = '${widget.controller.weightFormatter.format(weight)} kg';

    return AnimatedContainer(
      duration: DashboardThemeTokens.animationSlow,
      curve: Curves.fastEaseInToSlowEaseOut,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(DashboardThemeTokens.radiusXL),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedSwitcher(
            duration: DashboardThemeTokens.animationNormal,
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: Text(
              _metricHeader(metric, localizations),
              key: ValueKey<String>('metric-header-${metric.name}'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: widget.textColor.withValues(alpha: 0.8),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: DashboardThemeTokens.spacing6),
          AnimatedSwitcher(
            duration: DashboardThemeTokens.animationSlow,
            switchInCurve: Curves.easeOutBack,
            switchOutCurve: Curves.easeInBack,
            child: Text(
              weightLabel,
              key: ValueKey<String>('metric-weight-$weightLabel'),
              style: theme.textTheme.headlineSmall?.copyWith(
                color: widget.textColor,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: DashboardThemeTokens.spacing8),
          Text(
            metric == WasteMetric.total
                ? localizations.metricTapCard
                : localizations.metricTapBack,
            style: theme.textTheme.bodySmall?.copyWith(
              color: widget.textColor.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackStatusCard({
    required String message,
    required Color accentColor,
    bool showLoading = false,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.25),
        ),
        boxShadow: const [
          DashboardThemeTokens.lightShadow,
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showLoading)
            Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: accentColor,
                  ),
                ),
                const SizedBox(width: DashboardThemeTokens.spacing12),
                Expanded(
                  child: Text(
                    message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            )
          else
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          if (actionLabel != null && onAction != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onAction,
                child: Text(actionLabel),
              ),
            ),
        ],
      ),
    );
  }

  void _toggleMetric(WasteMetric metric) {
    setState(() {
      _activeMetric = _activeMetric == metric ? WasteMetric.total : metric;
    });
  }

  double _metricWeight(WasteSummary summary, WasteMetric metric) {
    switch (metric) {
      case WasteMetric.wet:
        return summary.wetWeight;
      case WasteMetric.dry:
        return summary.dryWeight;
      case WasteMetric.mixed:
        return summary.mixWeight;
      case WasteMetric.total:
        return summary.totalNetWeight;
    }
  }

  Color _metricAccent(WasteMetric metric) {
    switch (metric) {
      case WasteMetric.wet:
        return const Color(0xFF1976D2);
      case WasteMetric.dry:
        return const Color(0xFF2E7D32);
      case WasteMetric.mixed:
        return const Color(0xFFF57F17);
      case WasteMetric.total:
        return widget.highlightColor;
    }
  }

  String _metricHeader(WasteMetric metric, AppLocalizations localizations) {
    switch (metric) {
      case WasteMetric.wet:
        return localizations.metricWet;
      case WasteMetric.dry:
        return localizations.metricDry;
      case WasteMetric.mixed:
        return localizations.metricMixed;
      case WasteMetric.total:
        return localizations.metricTotal;
    }
  }

  String _periodLabel(WastePeriod period, AppLocalizations localizations) {
    switch (period) {
      case WastePeriod.daily:
        return localizations.periodDaily;
      case WastePeriod.monthly:
        return localizations.periodMonthly;
      case WastePeriod.total:
        return localizations.periodTotal;
    }
  }

  String _periodDescription(TrackController controller) {
    switch (controller.selectedPeriod) {
      case WastePeriod.daily:
        return controller.displayFormat.format(controller.selectedDate);
      case WastePeriod.monthly:
        return controller.monthFormat.format(controller.selectedDate);
      case WastePeriod.total:
        return 'All time';
    }
  }

  Widget _buildTrendSection(ThemeData theme) {
    // Trend chart removed per request.
    return const SizedBox.shrink();
  }
}

class _CalendarChip extends StatelessWidget {
  const _CalendarChip({
    required this.highlightColor,
    required this.label,
    this.enabled = true,
    required this.onTap,
  });
  final Color highlightColor;
  final String label;
  final bool enabled;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(DashboardThemeTokens.radiusLarge),
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DashboardThemeTokens.spacing12,
            vertical: DashboardThemeTokens.spacing10,
          ),
          decoration: BoxDecoration(
            color: enabled
                ? highlightColor.withValues(alpha: 0.15)
                : theme.disabledColor.withValues(alpha: 0.08),
            borderRadius:
                BorderRadius.circular(DashboardThemeTokens.radiusLarge),
            border: Border.all(
              color: enabled
                  ? highlightColor.withValues(alpha: 0.35)
                  : theme.disabledColor.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.calendar_month,
                size: 20,
                color: enabled ? highlightColor : theme.disabledColor,
              ),
              const SizedBox(width: DashboardThemeTokens.spacing8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localizations.calendarLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          enabled ? highlightColor : theme.disabledColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color:
                          enabled ? highlightColor : theme.disabledColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
