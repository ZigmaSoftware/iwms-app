import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../logic/auth/auth_bloc.dart';
import '../../../logic/auth/auth_event.dart';
import '../../../logic/theme/theme_cubit.dart';
import '../../../router/app_router.dart';

const String _languagePreferenceKey = 'profile_language_code';
const String _fontScalePreferenceKey = 'profile_font_scale';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.userName,
  });

  final String userName;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const List<_LanguageOption> _supportedLanguages = [
    _LanguageOption(code: 'en', label: 'English (EN)'),
    _LanguageOption(code: 'hi', label: 'Hindi (HI)'),
    _LanguageOption(code: 'ml', label: 'Malayalam (ML)'),
    _LanguageOption(code: 'ta', label: 'Tamil (TA)'),
  ];

  static const List<_FontSizeOption> _fontSizePresets = [
    _FontSizeOption(label: 'Compact', scale: 0.9),
    _FontSizeOption(label: 'Standard', scale: 1.0),
    _FontSizeOption(label: 'Comfort', scale: 1.1),
    _FontSizeOption(label: 'Large', scale: 1.2),
  ];

  late String _selectedLanguageCode = _supportedLanguages.first.code;
  double _fontScale = 1.0;
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _prefs = prefs;
      _selectedLanguageCode =
          prefs.getString(_languagePreferenceKey) ?? _selectedLanguageCode;
      _fontScale = prefs.getDouble(_fontScalePreferenceKey) ?? 1.0;
    });
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature is coming soon.')),
    );
  }

  void _showSavedSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Future<void> _onLanguageChanged(String code) async {
    setState(() => _selectedLanguageCode = code);
    await (_prefs ?? await SharedPreferences.getInstance())
        .setString(_languagePreferenceKey, code);
    final label =
        _supportedLanguages.firstWhere((lang) => lang.code == code).label;
    _showSavedSnack('Language preference set to $label');
  }

  Future<void> _onFontScaleChanged(double scale) async {
    setState(() => _fontScale = scale);
    await (_prefs ?? await SharedPreferences.getInstance())
        .setDouble(_fontScalePreferenceKey, scale);
    _showSavedSnack('Font size preference saved');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textColor = colorScheme.onSurface;
    final secondaryText = colorScheme.onSurfaceVariant;
    final highlightColor = colorScheme.primary;
    final backgroundColor = theme.scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    highlightColor,
                    highlightColor.withValues(alpha: 0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () {
                          final router = GoRouter.of(context);
                          if (router.canPop()) {
                            router.pop();
                          } else {
                            router.go(AppRoutePaths.citizenHome);
                          }
                        },
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      Text(
                        'Profile',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colorScheme.onPrimary,
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Image.asset(
                          'assets/icons/profile.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hi, ${widget.userName}',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Manage your account and collection preferences',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                children: [
                  _ProfileOptionTile(
                    icon: Icons.description_outlined,
                    label: 'Collection Details',
                    textColor: textColor,
                    highlightColor: highlightColor,
                    onTap: () => context.push(AppRoutePaths.citizenHistory),
                  ),
                  _ProfileOptionTile(
                    icon: Icons.history,
                    label: 'Collection History & Weighment',
                    textColor: textColor,
                    highlightColor: highlightColor,
                    onTap: () => context.push(AppRoutePaths.citizenHistory),
                  ),
                  _ProfileOptionTile(
                    icon: Icons.location_on_outlined,
                    label: 'Track My Waste',
                    textColor: textColor,
                    highlightColor: highlightColor,
                    onTap: () => context.push(AppRoutePaths.citizenTrack),
                  ),
                  _ProfileOptionTile(
                    icon: Icons.star_rate_outlined,
                    label: 'Rate Last Collection',
                    textColor: textColor,
                    highlightColor: highlightColor,
                    onTap: () => _showComingSoon(context, 'Rating feature'),
                  ),
                  _ProfileOptionTile(
                    icon: Icons.payments_outlined,
                    label: 'View Charges & Fines',
                    textColor: textColor,
                    highlightColor: highlightColor,
                    onTap: () =>
                        _showComingSoon(context, 'Charges & fines section'),
                  ),
                  _ProfileThemeToggle(
                    textColor: textColor,
                    secondaryText: secondaryText,
                    highlightColor: highlightColor,
                  ),
                  _LanguageSettingsCard(
                    textColor: textColor,
                    secondaryText: secondaryText,
                    highlightColor: highlightColor,
                    options: _supportedLanguages,
                    selectedCode: _selectedLanguageCode,
                    onChanged: _onLanguageChanged,
                  ),
                  _FontSizeSettingsCard(
                    textColor: textColor,
                    secondaryText: secondaryText,
                    highlightColor: highlightColor,
                    options: _fontSizePresets,
                    selectedScale: _fontScale,
                    onChanged: _onFontScaleChanged,
                  ),
                  _ProfileOptionTile(
                    icon: Icons.feedback_outlined,
                    label: 'Raise Grievance (Help Desk)',
                    textColor: textColor,
                    highlightColor: highlightColor,
                     onTap: () => context.push(AppRoutePaths.citizenGrievanceChat),
                  ),
                  const SizedBox(height: 12),
                  _LogoutTile(
                    textColor: textColor,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileOptionTile extends StatelessWidget {
  const _ProfileOptionTile({
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
    final Color tileColor = theme.cardColor;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: theme.brightness == Brightness.dark ? 0 : 2,
      color: tileColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Icon(icon, color: highlightColor),
        title: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
        ),
        trailing: Icon(Icons.chevron_right,
            color: theme.brightness == Brightness.dark
                ? Colors.white54
                : Colors.black26),
        onTap: onTap,
      ),
    );
  }
}

class _ProfileThemeToggle extends StatelessWidget {
  const _ProfileThemeToggle({
    required this.textColor,
    required this.secondaryText,
    required this.highlightColor,
  });

  final Color textColor;
  final Color secondaryText;
  final Color highlightColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color tileColor = theme.cardColor;
    final bool isDarkMode = theme.brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: isDarkMode ? 0 : 2,
      color: tileColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SwitchListTile.adaptive(
        value: isDarkMode,
        onChanged: (_) => context.read<ThemeCubit>().toggleTheme(),
        secondary: Icon(Icons.dark_mode_outlined, color: highlightColor),
        title: Text(
          'Dark Mode',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
        ),
        subtitle: Text(
          'Switch between light and dark experiences',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
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

class _LanguageSettingsCard extends StatelessWidget {
  const _LanguageSettingsCard({
    required this.textColor,
    required this.secondaryText,
    required this.highlightColor,
    required this.options,
    required this.selectedCode,
    required this.onChanged,
  });

  final Color textColor;
  final Color secondaryText;
  final Color highlightColor;
  final List<_LanguageOption> options;
  final String selectedCode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color tileColor = theme.cardColor;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: theme.brightness == Brightness.dark ? 0 : 2,
      color: tileColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Language',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: highlightColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Preview',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: highlightColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Pick the language you are most comfortable with. Content will adapt once localization is rolled out.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: secondaryText,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedCode,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                items: options
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
                onChanged: (value) {
                  if (value != null) {
                    onChanged(value);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FontSizeSettingsCard extends StatelessWidget {
  const _FontSizeSettingsCard({
    required this.textColor,
    required this.secondaryText,
    required this.highlightColor,
    required this.options,
    required this.selectedScale,
    required this.onChanged,
  });

  final Color textColor;
  final Color secondaryText;
  final Color highlightColor;
  final List<_FontSizeOption> options;
  final double selectedScale;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color tileColor = theme.cardColor;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: theme.brightness == Brightness.dark ? 0 : 2,
      color: tileColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Font Size',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _fontLabel(selectedScale),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: highlightColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Adjust how large text appears across the citizen experience.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: secondaryText,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: options.map((option) {
                final selected = option.scale == selectedScale;
                return ChoiceChip(
                  label: Text(option.label),
                  selected: selected,
                  onSelected: (_) => onChanged(option.scale),
                  selectedColor: highlightColor.withValues(alpha: 0.15),
                  backgroundColor: theme.brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.04),
                  labelStyle: theme.textTheme.bodySmall?.copyWith(
                    color: selected ? highlightColor : textColor,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Text(
                    'Aa',
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: textColor,
                      fontSize: 32 * selectedScale,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Sample text preview',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: secondaryText,
                      fontSize: 12 * selectedScale,
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

  String _fontLabel(double scale) {
    final option = options.firstWhere(
      (opt) => opt.scale == scale,
      orElse: () => _FontSizeOption(label: 'Custom', scale: scale),
    );
    return option.label;
  }
}

class _LogoutTile extends StatelessWidget {
  const _LogoutTile({
    required this.textColor,
  });

  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color tileColor = Theme.of(context).cardColor;

    return Card(
      elevation: isDarkMode ? 0 : 2,
      color: tileColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: const Icon(Icons.logout, color: Colors.red),
        title: Text(
          'Logout',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
        ),
        onTap: () {
          context.read<AuthBloc>().add(AuthLogoutRequested());
        },
      ),
    );
  }
}

class _LanguageOption {
  const _LanguageOption({
    required this.code,
    required this.label,
  });

  final String code;
  final String label;
}

class _FontSizeOption {
  const _FontSizeOption({
    required this.label,
    required this.scale,
  });

  final String label;
  final double scale;
}
