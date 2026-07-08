import 'package:flutter/material.dart';

import 'package:iwms_citizen_app/core/di.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/data/supervisor_models.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/data/supervisor_repository.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/presentation/theme/supervisor_theme.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/presentation/widgets/supervisor_state_views.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/presentation/widgets/supervisor_visuals.dart';

/// Staffs — the company's staff list grouped by designation.
class SupervisorStaffScreen extends StatefulWidget {
  const SupervisorStaffScreen({super.key});

  @override
  State<SupervisorStaffScreen> createState() => _SupervisorStaffScreenState();
}

class _SupervisorStaffScreenState extends State<SupervisorStaffScreen> {
  final SupervisorRepository _repo = getIt<SupervisorRepository>();

  bool _loading = true;
  String? _error;
  Map<String, List<SupervisorStaff>> _grouped = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final staff = await _repo.fetchStaff();
      final grouped = <String, List<SupervisorStaff>>{};
      for (final s in staff) {
        grouped.putIfAbsent(s.designation, () => []).add(s);
      }
      if (!mounted) return;
      setState(() {
        _grouped = grouped;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load staff';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SupervisorTheme.background,
      appBar: AppBar(
        backgroundColor: SupervisorTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Staffs'),
      ),
      body: SupervisorPatternBackground(child: _body()),
    );
  }

  Widget _body() {
    if (_loading) return const SupervisorLoadingView();
    if (_error != null) {
      return SupervisorErrorView(message: _error!, onRetry: _load);
    }
    if (_grouped.isEmpty) {
      return SupervisorEmptyView(
        message: 'No staff found.',
        icon: Icons.groups_rounded,
        onRefresh: _load,
      );
    }

    final designations = _grouped.keys.toList()..sort();

    return RefreshIndicator(
      color: SupervisorTheme.accent,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          for (final designation in designations) ...[
            _sectionHeader(designation, _grouped[designation]!.length),
            const SizedBox(height: 8),
            ..._grouped[designation]!.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _StaffCard(staff: s),
                )),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, int count) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: SupervisorTheme.strongText,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: SupervisorTheme.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: SupervisorTheme.accentDeep,
            ),
          ),
        ),
      ],
    );
  }
}

class _StaffCard extends StatelessWidget {
  const _StaffCard({required this.staff});

  final SupervisorStaff staff;

  @override
  Widget build(BuildContext context) {
    final initials = staff.name.isNotEmpty ? staff.name[0].toUpperCase() : '?';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SupervisorTheme.surface,
        borderRadius: SupervisorTheme.cardRadius,
        border: Border.all(color: SupervisorTheme.hairline.withValues(alpha: 0.6)),
        boxShadow: SupervisorTheme.softShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  SupervisorTheme.accent.withValues(alpha: 0.22),
                  SupervisorTheme.accent.withValues(alpha: 0.10),
                ],
              ),
              border:
                  Border.all(color: SupervisorTheme.accent.withValues(alpha: 0.4)),
            ),
            child: Text(
              initials,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: SupervisorTheme.accentDeep,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  staff.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: SupervisorTheme.strongText,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    if (staff.role.isNotEmpty) staff.role,
                    if (staff.site.isNotEmpty) staff.site,
                    if (staff.empId.isNotEmpty) 'ID ${staff.empId}',
                  ].join('  •  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: SupervisorTheme.mutedText,
                  ),
                ),
              ],
            ),
          ),
          if (staff.mobile.isNotEmpty)
            const Icon(Icons.phone_rounded,
                size: 16, color: SupervisorTheme.mutedText),
        ],
      ),
    );
  }
}
