import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iwms_citizen_app/core/di.dart';
import 'package:iwms_citizen_app/data/models/daily_assignment_model.dart';
import 'package:iwms_citizen_app/data/models/user_model.dart';
import 'package:iwms_citizen_app/data/repositories/auth_repository.dart';
import 'package:iwms_citizen_app/data/repositories/assignment_service.dart';
import 'package:iwms_citizen_app/logic/auth/auth_bloc.dart';
import 'package:iwms_citizen_app/logic/auth/auth_event.dart';
import 'package:iwms_citizen_app/logic/auth/auth_state.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/screens/operator_attendance_screen_integration.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/screens/operator_assignment_screen.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/screens/operator_dashboard_models.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/screens/operator_home_screen.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/screens/operator_overview_screen.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/screens/operator_profile_screen.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/screens/attendance/attendance_home_operator.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/screens/attendance/attendancehistory.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/theme/operator_theme.dart';
import 'package:iwms_citizen_app/modules/module3_operator/utils/attendance_blink_store.dart';
import 'package:iwms_citizen_app/router/app_router.dart';
import 'package:go_router/go_router.dart';
import 'package:iwms_citizen_app/localization/app_localizations.dart';

enum OperatorNavTab { home, assignments, overview, attendance, profile }

class MainOperatorTabBar extends StatefulWidget {
  const MainOperatorTabBar({
    super.key,
    this.initialTab = OperatorNavTab.home,
  });

  final OperatorNavTab initialTab;

  @override
  State<MainOperatorTabBar> createState() => _MainOperatorTabBarState();
}

