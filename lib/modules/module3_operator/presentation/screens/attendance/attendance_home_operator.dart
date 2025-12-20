import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:animated_neumorphic/animated_neumorphic.dart';
import 'package:iwms_citizen_app/logic/auth/auth_bloc.dart';
import 'package:iwms_citizen_app/logic/auth/auth_state.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart'; // Import geolocator package
import 'package:http/http.dart' as http;
import 'package:iwms_citizen_app/core/theme/app_text_styles.dart';
import 'package:iwms_citizen_app/core/theme/app_colors.dart';
import 'package:iwms_citizen_app/modules/module3_operator/presentation/screens/attendance/attendancehistory.dart';
// import 'package:zigma_payroll/attendance/userimage.dart';

// import '../provider/username.dart';
import 'camerapage.dart';

const Color _operatorPrimary = AppColors.primary;
const Color _operatorAccent = AppColors.primaryVariant;

class AttendancePage extends StatefulWidget {
  const AttendancePage({
    super.key,
    this.operatorName = '',
    this.operatorCode = '',
    this.emp_id='',
  });

  final String operatorName;
  final String operatorCode;
  final String emp_id;
  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  final bool _isElevated = false;
  bool _punchPressed = false;

  String greetingMessage = "";
  late String buttonText = "Mark for Today";
  final bool _isActive = false;
  String _latitude = '--';
  String _longitude = '--';
  DateTime? _checkInTime;
  DateTime? _checkOutTime;
  late String _time;
  late String _date;
  Timer? _timer; // Declare a Timer variable
  Timer? _clockTimer;
  StreamSubscription<ConnectivityResult>? _connectivitySub;
  bool _isOnline = true;

  Duration _totalWorkingHours = Duration.zero;
  String? imageName;
  bool isLoading = true;
  List<Map<String, dynamic>> _pendingSync = [];

  // Helper method to format duration
  String _formatDuration(Duration duration) {
    int hours = duration.inHours;
    int minutes = duration.inMinutes % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }




  @override
  void initState() {
    super.initState();
    _fetchLocation();

    _checkInternetInitial();

    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen((ConnectivityResult result) async {
      final hasInternet = await _hasInternet();
      if (!mounted) return;
      setState(() => _isOnline = hasInternet);
    });
    _clockTimer =
        Timer.periodic(const Duration(seconds: 1), (Timer t) => _getTime());
    _updateTimeAndDate();
    // fetchAndSetImage();
    // _fetchAttendanceData();
    _timer = Timer.periodic(const Duration(minutes: 1), (Timer timer) {
      // _fetchAttendanceData();
    });
   
    _pendingSync = [
      {
        "type": "Check In",
        "timestamp": "2025-01-20 09:15 AM",
        "lat": "11.0205",
        "long": "76.9760",
      },
      {
        "type": "Check Out",
        "timestamp": "2025-01-20 05:45 PM",
        "lat": "11.0210",
        "long": "76.9781",
      },
    ];
  }

  void _checkInternetInitial() async {
    final hasNet = await _hasInternet();
    if (!mounted) return;
    setState(() {
      _isOnline = hasNet;
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _timer?.cancel();
    _connectivitySub?.cancel();
    super.dispose();
  }

  Future<bool> _hasInternet() async {
    try {
      final result = await InternetAddress.lookup('one.one.one.one')
          .timeout(Duration(seconds: 2));

      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void _updateTimeAndDate() {
    final now = DateTime.now();
    _time = DateFormat('hh:mm a').format(now); // Format time as 09:00 AM
    _date = DateFormat('MMMM dd, yyyy - EEEE')
        .format(now); // Format date as Jan 13, 2025 - Monday
    if (!mounted) return;
    setState(() {}); // Update the UI
  }

  void _getTime() {
    final DateTime now = DateTime.now();
    final String formattedDateTime = _formatDateTime(now);
    if (!mounted) return;
    setState(() {
      _time = formattedDateTime;
    });
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('hh:mm a').format(dateTime);
  }

  Future<void> _fetchLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enable location services.")),
      );
      return;
    }

    // Check for location permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Location permission is required.")),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are permanently denied
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Location permissions are permanently denied.")),
      );
      return;
    }

