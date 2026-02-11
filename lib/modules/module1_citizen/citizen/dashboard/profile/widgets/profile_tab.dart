import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:iwms_citizen_app/localization/app_localizations.dart';
import 'package:iwms_citizen_app/logic/auth/auth_bloc.dart';
import 'package:iwms_citizen_app/logic/auth/auth_event.dart';
import 'package:iwms_citizen_app/logic/locale/locale_cubit.dart';
import 'package:iwms_citizen_app/logic/theme/theme_cubit.dart';
import 'package:iwms_citizen_app/router/app_router.dart';

class _LanguageOption {
  const _LanguageOption({
    required this.code,
    required this.label,
  });

  final String code;
  final String label;
}

const List<_LanguageOption> _languageSwitchOptions = [
  _LanguageOption(code: 'en', label: 'English'),
  _LanguageOption(code: 'hi', label: 'Hindi'),
  _LanguageOption(code: 'ta', label: 'Tamil'),
];

class ProfileTab extends StatelessWidget {
  const ProfileTab({
    super.key,
    required this.headerHeight,
    required this.headerGradientColors,
    required this.normalizedName,
    required this.highlightColor,
    required this.textColor,
    required this.secondaryTextColor,
  });

  final double headerHeight;
  final List<Color> headerGradientColors;
  final String normalizedName;
  final Color highlightColor;
  final Color textColor;
  final Color secondaryTextColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authBloc = context.read<AuthBloc>();
    final localizations = AppLocalizations.of(context);

    return Column(
      children: [
        Container(
          width: double.infinity,
          height: headerHeight * 0.55,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: headerGradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizations.profileTitle,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  localizations.greeting(normalizedName),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  localizations.profileSubtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            children: [
              _ProfileTile(
                icon: Icons.description_outlined,
                label: localizations.collectionDetails,
                onTap: () => context.push(AppRoutePaths.citizenHistory),
                textColor: textColor,
                highlightColor: highlightColor,
              ),
              _ProfileTile(
                icon: Icons.history,
                label: localizations.collectionHistory,
                onTap: () => context.push(AppRoutePaths.citizenHistory),
                textColor: textColor,
                highlightColor: highlightColor,
              ),
              _ProfileTile(
                icon: Icons.location_on_outlined,
                label: localizations.trackWaste,
                onTap: () => context.push(AppRoutePaths.citizenMap),
                textColor: textColor,
                highlightColor: highlightColor,
              ),
              _ProfileTile(
                icon: Icons.feedback_outlined,
                label: localizations.raiseGrievance,
                onTap: () => context.push(AppRoutePaths.citizenGrievanceChat),
                textColor: textColor,
                highlightColor: highlightColor,
              ),
              _themeToggleTile(context, highlightColor, secondaryTextColor),
              const SizedBox(height: 12),
              _LanguageSelectionCard(
                highlightColor: highlightColor,
                textColor: textColor,
                secondaryTextColor: secondaryTextColor,
              ),
              const SizedBox(height: 12),
              Card(
                elevation: theme.brightness == Brightness.dark ? 0 : 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: Text(
                    localizations.logout,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () => authBloc.add(AuthLogoutRequested()),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _themeToggleTile(
    BuildContext context,
    Color highlightColor,
    Color secondaryText,
  ) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context);
    final bool isDarkMode = theme.brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: isDarkMode ? 0 : 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SwitchListTile.adaptive(
        value: isDarkMode,
        onChanged: (_) => context.read<ThemeCubit>().toggleTheme(),
        secondary: Icon(Icons.dark_mode_outlined, color: highlightColor),
        title: Text(
          localizations.darkMode,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.textTheme.bodyMedium?.color,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          localizations.darkModeSubtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: secondaryText,
          ),
        ),
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => highlightColor,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? highlightColor.withValues(alpha: 0.5)
              : highlightColor.withValues(alpha: 0.2),
        ),
      ),
    );
  }
}

class _LanguageSelectionCard extends StatelessWidget {
  const _LanguageSelectionCard({
    required this.highlightColor,
    required this.textColor,
    required this.secondaryTextColor,
  });

  final Color highlightColor;
  final Color textColor;
  final Color secondaryTextColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context);
    final bool isDarkMode = theme.brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: isDarkMode ? 0 : 2,
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
            color: secondaryTextColor,
          ),
        ),
        trailing: BlocBuilder<LocaleCubit, Locale>(
          builder: (context, locale) {
            return DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: locale.languageCode,
                dropdownColor: theme.cardColor,
                items: _languageSwitchOptions
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
                  final selectedOption = _languageSwitchOptions.firstWhere(
                    (option) => option.code == code,
                    orElse: () => _languageSwitchOptions.first,
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

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.textColor,
    required this.highlightColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color textColor;
  final Color highlightColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: theme.brightness == Brightness.dark ? 0 : 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Icon(icon, color: highlightColor),
        title: Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: theme.brightness == Brightness.dark
              ? Colors.white54
              : Colors.black26,
        ),
        onTap: onTap,
      ),
    );
  }
}
