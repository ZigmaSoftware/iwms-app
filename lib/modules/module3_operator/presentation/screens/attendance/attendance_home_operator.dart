import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:iwms_citizen_app/core/api_config.dart';
import 'package:iwms_citizen_app/core/env.dart';
import 'package:iwms_citizen_app/core/network/authorized_dio.dart';
import 'package:iwms_citizen_app/core/theme/app_colors.dart';
import 'package:iwms_citizen_app/logic/auth/auth_bloc.dart';
import 'package:iwms_citizen_app/logic/auth/auth_state.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/screens/attendance/attendancehistory.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/screens/attendance/profile.dart';
import 'package:iwms_citizen_app/modules/module3_operator/utils/attendance_blink_store.dart';

import 'camerapage.dart';

// ── Design tokens ─────────────────────────────────────────────────────────
const _kPrimary = AppColors.primary;
const _kBg = Color(0xFFF4F6FA);
const _kSurface = Colors.white;
const _kGreen = Color(0xFF0F8A58);
const _kGreenBg = Color(0xFFE7F6EE);
const _kAmber = Color(0xFFD97706);
const _kAmberBg = Color(0xFFFFF8EB);
const _kTextPri = Color(0xFF0B1F3A);
const _kTextSec = Color(0xFF6B7C93);
const _kBorder = Color(0xFFE8ECF4);

const Duration kTripBlinkInterval = Duration(minutes: 2);
const Duration kTripBlinkDuration = Duration(minutes: 2);
const Duration kTripAttendanceCooldown = Duration(minutes: 1);