    // Get the current location
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    if (!mounted) return;
    setState(() {
      _latitude = position.latitude.toString();
      _longitude = position.longitude.toString();
    });
    print(_latitude);
  }

  Future<bool> _onWillPop() async {
    return (await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Are you sure?'),
            content: const Text('Do you want to exit the app?'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => exit(0),
                child: const Text('Yes'),
              ),
            ],
          ),
        )) ??
        false;
  }

  Widget _networkStatusChip() {
    final bool online = _isOnline;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: online ? Colors.green.shade500 : Colors.red.shade600,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(Icons.circle, color: Colors.white, size: 10),
          const SizedBox(width: 6),
          Text(
            online ? "Online" : "Offline",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pendingSyncTile(Map<String, dynamic> item) {
    return GestureDetector(
      onTap: () => _syncItem(item),
      child: Container(
        margin: EdgeInsets.only(bottom: 10),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item["type"],
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(item["timestamp"],
                    style: TextStyle(fontSize: 13, color: Colors.grey)),
              ],
            ),
            Icon(Icons.sync, color: Colors.orange),
          ],
        ),
      ),
    );
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

    return SafeArea(
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              // ===========================
              //        HEADER CARD
              // ===========================
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 26),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      _operatorPrimary,
                      _operatorAccent,
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(35),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Attendance",
                      style: AppTextStyles.heading2.copyWith(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Manage today's presence and history",
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              // Text(emp_idFromState!),
              SizedBox(height: 15),


              Container(
                margin: EdgeInsets.symmetric(horizontal: 20),
                padding: EdgeInsets.symmetric(vertical: 22, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 12,
                      spreadRadius: 2,
                      color: Colors.black12.withOpacity(0.07),
                      offset: Offset(0, 4),
                    )
                  ],
                ),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _kpiItem(Icons.calendar_today, "20", "Presence"),
                      _kpiItem(Icons.timer_off_rounded, "3", "Leaves"),
                      _kpiItem(Icons.access_time_filled, "2", "Permission"),
                    ]),
              ),

              SizedBox(height: 20),

              // ===========================
              //     CHECK-IN OUT CARD
              // ===========================
              Container(
                padding: EdgeInsets.all(22),
                margin: EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 8,
                      color: Colors.black12,
                      offset: Offset(0, 3),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('dd MMMM yyyy').format(DateTime.now()),
                      style: AppTextStyles.heading2.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _checkBox(
                          title: "Check In",
                          time: _checkInTime != null
                              ? "${_checkInTime!.hour}:${_checkInTime!.minute.toString().padLeft(2, '0')}"
                              : "--:--",
                          color: Colors.green,
                        ),
                        _checkBox(
                          title: "Check Out",
                          time: _checkOutTime != null
                              ? "${_checkOutTime!.hour}:${_checkOutTime!.minute.toString().padLeft(2, '0')}"
                              : "--:--",
                          color: Colors.orange,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _quickAction(Icons.logout, "Leave"),
                  _quickAction(Icons.place, "Visit"),
                  _quickAction(Icons.timer, "Overtime"),
                  _quickAction(Icons.history, "History", onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AttendanceHistory(empId: emp_idFromState!),
                      ),
                    );
                  }),
                  _quickAction(Icons.summarize_rounded, "Summary", onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AttendanceHistory(empId: emp_idFromState!),
                      ),
                    );
                  }),
                ],
              ),

              SizedBox(height: 25),

              GestureDetector(
                onTapDown: (_) => setState(() => _punchPressed = true),
                onTapUp: (_) => setState(() => _punchPressed = false),
                onTapCancel: () => setState(() => _punchPressed = false),
                onTap: () async {
                  try {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CameraScreen(
                          employeeName: nameFromState!,
                          employeeId: emp_idFromState!,
                        ),
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Unable to open camera: $e')),
                    );
                  }
                },
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  padding: EdgeInsets.all(18),
                  margin: EdgeInsets.symmetric(horizontal: 24),
                  height: 90,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.green.shade700, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.2),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.fingerprint,
                          size: 40, color: Colors.green.shade800),
                      SizedBox(width: 12),
                      Text(
                        "Punch Attendance",
                        style: AppTextStyles.heading2.copyWith(
                          color: _operatorPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

 

              SizedBox(height: 25),

              if (_pendingSync.isNotEmpty)
                Container(
                  width: double.infinity,
                  margin: EdgeInsets.symmetric(horizontal: 20),
                  padding: EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 6,
                        offset: Offset(0, 3),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Pending Sync",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.deepOrange,
                            ),
                          ),
                           Text(
                            "${emp_idFromState}",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.deepOrange,
                            ),
                          ),
                          Icon(Icons.sync_problem, color: Colors.deepOrange),
                        ],
                      ),
                      SizedBox(height: 10),
                      ..._pendingSync
                          .map((item) => _pendingSyncTile(item))
                          .toList(),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _syncItem(Map<String, dynamic> item) async {
    if (!_isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No internet. Cannot sync.")),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse("https://zigma/api/attendance/sync.php"),
        body: {
          "timestamp": item["timestamp"],
          "lat": item["lat"],
          "long": item["long"],
          "type": item["type"],
        },
      );

      final data = jsonDecode(response.body);

      if (data["status"] == "success") {
        _pendingSync.remove(item);
        setState(() {});

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Synced successfully.")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Sync failed.")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error syncing.")),
      );
    }
  }

  /// CHECK IN / OUT BOX
  Widget _checkBox(
      {required String title, required String time, required Color color}) {
    return Container(
      width: 130,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(time,
              style: TextStyle(
                  fontSize: 26, fontWeight: FontWeight.bold, color: color)),
          SizedBox(height: 6),
          Text(title,
              style: TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  /// QUICK ACTION ICON
  Widget _quickAction(IconData icon, String title, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          Container(
            height: 52,
            width: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  blurRadius: 8,
                  color: Colors.black12,
                )
              ],
            ),
            child: Icon(icon, size: 24, color: Color(0xFF1B5E20)),
          ),
          SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _kpiItem(IconData icon, String value, String title) {
    return Column(
      children: [
        // Container(
        //   padding: EdgeInsets.all(10),
        //   decoration: BoxDecoration(
        //     color: color.withOpacity(0.12),
        //     shape: BoxShape.circle,
        //   ),
        //   child: Icon(icon, color: color, size: 22),
        // ),
        // SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 2),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.black54,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}