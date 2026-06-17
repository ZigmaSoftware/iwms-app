import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iwms_citizen_app/logic/locale/locale_cubit.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/logic/supervisor_bloc.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/presentation/theme/supervisor_theme.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/presentation/widgets/supervisor_cards.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/presentation/widgets/supervisor_header.dart';

/// Profile tab — identity header, zone scope summary, language switcher,
/// and logout. Mirrors OperatorProfileScreen's structure.
class SupervisorProfileScreen extends StatelessWidget {
  const SupervisorProfileScreen({
    super.key,
    required this.name,
    required this.onLogout,
  });

  final String name;
  final VoidCallback onLogout;

  static const _languages = <String, String>{
    'en': 'English',
    'hi': 'हिन्दी',
    'ta': 'தமிழ்',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      color: SupervisorTheme.background,
      child: BlocBuilder<SupervisorBloc, SupervisorState>(
        builder: (context, state) {
          return Column(
            children: [
              SupervisorHeader(
                name: name,
                onLogout: onLogout,
                zoneCount: state.scope.zoneIds.length,
              ),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    20,
                    16,
                    20,
                    MediaQuery.viewPaddingOf(context).bottom + 200,
                  ),
                  children: [
                    _zoneCard(state),
                    const SizedBox(height: 16),
                    _languageCard(context),
                    const SizedBox(height: 16),
                    _logoutButton(context),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _zoneCard(SupervisorState state) {
    return SupervisorInfoCard(
      title: 'Zone scope',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _detailRow(Icons.map_outlined, 'Zones assigned',
              '${state.scope.zoneIds.length}'),
          if (state.scope.zoneIds.isNotEmpty)
            _detailRow(
                Icons.tag_rounded, 'Zone IDs', state.scope.zoneIds.join(', ')),
          _detailRow(Icons.route_rounded, 'Trips today', '${state.kpis.total}'),
        ],
      ),
    );
  }

  Widget _languageCard(BuildContext context) {
    return SupervisorInfoCard(
      title: 'Language',
      child: BlocBuilder<LocaleCubit, Locale>(
        builder: (context, locale) {
          return Column(
            children: _languages.entries.map((e) {
              final selected = locale.languageCode == e.key;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                onTap: () =>
                    context.read<LocaleCubit>().setLocale(Locale(e.key)),
                leading: Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: selected
                      ? SupervisorTheme.accent
                      : SupervisorTheme.mutedText,
                ),
                title: Text(
                  e.value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: SupervisorTheme.strongText,
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: SupervisorTheme.mutedText),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: SupervisorTheme.mutedText,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: SupervisorTheme.strongText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _logoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onLogout,
        style: OutlinedButton.styleFrom(
          foregroundColor: SupervisorTheme.danger,
          side:
              BorderSide(color: SupervisorTheme.danger.withValues(alpha: 0.4)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: SupervisorTheme.cardRadius,
          ),
        ),
        icon: const Icon(Icons.logout_rounded, size: 18),
        label: const Text(
          'Logout',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