// ── Pulse rings painter ───────────────────────────────────────────────────
class _RingsPainter extends CustomPainter {
  const _RingsPainter({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    for (int i = 0; i < 3; i++) {
      final t = (progress + i / 3) % 1.0;
      final radius = size.width * (0.30 + t * 0.22);
      final opacity = (1 - t) * 0.20;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = color.withOpacity(opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2 - t * 1.4,
      );
    }
  }

  @override
  bool shouldRepaint(_RingsPainter o) =>
      progress != o.progress || color != o.color;
}

// ════════════════════════════════════════════════════════════════════════════
// Main Widget
// ════════════════════════════════════════════════════════════════════════════
class AttendancePage extends StatefulWidget {
  const AttendancePage({
    super.key,
    this.operatorName = '',
    this.operatorCode = '',
    this.empId = '',
  });
  final String operatorName;
  final String operatorCode;
  final String empId;

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage>
    with SingleTickerProviderStateMixin {
  // state
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
  DateTime? _lastTripAt;
  late String _time;
  late String _date;
  Timer? _clockTimer;
  Timer? _tripCooldownTimer;
  StreamSubscription? _connectivitySub;
  bool _isOnline = true;
  Duration _worked = Duration.zero;
  List<Map<String, dynamic>> _pendingSync = [];
  bool _tripWindow = false;
  late VoidCallback _blinkCb;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..repeat();
    _updateClock();
    _fetchLocation();
    _checkNet();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((_) async {
      final ok = await _hasInternet();
      if (mounted) setState(() => _isOnline = ok);
    });
    _clockTimer =
        Timer.periodic(const Duration(seconds: 1), (_) => _updateClock());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStatus();
      _loadSummary();
    });
    _blinkCb = () {
      final active = AttendanceBlinkStore.windowNotifier.value;
      if (!mounted) return;
      if (_isCooldown()) {
        if (_tripWindow) setState(() => _tripWindow = false);
        return;
      }
      setState(() => _tripWindow = active);
    };
    AttendanceBlinkStore.windowNotifier.addListener(_blinkCb);
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _tripCooldownTimer?.cancel();
    _connectivitySub?.cancel();
    AttendanceBlinkStore.windowNotifier.removeListener(_blinkCb);
    _pulse.dispose();
    super.dispose();
  }

  void _updateClock() {
    final now = DateTime.now();
    _time = DateFormat('hh:mm a').format(now);
    _date = DateFormat('EEE, dd MMM yyyy').format(now);
    if (mounted) setState(() {});
  }

  String _fmtDur(Duration d) =>
      '${d.inHours.toString().padLeft(2, '0')}:${(d.inMinutes % 60).toString().padLeft(2, '0')}';

  bool _isCooldown() {
    if (_lastTripAt == null) return false;
    return DateTime.now().difference(_lastTripAt!) < kTripAttendanceCooldown;
  }

  Duration _cooldownLeft() {
    if (_lastTripAt == null) return Duration.zero;
    final e = DateTime.now().difference(_lastTripAt!);
    return e >= kTripAttendanceCooldown
        ? Duration.zero
        : kTripAttendanceCooldown - e;
  }

  Future<bool> _hasInternet() async {
    try {
      final r = await InternetAddress.lookup('one.one.one.one')
          .timeout(const Duration(seconds: 2));
      return r.isNotEmpty && r[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _checkNet() async {
    final ok = await _hasInternet();
    if (mounted) setState(() => _isOnline = ok);
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
        _updateBlink();
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
        queryParameters: {'emp_id': id, 'month': now.month, 'year': now.year},
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

  void _updateBlink() {
    final should = _isCheckedIn && !_isCheckedOut;
    _tripCooldownTimer?.cancel();
    if (!should) {
      AttendanceBlinkStore.dispose();
      if (mounted && _tripWindow) setState(() => _tripWindow = false);
      return;
    }
    if (_isCooldown()) {
      AttendanceBlinkStore.dispose();
      if (mounted && _tripWindow) setState(() => _tripWindow = false);
      final rem = _cooldownLeft();
      if (rem > Duration.zero) {
        _tripCooldownTimer = Timer(rem, () {
          if (mounted) _updateBlink();
        });
      }
      return;
    }
    AttendanceBlinkStore.startPeriodicReminder(
      interval: kTripBlinkInterval,
      blinkDuration: kTripBlinkDuration,
      initialDelay: kTripBlinkInterval,
    );
  }

  Future<void> _fetchLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) return;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied)
      perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) return;
    final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    if (mounted)
      setState(() {
        _lat = pos.latitude.toStringAsFixed(5);
        _lng = pos.longitude.toStringAsFixed(5);
      });
  }

  Future<void> _handlePunch({required String name, required String? id}) async {
    if (id == null || id.trim().isEmpty) {
      _snack('Employee ID is missing.');
      return;
    }
    try {
      if (_isCheckedIn && !_isCheckedOut && _tripWindow) {
        final ok = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                  builder: (_) => CameraScreen(
                      employeeName: name,
                      employeeId: id,
                      isTripAttendance: true)),
            ) ??
            false;
        if (ok) {
          _lastTripAt = DateTime.now();
          AttendanceBlinkStore.dispose();
          if (mounted) setState(() => _tripWindow = false);
        }
      } else {
        await Navigator.of(context).push<bool>(
          MaterialPageRoute(
              builder: (_) => CameraScreen(
                  employeeName: name, employeeId: id, isTripAttendance: false)),
        );
      }
      await _loadStatus();
      await _loadSummary();
    } catch (e) {
      if (mounted) _snack('Unable to open camera: $e');
    }
  }

  Future<void> _syncItem(Map<String, dynamic> item) async {
    if (!_isOnline) {
      _snack('No internet.');
      return;
    }
    try {
      final res = await http
          .post(Uri.parse('https://zigma/api/attendance/sync.php'), body: {
        'timestamp': item['timestamp'],
        'lat': item['lat'],
        'long': item['long'],
        'type': item['type']
      });
      final data = jsonDecode(res.body);
      if (!mounted) return;
      if (data['status'] == 'success') {
        _pendingSync.remove(item);
        setState(() {});
        _snack('Synced.');
      } else
        _snack('Sync failed.');
    } catch (_) {
      if (mounted) _snack('Error syncing.');
    }
  }

  void _openHistory(String? id) {
    if (id == null || id.trim().isEmpty) {
      _snack('Employee ID missing.');
      return;
    }
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => AttendanceHistory(empId: id)));
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));

  bool get _hasLoc => _lat != '--';

  Color get _accent {
    if (_tripWindow) return _kAmber;
    if (_isCheckedIn) return _kGreen;
    return _kPrimary;
  }

  Color get _accentBg {
    if (_tripWindow) return _kAmberBg;
    return _kGreenBg;
  }

  IconData get _statusIcon {
    if (_tripWindow) return Icons.notifications_active_rounded;
    if (_isCheckedOut) return Icons.verified_rounded;
    if (_isCheckedIn) return Icons.timelapse_rounded;
    return Icons.fingerprint_rounded;
  }

  String get _statusLabel {
    if (_isStatusLoading) return 'Syncing\u2026';
    if (_tripWindow) return 'Trip reminder';
    if (_isCheckedOut) return 'Day complete';
    if (_isCheckedIn) return 'Checked in';
    return 'Not punched';
  }

  String get _punchLabel {
    if (_tripWindow) return 'Trip Punch';
    if (_isCheckedIn && !_isCheckedOut) return 'Punch Out';
    if (_isCheckedOut) return 'Camera';
    return 'Punch In';
  }

  String get _punchSub {
    if (_tripWindow) return 'Reminder active';
    if (_isCheckedOut) return 'Day complete';
    if (_isCheckedIn) return 'Shift running';
    return 'Tap to begin';
  }

  @override
  Widget build(BuildContext context) {
    final nameAuth = context.select<AuthBloc, String?>((b) =>
        b.state is AuthStateAuthenticated
            ? (b.state as AuthStateAuthenticated).userName
            : null);
    final idAuth = context.select<AuthBloc, String?>((b) =>
        b.state is AuthStateAuthenticated
            ? (b.state as AuthStateAuthenticated).emp_id
            : null);

    final displayName = nameAuth?.trim().isNotEmpty == true
        ? nameAuth!.trim()
        : widget.operatorName.trim().isNotEmpty
            ? widget.operatorName.trim()
            : 'Operator';
    final employeeId = idAuth?.trim().isNotEmpty == true
        ? idAuth!.trim()
        : widget.empId.trim().isNotEmpty
            ? widget.empId.trim()
            : null;
    final opCode = widget.operatorCode.trim().isNotEmpty
        ? widget.operatorCode.trim()
        : (employeeId ?? '\u2014');

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: RefreshIndicator(
          color: _kPrimary,
          onRefresh: () async {
            await _loadStatus();
            await _loadSummary();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            child: Column(
              children: [
                _CompactHeader(
                    name: displayName,
                    opCode: opCode,
                    date: _date,
                    time: _time,
                    isOnline: _isOnline),
                const SizedBox(height: 12),
                _StatusStrip(
                  icon: _statusIcon,
                  label: _statusLabel,
                  accent: _accent,
                  accentBg: _accentBg,
                  isLoading: _isStatusLoading,
                  checkIn: _checkIn,
                  checkOut: _checkOut,
                  worked: _fmtDur(_worked),
                ),
                const SizedBox(height: 12),
                _PunchCard(
                  pulse: _pulse,
                  punchLabel: _punchLabel,
                  punchSub: _punchSub,
                  accent: _accent,
                  isPressed: _punchPressed,
                  isTripActive: _tripWindow,
                  onDown: () => setState(() => _punchPressed = true),
                  onUp: () => setState(() => _punchPressed = false),
                  onCancel: () => setState(() => _punchPressed = false),
                  onTap: () => _handlePunch(name: displayName, id: employeeId),
                ),
                const SizedBox(height: 12),
                _SummaryCard(
                  present: _presentDays,
                  leave: _leaveDays,
                  perm: _permDays,
                  hasLoc: _hasLoc,
                  lat: _lat,
                  lng: _lng,
                  onHistory: () => _openHistory(employeeId),
                ),
                if (_pendingSync.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _PendingSyncCard(items: _pendingSync, onSync: _syncItem),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactHeader extends StatelessWidget {
  const _CompactHeader({
    required this.name,
    required this.opCode,
    required this.date,
    required this.time,
    required this.isOnline,
  });

  final String name;
  final String opCode;
  final String date;
  final String time;
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D3B26), Color(0xFF175E3C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D3B26).withOpacity(0.22),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: name + online chip
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar initials
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'O',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'ID: $opCode',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              // Online chip
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isOnline
                      ? Colors.white.withOpacity(0.14)
                      : Colors.red.shade400.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withOpacity(0.15)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            isOnline ? const Color(0xFF7EF59F) : Colors.white,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isOnline ? 'Online' : 'Offline',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Row 2: date pill + live time
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today_rounded,
                        size: 12, color: Colors.white.withOpacity(0.7)),
                    const SizedBox(width: 6),
                    Text(
                      date,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600),
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
                    letterSpacing: 0.5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── _StatusStrip ──────────────────────────────────────────────────────────
/// Compact card: status badge + IN/OUT/Worked three cells in one row.
class _StatusStrip extends StatelessWidget {
  const _StatusStrip({
    required this.icon,
    required this.label,
    required this.accent,
    required this.accentBg,
    required this.isLoading,
    required this.checkIn,
    required this.checkOut,
    required this.worked,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final Color accentBg;
  final bool isLoading;
  final String checkIn;
  final String checkOut;
  final String worked;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBorder, width: 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 14,
              offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        children: [
          // Status row
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                    color: accentBg, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 17, color: accent),
              ),
              const SizedBox(width: 10),
              Text(label,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: accent)),
              const Spacer(),
              if (isLoading)
                SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: accent)),
            ],
          ),
          const SizedBox(height: 12),
          // Timeline row
          Row(
            children: [
              _TimeCell(label: 'Check In', value: checkIn, color: _kGreen),
              _Vline(),
              _TimeCell(label: 'Check Out', value: checkOut, color: _kAmber),
              _Vline(),
              _TimeCell(label: 'Worked', value: worked, color: _kTextPri),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimeCell extends StatelessWidget {
  const _TimeCell(
      {required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10.5,
                  color: _kTextSec,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}

class _Vline extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
      width: 1,
      height: 32,
      color: _kBorder,
      margin: const EdgeInsets.symmetric(horizontal: 4));
}

class DriverAvatar extends StatefulWidget {
  final String empId;
  const DriverAvatar({super.key, required this.empId});

  @override
  State<DriverAvatar> createState() => _DriverAvatarState();
}

class _DriverAvatarState extends State<DriverAvatar> {
  bool hasProfile = false;
  bool imageLoading = true;
  String? imageName;

  @override
  void initState() {
    super.initState();
    fetchEmployeeImage();
  }

  Future<void> fetchEmployeeImage() async {
    try {
      final dio = await authorizedDio();
      final response = await dio.get(
        '${ApiConfig.desktopBase}staff-profile/',
        queryParameters: {'staff_id_id': widget.empId},
      );
      final json = response.data;

      if (json["status"] == "success") {
        setState(() {
          imageName = json["data"]["photo"] ?? "";
          hasProfile = imageName != null && imageName!.isNotEmpty;
          imageLoading = false;
        });
      } else {
        setState(() {
          hasProfile = false;
          imageLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        hasProfile = false;
        imageLoading = false;
      });
    }
  }

  String convertToUrl(String path) {
    final clean = path.replaceAll("\\", "/");
    return "$kOperatorProfileBaseUrl/media/$clean";
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProfilePage(empId: widget.empId),
          ),
        );
        fetchEmployeeImage();
      },
      child: CircleAvatar(
        radius: 30,
        backgroundColor: Colors.white,
        backgroundImage: (hasProfile && imageName != null)
            ? NetworkImage(convertToUrl(imageName!))
            : null,
        child: imageLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.green,
                ),
              )
            : (!hasProfile)
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.person_add_alt_1,
                          size: 26, color: Colors.green),
                      SizedBox(height: 2),
                      Text(
                        "Register",
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  )
                : null,
      ),
    );
  }
}

