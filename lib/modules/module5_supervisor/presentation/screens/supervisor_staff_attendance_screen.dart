import 'package:flutter/material.dart';

import 'package:iwms_citizen_app/core/di.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/screens/attendance/attendancehistory.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/data/supervisor_models.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/data/supervisor_repository.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/presentation/theme/supervisor_theme.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/presentation/widgets/supervisor_state_views.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/presentation/widgets/supervisor_visuals.dart';

/// Attendance (oversight) — a staff directory where tapping a staff member
/// opens their punch records (from the `app_recognized` table via the
/// attendance-list endpoint). Read-only; no punching happens here.
class SupervisorStaffAttendanceScreen extends StatefulWidget {
  const SupervisorStaffAttendanceScreen({super.key});

  @override
  State<SupervisorStaffAttendanceScreen> createState() =>
      _SupervisorStaffAttendanceScreenState();
}

class _SupervisorStaffAttendanceScreenState
    extends State<SupervisorStaffAttendanceScreen> {
  final SupervisorRepository _repo = getIt<SupervisorRepository>();

  bool _loading = true;
  String? _error;
  List<SupervisorStaff> _staff = [];
  String _query = '';

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
      if (!mounted) return;
      setState(() {
        _staff = staff;
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

  List<SupervisorStaff> get _filtered {
    if (_query.trim().isEmpty) return _staff;
    final q = _query.toLowerCase();
    return _staff
        .where((s) =>
            s.name.toLowerCase().contains(q) ||
            s.designation.toLowerCase().contains(q) ||
            s.role.toLowerCase().contains(q) ||
            s.empId.toLowerCase().contains(q))
        .toList();
  }

  void _openRecords(SupervisorStaff staff) {
    if (staff.uniqueId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Staff ID unavailable.')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AttendanceHistory(empId: staff.uniqueId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SupervisorTheme.background,
      appBar: AppBar(
        backgroundColor: SupervisorTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Staff attendance'),
      ),
      body: SupervisorPatternBackground(child: _body()),
    );
  }

  Widget _body() {
    if (_loading) return const SupervisorLoadingView();
    if (_error != null) {
      return SupervisorErrorView(message: _error!, onRetry: _load);
    }
    if (_staff.isEmpty) {
      return SupervisorEmptyView(
        message: 'No staff found.',
        icon: Icons.groups_rounded,
        onRefresh: _load,
      );
    }

    final list = _filtered;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search staff…',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              isDense: true,
              filled: true,
              fillColor: SupervisorTheme.surface,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                    color: SupervisorTheme.hairline.withValues(alpha: 0.6)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                    color: SupervisorTheme.hairline.withValues(alpha: 0.6)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: SupervisorTheme.accent, width: 1.4),
              ),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: SupervisorTheme.accent,
            onRefresh: _load,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _StaffRow(
                staff: list[i],
                onTap: () => _openRecords(list[i]),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StaffRow extends StatelessWidget {
  const _StaffRow({required this.staff, required this.onTap});

  final SupervisorStaff staff;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final initials = staff.name.isNotEmpty ? staff.name[0].toUpperCase() : '?';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: SupervisorTheme.cardRadius,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: SupervisorTheme.surface,
            borderRadius: SupervisorTheme.cardRadius,
            border: Border.all(
                color: SupervisorTheme.hairline.withValues(alpha: 0.6)),
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
                  border: Border.all(
                      color: SupervisorTheme.accent.withValues(alpha: 0.4)),
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
                        if (staff.designation.isNotEmpty) staff.designation,
                        if (staff.role.isNotEmpty) staff.role,
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
              const Icon(Icons.event_note_rounded,
                  size: 18, color: SupervisorTheme.accent),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: SupervisorTheme.mutedText),
            ],
          ),
        ),
      ),
    );
  }
}
