import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iwms_citizen_app/core/theme/app_colors.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/screens/operator_dashboard_models.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/widgets/operator_header.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/widgets/operator_cards.dart';
import 'package:iwms_citizen_app/localization/app_localizations.dart';
import 'package:iwms_citizen_app/logic/locale/locale_cubit.dart';

const EdgeInsets _profilePagePadding =
    EdgeInsets.symmetric(horizontal: 20, vertical: 16);
class _OperatorLanguageOption {
  const _OperatorLanguageOption({
    required this.code,
    required this.label,
  });

  final String code;
  final String label;
}

const List<_OperatorLanguageOption> _operatorLanguageOptions = [
  _OperatorLanguageOption(code: 'en', label: 'English'),
  _OperatorLanguageOption(code: 'hi', label: 'Hindi'),
  _OperatorLanguageOption(code: 'ta', label: 'Tamil'),
];

const Gradient _profileHeaderGradient = LinearGradient(
  colors: [AppColors.primary, AppColors.primaryVariant],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class OperatorProfileScreen extends StatelessWidget {
  const OperatorProfileScreen({
    super.key,
    required this.operatorName,
    required this.operatorCode,
    required this.wardLabel,
    required this.zoneLabel,
    required this.onLogout,
    this.onEditProfile,
    this.contactInfo = const OperatorContactInfo(),
    this.attendanceSummary = const OperatorAttendanceSummary(),
  });

  final String operatorName;
  final String operatorCode;
  final String wardLabel;
  final String zoneLabel;
  final VoidCallback onLogout;
  final VoidCallback? onEditProfile;
  final OperatorContactInfo contactInfo;
  final OperatorAttendanceSummary attendanceSummary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context);
    return ColoredBox(
      color: AppColors.background,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OperatorHeader(
              name: operatorName,
              badge: operatorCode,
              ward: wardLabel,
              zone: zoneLabel,
              onLogout: onLogout,
              onMenuTap: onEditProfile,
            ),
            Padding(
              padding: _profilePagePadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  OperatorInfoCard(
                    title: localizations.profileContactTitle,
                    titleStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                    subtitle: localizations.profileContactSubtitle,
                    child: Column(
                      children: [
                        _ProfileDetailRow(
                          icon: Icons.phone,
                          label: localizations.profilePhoneLabel,
                          value: contactInfo.phone,
                        ),
                        const SizedBox(height: 12),
                        _ProfileDetailRow(
                          icon: Icons.mail_outline,
                          label: localizations.profileEmailLabel,
                          value: contactInfo.email,
                        ),
                        const SizedBox(height: 12),
                        _ProfileDetailRow(
                          icon: Icons.badge_outlined,
                          label: localizations.profileDesignationLabel,
                          value: contactInfo.designation ?? "-",
                        ),
                        const SizedBox(height: 12),
                        _ProfileDetailRow(
                          icon: Icons.location_city,
                          label: localizations.profileWardZoneLabel,
                          value: '$wardLabel · $zoneLabel',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  OperatorInfoCard(
                    title: localizations.profileAttendanceTitle,
                    titleStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                    subtitle: localizations.profileAttendanceSubtitle,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: OperatorQuickStat(
                                label: localizations.operatorAttendanceMonth,
                                value: attendanceSummary.monthStat ?? "--",
                                icon: Icons.calendar_month,
                                emphasis: true,
                              ),
                            ),
                            Expanded(
                              child: OperatorQuickStat(
                                label: localizations.operatorLeaveBalance,
                                value: attendanceSummary.leaveBalance ?? "--",
                                icon: Icons.eco_outlined,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      attendanceSummary.streakLabel ??
                                          localizations.operatorAttendanceStreak,
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      attendanceSummary.streakValue ?? "--",
                                      style: theme.textTheme.headlineSmall
                                          ?.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              FilledButton.icon(
                                onPressed: onEditProfile ??
                                    () => _showComingSoon(context),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                ),
                                icon: const Icon(Icons.edit,
                                    color: Colors.white),
                                label: Text(
                                  localizations.profileEditButton,
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  _OperatorLanguageCard(),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: onLogout,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFCF1B1B),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                    ),
                    icon: const Icon(Icons.logout, color: Colors.white),
                    label: const Text(
                      "Logout",
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Edit profile flow will open the existing screen."),
      ),
    );
  }
}

class _OperatorLanguageCard extends StatelessWidget {
  const _OperatorLanguageCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context);
    final Color highlightColor = AppColors.primary;
    final Color textColor =
        theme.textTheme.bodyMedium?.color ?? Colors.black87;

    return Card(
      elevation: theme.brightness == Brightness.dark ? 0 : 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Icon(Icons.language, color: highlightColor),
        title: Text(
          localizations.changeLanguage,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          localizations.changeLanguageSubtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.textTheme.bodySmall?.color,
          ),
        ),
        trailing: BlocBuilder<LocaleCubit, Locale>(
          builder: (context, locale) {
            return DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: locale.languageCode,
                dropdownColor: theme.cardColor,
                items: _operatorLanguageOptions
                    .map(
                      (option) => DropdownMenuItem<String>(
                        value: option.code,
                        child: Text(
                          option.label,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: textColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (code) async {
                  if (code == null || code == locale.languageCode) return;
                  final selectedOption = _operatorLanguageOptions.firstWhere(
                    (option) => option.code == code,
                    orElse: () => _operatorLanguageOptions.first,
                  );
                  await context
                      .read<LocaleCubit>()
                      .setLocale(Locale(selectedOption.code));
                  final messenger = ScaffoldMessenger.of(context);
                  messenger
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(
                        content: Text(
                          localizations.languageSaved(selectedOption.label),
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                },
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ProfileDetailRow extends StatelessWidget {
  const _ProfileDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
