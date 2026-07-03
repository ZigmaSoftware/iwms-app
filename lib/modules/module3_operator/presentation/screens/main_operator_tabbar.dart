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
import 'package:iwms_citizen_app/modules/module3_operator/presentation/screens/operator_profile_screen.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/screens/operator_trip_home_screen.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/screens/operator_qr_scanner.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/theme/operator_theme.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/widgets/operator_animated_nav_bar.dart';
import 'package:iwms_citizen_app/modules/module3_operator/utils/attendance_blink_store.dart';
import 'package:iwms_citizen_app/modules/module3_operator/utils/household_mode_store.dart';
import 'package:iwms_citizen_app/localization/app_localizations.dart';

/// DEPRECATED (July 2026): the standalone operator app surface is retired —
/// one phone per vehicle, held by the driver. Use the merged Captain shell
/// (`module2_driver/driver_home_page.dart`) instead. This shell is kept for
/// backward compatibility with existing operator logins; see
/// `module3_operator/README.md` for the migration map.
///
/// Tabs surfaced in the operator shell. QR is intentionally NOT a tab —
/// it lives as a PhonePe-style green floating action button docked in the
/// bottom-app-bar notch. The 4 nav slots are: Home / Assignments / (QR FAB)
/// / Attendance / Profile.
enum OperatorNavTab { home, assignments, attendance, profile }

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
  // Mapping between visible nav positions (4 slots) and OperatorNavTab.
  // Layout: [Home][Assignments] (QR FAB) [Attendance][Profile]
  static const _slotTabs = <OperatorNavTab>[
    OperatorNavTab.home,
    OperatorNavTab.assignments,
    OperatorNavTab.attendance,
    OperatorNavTab.profile,
  ];

  OperatorNavTab _activeTab = OperatorNavTab.home;
  OperatorSessionDetails? _sessionDetails;
  DailyAssignmentModel? _selectedAssignment;
  int _tripRefreshVersion = 0;
  late final AssignmentRepository _assignmentRepository;

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
    _assignmentRepository = getIt<AssignmentRepository>();
    // Hydrate the persisted Household-mode flag so the profile toggle and the
    // QR FAB both reflect the operator's last choice on entry.
    HouseholdModeStore.load();
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

      if (wardName.isNotEmpty) {
        wardLabel = wardName;
      } else if (wardId.isNotEmpty) {
        wardLabel = wardId;
      }

      return session.copyWith(wardLabel: wardLabel, zoneLabel: '');
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
      wardLabel: "",
      zoneLabel: "",
      contactInfo: OperatorContactInfo(
        phone: "+91 98765 43210",
        email: "${fallbackCode.toLowerCase()}@iwms.gov.in",
        designation: "Field Operator",
      ),
    );
  }

  void _setTab(OperatorNavTab tab, {DailyAssignmentModel? assignment}) {
    if (_activeTab == tab && assignment == null) return;
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

  Future<void> _openQrScanner() async {
    // The central bottom-nav QR FAB has two destinations, chosen by the
    // persisted "Household collection" toggle on the profile screen:
    //   • Household ON  → OperatorQRScanner: scan a customer QR, then enter
    //     wet/dry/mixed waste with weights (Bluetooth scale or manual) + photo
    //     via OperatorDataScreen.
    //   • Household OFF → OperatorTripScanScreen: the default bin/trip flow.
    if (HouseholdModeStore.isEnabled) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const OperatorQRScanner()),
      );
      // The household flow manages its own submission/navigation; just
      // refresh the trip view in case shared collection points changed.
      if (!mounted) return;
      setState(() {
        _tripRefreshVersion++;
      });
      return;
    }

    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const OperatorTripScanScreen()),
    );
    if (!mounted || result == null) return;
    setState(() {
      _tripRefreshVersion++;
    });
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

    final navItems = <OperatorNavItem>[
      OperatorNavItem(
        icon: Icons.home_rounded,
        label: localizations.operatorNavHome,
      ),
      OperatorNavItem(
        icon: Icons.assignment_rounded,
        label: localizations.operatorNavAssignments,
      ),
      OperatorNavItem(
        icon: Icons.fact_check_rounded,
        label: localizations.operatorNavAttendance,
        blink: true,
      ),
      OperatorNavItem(
        icon: Icons.person_rounded,
        label: localizations.operatorNavProfile,
      ),
    ];

    final activeSlot =
        _slotTabs.indexOf(_activeTab).clamp(0, _slotTabs.length - 1);

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
        extendBody: true,
        body: SafeArea(
          bottom: false,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, anim) {
              return FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.02),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              );
            },
            child: KeyedSubtree(
              key: ValueKey<OperatorNavTab>(_activeTab),
              child: _buildTab(session),
            ),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: OperatorQrFab(
          onPressed: _openQrScanner,
          label: localizations.operatorTapToScan,
        ),
        bottomNavigationBar: OperatorAnimatedNavBar(
          activeIndex: activeSlot,
          items: navItems,
          onTabSelected: (index) => _setTab(_slotTabs[index]),
        ),
      ),
    );
  }

  Widget _buildTab(OperatorSessionDetails session) {
    switch (_activeTab) {
      case OperatorNavTab.home:
        return OperatorHomeScreen(
          key: ValueKey<int>(_tripRefreshVersion),
          operatorName: session.displayName,
          operatorCode: session.operatorCode,
          emp_id: session.operatoremp_id,
          employeeCode: session.employeeCode,
          wardLabel: session.wardLabel,
          zoneLabel: session.zoneLabel,
          designation: session.contactInfo.designation,
          onScanPressed: _openQrScanner,
          onLogout: _logout,
          onOpenAssignments: (assignment) =>
              _setTab(OperatorNavTab.assignments, assignment: assignment),
          onOpenProfile: () => _setTab(OperatorNavTab.profile),
        );
      case OperatorNavTab.assignments:
        return OperatorAssignmentScreen(
          initialAssignment: _selectedAssignment,
        );
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
          onEditProfile: _openProfileEditor,
        );
    }
  }

  void _openProfileEditor() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Opening operator profile editor...')),
    );
  }
}
