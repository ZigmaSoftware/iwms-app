import 'dart:async';
import 'dart:math' as math;

import 'package:dynamic_tabbar/dynamic_tabbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:iwms_citizen_app/core/di.dart';
import 'package:iwms_citizen_app/data/models/vehicle_model.dart';
import 'package:iwms_citizen_app/data/repositories/vehicle_repository.dart';
import 'package:iwms_citizen_app/modules/module1_citizen/citizen/dashboard/track/models/waste_reports.dart';
import 'package:iwms_citizen_app/modules/module1_citizen/citizen/dashboard/track/models/waste_summary.dart';
import 'package:iwms_citizen_app/modules/module1_citizen/citizen/dashboard/track/services/track_service.dart';
import 'package:iwms_citizen_app/logic/auth/auth_bloc.dart';
import 'package:iwms_citizen_app/logic/auth/auth_event.dart';
import 'package:iwms_citizen_app/modules/module4_admin/dashboard/presentation/screens/assignment_details_screen.dart';
import 'package:iwms_citizen_app/modules/module4_admin/dashboard/presentation/screens/citizen_collection_screen.dart';
import 'package:iwms_citizen_app/modules/module4_admin/dashboard/presentation/screens/staff_management_screen.dart';
import 'package:iwms_citizen_app/router/app_router.dart';
import 'package:iwms_citizen_app/data/repositories/assignment_service.dart';
import 'package:iwms_citizen_app/data/models/daily_assignment_model.dart';
import 'package:iwms_citizen_app/data/models/staff_assignment_models.dart';

import 'package:iwms_citizen_app/modules/module1_citizen/citizen/map.dart'
    as citizen_map;

const _primaryGreen = Color(0xFF2E7D32);
const _softGreen = Color(0xFFA5D6A7);
const _softYellow = Color(0xFFFFE082);
const _softRed = Color(0xFFFF8A80);
const _softBlue = Color(0xFFBBDEFB);
const _bgWhite = Color(0xFFFFFFFF);
const _cardBackground = Color(0xFFF8F9FB);
const _iconGray = Color(0xFF9E9E9E);
const _borderGray = Color(0xFFE0E0E0);

List<BoxShadow> _softCardShadow() => [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.07),
        blurRadius: 16,
        offset: const Offset(0, 6),
      ),
    ];

BoxDecoration _cardDecoration({Color color = _cardBackground}) => BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(18),
      boxShadow: _softCardShadow(),
    );

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) => const _DashboardShell();
}

class _DashboardShell extends StatefulWidget {
  const _DashboardShell();

