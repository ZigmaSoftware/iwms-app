import 'package:flutter/material.dart';
import 'package:iwms_citizen_app/core/theme/app_colors.dart';
import 'package:iwms_citizen_app/core/theme/app_text_styles.dart';
import 'package:iwms_citizen_app/localization/app_localizations.dart';

const LinearGradient _headerGradient = LinearGradient(
  colors: [AppColors.primary, AppColors.primaryVariant],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class OperatorHeader extends StatelessWidget {
  const OperatorHeader({
    super.key,
    required this.name,
    required this.badge,
    required this.ward,
    required this.zone,
    required this.onLogout,
    this.onMenuTap,
    this.subtitle,
    this.showAvatar = false,
  });

  final String name;
  final String badge;
  final String ward;
  final String zone;
  final String? subtitle;
  final VoidCallback onLogout;
  final VoidCallback? onMenuTap;
  final bool showAvatar;
  String toTitleCase(String s) {
    return s.split(" ").map((word) {
      if (word.isEmpty) return "";
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(" ");
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final localizations = AppLocalizations.of(context);

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: _headerGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopBar(textTheme, localizations),
              const SizedBox(height: 20),
              _buildLocationCard(textTheme, localizations),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // Top row: Title, name, subtitle & buttons
  // -------------------------------------------------------------
  Widget _buildTopBar(
    TextTheme textTheme,
    AppLocalizations localizations,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildTitleSection(textTheme, localizations)),
        _buildHeaderActionButtons(),
      ],
    );
  }

  Widget _buildTitleSection(
    TextTheme textTheme,
    AppLocalizations localizations,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          localizations.operatorLabel,
          style: AppTextStyles.bodyMedium.copyWith(
            color: Colors.white.withOpacity(.75),
            fontWeight: FontWeight.w600,
            letterSpacing: .3,
          ),
        ),
        const SizedBox(height: 6),

        // Name text
        Text(
          toTitleCase(name),
          style: AppTextStyles.heading2.copyWith(
            color: Colors.white,
            height: 1.15,
          ),
        ),

        const SizedBox(height: 4),

        // Badge or subtitle
        // Text(
        //   subtitle ?? badge,
        //   style: AppTextStyles.bodyMedium.copyWith(
        //     color: Colors.white70,
        //   ),
        // ),
      ],
    );
  }

  Widget _buildHeaderActionButtons() {
    return Row(
      children: [
        if (onMenuTap != null)
          IconButton(
            tooltip: 'More',
            onPressed: onMenuTap,
            icon: const Icon(Icons.more_horiz_rounded, color: Colors.white),
          ),
      ],
    );
  }

  // -------------------------------------------------------------
  // Ward/Zone & Badge card
  // -------------------------------------------------------------
  Widget _buildLocationCard(
    TextTheme textTheme,
    AppLocalizations localizations,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withOpacity(0.28)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              localizations.operatorWardZone(ward, zone),
              style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