// ── _PunchCard ────────────────────────────────────────────────────────────
class _PunchCard extends StatelessWidget {
  const _PunchCard({
    required this.pulse,
    required this.punchLabel,
    required this.punchSub,
    required this.accent,
    required this.isPressed,
    required this.isTripActive,
    required this.onDown,
    required this.onUp,
    required this.onCancel,
    required this.onTap,
  });

  final AnimationController pulse;
  final String punchLabel;
  final String punchSub;
  final Color accent;
  final bool isPressed;
  final bool isTripActive;
  final VoidCallback onDown;
  final VoidCallback onUp;
  final VoidCallback onCancel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 6))
        ],
      ),
      child: Column(
        children: [
          // Punch label above button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                punchLabel,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800, color: accent),
              ),
              if (isTripActive)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: _kAmberBg, borderRadius: BorderRadius.circular(8)),
                  child: const Text('TRIP',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _kAmber,
                          letterSpacing: 1)),
                ),
            ],
          ),
          const SizedBox(height: 18),

          // Pulse + button
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
                    painter:
                        _RingsPainter(progress: pulse.value, color: accent),
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
                      child: Container(
                        width: 148,
                        height: 148,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [accent, accent.withOpacity(0.75)],
                          ),
                          boxShadow: [
                            BoxShadow(
                                color: accent.withOpacity(0.30),
                                blurRadius: 28,
                                offset: const Offset(0, 12)),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.18),
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.fingerprint_rounded,
                                  size: 24, color: Colors.white),
                            ),
                            const SizedBox(height: 10),
                            Text(punchLabel,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 2),
                            Text(punchSub,
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.72),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Trip reminder notice (only when trip active)
          if (isTripActive) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                  color: _kAmberBg, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Icon(Icons.notifications_active_rounded,
                      color: _kAmber, size: 16),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Trip reminder active — tap to capture.',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _kAmber),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── _SummaryCard ──────────────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.present,
    required this.leave,
    required this.perm,
    required this.hasLoc,
    required this.lat,
    required this.lng,
    required this.onHistory,
  });

  final int present;
  final int leave;
  final int perm;
  final bool hasLoc;
  final String lat;
  final String lng;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 14,
              offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              const Text('This month',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _kTextPri)),
              const Spacer(),
              GestureDetector(
                onTap: onHistory,
                child: Row(
                  children: [
                    const Icon(Icons.history_rounded,
                        size: 15, color: _kTextSec),
                    const SizedBox(width: 4),
                    Text('History',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _kPrimary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Three metric tiles
          Row(
            children: [
              _MetricTile(
                  label: 'Present',
                  value: '$present',
                  color: _kGreen,
                  icon: Icons.event_available_rounded),
              const SizedBox(width: 10),
              _MetricTile(
                  label: 'Leave',
                  value: '$leave',
                  color: _kAmber,
                  icon: Icons.event_busy_rounded),
              const SizedBox(width: 10),
              _MetricTile(
                  label: 'Permission',
                  value: '$perm',
                  color: _kPrimary,
                  icon: Icons.verified_user_outlined),
            ],
          ),
          const SizedBox(height: 12),

          // Location row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F6FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  hasLoc
                      ? Icons.my_location_rounded
                      : Icons.location_searching_rounded,
                  size: 15,
                  color: hasLoc ? _kGreen : _kTextSec,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasLoc ? 'Lat $lat, Lng $lng' : 'Fetching location\u2026',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: hasLoc ? _kTextPri : _kTextSec,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile(
      {required this.label,
      required this.value,
      required this.color,
      required this.icon});
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: color,
                    height: 1)),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _kTextSec)),
          ],
        ),
      ),
    );
  }
}

// ── _PendingSyncCard ──────────────────────────────────────────────────────
class _PendingSyncCard extends StatelessWidget {
  const _PendingSyncCard({required this.items, required this.onSync});
  final List<Map<String, dynamic>> items;
  final void Function(Map<String, dynamic>) onSync;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 14,
              offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                    color: const Color(0xFFFFF4E8),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.sync_problem_rounded,
                    color: Color(0xFFCE7A13), size: 17),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Pending sync',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _kTextPri)),
              ),
              Text('${items.length} items',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _kTextSec)),
            ],
          ),
          ...items
              .map((item) => _SyncTile(item: item, onTap: () => onSync(item))),
        ],
      ),
    );
  }
}

class _SyncTile extends StatelessWidget {
  const _SyncTile({required this.item, required this.onTap});
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF4E8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFFD9AE)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['type']?.toString() ?? 'Pending',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _kTextPri)),
                  const SizedBox(height: 2),
                  Text(item['timestamp']?.toString() ?? '--',
                      style: const TextStyle(
                          fontSize: 11,
                          color: _kTextSec,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: Color(0xFFCE7A13), size: 18),
          ],
        ),
      ),
    );
  }
}
