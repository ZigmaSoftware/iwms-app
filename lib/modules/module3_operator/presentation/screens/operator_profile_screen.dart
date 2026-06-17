import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iwms_citizen_app/core/theme/app_colors.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/screens/operator_dashboard_models.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/widgets/operator_header.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/widgets/operator_cards.dart';
import 'package:iwms_citizen_app/modules/module3_operator/utils/household_mode_store.dart';
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

class OperatorProfileScreen extends StatelessWidget {
  const OperatorProfileScreen({
    super.key,
    required this.operatorName,
    required this.emp_id,
    required this.operatorCode,
    required this.employeeCode,
    required this.wardLabel,
    required this.zoneLabel,
    required this.onLogout,
    this.onEditProfile,
    this.contactInfo = const OperatorContactInfo(),
    this.attendanceSummary = const OperatorAttendanceSummary(),
  });

  final String operatorName;
  final String operatorCode;
  final String emp_id;
  final String employeeCode;
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
    // Operator nav bar = 72 (visible) + docked QR FAB rises ~24 above it,
    // plus the device's safe-area bottom inset. Reserve enough padding so
    // the last button (Logout) clears all of that and stays scrollable.
    final bottomNavClearance =
        MediaQuery.viewPaddingOf(context).bottom + 180;
    final assignedArea = [
      if (wardLabel.trim().isNotEmpty) wardLabel.trim(),
      if (zoneLabel.trim().isNotEmpty) zoneLabel.trim(),
    ].join(' · ');

    return ColoredBox(
      color: AppColors.background,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OperatorHeader(
              name: operatorName,
              empId: emp_id,
              displayId: employeeCode,
              badge: operatorCode,
              ward: wardLabel,
              zone: zoneLabel,
              onLogout: onLogout,
              onMenuTap: onEditProfile,
            ),
            Padding(
              padding: _profilePagePadding.add(
                EdgeInsets.only(bottom: bottomNavClearance),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  OperatorInfoCard(
                    title: localizations.profileContactTitle,
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
                          value: assignedArea.isEmpty
                              ? 'Assigned area not available'
                              : assignedArea,
                        ),
                      ],
                    ),
                  ),
                  // const SizedBox(height: 24),
                  // OperatorInfoCard(
                  //   title: localizations.profileAttendanceTitle,
                  //   subtitle: localizations.profileAttendanceSubtitle,
                  //   child: Column(
                  //     children: [
                  //       Row(
                  //         children: [
                  //           Expanded(
                  //             child: OperatorQuickStat(
                  //               label: localizations.operatorAttendanceMonth,
                  //               value: attendanceSummary.monthStat ?? "--",
                  //               icon: Icons.calendar_month,
                  //               emphasis: true,
                  //             ),
                  //           ),
                  //           Expanded(
                  //             child: OperatorQuickStat(
                  //               label: localizations.operatorLeaveBalance,
                  //               value: attendanceSummary.leaveBalance ?? "--",
                  //               icon: Icons.eco_outlined,
                  //             ),
                  //           ),
                  //         ],
                  //       ),
                  //       const SizedBox(height: 16),
                  //       Container(
                  //         padding: const EdgeInsets.all(16),
                  //         decoration: BoxDecoration(
                  //           color: AppColors.primary.withOpacity(0.08),
                  //           borderRadius: BorderRadius.circular(18),
                  //         ),
                  //         child: Row(
                  //           children: [
                  //             Expanded(
                  //               child: Column(
                  //                 crossAxisAlignment: CrossAxisAlignment.start,
                  //                 children: [
                  //                   Text(
                  //                     attendanceSummary.streakLabel ??
                  //                         localizations
                  //                             .operatorAttendanceStreak,
                  //                     style:
                  //                         theme.textTheme.bodySmall?.copyWith(
                  //                       color: AppColors.textSecondary,
                  //                     ),
                  //                   ),
                  //                   const SizedBox(height: 4),
                  //                   Text(
                  //                     attendanceSummary.streakValue ?? "--",
                  //                     style: theme.textTheme.headlineSmall
                  //                         ?.copyWith(
                  //                       color: AppColors.primary,
                  //                       fontWeight: FontWeight.w800,
                  //                     ),
                  //                   ),
                  //                 ],
                  //               ),
                  //             ),
                  //             FilledButton.icon(
                  //               onPressed: onEditProfile ??
                  //                   () => _showComingSoon(context),
                  //               icon:
                  //                   const Icon(Icons.edit, color: Colors.white),
                  //               label: Text(
                  //                 localizations.profileEditButton,
                  //                 style: const TextStyle(color: Colors.white),
                  //               ),
                  //             ),
                  //           ],
                  //         ),
                  //       ),
                  //     ],
                  //   ),
                  // ),
                  const SizedBox(height: 32),
                  const _HouseholdModeCard(),
                  const SizedBox(height: 16),
                  const _OperatorLanguageCard(),
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

/// Toggle that switches the operator between the default bin/trip scan flow
/// (OFF) and the household waste-entry flow (ON). When ON, the central QR FAB
/// scans a customer QR and opens the wet/dry/mixed weight + photo screen.
/// State is persisted per-device via [HouseholdModeStore].
class _HouseholdModeCard extends StatelessWidget {
  const _HouseholdModeCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ValueListenableBuilder<bool>(
        valueListenable: HouseholdModeStore.listenable,
        builder: (context, enabled, _) {
          return SwitchListTile(
            value: enabled,
            onChanged: (value) => HouseholdModeStore.setEnabled(value),
            activeColor: AppColors.primary,
            secondary: const Icon(Icons.home_work_outlined,
                color: AppColors.primary),
            title: const Text('Household collection'),
            subtitle: Text(
              enabled
                  ? 'QR scan opens customer waste entry (wet/dry, weight & photo).'
                  : 'QR scan follows the default bin/trip flow.',
            ),
          );
        },
      ),
    );
  }
}

class _OperatorLanguageCard extends StatelessWidget {
  const _OperatorLanguageCard();

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: const Icon(Icons.language, color: AppColors.primary),
        title: Text(localizations.changeLanguage),
        subtitle: Text(localizations.changeLanguageSubtitle),

        // Keep the language selector constrained inside the ListTile.
        trailing: SizedBox(
          width: 120,
          child: BlocBuilder<LocaleCubit, Locale>(
            builder: (context, locale) {
              return DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: locale.languageCode,
                  items: _operatorLanguageOptions
                      .map(
                        (o) => DropdownMenuItem<String>(
                          value: o.code,
                          child: Text(o.label),
                        ),
                      )
                      .toList(),
                  onChanged: (code) {
                    if (code == null) return;
                    context.read<LocaleCubit>().setLocale(Locale(code));
                  },
                ),
              );
            },
          ),
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
