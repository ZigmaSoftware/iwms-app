import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import 'package:iwms_citizen_app/core/api_config.dart';
import 'package:iwms_citizen_app/core/network/authorized_dio.dart';
import 'package:iwms_citizen_app/logic/auth/auth_bloc.dart';
import 'package:iwms_citizen_app/logic/auth/auth_state.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/screens/attendance/attendancehistory.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/screens/attendance/camerapage.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/presentation/screens/attendance/supervisor_face_register.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/presentation/widgets/supervisor_visuals.dart';

// Driver attendance palette, reused here so supervisor attendance matches the
// same blue theme instead of the older purple supervisor palette.
const _kPrimary = Color.fromARGB(255, 20, 34, 74);
const _kPrimaryDeep = Color.fromARGB(255, 22, 35, 96);
const _kBg = Color(0xFFF7F9FF);
const _kSurface = Colors.white;
const _kSuccess = _kPrimary;
const _kSuccessBg = Color(0xFFE8EEFF);
const _kAmber = Color(0xFFD97706);
const _kDanger = Color(0xFFDC2626);
const _kTextPri = Color(0xFF0B1F3A);
const _kTextSec = Color(0xFF6B7C93);
const _kBorder = Color(0xFFE8ECF4);
const _kHairline = Color(0xFFDCE3EF);

/// Supervisor self-attendance — a face-recognition punch screen that mirrors
/// the driver attendance layout (compact header, status strip, big punch
/// button, summary) but re-skinned in the supervisor palette with liquid-glass
/// surfaces (frosted cards + a glassmorphism punch button).
///
/// Registration (enrolling the supervisor's face) and punch (matching against
/// the enrolled face) both hit the shared, role-agnostic mobile endpoints:
///   • POST  {base}register/           — enroll face
///   • POST  {base}recognize/          — punch IN/OUT (via [CameraScreen])
///   • GET   {base}attendance-list/today/    — today's check-in / out
///   • GET   {base}attendance-list/summary/  — month presence / leave counts
class SupervisorAttendancePage extends StatefulWidget {
  const SupervisorAttendancePage({
    super.key,
    this.name = '',
    this.empId = '',
  });

  final String name;
  final String empId;

  @override
  State<SupervisorAttendancePage> createState() =>
      _SupervisorAttendancePageState();
}