class _MainOperatorTabBarState extends State<MainOperatorTabBar> {
  OperatorNavTab _activeTab = OperatorNavTab.home;
  OperatorSessionDetails? _sessionDetails;
  DailyAssignmentModel? _selectedAssignment;
  late final AssignmentRepository _assignmentRepository;

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
    _assignmentRepository = getIt<AssignmentRepository>();
    _loadOperatorDetails();
  }

  Future<void> _loadOperatorDetails() async {
    final authRepository = getIt<AuthRepository>();
    final user = await authRepository.getAuthenticatedUser();
    if (!mounted) return;

    var session = _sessionFromUser(user);
    session = await _applyAssignmentContext(session, user?.userId ?? '');
    if (!mounted) return;
    setState(() {
      _sessionDetails = session;
    });
  }

  Future<OperatorSessionDetails> _applyAssignmentContext(
    OperatorSessionDetails session,
    String operatorId,
  ) async {
    if (operatorId.trim().isEmpty) return session;
    try {
      final assignments =
          await _assignmentRepository.fetchAssignmentsForOperator(
        operatorId: operatorId.trim(),
      );
      if (assignments.isEmpty) return session;

      DailyAssignmentModel? assignment;
      for (final item in assignments) {
        assignment ??= item;
        if (item.isActive) {
          assignment = item;
          break;
        }
      }

      if (assignment == null) return session;
      final wardId = assignment.wardId.trim();
      final wardName = assignment.ward.trim();
      String wardLabel = session.wardLabel;

      if (wardId.isNotEmpty && wardName.isNotEmpty && wardId != wardName) {
        wardLabel = '$wardId • $wardName';
      } else if (wardId.isNotEmpty) {
        wardLabel = wardId;
      } else if (wardName.isNotEmpty) {
        wardLabel = wardName;
      }

      return session.copyWith(wardLabel: wardLabel);
    } catch (_) {
      return session;
    }
  }

  OperatorSessionDetails _sessionFromUser(UserModel? user) {
    final fallbackName =
        user?.userName.trim().isNotEmpty == true ? user!.userName : "Operator";
    final fallbackCode =
        user?.userId.trim().isNotEmpty == true ? user!.userId : "OP-000";
    final fallbackEmpId =
        user?.emp_id?.trim().isNotEmpty == true ? user!.emp_id : "000";
    final fallbackEmployeeCode =
        user?.employeeId?.trim().isNotEmpty == true ? user!.employeeId : "";
    return OperatorSessionDetails(
      displayName: fallbackName,
      operatorCode: fallbackCode,
      operatoremp_id: fallbackEmpId!,
      employeeCode: fallbackEmployeeCode ?? "",
      wardLabel: "Ward 12",
      zoneLabel: "Zone 3",
      contactInfo: OperatorContactInfo(
        phone: "+91 98765 43210",
        email: "${fallbackCode.toLowerCase()}@iwms.gov.in",
        designation: "Field Operator",
      ),
    );
  }

  void _setTab(OperatorNavTab tab, {DailyAssignmentModel? assignment}) {
    if (_activeTab == tab) return;
    setState(() {
      _activeTab = tab;
      if (assignment != null) {
        _selectedAssignment = assignment;
      }
    });
  }

  void _logout() {
    context.read<AuthBloc>().add(AuthLogoutRequested());
  }

  @override
  void dispose() {
    AttendanceBlinkStore.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nameFromState = context.select<AuthBloc, String?>((bloc) =>
        bloc.state is AuthStateAuthenticated
            ? (bloc.state as AuthStateAuthenticated).userName
            : null);
    final empIdFromState = context.select<AuthBloc, String?>((bloc) =>
        bloc.state is AuthStateAuthenticated
            ? (bloc.state as AuthStateAuthenticated).emp_id
            : null);
    final employeeIdFromState = context.select<AuthBloc, String?>((bloc) =>
        bloc.state is AuthStateAuthenticated
            ? (bloc.state as AuthStateAuthenticated).employeeId
            : null);
    final localizations = AppLocalizations.of(context);
    final resolvedEmpId = (empIdFromState?.trim().isNotEmpty == true)
        ? empIdFromState!
        : (_sessionDetails?.operatoremp_id ?? "000");
    final resolvedEmployeeCode =
        (employeeIdFromState?.trim().isNotEmpty == true)
            ? employeeIdFromState!
            : (_sessionDetails?.employeeCode ?? resolvedEmpId);
    final session = (_sessionDetails ??
            OperatorSessionDetails(
              displayName: nameFromState ?? "Operator",
              operatorCode: "OP-000",
              operatoremp_id: resolvedEmpId,
              employeeCode: resolvedEmployeeCode,
            ))
        .copyWith(displayName: nameFromState ?? _sessionDetails?.displayName);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return WillPopScope(
      onWillPop: () async {
        if (_activeTab != OperatorNavTab.home) {
          _setTab(OperatorNavTab.home);
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: OperatorTheme.background,
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeIn,
            switchOutCurve: Curves.easeOut,
            child: KeyedSubtree(
              key: ValueKey<OperatorNavTab>(_activeTab),
              child: _buildTab(session),
            ),
          ),
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: OperatorTheme.surface,
            border: const Border(
              top: BorderSide(color: OperatorTheme.cardBorder, width: 1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.14),
                blurRadius: 24,
                spreadRadius: 2,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          padding: EdgeInsets.fromLTRB(
            8,
            4,
            8,
            bottomInset > 0 ? (bottomInset - 14).clamp(4, 14).toDouble() : 4,
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildNavItem(
                  icon: const Icon(Icons.home_rounded),
                  label: localizations.operatorNavHome,
                  selected: _activeTab == OperatorNavTab.home,
                  onTap: () => _setTab(OperatorNavTab.home),
                ),
              ),
              Expanded(
                child: _buildNavItem(
                  icon: const Icon(Icons.assignment_outlined),
                  label: localizations.operatorNavAssignments,
                  selected: _activeTab == OperatorNavTab.assignments,
                  onTap: () => _setTab(OperatorNavTab.assignments),
                ),
              ),
              Expanded(
                child: _buildNavItem(
                  icon: const Icon(Icons.dashboard_outlined),
                  label: localizations.operatorNavOverview,
                  selected: _activeTab == OperatorNavTab.overview,
                  onTap: () => _setTab(OperatorNavTab.overview),
                ),
              ),
              Expanded(
                child: _buildNavItem(
                  icon: _buildAttendanceIcon(),
                  label: localizations.operatorNavAttendance,
                  selected: _activeTab == OperatorNavTab.attendance,
                  onTap: () => _setTab(OperatorNavTab.attendance),
                ),
              ),
              Expanded(
                child: _buildNavItem(
                  icon: const Icon(Icons.person_outline_rounded),
                  label: localizations.operatorNavProfile,
                  selected: _activeTab == OperatorNavTab.profile,
                  onTap: () => _setTab(OperatorNavTab.profile),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required Widget icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final itemColor = selected ? OperatorTheme.primary : Colors.black54;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: selected
                ? OperatorTheme.accentLight.withOpacity(0.92)
                : Colors.transparent,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Transform.translate(
                offset: const Offset(0, 2),
                child: IconTheme(
                  data: IconThemeData(
                    color: itemColor,
                    size: selected ? 24 : 23,
                  ),
                  child: icon,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: itemColor,
                  fontSize: 10.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceIcon() {
    return ValueListenableBuilder<bool>(
      valueListenable: AttendanceBlinkStore.notifier,
      builder: (context, isBlinking, child) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            child!,
            if (isBlinking)
              Positioned(
                right: -2,
                top: -2,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 260),
                  opacity: isBlinking ? 1 : 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: OperatorTheme.attendanceAlert,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: OperatorTheme.attendanceAlert
                              .withValues(alpha: 0.6),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
      child: const Icon(Icons.fact_check_outlined),
    );
  }

  Widget _buildTab(OperatorSessionDetails session) {
    switch (_activeTab) {
      case OperatorNavTab.home:
        return OperatorHomeScreen(
          operatorName: session.displayName,
          operatorCode: session.operatorCode,
          emp_id: session.operatoremp_id,
          employeeCode: session.employeeCode,
          wardLabel: session.wardLabel,
          zoneLabel: session.zoneLabel,
          onScanPressed: () => context.push(AppRoutePaths.operatorQR),
          onLogout: _logout,
          onOpenAssignments: (assignment) =>
              _setTab(OperatorNavTab.assignments, assignment: assignment),
          onOpenAttendance: () => _setTab(OperatorNavTab.attendance),
          onOpenProfile: () => _setTab(OperatorNavTab.profile),
          onOpenHistory: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    AttendanceHistory(empId: session.operatoremp_id),
              ),
            );
          },
          onOpenAttendanceSummary: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AttendancePage(
                  operatorName: session.displayName,
                  operatorCode: session.operatorCode,
                ),
              ),
            );
          },
        );
      case OperatorNavTab.assignments:
        return OperatorAssignmentScreen(
          initialAssignment: _selectedAssignment,
        );
      case OperatorNavTab.overview:
        return const OperatorOverviewScreen();
      case OperatorNavTab.attendance:
        return OperatorAttendanceScreenIntegration(
          operatorName: session.displayName,
          operatorCode: session.operatorCode,
        );
      case OperatorNavTab.profile:
        return OperatorProfileScreen(
          emp_id: session.operatoremp_id,
          employeeCode: session.employeeCode,
          operatorName: session.displayName,
          operatorCode: session.operatorCode,
          wardLabel: session.wardLabel,
          zoneLabel: session.zoneLabel,
          onLogout: _logout,
          contactInfo: session.contactInfo,
          onEditProfile: () => _openProfileEditor(),
        );
    }
  }

  void _openProfileEditor() {
    // Placeholder to hook into the actual profile edit logic/route when available.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Opening operator profile editor...')),
    );
  }
}
