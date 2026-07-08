import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iwms_citizen_app/core/di.dart';
import 'package:iwms_citizen_app/logic/auth/auth_bloc.dart';
import 'package:iwms_citizen_app/logic/auth/auth_event.dart';
import 'package:iwms_citizen_app/logic/auth/auth_state.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/data/supervisor_repository.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/logic/supervisor_bloc.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/presentation/screens/attendance/supervisor_attendance_page.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/presentation/screens/supervisor_assignments_screen.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/presentation/screens/supervisor_attendance_screen.dart'
    as attendance;
import 'package:iwms_citizen_app/modules/module5_supervisor/presentation/screens/supervisor_home_page.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/presentation/screens/supervisor_profile_screen.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/presentation/screens/supervisor_trips_screen.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/presentation/theme/supervisor_theme.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/presentation/widgets/supervisor_animated_nav_bar.dart';

/// Tabs surfaced in the supervisor shell.
/// The 4 nav slots are: Dashboard / Trips / Attendance / Profile.
enum SupervisorNavTab { dashboard, trips, attendance, profile }

class MainSupervisorTabBar extends StatelessWidget {
  const MainSupervisorTabBar({
    super.key,
    this.initialTab = SupervisorNavTab.dashboard,
  });

  final SupervisorNavTab initialTab;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SupervisorBloc>(
      create: (_) => SupervisorBloc(repository: getIt<SupervisorRepository>())
        ..add(const SupervisorLoadRequested()),
      child: _SupervisorShell(initialTab: initialTab),
    );
  }
}

class _SupervisorShell extends StatefulWidget {
  const _SupervisorShell({required this.initialTab});

  final SupervisorNavTab initialTab;

  @override
  State<_SupervisorShell> createState() => _SupervisorShellState();
}

class _SupervisorShellState extends State<_SupervisorShell> {
  static const _slotTabs = <SupervisorNavTab>[
    SupervisorNavTab.dashboard,
    SupervisorNavTab.trips,
    SupervisorNavTab.attendance,
    SupervisorNavTab.profile,
  ];

  late SupervisorNavTab _activeTab = widget.initialTab;

  void _setTab(SupervisorNavTab tab) {
    if (_activeTab == tab) return;
    setState(() => _activeTab = tab);
  }

  void _logout() {
    context.read<AuthBloc>().add(AuthLogoutRequested());
  }

  void _openAssignments() {
    // Review list is no longer a bottom-nav tab (Attendance took its slot), so
    // the dashboard's "Review" affordance opens it as a pushed screen, sharing
    // the existing SupervisorBloc.
    final bloc = context.read<SupervisorBloc>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider<SupervisorBloc>.value(
          value: bloc,
          child: Scaffold(
            backgroundColor: SupervisorTheme.background,
            appBar: AppBar(
              backgroundColor: SupervisorTheme.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              title: const Text('Review'),
            ),
            body: const SupervisorAssignmentsScreen(),
          ),
        ),
      ),
    );
  }

  void _openTeam() {
    // Push the read-only team roster, sharing the existing SupervisorBloc.
    final bloc = context.read<SupervisorBloc>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider<SupervisorBloc>.value(
          value: bloc,
          child: Scaffold(
            backgroundColor: SupervisorTheme.background,
            appBar: AppBar(
              backgroundColor: SupervisorTheme.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              title: const Text('Team on duty'),
            ),
            body: const attendance.SupervisorAttendanceScreen(),
          ),
        ),
      ),
    );
  }

  String _identityName() {
    final state = context.read<AuthBloc>().state;
    if (state is AuthStateAuthenticated) {
      return state.userName.trim().isNotEmpty ? state.userName : 'Supervisor';
    }
    return 'Supervisor';
  }

  @override
  Widget build(BuildContext context) {
    final name = _identityName();

    final navItems = <SupervisorNavItem>[
      const SupervisorNavItem(
        icon: Icons.dashboard_rounded,
        label: 'Dashboard',
      ),
      const SupervisorNavItem(
        icon: Icons.local_shipping_rounded,
        label: 'Trips',
      ),
      const SupervisorNavItem(
        icon: Icons.fingerprint_rounded,
        label: 'Attendance',
      ),
      const SupervisorNavItem(
        icon: Icons.person_rounded,
        label: 'Profile',
        iconAsset: 'assets/icons/profile_s.png',
      ),
    ];

    final activeSlot =
        _slotTabs.indexOf(_activeTab).clamp(0, _slotTabs.length - 1);

    return WillPopScope(
      onWillPop: () async {
        if (_activeTab != SupervisorNavTab.dashboard) {
          _setTab(SupervisorNavTab.dashboard);
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: SupervisorTheme.background,
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
              key: ValueKey<SupervisorNavTab>(_activeTab),
              child: _buildTab(name),
            ),
          ),
        ),
        bottomNavigationBar: SupervisorAnimatedNavBar(
          activeIndex: activeSlot,
          items: navItems,
          onTabSelected: (index) => _setTab(_slotTabs[index]),
        ),
      ),
    );
  }

  Widget _buildTab(String name) {
    switch (_activeTab) {
      case SupervisorNavTab.dashboard:
        return SupervisorHomePage(
          name: name,
          onLogout: _logout,
          onOpenTrips: () => _setTab(SupervisorNavTab.trips),
          onOpenAssignments: _openAssignments,
          onOpenTeam: _openTeam,
        );
      case SupervisorNavTab.trips:
        return const SupervisorTripsScreen();
      case SupervisorNavTab.attendance:
        return SupervisorAttendancePage(name: name);
      case SupervisorNavTab.profile:
        return SupervisorProfileScreen(
          name: name,
          onLogout: _logout,
        );
    }
  }
}