class _SupervisorAttendancePageState extends State<SupervisorAttendancePage>
    with SingleTickerProviderStateMixin {
  bool _punchPressed = false;
  String _lat = '--';
  String _lng = '--';
  String _checkIn = '--:--';
  String _checkOut = '--:--';
  bool _isCheckedIn = false;
  bool _isCheckedOut = false;
  bool _isStatusLoading = false;
  int _presentDays = 0;
  int _leaveDays = 0;
  int _permDays = 0;
  bool _recordsLoading = false;
  List<Map<String, dynamic>> _records = [];
  late String _time;
  late String _date;
  Timer? _clockTimer;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _updateClock();
    _fetchLocation();

    _clockTimer =
        Timer.periodic(const Duration(seconds: 1), (_) => _updateClock());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStatus();
      _loadSummary();
      _loadRecords();
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  void _updateClock() {
    final now = DateTime.now();
    _time = DateFormat('hh:mm a').format(now);
    _date = DateFormat('EEE, dd MMM yyyy').format(now);
    if (mounted) setState(() {});
  }

  String? _staffId() {
    final auth = context.read<AuthBloc>().state;
    if (auth is AuthStateAuthenticated) {
      final id = auth.emp_id?.trim();
      if (id != null && id.isNotEmpty) return id;
    }
    final fb = widget.empId.trim();
    return fb.isNotEmpty ? fb : null;
  }

  Future<void> _loadStatus() async {
    final id = _staffId();
    if (id == null) return;

    setState(() => _isStatusLoading = true);

    try {
      final dio = await authorizedDio();
      final res = await dio.get(
        '${ApiConfig.desktopBase}attendance-list/today/',
        queryParameters: {'emp_id': id},
      );

      final data = res.data;
      if (data is Map && data['status'] == 'success' && mounted) {
        setState(() {
          _checkIn = (data['check_in_time'] ?? '--:--').toString();
          _checkOut = (data['check_out_time'] ?? '--:--').toString();
          _isCheckedIn = data['checked_in'] == true;
          _isCheckedOut = data['checked_out'] == true;
          _isStatusLoading = false;
        });
        return;
      }
    } catch (_) {}

    if (mounted) setState(() => _isStatusLoading = false);
  }

  Future<void> _loadSummary() async {
    final id = _staffId();
    if (id == null) return;

    try {
      final now = DateTime.now();
      final dio = await authorizedDio();
      final res = await dio.get(
        '${ApiConfig.desktopBase}attendance-list/summary/',
        queryParameters: {
          'emp_id': id,
          'month': now.month,
          'year': now.year,
        },
      );

      final data = res.data;
      if (data is Map && data['status'] == 'success' && mounted) {
        setState(() {
          _presentDays = (data['present_days'] ?? 0) as int;
          _leaveDays = (data['leave_days'] ?? 0) as int;
          _permDays = (data['permission_days'] ?? 0) as int;
        });
      }
    } catch (_) {}
  }

  /// Loads this month's recognized attendance records (app_recognized) for the
  /// current supervisor via the attendance-list `list` action.
  Future<void> _loadRecords() async {
    final id = _staffId();
    if (id == null) return;

    setState(() => _recordsLoading = true);
    try {
      final now = DateTime.now();
      final dio = await authorizedDio();
      final res = await dio.get(
        '${ApiConfig.desktopBase}attendance-list/',
        queryParameters: {
          'emp_id': id,
          'month': now.month,
          'year': now.year,
        },
      );
      final data = res.data;
      if (data is Map &&
          data['status'] == 'success' &&
          data['records'] is List &&
          mounted) {
        setState(() {
          _records = (data['records'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          _recordsLoading = false;
        });
        return;
      }
    } catch (_) {}
    if (mounted) setState(() => _recordsLoading = false);
  }

  Future<void> _fetchLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) return;

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return;
    }

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    if (mounted) {
      setState(() {
        _lat = pos.latitude.toStringAsFixed(5);
        _lng = pos.longitude.toStringAsFixed(5);
      });
    }
  }

  Future<void> _handlePunch({
    required String name,
    required String? id,
  }) async {
    if (id == null || id.trim().isEmpty) {
      _snack('Employee ID is missing.');
      return;
    }

    try {
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => CameraScreen(
            employeeName: name,
            employeeId: id,
            isTripAttendance: false,
          ),
        ),
      );
      await _loadStatus();
      await _loadSummary();
      await _loadRecords();
    } catch (e) {
      if (mounted) _snack('Unable to open camera: $e');
    }
  }

  Future<void> _registerFace({
    required String name,
    required String? id,
  }) async {
    if (id == null || id.trim().isEmpty) {
      _snack('Employee ID is missing.');
      return;
    }
    final registered = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SupervisorFaceRegisterScreen(
          employeeName: name,
          employeeId: id,
        ),
      ),
    );
    if (registered == true && mounted) {
      _snack('Face registered — you can now punch attendance.');
    }
  }

  void _openHistory(String? id) {
    if (id == null || id.trim().isEmpty) {
      _snack('Employee ID missing.');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AttendanceHistory(empId: id)),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  bool get _hasLoc => _lat != '--';

  IconData get _statusIcon {
    if (_isCheckedOut) return Icons.verified_rounded;
    if (_isCheckedIn) return Icons.timelapse_rounded;
    return Icons.fingerprint_rounded;
  }

  String get _statusLabel {
    if (_isStatusLoading) return 'Syncing…';
    if (_isCheckedOut) return 'Day complete';
    if (_isCheckedIn) return 'Checked in';
    return 'Not punched';
  }

  String get _punchLabel {
    if (_isCheckedIn && !_isCheckedOut) return 'Punch Out';
    if (_isCheckedOut) return 'Punch';
    return 'Punch In';
  }

  String get _punchSub {
    if (_isCheckedOut) return 'Day complete';
    if (_isCheckedIn) return 'Shift running';
    return 'Tap to begin';
  }

  @override
  Widget build(BuildContext context) {
    final nameAuth = context.select<AuthBloc, String?>(
      (b) => b.state is AuthStateAuthenticated
          ? (b.state as AuthStateAuthenticated).userName
          : null,
    );
    final idAuth = context.select<AuthBloc, String?>(
      (b) => b.state is AuthStateAuthenticated
          ? (b.state as AuthStateAuthenticated).emp_id
          : null,
    );

    final displayName = nameAuth?.trim().isNotEmpty == true
        ? nameAuth!.trim()
        : widget.name.trim().isNotEmpty
            ? widget.name.trim()
            : 'Supervisor';

    final employeeId = idAuth?.trim().isNotEmpty == true
        ? idAuth!.trim()
        : widget.empId.trim().isNotEmpty
            ? widget.empId.trim()
            : null;

    final staffCode = employeeId ?? '—';

    return Container(
      color: _kBg,
      child: SupervisorPatternBackground(
        child: RefreshIndicator(
          color: _kPrimary,
          onRefresh: () async {
            await _loadStatus();
            await _loadSummary();
            await _loadRecords();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 140),
            child: Column(
              children: [
                _Header(
                  name: displayName,
                  code: staffCode,
                  date: _date,
                  time: _time,
                ),
                const SizedBox(height: 12),
                _StatusStrip(
                  icon: _statusIcon,
                  label: _statusLabel,
                  isLoading: _isStatusLoading,
                  checkIn: _checkIn,
                  checkOut: _checkOut,
                ),
                const SizedBox(height: 14),
                _GlassPunchCard(
                  pulse: _pulse,
                  punchLabel: _punchLabel,
                  punchSub: _punchSub,
                  isPressed: _punchPressed,
                  onDown: () => setState(() => _punchPressed = true),
                  onUp: () => setState(() => _punchPressed = false),
                  onCancel: () => setState(() => _punchPressed = false),
                  onTap: () => _handlePunch(name: displayName, id: employeeId),
                ),
                const SizedBox(height: 14),
                _SummaryCard(
                  present: _presentDays,
                  leave: _leaveDays,
                  perm: _permDays,
                  hasLoc: _hasLoc,
                  lat: _lat,
                  lng: _lng,
                  onRegister: () =>
                      _registerFace(name: displayName, id: employeeId),
                  onHistory: () => _openHistory(employeeId),
                ),
                const SizedBox(height: 14),
                _RecordsCard(
                  records: _records,
                  loading: _recordsLoading,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Recognized attendance records (app_recognized) — this month
// ─────────────────────────────────────────────────────────────────────────────

class _RecordsCard extends StatelessWidget {
  const _RecordsCard({required this.records, required this.loading});

  final List<Map<String, dynamic>> records;
  final bool loading;

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return _kSuccess;
      case 'pending out':
        return _kAmber;
      default:
        return _kDanger;
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Glass(
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_note_rounded, size: 18, color: _kPrimary),
              const SizedBox(width: 8),
              const Text(
                'This month',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _kTextPri,
                ),
              ),
              const Spacer(),
              if (loading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: _kPrimary),
                )
              else
                Text(
                  '${records.length} day(s)',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: _kTextSec,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (!loading && records.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text(
                'No attendance records yet this month.',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: _kTextSec,
                ),
              ),
            )
          else
            ...records.take(12).map((r) {
              final date = (r['date'] ?? '').toString();
              final inTime = (r['in_time'] ?? '--').toString();
              final outTime = (r['out_time'] ?? '--').toString();
              final status = (r['day_status'] ?? '').toString();
              final color = _statusColor(status);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration:
                          BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        date,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: _kTextPri,
                        ),
                      ),
                    ),
                    Text(
                      'IN $inTime',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: _kSuccess,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'OUT $outTime',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: _kAmber,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Glass helper
// ─────────────────────────────────────────────────────────────────────────────

/// A frosted glass surface: blurs whatever scrolls beneath, washed with a
/// faint white gradient and a hairline border. Used for every card here so the
/// supervisor attendance screen reads as one glass system.
class _Glass extends StatelessWidget {
  const _Glass({
    required this.child,
    this.radius = 22,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: _kSurface.withValues(alpha: 0.62),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: _kSurface.withValues(alpha: 0.7),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _kPrimary.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.code,
    required this.date,
    required this.time,
  });

  final String name;
  final String code;
  final String date;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_kPrimary, _kPrimaryDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _kPrimary.withValues(alpha: 0.24),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'S',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'ID: $code',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _kPrimaryDeep.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Attendance',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 12,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      date,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                time,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status strip
// ─────────────────────────────────────────────────────────────────────────────

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({
    required this.icon,
    required this.label,
    required this.isLoading,
    required this.checkIn,
    required this.checkOut,
  });

  final IconData icon;
  final String label;
  final bool isLoading;
  final String checkIn;
  final String checkOut;

  @override
  Widget build(BuildContext context) {
    return _Glass(
      radius: 20,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _kSuccessBg.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 17, color: _kPrimary),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: _kPrimary,
                ),
              ),
              const Spacer(),
              if (isLoading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _kPrimary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _TimeCell(
                label: 'Check In',
                value: checkIn,
                color: _kSuccess,
              ),
              _vline(),
              _TimeCell(
                label: 'Check Out',
                value: checkOut,
                color: _kAmber,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _vline() => Container(
        width: 1,
        height: 32,
        color: _kHairline.withValues(alpha: 0.5),
        margin: const EdgeInsets.symmetric(horizontal: 4),
      );
}

class _TimeCell extends StatelessWidget {
  const _TimeCell({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              color: _kTextSec,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Punch card — glassmorphism button
// ─────────────────────────────────────────────────────────────────────────────

class _GlassPunchCard extends StatelessWidget {
  const _GlassPunchCard({
    required this.pulse,
    required this.punchLabel,
    required this.punchSub,
    required this.isPressed,
    required this.onDown,
    required this.onUp,
    required this.onCancel,
    required this.onTap,
  });

  final AnimationController pulse;
  final String punchLabel;
  final String punchSub;
  final bool isPressed;
  final VoidCallback onDown;
  final VoidCallback onUp;
  final VoidCallback onCancel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Glass(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                punchLabel,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _kPrimary,
                ),
              ),
              const Spacer(),
              const Icon(Icons.face_retouching_natural_rounded,
                  size: 18, color: _kTextSec),
              const SizedBox(width: 6),
              const Text(
                'Face punch',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: _kTextSec,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 210,
            width: double.infinity,
            child: AnimatedBuilder(
              animation: pulse,
              builder: (_, __) => Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size.square(200),
                    painter: _RingsPainter(
                      progress: pulse.value,
                      color: _kPrimary,
                    ),
                  ),
                  GestureDetector(
                    onTapDown: (_) => onDown(),
                    onTapUp: (_) => onUp(),
                    onTapCancel: onCancel,
                    onTap: onTap,
                    child: AnimatedScale(
                      scale: isPressed ? 0.94 : 1.0,
                      duration: const Duration(milliseconds: 120),
                      curve: Curves.easeOut,
                      child: _GlassPunchButton(
                        label: punchLabel,
                        sub: punchSub,
                      ),
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

/// The frosted circular punch button — a real glassmorphism control: a blurred
/// translucent disc washed with the accent, a bright rim, an inner glow, and
/// the fingerprint glyph.
class _GlassPunchButton extends StatelessWidget {
  const _GlassPunchButton({required this.label, required this.sub});

  final String label;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: 156,
          height: 156,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _kPrimary.withValues(alpha: 0.92),
                _kPrimaryDeep.withValues(alpha: 0.82),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.55),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _kPrimary.withValues(alpha: 0.35),
                blurRadius: 26,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.fingerprint_rounded,
                color: Colors.white,
                size: 44,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                sub,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.88),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  const _RingsPainter({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    for (int i = 0; i < 3; i++) {
      final t = (progress + i / 3) % 1.0;
      final radius = size.width * (0.32 + t * 0.22);
      final opacity = (1 - t) * 0.22;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = color.withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2 - t * 1.4,
      );
    }
  }

  @override
  bool shouldRepaint(_RingsPainter o) =>
      progress != o.progress || color != o.color;
}

// ─────────────────────────────────────────────────────────────────────────────
// Summary card
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.present,
    required this.leave,
    required this.perm,
    required this.hasLoc,
    required this.lat,
    required this.lng,
    required this.onRegister,
    required this.onHistory,
  });

  final int present;
  final int leave;
  final int perm;
  final bool hasLoc;
  final String lat;
  final String lng;
  final VoidCallback onRegister;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    return _Glass(
      radius: 22,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  title: 'Presence',
                  value: '$present',
                  icon: Icons.calendar_month_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStat(
                  title: 'Leaves',
                  value: '$leave',
                  icon: Icons.event_busy_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStat(
                  title: 'Permission',
                  value: '$perm',
                  icon: Icons.badge_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _kBorder.withValues(alpha: 0.85),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on_rounded,
                    color: _kPrimary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasLoc ? 'Lat: $lat  •  Lng: $lng' : 'Location unavailable',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: _kTextSec,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ActionBtn(
                  title: 'Register Face',
                  icon: Icons.face_retouching_natural_rounded,
                  filled: true,
                  onTap: onRegister,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionBtn(
                  title: 'History',
                  icon: Icons.history_rounded,
                  filled: false,
                  onTap: onHistory,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _kBorder.withValues(alpha: 0.85),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: _kPrimary, size: 18),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _kTextPri,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: _kTextSec,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.title,
    required this.icon,
    required this.filled,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = filled ? _kPrimary : Colors.white;
    final fg = filled ? Colors.white : _kPrimary;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _kPrimary.withValues(alpha: 0.22),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
