import 'package:flutter/material.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/presentation/theme/supervisor_theme.dart';

/// Supervisor header — charcoal slate gradient top section with an avatar
/// anchored LEFT, identity (name, designation) stacked to its right,
/// a greeting pill + logout on the right, and an optional zone strip below.
/// Mirrors OperatorHeader's structure and tokens exactly.
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
        gradient: SupervisorTheme.headerGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(22),
          bottomRight: Radius.circular(22),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x29000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 30, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _avatar(),
                  const SizedBox(width: 11),
                  Expanded(child: _identitySection()),
                  const SizedBox(width: 8),
                  _greetingPill(),
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
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [SupervisorTheme.accent, SupervisorTheme.accentDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: SupervisorTheme.accent.withValues(alpha: 0.28),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(2),
      child: CircleAvatar(
        radius: 23,
        backgroundColor: Colors.white,
        child: Text(
          _initials(name),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
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
          _toTitleCase(name),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white,
            fontWeight: FontWeight.w800,
            height: 1.12,
          ),
        ),
        const SizedBox(height: 3),
        Row(
          children: [
            const Icon(Icons.shield_outlined,
                color: Color.fromARGB(255, 242, 158, 31), size: 11),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                designation,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
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

  Widget _greetingPill() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wb_sunny_rounded,
                  color: SupervisorTheme.accent, size: 12),
              const SizedBox(width: 4),
              Text(
                _greeting(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 36,
          height: 36,
          child: IconButton(
            padding: EdgeInsets.zero,
            icon:
                const Icon(Icons.logout_rounded, color: Colors.white, size: 18),
            onPressed: onLogout,
            tooltip: 'Logout',
          ),
        ),
      ],
    );
  }

  Widget _zoneStrip() {
    final label = zoneLabel.trim().isNotEmpty
        ? zoneLabel
        : (zoneCount > 0
            ? '$zoneCount zone${zoneCount == 1 ? '' : 's'} assigned'
            : 'No zones assigned');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          const Icon(Icons.map_outlined,
              color: SupervisorTheme.accent, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
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
              fontWeight: FontWeight.w800,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}
