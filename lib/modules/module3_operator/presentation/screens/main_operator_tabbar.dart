import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iwms_citizen_app/core/di.dart';
import 'package:iwms_citizen_app/data/models/daily_assignment_model.dart';
import 'package:iwms_citizen_app/data/models/user_model.dart';
import 'package:iwms_citizen_app/data/repositories/auth_repository.dart';
import 'package:iwms_citizen_app/data/repositories/assignment_repository.dart';
import 'package:iwms_citizen_app/logic/auth/auth_bloc.dart';
import 'package:iwms_citizen_app/logic/auth/auth_event.dart';
import 'package:iwms_citizen_app/logic/auth/auth_state.dart';
import 'package:iwms_citizen_app/core/theme/app_colors.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/screens/operator_attendance_screen_integration.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/screens/operator_assignment_screen.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/screens/operator_dashboard_models.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/screens/operator_home_screen.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/screens/operator_overview_screen.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/screens/operator_profile_screen.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/screens/attendance/attendance_home_operator.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/screens/attendance/attendancehistory.dart';
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
       final fallbackemp_id =
        user?.emp_id?.trim().isNotEmpty == true ? user!.emp_id : "000";  
    return OperatorSessionDetails(
      displayName: fallbackName,
      operatorCode: fallbackCode,
      operatoremp_id:fallbackemp_id!,
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
  Widget build(BuildContext context) {
    final nameFromState = context.select<AuthBloc, String?>((bloc) =>
        bloc.state is AuthStateAuthenticated
            ? (bloc.state as AuthStateAuthenticated).userName
            : null);
    final emp_idFromState = context.select<AuthBloc, String?>((bloc) =>
        bloc.state is AuthStateAuthenticated
            ? (bloc.state as AuthStateAuthenticated).emp_id
            : null);
    final localizations = AppLocalizations.of(context);
    final resolvedEmpId = (emp_idFromState?.trim().isNotEmpty == true)
        ? emp_idFromState!
        : (_sessionDetails?.operatoremp_id ?? "000");
    final session = (_sessionDetails ??
            OperatorSessionDetails(
              displayName: nameFromState ?? "Operator",
              operatorCode: "OP-000",
              operatoremp_id: resolvedEmpId,
            ))
        .copyWith(displayName: nameFromState ?? _sessionDetails?.displayName);

    return WillPopScope(
      onWillPop: () async {
        if (_activeTab != OperatorNavTab.home) {
          _setTab(OperatorNavTab.home);
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
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
        bottomNavigationBar: SafeArea(
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: _activeTab.index,
            onTap: (index) => _setTab(OperatorNavTab.values[index]),
            selectedItemColor: AppColors.primary,
            unselectedItemColor: Colors.black54,
            showUnselectedLabels: true,
            selectedFontSize: 11,
            unselectedFontSize: 11,
            items: [
              BottomNavigationBarItem(
                icon: const Icon(Icons.home_rounded),
                label: localizations.operatorNavHome,
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.assignment_outlined),
                label: localizations.operatorNavAssignments,
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.dashboard_outlined),
                label: localizations.operatorNavOverview,
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.fact_check_outlined),
                label: localizations.operatorNavAttendance,
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.person_outline_rounded),
                label: localizations.operatorNavProfile,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTab(OperatorSessionDetails session) {
    switch (_activeTab) {
      case OperatorNavTab.home:
        return OperatorHomeScreen(
          operatorName: session.displayName,
          operatorCode: session.operatorCode,
          emp_id: session.operatoremp_id,
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
                builder: (_) => AttendanceHistory(empId: session.operatoremp_id),
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

  String _labelForTab(OperatorNavTab tab) {
    switch (tab) {
      case OperatorNavTab.home:
        return "Home";
      case OperatorNavTab.assignments:
        return "Assignments";
      case OperatorNavTab.overview:
        return "Overview";
      case OperatorNavTab.attendance:
        return "Attendance";
      case OperatorNavTab.profile:
        return "Profile";
    }
  }

  OperatorNavTab? _tabFromValue(dynamic value) {
    if (value is OperatorNavTab) return value;
    if (value is int) {
      return OperatorNavTab.values[value];
    }
    if (value is String) {
      switch (value) {
        case "Home":
          return OperatorNavTab.home;
        case "Assignments":
          return OperatorNavTab.assignments;
        case "Overview":
          return OperatorNavTab.overview;
        case "Attendance":
          return OperatorNavTab.attendance;
        case "Profile":
          return OperatorNavTab.profile;
      }
    }
    return null;
  }
}
