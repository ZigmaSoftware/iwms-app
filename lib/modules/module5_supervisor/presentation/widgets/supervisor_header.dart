import 'package:flutter/material.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/presentation/theme/supervisor_theme.dart';

/// Supervisor header.
class SupervisorHeader extends StatelessWidget {
  const SupervisorHeader({
    super.key,
    required this.name,
    required this.onLogout,
    this.designation = 'Supervisor',
    this.zoneLabel = '',
    this.zoneCount = 0,
  });

  final String name;
  final String designation;
  final String zoneLabel;
  final int zoneCount;
  final VoidCallback onLogout;

  String _toTitleCase(String s) => s
      .split(' ')
      .map((w) => w.isEmpty
          ? ''
          : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
      .join(' ');

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _initials(String value) {
    final parts = value.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'S';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: SupervisorTheme.surface,
        boxShadow: SupervisorTheme.softShadow,
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _avatar(),
                  const SizedBox(width: 12),
                  Expanded(child: _identitySection()),
                  _logoutButton(),
                ],
              ),
              const SizedBox(height: 10),
              _zoneStrip(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatar() {
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: SupervisorTheme.accent,
      ),
      padding: const EdgeInsets.all(2),
      child: CircleAvatar(
        radius: 23,
        backgroundColor: SupervisorTheme.surface,
        child: Text(
          _initials(name),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: SupervisorTheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _identitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${_greeting()}, ${_toTitleCase(name)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 17,
            color: SupervisorTheme.strongText,
            fontWeight: FontWeight.w700,
            height: 1.12,
          ),
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            const Icon(Icons.shield_outlined,
                color: SupervisorTheme.warning, size: 12),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                designation,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: SupervisorTheme.mutedText,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _logoutButton() {
    return SizedBox(
      width: 40,
      height: 40,
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: const Icon(
          Icons.more_vert_rounded,
          color: SupervisorTheme.strongText,
          size: 22,
        ),
        onPressed: onLogout,
        tooltip: 'Logout',
      ),
    );
  }

  Widget _zoneStrip() {
    final label = zoneLabel.trim().isNotEmpty
        ? zoneLabel
        : (zoneCount > 0
            ? '$zoneCount zone${zoneCount == 1 ? '' : 's'} assigned'
            : 'No zones assigned');
    return Row(
      children: [
        const Icon(Icons.map_outlined, color: SupervisorTheme.accent, size: 14),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: SupervisorTheme.strongText,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: SupervisorTheme.success,
          ),
        ),
        const SizedBox(width: 6),
        const Text(
          'On Duty',
          style: TextStyle(
            color: SupervisorTheme.success,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}