  @override
  State<_DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<_DashboardShell> {
  int _currentIndex = 0; // ✅ ADD THIS
  int _assignmentsReloadToken = 0;

  late final TrackService _trackService;
  late final VehicleRepository _vehicleRepository;
  late Future<_DashboardData> _dashboardFuture;

  @override
  void initState() {
    super.initState();
    _trackService = TrackService();
    _vehicleRepository = getIt<VehicleRepository>();
    _dashboardFuture = _loadDashboardData();
  }

  void _reloadDashboard() {
    setState(() {
      _dashboardFuture = _loadDashboardData();
    });
  }

  Future<_DashboardData> _loadDashboardData() async {
    final today = DateTime.now();
    final todayKey = DateFormat('yyyy-MM-dd').format(today);
    final fromDate = DateTime(today.year, today.month, 1);

    final summaryFuture = _trackService
        .fetchMonthlySummaries(today)
        .catchError((_) => <String, WasteSummary>{});
    final vehiclesFuture = _vehicleRepository
        .fetchAllVehicleLocations()
        .catchError((_) => <VehicleModel>[]);
    final dateRangeFuture = _trackService
        .fetchDateWiseSummaries(fromDate, today)
        .catchError((_) => <WasteSummary>[]);
    final dayTicketsFuture = _trackService
        .fetchDayWiseTickets(today)
        .catchError((_) => <DayWiseTicket>[]);
    final vehicleWeightsFuture = _trackService
        .fetchVehicleWiseReport(today)
        .catchError((_) => <VehicleWeightReport>[]);

    final summaryMap = await summaryFuture;
    WasteSummary? summary;
    if (summaryMap.containsKey(todayKey)) {
      summary = summaryMap[todayKey];
    } else if (summaryMap.isNotEmpty) {
      summary = summaryMap.values.first;
    }

    final monthSeries = summaryMap.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final vehicles = await vehiclesFuture;
    final dateRangeSummaries = await dateRangeFuture;
    final dayTickets = await dayTicketsFuture;
    final vehicleWeights = await vehicleWeightsFuture;
    const assignments = <DailyAssignmentModel>[];

    return _DashboardData(
      summary: summary,
      vehicles: vehicles,
      monthSeries: monthSeries,
      dateRangeSummaries: dateRangeSummaries,
      dayTickets: dayTickets,
      vehicleWeights: vehicleWeights,
      assignments: assignments,
    );
  }

  Future<void> _refreshHome() async {
    setState(() {
      _dashboardFuture = _loadDashboardData();
    });
    await _dashboardFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildHome(context), // 0
          AssignmentsScreen(key: ValueKey(_assignmentsReloadToken)), // 1
          const _ApprovalsScreen(), // 2
          VehiclesScreen(vehicleRepository: _vehicleRepository), // 3
          const MoreScreen(), // 4
        ],
      ),
      bottomNavigationBar: _DashboardNavBar(
        currentIndex: _currentIndex,
        onChanged: (index) {
          setState(() {
            _currentIndex = index;
            if (index == 0) {
              _dashboardFuture = _loadDashboardData();
            } else if (index == 1) {
              _assignmentsReloadToken++;
            }
          });
        },
      ),
    );
  }

  Widget _buildHome(BuildContext context) {
    return FutureBuilder<_DashboardData>(
      future: _dashboardFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off, size: 52, color: _iconGray),
                  const SizedBox(height: 12),
                  Text(
                    'Unable to load live data.\nPull down to retry.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _refreshHome,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        final data = snapshot.data ?? const _DashboardData.empty();
        return SafeArea(
          top: true,
          child: RefreshIndicator(
            onRefresh: _refreshHome,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final content = _DashboardHomeContent(
                  data: data,
                  maxWidth: constraints.maxWidth,
                );
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: content,
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _DashboardHomeContent extends StatelessWidget {
  const _DashboardHomeContent({required this.data, required this.maxWidth});

  final _DashboardData data;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final summary = data.summary;
    final wasteSlices = [
      _WasteSlice('Wet Waste', summary?.wetWeight ?? 0, _primaryGreen),
      _WasteSlice(
        'Dry Waste',
        summary?.dryWeight ?? 0,
        const Color(0xFF2979FF),
      ),
      _WasteSlice(
        'Mixed Waste',
        summary?.mixWeight ?? 0,
        const Color(0xFFFFB74D),
      ),
    ];
    final statusCounts = data.statusCounts;

    return Column(
      children: [
        _HeaderHero(maxWidth: maxWidth),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: _bgWhite,
              borderRadius: BorderRadius.circular(24),
              boxShadow: _softCardShadow(),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
            child: Column(
              children: [
                _DailyWasteCard(summary: summary, slices: wasteSlices),
                const SizedBox(height: 12),
                const SizedBox(height: 16),
                _AttendanceRow(
                  statusCounts: statusCounts,
                  totalVehicles: data.vehicles.length,
                ),
                const SizedBox(height: 16),
                const _CitizenCollectionCard(),
                const SizedBox(height: 16),
//                 const SizedBox(height: 16),
// Container(
//   padding: const EdgeInsets.all(12),
//   color: Colors.redAccent,
//   child: Text(
//     'Assignments length = ${data.assignments.length}',
//     style: const TextStyle(color: Colors.white),
//   ),
// ),
                if (data.assignments.isNotEmpty)
                  _TodayAssignmentsCarousel(
                    assignments: data.assignments,
                    onCancelled: () {
                      (context.findAncestorStateOfType<_DashboardShellState>())
                          ?._reloadDashboard();
                    },
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TodayAssignmentsCarousel extends StatelessWidget {
  const _TodayAssignmentsCarousel({
    required this.assignments,
    required this.onCancelled,
  });

  final List<DailyAssignmentModel> assignments;
  final VoidCallback onCancelled;

  @override
  Widget build(BuildContext context) {
    final cardWidth = math.min(320.0, MediaQuery.of(context).size.width - 48);
    const cardHeight = 168.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            "Today’s Assignments",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: List.generate(assignments.length, (i) {
              return Padding(
                padding: EdgeInsets.only(
                    bottom: i == assignments.length - 1 ? 0 : 12),
                child: _AssignmentCarouselCard(
                  assignment: assignments[i],
                  onCancelled: onCancelled,
                  width: cardWidth,
                  height: cardHeight,
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _AssignmentCarouselCard extends StatelessWidget {
  const _AssignmentCarouselCard({
    required this.assignment,
    required this.onCancelled,
    this.width,
    this.height,
  });

  final DailyAssignmentModel assignment;
  final VoidCallback onCancelled;
  final double? width;
  final double? height;

  Color _typeBg(String type) {
    switch (type.toLowerCase()) {
      case 'temporary':
        return const Color(0xFFFFF3E0);
      case 'emergency':
        return const Color(0xFFFFEBEE);
      default:
        return const Color(0xFFE8F5E9);
    }
  }

  Color _typeFg(String type) {
    switch (type.toLowerCase()) {
      case 'temporary':
        return const Color(0xFFF57C00);
      case 'emergency':
        return const Color(0xFFC62828);
      default:
        return _primaryGreen;
    }
  }

  Widget _roleStatusChip({
    required String label,
    required AssignmentRoleStatus status,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: status.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: status.color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 10, color: status.color),
          const SizedBox(width: 3),
          Text(
            '$label: ${status.displayName}',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: status.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _staffLine({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 12, color: _iconGray),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            '$label: $value',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF263238),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardWidth =
        width ?? math.min(320.0, MediaQuery.of(context).size.width - 48);
    final cardHeight = height ?? 168.0;
    final statusColor = assignment.statusColor;

    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: cardWidth,
        height: cardHeight,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: _softCardShadow(),
            border: Border.all(color: statusColor.withOpacity(0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      assignment.statusLabel,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    DateFormat('MMM d').format(assignment.date),
                    style: const TextStyle(
                      fontSize: 10,
                      color: _iconGray,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                assignment.ward,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: _staffLine(
                      icon: Icons.local_shipping_outlined,
                      label: 'Driver',
                      value: assignment.driver,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _staffLine(
                      icon: Icons.support_agent_outlined,
                      label: 'Operator',
                      value: assignment.operatorName,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _roleStatusChip(
                    label: 'Driver',
                    status: assignment.driverStatus,
                  ),
                  const SizedBox(width: 6),
                  _roleStatusChip(
                    label: 'Operator',
                    status: assignment.operatorStatus,
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: _typeBg(assignment.assignmentType),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      assignment.assignmentType.toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                        color: _typeFg(assignment.assignmentType),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    assignment.shift.replaceAll('_', ' ').toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      color: _iconGray,
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AssignmentDetailsScreen(
                            assignment: assignment,
                            onCancelled: onCancelled,
                          ),
                        ),
                      );
                    },
                    child: const Text(
                      'Details',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderHero extends StatelessWidget {
  const _HeaderHero({required this.maxWidth});

  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 140,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xCCFFFFFF), Color(0x99FFFFFF)],
            ),
            image: DecorationImage(
              image: AssetImage('assets/images/admin_header.png'),
              fit: BoxFit.cover,
              alignment: Alignment.centerRight,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: _softCardShadow(),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Image.asset(
                          'asset/images/logo.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.eco, color: _primaryGreen),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'IWMS',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Color.fromARGB(255, 255, 255, 255),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _DailyWasteCard extends StatelessWidget {
  const _DailyWasteCard({required this.summary, required this.slices});

  final WasteSummary? summary;
  final List<_WasteSlice> slices;

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<double>(0, (sum, slice) => sum + slice.value);
    final subtitle = summary != null
        ? DateFormat('EEE, d MMM').format(summary!.date)
        : 'Live collection (today)';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily Waste Collection',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: _iconGray),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _primaryGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.autorenew, size: 16, color: _primaryGreen),
                    const SizedBox(width: 6),
                    Container(
                      child: Text(
                        'Live',
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: _primaryGreen,
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 380;
              final chart = SizedBox(
                height: 140,
                width: 140,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size.square(140),
                      painter: _WasteDonutPainter(slices: slices),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          total.toStringAsFixed(1),
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Total tons',
                          style: TextStyle(fontSize: 12, color: _iconGray),
                        ),
                      ],
                    ),
                  ],
                ),
              );
              final legendContent = Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: slices
                    .map(
                      (slice) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 17,
                              height: 12,
                              decoration: BoxDecoration(
                                color: slice.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                slice.label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Text(
                              '${slice.value.toStringAsFixed(1)} t',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              );

              return isNarrow
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        chart,
                        const SizedBox(height: 14),
                        legendContent,
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        chart,
                        const SizedBox(width: 16),
                        Flexible(fit: FlexFit.loose, child: legendContent),
                      ],
                    );
            },
          ),
          if (summary != null) ...[
            const SizedBox(height: 12),
            Text(
              'Average per trip: ${summary!.averageWeightPerTrip.toStringAsFixed(2)} tons across ${summary!.totalTrip} trips',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: _iconGray),
            ),
          ],
        ],
      ),
    );
  }
}

class _CitizenCollectionCard extends StatelessWidget {
  const _CitizenCollectionCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people_alt_outlined, color: _primaryGreen),
              const SizedBox(width: 8),
              Text(
                'Citizen Collection Status',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Review completed, pending, or skipped pickups ward-wise.',
            style: TextStyle(color: _iconGray),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CitizenCollectionScreen(),
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: _primaryGreen,
                side: const BorderSide(color: _primaryGreen),
              ),
              child: const Text('View citizens'),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationsCard extends StatelessWidget {
  const _NotificationsCard({
    required this.pendingApprovals,
    required this.acceptedApprovals,
  });

  final int pendingApprovals;
  final int acceptedApprovals;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(color: _softBlue.withValues(alpha: 0.35)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: _softCardShadow(),
                ),
                child: const Icon(
                  Icons.notifications_active,
                  color: _primaryGreen,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Approval notifications',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _primaryGreen,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Review leave requests from drivers and operators.',
                      style: TextStyle(
                        fontSize: 12,
                        color: _iconGray,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _NotificationChip(
                label: 'Pending',
                value: pendingApprovals,
                color: const Color(0xFFF9A825),
              ),
              const SizedBox(width: 10),
              _NotificationChip(
                label: 'Accepted',
                value: acceptedApprovals,
                color: _primaryGreen,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NotificationChip extends StatelessWidget {
  const _NotificationChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: color,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '$value',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: color,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttendanceRow extends StatelessWidget {
  const _AttendanceRow({
    required this.statusCounts,
    required this.totalVehicles,
  });

  final Map<_VehicleState, int> statusCounts;
  final int totalVehicles;

  @override
  Widget build(BuildContext context) {
    final running = statusCounts[_VehicleState.running] ?? 0;
    final idle = statusCounts[_VehicleState.idle] ?? 0;

    final present = running + idle;
    final onLeave = statusCounts[_VehicleState.parked] ?? 0;
    final absent = statusCounts[_VehicleState.nodata] ?? 0;

    return Row(
      children: [
        Expanded(
          child: _Tile(
            label: "Total",
            count: totalVehicles,
            background: Colors.white,
            textColor: Colors.black87,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Tile(
            label: "Present",
            count: present,
            background: const Color(0xFFE8F5E9), // light green
            textColor: _primaryGreen,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Tile(
            label: "Absent",
            count: absent,
            background: const Color(0xFFFFEBEE), // light red
            textColor: const Color(0xFFB71C1C),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Tile(
            label: "Leave",
            count: onLeave,
            background: const Color(0xFFFFF9C4), // light yellow
            textColor: const Color(0xFFF57F17),
          ),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.label,
    required this.count,
    required this.background,
    required this.textColor,
  });

  final String label;
  final int count;
  final Color background;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "$count",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// class _AttendanceRow extends StatelessWidget {
//   const _AttendanceRow({
//     required this.statusCounts,
//     required this.totalVehicles,
//   });

//   final Map<_VehicleState, int> statusCounts;
//   final int totalVehicles;

//   @override
//   Widget build(BuildContext context) {
//     final running = statusCounts[_VehicleState.running] ?? 0;
//     final idle = statusCounts[_VehicleState.idle] ?? 0;

//     final present = running + idle;
//     final onLeave = statusCounts[_VehicleState.parked] ?? 0;
//     final absent = statusCounts[_VehicleState.nodata] ?? 0;

//     return Row(
//       children: [
//         Expanded(
//           child: _Tile(
//             label: "Total",
//             count: totalVehicles,
//             background: const Color.fromARGB(255, 241, 255, 221),
//             textColor: Colors.black87,
//           ),
//         ),
//         const SizedBox(width: 8),
//         Expanded(
//           child: _Tile(
//             label: "Present",
//             count: present,
//             background: const Color(0xFFE8F5E9), // light green
//             textColor: _primaryGreen,
//           ),
//         ),
//         const SizedBox(width: 8),
//         Expanded(
//           child: _Tile(
//             label: "Absent",
//             count: absent,
//             background: const Color(0xFFFFEBEE), // light red
//             textColor: const Color(0xFFB71C1C),
//           ),
//         ),
//         const SizedBox(width: 8),
//         Expanded(
//           child: _Tile(
//             label: "Leave",
//             count: onLeave,
//             background: const Color(0xFFFFF9C4), // light yellow
//             textColor: const Color(0xFFF57F17),
//           ),
//         ),
//       ],
//     );
//   }
// }

// class _Tile extends StatelessWidget {
//   const _Tile({
//     required this.label,
//     required this.count,
//     required this.background,
//     required this.textColor,
//   });

//   final String label;
//   final int count;
//   final Color background;
//   final Color textColor;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 20),
//       decoration: BoxDecoration(
//         color: background,
//         borderRadius: BorderRadius.circular(14),
//       ),
//       child: FittedBox(
//         fit: BoxFit.scaleDown,
//         alignment: Alignment.centerLeft,
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               "$count",
//               style: TextStyle(
//                 fontSize: 22,
//                 fontWeight: FontWeight.w800,
//                 color: textColor,
//               ),
//             ),
//             const SizedBox(height: 3),
//             Text(
//               label,
//               style: const TextStyle(
//                 fontSize: 12,
//                 color: Colors.black87,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

class _ActivityAndVehicleRow extends StatelessWidget {
  const _ActivityAndVehicleRow({
    required this.vehicles,
    required this.statusCounts,
    required this.summary,
  });

  final List<VehicleModel> vehicles;
  final Map<_VehicleState, int> statusCounts;
  final WasteSummary? summary;

  @override
  Widget build(BuildContext context) {
    final recent = _RecentActivityCard(
      entries: _buildActivityEntries(vehicles, summary, statusCounts),
    );
    return recent;
  }

  List<_ActivityEntry> _buildActivityEntries(
    List<VehicleModel> vehicles,
    WasteSummary? summary,
    Map<_VehicleState, int> statusCounts,
  ) {
    final running = statusCounts[_VehicleState.running] ?? 0;
    final idle = statusCounts[_VehicleState.idle] ?? 0;
    final latest = vehicles.isNotEmpty ? vehicles.first : null;
    final lastUpdate = latest?.lastUpdated;

    return [
      if (summary != null)
        _ActivityEntry(
          'Waste collected ${summary.totalNetWeight.toStringAsFixed(1)} t',
          'Average ${summary.averageWeightPerTrip.toStringAsFixed(2)} t per trip',
          ActivityTone.success,
        ),
      _ActivityEntry(
        'Active vehicles: ${running + idle}',
        'Running: $running | Idle: $idle',
        ActivityTone.success,
      ),
      _ActivityEntry(
        'Latest update',
        lastUpdate != null
            ? 'Last seen ${_formatRelative(lastUpdate)}'
            : 'Awaiting telemetry',
        lastUpdate != null ? ActivityTone.success : ActivityTone.warning,
      ),
    ];
  }
}

class _WeighbridgeInsights extends StatelessWidget {
  const _WeighbridgeInsights({
    required this.monthSeries,
    required this.rangeSummaries,
    required this.dayTickets,
    required this.vehicleWeights,
  });

  final List<WasteSummary> monthSeries;
  final List<WasteSummary> rangeSummaries;
  final List<DayWiseTicket> dayTickets;
  final List<VehicleWeightReport> vehicleWeights;

  @override
  Widget build(BuildContext context) {
    final NumberFormat weightFormat = NumberFormat.decimalPattern();
    final totalsSource =
        rangeSummaries.isNotEmpty ? rangeSummaries : monthSeries;
    final double mtdNet = totalsSource.fold<double>(
      0,
      (sum, item) => sum + item.totalNetWeight,
    );
    final int mtdTrips = totalsSource.fold<int>(
      0,
      (sum, item) => sum + item.totalTrip,
    );

    final topVehicles = List<VehicleWeightReport>.from(vehicleWeights)
      ..sort((a, b) => b.totalWeight.compareTo(a.totalWeight));
    final latestTickets = dayTickets.take(3).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weighbridge Insights',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'Powered by month/day/vehicle reports',
            style: TextStyle(color: _iconGray, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildMetric(
                icon: Icons.scale_outlined,
                label: 'Net collected',
                value: '${weightFormat.format(mtdNet)} kg',
              ),
              _buildMetric(
                icon: Icons.route_outlined,
                label: 'Trips',
                value: mtdTrips.toString(),
              ),
              if (latestTickets.isNotEmpty)
                _buildMetric(
                  icon: Icons.receipt_long,
                  label: 'Tickets today',
                  value: latestTickets.length.toString(),
                ),
            ],
          ),
          if (topVehicles.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Top vehicles (weight)',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ...topVehicles.take(3).map(
                  (v) => _insightRow(
                    icon: Icons.local_shipping,
                    leading: v.vehicleNo,
                    trailing: '${weightFormat.format(v.totalWeight)} kg',
                  ),
                ),
          ],
          if (latestTickets.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Latest weighbridge tickets',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ...latestTickets.map(
              (t) => _insightRow(
                icon: Icons.receipt_long,
                leading: 'Ticket ${t.ticketNo}',
                trailing: '${weightFormat.format(t.netWeight)} kg',
                subtitle: t.vehicleNo,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetric({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _bgWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderGray),
        boxShadow: _softCardShadow(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _primaryGreen, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: _iconGray,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _insightRow({
    required IconData icon,
    required String leading,
    required String trailing,
    String? subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: _bgWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderGray),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _softGreen.withValues(alpha: 0.35),
            ),
            child: Icon(icon, color: _primaryGreen, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  leading,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: const TextStyle(color: _iconGray, fontSize: 12),
                  ),
              ],
            ),
          ),
          Text(
            trailing,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: _primaryGreen,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard({required this.entries});

  final List<_ActivityEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Activity',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          ...entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(entry.icon, color: entry.color, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          entry.subtitle,
                          style: const TextStyle(
                            fontSize: 13,
                            color: _iconGray,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleStatusCard extends StatelessWidget {
  const _VehicleStatusCard({
    required this.vehicles,
    required this.statusCounts,
  });

  final List<VehicleModel> vehicles;
  final Map<_VehicleState, int> statusCounts;

  @override
  Widget build(BuildContext context) {
    final cards = <_StatusCount>[
      _StatusCount(
        label: 'Running',
        value: statusCounts[_VehicleState.running] ?? 0,
        color: _primaryGreen,
      ),
      _StatusCount(
        label: 'Idle',
        value: statusCounts[_VehicleState.idle] ?? 0,
        color: _softYellow,
      ),
      _StatusCount(
        label: 'Stopped',
        value: statusCounts[_VehicleState.parked] ?? 0,
        color: _softRed,
      ),
      _StatusCount(
        label: 'No Data',
        value: statusCounts[_VehicleState.nodata] ?? 0,
        color: _iconGray,
      ),
    ];

    final highlighted =
        vehicles.isNotEmpty ? vehicles.firstWhere((_) => true) : null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Vehicle Status',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          ...cards.map(
            (item) => Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: item.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Text(
                    item.value.toString(),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: item.color,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (highlighted != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _softBlue.withValues(alpha: 0.4),
                  ),
                  child: const Icon(Icons.local_shipping, color: _primaryGreen),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        highlighted.registrationNumber ??
                            'Vehicle ${highlighted.id}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        highlighted.address ?? 'Live telemetry',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _iconGray, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                _StatusPill(state: _vehicleStateFor(highlighted)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DashboardNavBar extends StatelessWidget {
  const _DashboardNavBar({required this.currentIndex, required this.onChanged});

  final int currentIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: currentIndex,
      onTap: onChanged,
      backgroundColor: Colors.white,
      selectedItemColor: _primaryGreen,
      unselectedItemColor: _iconGray,
      selectedFontSize: 11,
      unselectedFontSize: 11,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
        BottomNavigationBarItem(
            icon: Icon(Icons.assignment_outlined), label: 'Assignments'),
        BottomNavigationBarItem(
            icon: Icon(Icons.fact_check_outlined), label: 'Approvals'),
        BottomNavigationBarItem(
            icon: Icon(Icons.directions_bus_outlined), label: 'Vehicles'),
        BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: 'More'),
      ],
    );
  }
}
// ---------------------------------------------------------------------------
// MAP SCREEN
// ---------------------------------------------------------------------------

class AdminMapScreen extends StatelessWidget {
  const AdminMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Reuse the production map experience (live vehicles, polygons, filters).
    return const citizen_map.MapScreen(showBackButton: false);
  }
}
// ---------------------------------------------------------------------------
// VEHICLES SCREEN
// ---------------------------------------------------------------------------

class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({super.key, required this.vehicleRepository});

  final VehicleRepository vehicleRepository;

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  List<VehicleModel> _vehicles = const [];
  bool _loading = true;
  Object? _error;
  Timer? _poller;
  bool _showList = false;

  @override
  void initState() {
    super.initState();
    _fetchVehicles();
    _poller = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _fetchVehicles(silent: true),
    );
  }

  @override
  void dispose() {
    _poller?.cancel();
    super.dispose();
  }

  Future<void> _fetchVehicles({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final result = await widget.vehicleRepository.fetchAllVehicleLocations();
      if (!mounted) return;
      setState(() {
        _vehicles = result;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _fetchVehicles,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                    children: const [
                      Text(
                        'Unable to load vehicle list.',
                        style: TextStyle(color: _iconGray),
                      ),
                    ],
                  )
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                    children: [
                      const _SectionHeader(
                        title: 'Vehicles',
                        subtitle: 'Live feed from vehicle tracking API',
                      ),
                      const SizedBox(height: 12),
                      _VehicleStatusCard(
                        vehicles: _vehicles,
                        statusCounts: _DashboardData.countByStatus(_vehicles),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            icon: Icon(
                              _showList ? Icons.list_alt : Icons.directions_bus,
                            ),
                            label: Text(
                                _showList ? 'Hide vehicles' : 'All vehicles'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryGreen,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () =>
                                setState(() => _showList = !_showList),
                          ),
                          const SizedBox(width: 12),

                          // 🔽 NEW VIEW MAP BUTTON
                          OutlinedButton.icon(
                            icon: const Icon(Icons.map_outlined),
                            label: const Text('View Map'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _primaryGreen,
                              side: BorderSide(
                                  color: _primaryGreen.withOpacity(0.6)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AdminMapScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_showList)
                        ..._vehicles.map(
                          (vehicle) => _VehicleTile(vehicle: vehicle),
                        ),
                    ],
                  ),
      ),
    );
  }
}

class _VehicleTile extends StatelessWidget {
  const _VehicleTile({required this.vehicle});

  final VehicleModel vehicle;

  @override
  Widget build(BuildContext context) {
    final status = _vehicleStateFor(vehicle);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _softGreen.withValues(alpha: 0.45),
            ),
            child: const Icon(Icons.local_shipping, color: _primaryGreen),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vehicle.registrationNumber ?? 'Vehicle ${vehicle.id}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: _iconGray),
                    const SizedBox(width: 4),
                    Text(
                      _formatRelative(vehicle.lastUpdated),
                      style: const TextStyle(color: _iconGray, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _StatusPill(state: status),
        ],
      ),
    );
  }
}

class _ApprovalRequest {
  const _ApprovalRequest({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.dateLabel,
  });

  final String title;
  final String subtitle;
  final _ApprovalStatus status;
  final String dateLabel;

  Color get color {
    switch (status) {
      case _ApprovalStatus.pending:
        return const Color(0xFFF9A825);
      case _ApprovalStatus.approved:
        return _primaryGreen;
      case _ApprovalStatus.rejected:
        return const Color(0xFFB71C1C);
    }
  }

  IconData get icon {
    switch (status) {
      case _ApprovalStatus.pending:
        return Icons.schedule_outlined;
      case _ApprovalStatus.approved:
        return Icons.check_circle_outline;
      case _ApprovalStatus.rejected:
        return Icons.highlight_off_outlined;
    }
  }

  String get statusLabel {
    switch (status) {
      case _ApprovalStatus.pending:
        return 'Pending';
      case _ApprovalStatus.approved:
        return 'Approved';
      case _ApprovalStatus.rejected:
        return 'Rejected';
    }
  }
}

enum _ApprovalStatus { pending, approved, rejected }

const _mockApprovalRequests = <_ApprovalRequest>[
  _ApprovalRequest(
    title: 'Driver | Arun Menon',
    subtitle: 'Annual leave - 3 days - requested by driver',
    status: _ApprovalStatus.pending,
    dateLabel: 'Dec 12, 2025',
  ),
  _ApprovalRequest(
    title: 'Operator | Lata Fernandes',
    subtitle: 'Sick leave - 1 day - requested by operator',
    status: _ApprovalStatus.approved,
    dateLabel: 'Dec 10, 2025',
  ),
  _ApprovalRequest(
    title: 'Driver | Naveen Pillai',
    subtitle: 'Shift swap fallback - requested by driver',
    status: _ApprovalStatus.rejected,
    dateLabel: 'Dec 08, 2025',
  ),
];

// ---------------------------------------------------------------------------
// APPROVALS SCREEN
// ---------------------------------------------------------------------------

class _ApprovalsScreen extends StatelessWidget {
  const _ApprovalsScreen();

  @override
  Widget build(BuildContext context) {
    final pendingCount = _mockApprovalRequests
        .where((r) => r.status == _ApprovalStatus.pending)
        .length;
    final acceptedCount = _mockApprovalRequests
        .where((r) => r.status == _ApprovalStatus.approved)
        .length;
    final driverCount = _mockApprovalRequests
        .where((r) => r.title.toLowerCase().contains('driver'))
        .length;
    final operatorCount = _mockApprovalRequests
        .where((r) => r.title.toLowerCase().contains('operator'))
        .length;

    final tiles = [
      _ApprovalGridTile(
        title: 'Driver',
        count: driverCount,
        color: _primaryGreen,
        icon: Icons.local_shipping_outlined,
      ),
      _ApprovalGridTile(
        title: 'Operator',
        count: operatorCount,
        color: const Color(0xFF1565C0),
        icon: Icons.support_agent,
      ),
      _ApprovalGridTile(
        title: 'Pending',
        count: pendingCount,
        color: const Color(0xFFF9A825),
        icon: Icons.schedule_outlined,
      ),
      _ApprovalGridTile(
        title: 'Accepted',
        count: acceptedCount,
        color: const Color(0xFF2E7D32),
        icon: Icons.check_circle_outline,
      ),
    ];

    return SafeArea(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(
              title: 'Approvals',
              subtitle: 'Leave approvals from drivers and operators',
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                const spacing = 12.0;
                final width = constraints.maxWidth;
                const columns = 2;
                final tileWidth = (width - spacing * (columns - 1)) / columns;

                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: tiles
                      .map(
                        (tile) => ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: tileWidth,
                            maxWidth: tileWidth,
                          ),
                          child: tile,
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ApprovalGridTile extends StatelessWidget {
  const _ApprovalGridTile({
    required this.title,
    required this.count,
    required this.color,
    required this.icon,
  });

  final String title;
  final int count;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$count',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: _iconGray),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// MORE SCREEN
// ---------------------------------------------------------------------------

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <_MoreItem>[
      _MoreItem(Icons.person_outline, 'Profile'),
      _MoreItem(
        Icons.people_alt_outlined,
        'Staffs',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const StaffManagementScreen(),
            ),
          );
        },
      ),
      _MoreItem(Icons.notifications_none, 'Notifications'),
      _MoreItem(Icons.settings_outlined, 'Settings'),
      _MoreItem(Icons.support_agent, 'Support'),
      _MoreItem(Icons.insert_chart_outlined, 'Weighbridge reports'),
      _MoreItem(Icons.map_outlined, 'Manage sites & geofences'),
      _MoreItem(Icons.security, 'Admin controls'),
      _MoreItem(
        Icons.logout,
        'Logout',
        onTap: () {
          context.read<AuthBloc>().add(AuthLogoutRequested());
          context.go(AppRoutePaths.citizenLogin);
        },
      ),
    ];
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(
              title: 'More',
              subtitle: 'Manage your profile, alerts and support',
            ),
            const SizedBox(height: 12),
            ...items.map(
              (item) => InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: item.onTap,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(18),
                  decoration: _cardDecoration(),
                  child: Row(
                    children: [
                      Icon(item.icon, color: _primaryGreen),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item.label,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: _iconGray),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreItem {
  const _MoreItem(this.icon, this.label, {this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
}

// ---------------------------------------------------------------------------
// HELPERS & MODELS
// ---------------------------------------------------------------------------
class _DashboardData {
  const _DashboardData({
    this.summary,
    this.vehicles = const [],
    this.monthSeries = const [],
    this.dateRangeSummaries = const [],
    this.dayTickets = const [],
    this.vehicleWeights = const [],
    this.assignments = const [],
  });

  const _DashboardData.empty() : this();

  final WasteSummary? summary;
  final List<VehicleModel> vehicles;
  final List<WasteSummary> monthSeries;
  final List<WasteSummary> dateRangeSummaries;
  final List<DayWiseTicket> dayTickets;
  final List<VehicleWeightReport> vehicleWeights;

  // 🔽 NEW
  final List<DailyAssignmentModel> assignments;

  Map<_VehicleState, int> get statusCounts => countByStatus(vehicles);

  static Map<_VehicleState, int> countByStatus(List<VehicleModel> vehicles) {
    final counts = {
      _VehicleState.running: 0,
      _VehicleState.idle: 0,
      _VehicleState.parked: 0,
      _VehicleState.nodata: 0,
    };
    for (final vehicle in vehicles) {
      final state = _vehicleStateFor(vehicle);
      counts[state] = (counts[state] ?? 0) + 1;
    }
    return counts;
  }
}

class _WasteSlice {
  const _WasteSlice(this.label, this.value, this.color);

  final String label;
  final double value;
  final Color color;
}

class _WasteDonutPainter extends CustomPainter {
  const _WasteDonutPainter({required this.slices});

  final List<_WasteSlice> slices;

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold<double>(0, (sum, slice) => sum + slice.value);
    if (total == 0) return;

    const strokeWidth = 22.0;
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    double startAngle = -math.pi / 2;
    for (final slice in slices) {
      final sweepAngle = (slice.value / total) * 2 * math.pi;
      paint.color = slice.color;
      canvas.drawArc(
        rect.deflate(strokeWidth / 2),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _WasteDonutPainter oldDelegate) =>
      oldDelegate.slices != slices;
}

class _StatusCount {
  const _StatusCount({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final int value;
  final Color color;
}

enum _VehicleState { running, idle, parked, nodata }

_VehicleState _vehicleStateFor(VehicleModel vehicle) {
  final raw = vehicle.status?.toLowerCase().trim() ?? '';
  if (raw.contains('run')) return _VehicleState.running;
  if (raw.contains('idle') || raw == 'on') return _VehicleState.idle;
  if (raw.contains('park') || raw.contains('stop') || raw.contains('off')) {
    return _VehicleState.parked;
  }
  return _VehicleState.nodata;
}

Color _vehicleStateColor(_VehicleState state) {
  switch (state) {
    case _VehicleState.running:
      return _primaryGreen;
    case _VehicleState.idle:
      return _softYellow;
    case _VehicleState.parked:
      return _softRed;
    case _VehicleState.nodata:
      return _iconGray;
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.state});

  final _VehicleState state;

  String get _label {
    switch (state) {
      case _VehicleState.running:
        return 'Running';
      case _VehicleState.idle:
        return 'Idle';
      case _VehicleState.parked:
        return 'Stopped';
      case _VehicleState.nodata:
        return 'No Data';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _vehicleStateColor(state).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _vehicleStateColor(state),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _label,
            style: TextStyle(
              color: _vehicleStateColor(state),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityEntry {
  const _ActivityEntry(this.title, this.subtitle, this.tone);

  final String title;
  final String subtitle;
  final ActivityTone tone;

  Color get color => tone == ActivityTone.success ? _primaryGreen : _softYellow;
  IconData get icon => tone == ActivityTone.success
      ? Icons.check_circle_outline
      : Icons.warning_amber_outlined;
}

enum ActivityTone { success, warning }

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: _iconGray),
        ),
      ],
    );
  }
}

String _formatRelative(String? raw) {
  if (raw == null || raw.isEmpty) return 'Just now';
  try {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final now = DateTime.now();
    final difference = now.difference(parsed);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    }
    if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    }
    return '${difference.inDays}d ago';
  } catch (_) {
    return raw;
  }
}

class AssignmentsScreen extends StatefulWidget {
  const AssignmentsScreen({super.key});

  @override
  State<AssignmentsScreen> createState() => _AssignmentsScreenState();
}

class _AssignmentsScreenState extends State<AssignmentsScreen> {
  late final AssignmentRepository _assignmentRepository;

  bool _loading = true;
  bool _historyFiltering = false;
  String? _error;
  bool _didSetInitialTab = false;

  List<DailyAssignmentModel> _currentAssignments = [];
  List<DailyAssignmentModel> _historyAssignments = [];
  List<DailyAssignmentModel> _filteredHistoryAssignments = [];

  DateTime? _historyFromDate;
  DateTime? _historyToDate;
  DateTimeRange? _historyLoadedRange;
  final Set<String> _historyStatusFilters = {};

  static const _historyStatusOptions = [
    _HistoryFilterOption('completed', 'Completed'),
    _HistoryFilterOption('skipped', 'Skipped'),
    _HistoryFilterOption('cancelled', 'Cancelled'),
    _HistoryFilterOption('failed', 'Failed'),
    _HistoryFilterOption('expired', 'Expired'),
  ];

  @override
  void initState() {
    super.initState();
    _assignmentRepository = getIt<AssignmentRepository>();
    _loadAssignments();
  }

  String _assignmentKey(DailyAssignmentModel assignment) {
    if (assignment.uniqueId.isNotEmpty) {
      return assignment.uniqueId;
    }
    return '${assignment.id}::${assignment.date.toIso8601String()}';
  }

  List<DailyAssignmentModel> _dedupeAssignments(
    List<DailyAssignmentModel> assignments,
  ) {
    final map = <String, DailyAssignmentModel>{};
    for (final assignment in assignments) {
      map[_assignmentKey(assignment)] = assignment;
    }
    return map.values.toList();
  }

  DateTime _stripTime(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  DateTimeRange? _resolveHistoryRange() {
    if (_historyFromDate == null && _historyToDate == null) {
      return null;
    }
    final start = _stripTime(_historyFromDate ?? _historyToDate!);
    final end = _stripTime(_historyToDate ?? _historyFromDate!);
    return DateTimeRange(start: start, end: end);
  }

  bool _sameRange(DateTimeRange? a, DateTimeRange? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return a.start == b.start && a.end == b.end;
  }

  List<DailyAssignmentModel> _buildHistoryList(
    List<DailyAssignmentModel> raw,
  ) {
    final currentIds = _currentAssignments.map(_assignmentKey).toSet();
    final history = _dedupeAssignments(raw)
        .where((assignment) => !assignment.isActive)
        .where((assignment) => !currentIds.contains(_assignmentKey(assignment)))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return history;
  }

  Future<void> _loadAssignments({bool showLoader = true}) async {
    if (showLoader) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      _error = null;
    }

    try {
      final results = await Future.wait<List<DailyAssignmentModel>>([
        _assignmentRepository.fetchTodayAssignments(),
        _assignmentRepository.fetchAssignmentHistory(),
      ]);

      final currentRaw = _dedupeAssignments(results[0]);
      final historyRaw = _dedupeAssignments(results[1]);

      final current = currentRaw.where((a) => a.isActive).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

      _currentAssignments = current;
      final history = _buildHistoryList(historyRaw);

      final filteredHistory = _applyHistoryFiltersInternal(history);
      setState(() {
        _currentAssignments = current;
        _historyAssignments = history;
        _filteredHistoryAssignments = filteredHistory;
        _historyLoadedRange = null;
        _loading = false;
        _historyFiltering = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<DailyAssignmentModel> _applyHistoryFiltersInternal(
    List<DailyAssignmentModel> base,
  ) {
    var filtered = base;
    if (_historyStatusFilters.isNotEmpty) {
      filtered = filtered
          .where((assignment) =>
              _historyStatusFilters.contains(assignment.statusKey))
          .toList();
    }
    if (_historyFromDate != null) {
      filtered = filtered
          .where((assignment) => !assignment.date.isBefore(_historyFromDate!))
          .toList();
    }
    if (_historyToDate != null) {
      filtered = filtered
          .where((assignment) => !assignment.date.isAfter(_historyToDate!))
          .toList();
    }
    return filtered;
  }

  Future<void> _applyHistoryFilters({bool showLoader = true}) async {
    if (showLoader) {
      setState(() {
        _historyFiltering = true;
      });
    }

    final targetRange = _resolveHistoryRange();
    if (targetRange != null && !_sameRange(targetRange, _historyLoadedRange)) {
      try {
        final fetched = await _assignmentRepository.fetchAssignmentHistory(
          fromDate: targetRange.start,
          toDate: targetRange.end,
        );
        _historyAssignments = _buildHistoryList(fetched);
        _historyLoadedRange = targetRange;
      } catch (_) {}
    }

    await Future.delayed(const Duration(milliseconds: 120));
    final filtered = _applyHistoryFiltersInternal(_historyAssignments);

    if (!mounted) return;
    setState(() {
      _filteredHistoryAssignments = filtered;
      _historyFiltering = false;
    });
  }

  Future<void> _pickHistoryDate({required bool isFrom}) async {
    final initial = isFrom
        ? (_historyFromDate ?? DateTime.now())
        : (_historyToDate ?? DateTime.now());

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _historyFromDate = picked;
        if (_historyToDate != null && _historyToDate!.isBefore(picked)) {
          _historyToDate = picked;
        }
      } else {
        _historyToDate = picked;
        if (_historyFromDate != null && _historyFromDate!.isAfter(picked)) {
          _historyFromDate = picked;
        }
      }
    });
    await _applyHistoryFilters();
  }

  void _toggleHistoryStatus(String statusKey, bool selected) {
    setState(() {
      if (selected) {
        _historyStatusFilters.add(statusKey);
      } else {
        _historyStatusFilters.remove(statusKey);
      }
    });
    _applyHistoryFilters();
  }

  void _resetHistoryFilters() {
    setState(() {
      _historyStatusFilters.clear();
      _historyFromDate = null;
      _historyToDate = null;
    });
    _loadAssignments(showLoader: false);
  }

  List<TabData> _buildTabs() {
    final tabs = [
      _AssignmentTabSpec(
        key: 'current',
        title: 'Current',
        builder: () => _CurrentAssignmentsTab(
          assignments: _currentAssignments,
          onRefresh: () => _loadAssignments(showLoader: false),
        ),
      ),
      _AssignmentTabSpec(
        key: 'history',
        title: 'History',
        builder: () => _HistoryAssignmentsTab(
          assignments: _filteredHistoryAssignments,
          filtering: _historyFiltering,
          statusFilters: _historyStatusFilters,
          fromDate: _historyFromDate,
          toDate: _historyToDate,
          statusOptions: _historyStatusOptions,
          onStatusToggled: _toggleHistoryStatus,
          onPickFromDate: () => _pickHistoryDate(isFrom: true),
          onPickToDate: () => _pickHistoryDate(isFrom: false),
          onResetFilters: _resetHistoryFilters,
          onRefresh: () => _loadAssignments(showLoader: false),
        ),
      ),
    ];

    return tabs
        .asMap()
        .entries
        .map(
          (entry) => TabData(
            index: entry.key,
            title: Tab(text: entry.value.title),
            content: _KeepAliveTab(child: entry.value.builder()),
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _AssignmentsErrorState(
                    message: _error!,
                    onRetry: () => _loadAssignments(),
                  )
                : Column(
                    children: [
                      _AssignmentsHeader(
                        currentCount: _currentAssignments.length,
                        historyCount: _historyAssignments.length,
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: DynamicTabBarWidget(
                          dynamicTabs: _buildTabs(),
                          onTabControllerUpdated: (controller) {
                            if (!_didSetInitialTab && controller.length > 0) {
                              _didSetInitialTab = true;
                              controller.animateTo(0);
                            }
                          },
                          onTabChanged: (_) =>
                              _loadAssignments(showLoader: false),
                          isScrollable: false,
                          indicatorColor: _primaryGreen,
                          labelColor: _primaryGreen,
                          unselectedLabelColor: _iconGray,
                          labelStyle: const TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                          unselectedLabelStyle: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _AssignmentTabSpec {
  const _AssignmentTabSpec({
    required this.key,
    required this.title,
    required this.builder,
  });

  final String key;
  final String title;
  final Widget Function() builder;
}

class _HistoryFilterOption {
  const _HistoryFilterOption(this.value, this.label);

  final String value;
  final String label;
}

class _AssignmentsHeader extends StatelessWidget {
  const _AssignmentsHeader({
    required this.currentCount,
    required this.historyCount,
  });

  final int currentCount;
  final int historyCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.assignment_outlined,
              color: _primaryGreen,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Assignments',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '$currentCount current • $historyCount history',
                style: const TextStyle(
                  fontSize: 13,
                  color: _iconGray,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AssignmentsErrorState extends StatelessWidget {
  const _AssignmentsErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 52, color: _iconGray),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _KeepAliveTab extends StatefulWidget {
  const _KeepAliveTab({required this.child});

  final Widget child;

  @override
  State<_KeepAliveTab> createState() => _KeepAliveTabState();
}

class _KeepAliveTabState extends State<_KeepAliveTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _AssignmentsEmptyState extends StatelessWidget {
  const _AssignmentsEmptyState({
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42, color: _iconGray),
          const SizedBox(height: 8),
          Text(message),
        ],
      ),
    );
  }
}

class _CurrentAssignmentsTab extends StatelessWidget {
  const _CurrentAssignmentsTab({
    required this.assignments,
    required this.onRefresh,
  });

  final List<DailyAssignmentModel> assignments;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (assignments.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            _AssignmentsEmptyState(
              icon: Icons.pending_actions_outlined,
              message: 'No pending assignments available',
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        itemCount: assignments.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final assignment = assignments[i];
          return _AssignmentCarouselCard(
            assignment: assignment,
            onCancelled: () => onRefresh(),
          );
        },
      ),
    );
  }
}

class _HistoryAssignmentsTab extends StatelessWidget {
  const _HistoryAssignmentsTab({
    required this.assignments,
    required this.filtering,
    required this.statusFilters,
    required this.fromDate,
    required this.toDate,
    required this.statusOptions,
    required this.onStatusToggled,
    required this.onPickFromDate,
    required this.onPickToDate,
    required this.onResetFilters,
    required this.onRefresh,
  });

  final List<DailyAssignmentModel> assignments;
  final bool filtering;
  final Set<String> statusFilters;
  final DateTime? fromDate;
  final DateTime? toDate;
  final List<_HistoryFilterOption> statusOptions;
  final void Function(String, bool) onStatusToggled;
  final VoidCallback onPickFromDate;
  final VoidCallback onPickToDate;
  final VoidCallback onResetFilters;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          _HistoryFilters(
            statusOptions: statusOptions,
            selectedStatuses: statusFilters,
            fromDate: fromDate,
            toDate: toDate,
            onStatusToggled: onStatusToggled,
            onPickFromDate: onPickFromDate,
            onPickToDate: onPickToDate,
            onResetFilters: onResetFilters,
          ),
          if (filtering)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          if (assignments.isEmpty && !filtering)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: _AssignmentsEmptyState(
                icon: Icons.history_toggle_off_outlined,
                message: 'No archived assignments',
              ),
            )
          else
            ...assignments.map(
              (assignment) => Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _AssignmentCarouselCard(
                  assignment: assignment,
                  onCancelled: () => onRefresh(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HistoryFilters extends StatelessWidget {
  const _HistoryFilters({
    required this.statusOptions,
    required this.selectedStatuses,
    required this.fromDate,
    required this.toDate,
    required this.onStatusToggled,
    required this.onPickFromDate,
    required this.onPickToDate,
    required this.onResetFilters,
  });

  final List<_HistoryFilterOption> statusOptions;
  final Set<String> selectedStatuses;
  final DateTime? fromDate;
  final DateTime? toDate;
  final void Function(String, bool) onStatusToggled;
  final VoidCallback onPickFromDate;
  final VoidCallback onPickToDate;
  final VoidCallback onResetFilters;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'History Filters',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: onResetFilters,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Reset',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: statusOptions
                .map(
                  (option) => FilterChip(
                    label: Text(option.label),
                    selected: selectedStatuses.contains(option.value),
                    selectedColor: _primaryGreen.withOpacity(0.15),
                    labelStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    onSelected: (selected) =>
                        onStatusToggled(option.value, selected),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _DateFilterChip(
                label: 'From',
                date: fromDate,
                onTap: onPickFromDate,
              ),
              const SizedBox(width: 8),
              _DateFilterChip(
                label: 'To',
                date: toDate,
                onTap: onPickToDate,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DateFilterChip extends StatelessWidget {
  const _DateFilterChip({
    required this.label,
    required this.date,
    required this.onTap,
  });

  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = date == null ? label : DateFormat('MMM d').format(date!);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: _borderGray),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 12, color: _iconGray),
            const SizedBox(width: 4),
            Text(
              text,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
