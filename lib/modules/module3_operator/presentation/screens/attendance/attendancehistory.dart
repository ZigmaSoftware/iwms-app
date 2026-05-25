import 'package:flutter_map/flutter_map.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:iwms_citizen_app/core/api_config.dart';
import 'package:iwms_citizen_app/core/env.dart';
import 'package:iwms_citizen_app/core/network/authorized_dio.dart';

class AttendanceDetailPage extends StatefulWidget {
  final Map<String, dynamic> record;
  final DateTime selectedDate;

  const AttendanceDetailPage({
    super.key,
    required this.record,
    required this.selectedDate,
  });

  @override
  State<AttendanceDetailPage> createState() => _AttendanceDetailPageState();
}

class _AttendanceDetailPageState extends State<AttendanceDetailPage> {
  String checkInLocation = "Fetching location...";
  String checkOutLocation = "Fetching location...";
  late final LatLng checkInLatLng;
  late final LatLng checkOutLatLng;
  late final LatLng mapCenter;
  String? checkInResolved;
  String? checkOutResolved;

  @override
  // void initState() {
  //   super.initState();
  //   _fetchLocation();
  // }
  @override
  void initState() {
    super.initState();

    final inLat =
        double.tryParse(widget.record['check_in_latitude'] ?? '0.0') ?? 0.0;
    final inLon =
        double.tryParse(widget.record['check_in_longitude'] ?? '0.0') ?? 0.0;
    final outLat =
        double.tryParse(widget.record['check_out_latitude'] ?? '0.0') ?? 0.0;
    final outLon =
        double.tryParse(widget.record['check_out_longitude'] ?? '0.0') ?? 0.0;

    checkInLatLng = LatLng(inLat, inLon);
    checkOutLatLng = LatLng(outLat, outLon);

    if (inLat != 0 && outLat != 0) {
      // Center between two points
      mapCenter = LatLng((inLat + outLat) / 2, (inLon + outLon) / 2);
    } else {
      mapCenter = inLat != 0 ? checkInLatLng : checkOutLatLng;
    }

    _fetchLocation();
    _resolveImages();
  }

  Future<void> _resolveImages() async {
    final rawCheckIn = (widget.record['check_in_image'] ?? '').replaceAll(
      "\\",
      "/",
    );
    final rawCheckOut = (widget.record['check_out_image'] ?? '').replaceAll(
      "\\",
      "/",
    );

    checkInResolved = await resolveAttendanceImage(rawCheckIn);
    checkOutResolved = await resolveAttendanceImage(rawCheckOut);

    setState(() {});
  }

  Future<String?> resolveAttendanceImage(String rawPath) async {
    if (rawPath.isEmpty) return null;

    final normalizedPath = rawPath.replaceAll("\\", "/");
    if (normalizedPath.startsWith("http://") ||
        normalizedPath.startsWith("https://")) {
      return normalizedPath;
    }

    if (normalizedPath.startsWith("/media/")) {
      return "$kOperatorProfileBaseUrl$normalizedPath";
    }

    if (normalizedPath.startsWith("media/")) {
      return "$kOperatorProfileBaseUrl/$normalizedPath";
    }

    return "$kOperatorProfileBaseUrl/$normalizedPath";
  }

  Future<void> _fetchLocation() async {
    await _fetchSingleLocation(
      double.tryParse(widget.record['check_in_latitude'] ?? '0') ?? 0.0,
      double.tryParse(widget.record['check_in_longitude'] ?? '0') ?? 0.0,
      isCheckIn: true,
    );
    await _fetchSingleLocation(
      double.tryParse(widget.record['check_out_latitude'] ?? '0') ?? 0.0,
      double.tryParse(widget.record['check_out_longitude'] ?? '0') ?? 0.0,
      isCheckIn: false,
    );
  }

  Future<void> _fetchSingleLocation(
    double lat,
    double lon, {
    required bool isCheckIn,
  }) async {
    if (lat == 0.0 && lon == 0.0) {
      setState(() {
        if (isCheckIn) {
          checkInLocation = "Location not available";
        } else {
          checkOutLocation = "Location not available";
        }
      });
      return;
    }

    final url =
        "https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon";

    try {
      final response = await http.get(Uri.parse(url));
      final jsonData = json.decode(response.body);
      final address = jsonData['address'];

      final formatted = address != null
          ? "${address['suburb'] ?? ''} ${address['city'] ?? ''}".trim()
          : jsonData['display_name'] ?? 'Unknown';

      setState(() {
        if (isCheckIn) {
          checkInLocation = formatted;
        } else {
          checkOutLocation = formatted;
        }
      });
    } catch (e) {
      print("Location fetch error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = widget.selectedDate;

    return SafeArea(
      child: Scaffold(
        backgroundColor: Color(0xFFF6F7FB),
        body: Column(
          children: [
            // ===========================
            // 🌍 MAP SECTION (40% Height)
            // ===========================
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.40,
              child: Stack(
                children: [
                  FlutterMap(
                    options: MapOptions(
                      initialCenter: mapCenter,
                      initialZoom: 15,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.none,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                        subdomains: ['a', 'b', 'c'],
                      ),

                      // ======================
                      // MARKERS WITH OUTLINE
                      // ======================
                      MarkerLayer(
                        markers: [
                          if (checkInLatLng.latitude != 0)
                            Marker(
                              point: checkInLatLng,
                              width: 60,
                              height: 60,
                              child: _buildMarkerCircle(),
                            ),
                          if (checkOutLatLng.latitude != 0)
                            Marker(
                              point: checkOutLatLng,
                              width: 60,
                              height: 60,
                              child: _buildMarkerCircle(),
                            ),
                        ],
                      ),
                    ],
                  ),

                  // ======================
                  // HEADER OVERLAY
                  // ======================
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: EdgeInsets.fromLTRB(12, 12, 12, 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFF1B5E20),
                            Color(0xFF1B5E20),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 8,
                            color: Colors.black26,
                          )
                        ],
                      ),
                      child: Row(
                        children: [
                          InkWell(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.arrow_back,
                                  color: Colors.white, size: 18),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            "Attendance Summary",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 12),

            // ==========================
            // LOCATION INFO BOX – Glass
            // ==========================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Color(0xFF1B5E20),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 10,
                      color: Colors.black12,
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _infoText("PUNCH IN", checkInLocation),
                    SizedBox(height: 6),
                    _infoText("PUNCH OUT", checkOutLocation),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            // ==========================
            // DATE DISPLAY
            // ==========================
            Text(
              DateFormat("dd MMMM yyyy | EEEE")
                  .format(selectedDate)
                  .toUpperCase(),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                letterSpacing: 0.5,
                color: Colors.grey[800],
              ),
            ),

            SizedBox(height: 20),

            // ==========================
            // CLOCK IN / OUT ROW
            // ==========================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildClockCard("Clock In",
                    widget.record['check_in_time'] ?? "--:--", checkInResolved),
                _buildClockCard(
                    "Clock Out",
                    widget.record['check_out_time'] ?? "--:--",
                    checkOutResolved),
              ],
            ),
          ],
        ),
      ),
    );
  }

// =============================
// STYLISH PUNCH CARD UI
// =============================
  Widget _buildClockCard(String title, String time, String? imgUrl) {
    return Container(
      width: 130,
      padding: EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.grey.shade200,
            backgroundImage: imgUrl != null
                ? NetworkImage(imgUrl)
                : AssetImage("assets/images/default_user.png") as ImageProvider,
          ),
          SizedBox(height: 10),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
          Text(
            time,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1B5E20),
            ),
          )
        ],
      ),
    );
  }

// =============================
// MARKER AVATAR STYLE
// =============================
  Widget _buildMarkerCircle() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: CircleAvatar(
        radius: 28,
        backgroundImage: AssetImage("assets/images/image.png"),
      ),
    );
  }

// =============================
// TEXT BLOCK (Punch IN/OUT info)
// =============================
  Widget _infoText(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 11,
            letterSpacing: 1,
          ),
        ),
        SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildClockBox(String label, String time, String? imgUrl) {
    return SizedBox(
      height: 120,
      child: Column(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundImage: imgUrl != null
                ? NetworkImage(imgUrl)
                : const AssetImage('assets/images/default_user.png')
                    as ImageProvider,
          ),
          const SizedBox(height: 8),
          Text(
            label.toUpperCase(),
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          Text(
            time,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class AttendanceHistory extends StatefulWidget {
  final String empId;
  const AttendanceHistory({super.key, required this.empId});

  @override
  State<AttendanceHistory> createState() => _AttendanceHistoryState();
}

class _AttendanceHistoryState extends State<AttendanceHistory> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  DateTime? _selectedDay;
  RangeSelectionMode _rangeSelectionMode = RangeSelectionMode.toggledOn;

  Map<DateTime, Map<String, String>> attendanceMap = {};
  Map<DateTime, String> holidayMap = {};
  bool isLoading = false;
  bool _isValidAttendance(Map<String, String> data) {
    return (data['in'] != null && data['in']!.trim().isNotEmpty) ||
        (data['out'] != null && data['out']!.trim().isNotEmpty);
  }

  DateTime normalizeDate(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  @override
  void initState() {
    super.initState();
    fetchAttendanceData();
  }

  Future<void> fetchHolidays() async {
    final url = Uri.parse(
      "https://zigmaglobal.in/zigma_desk_app_updated/getholidays.php",
    );

    try {
      final response = await http.post(url, body: {
        'zigma_id': widget.empId,
        'from_date': DateFormat('yyyy-MM-01').format(_focusedDay),
        'to_date': DateFormat('yyyy-MM-dd')
            .format(DateTime(_focusedDay.year, _focusedDay.month + 1, 0)),
      });

      final data = json.decode(response.body);

      if (data['status'] == 'success') {
        for (var item in data['data']) {
          if (item['date'] != null) {
            final rawDate = DateFormat("d MMM y").parse(item['date']);
            final date = normalizeDate(rawDate);

            holidayMap[date] = item['reason'] ?? item['status'] ?? 'Holiday';
          }
        }
        setState(() {});
      }
    } catch (e) {
      print("❌ Error fetching holidays: $e");
    }
  }

  Future<void> fetchAttendanceData() async {
    setState(() => isLoading = true);

    try {
      final dio = await authorizedDio();
      final response = await dio.get(
        '${ApiConfig.desktopBase}attendance-list/',
        queryParameters: {
          'emp_id': widget.empId,
          'month': _focusedDay.month,
          'year': _focusedDay.year,
        },
      );
      final data = response.data;

      if (data is Map && data['records'] != null && data['records'] is List) {
        // ✅ Typed correctly
        Map<DateTime, Map<String, String>> parsed = {};

        for (var item in data['records']) {
          final raw =
              DateFormat("dd/MMMM/yyyy", "en_US").parseStrict(item['date']);
          final date = DateTime(raw.year, raw.month, raw.day);

          // ✅ FORCE everything to String and type the map
          final Map<String, String> mapEntry = {
            "in": (item['in_time'] ?? '').toString(),
            "out": (item['out_time'] ?? '').toString(),
            "check_in_latitude": (item['in_latitude'] ?? '').toString(),
            "check_in_longitude": (item['in_longitude'] ?? '').toString(),
            "check_out_latitude": (item['out_latitude'] ?? '').toString(),
            "check_out_longitude": (item['out_longitude'] ?? '').toString(),
            "check_in_image": ((item['in_image_path'] ?? '').toString())
                .replaceAll("\\", "/"),
            "check_out_image": ((item['out_image_path'] ?? '').toString())
                .replaceAll("\\", "/"),
            "total_worked_time":
                (item['total_worked_time'] ?? '00:00').toString(),
            "day_status": (item['day_status'] ?? '').toString(),
          };

          // ✅ Now this matches Map<String, String>
          parsed[date] = mapEntry;
        }

        setState(() {
          attendanceMap = parsed;
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      print("❌ API Error: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchLeavePermissionTickets() async {
    final url = Uri.parse(
        "https://zigmaglobal.in/zigma_desk_app_updated/get_leave_status.php");

    final response = await http.post(url, body: {
      'zigma_id': widget.empId,
      'from_date': DateFormat('yyyy-MM-01').format(_focusedDay),
      'to_date': DateFormat('yyyy-MM-dd')
          .format(DateTime(_focusedDay.year, _focusedDay.month + 1, 0)),
    });

    final data = json.decode(response.body);

    if (data['status'] == 'success') {
      for (var item in data['data']) {
        final rawDate = DateFormat("d MMM y").parse(item['date']);
        final date = normalizeDate(rawDate);

        attendanceMap[date] ??= {};

        if (item['type'] == "Permission") {
          attendanceMap[date]!['permission'] = item['status'];
          attendanceMap[date]!['reason'] = item['reason'] ?? '';
        } else {
          attendanceMap[date]!['leave'] = item['status'];
          attendanceMap[date]!['leave_type'] = item['type'];
          attendanceMap[date]!['reason'] = item['reason'] ?? '';
        }
      }
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> details = [];

    if (_rangeStart != null) {
      final start = _rangeStart!;
      final end = _rangeEnd ?? _rangeStart!;

      final days = List.generate(
        end.difference(start).inDays + 1,
        (i) => start.add(Duration(days: i)),
      );

      // for (final day in days) {
      //   final data = attendanceMap[normalizeDate(day)];

      //  if (_isValidAttendance(data!)) {
      //     details.add(_buildDetailCard(day, data));
      //   } else {
      //     details.add(_buildAbsentCard(day));
      //   }
      // }
      for (final day in days) {
        final date = normalizeDate(day);
        final data = attendanceMap[date] ?? {};

        if (_isValidAttendance(data)) {
          details.add(_buildDetailCard(day, data));
        } else {
          details.add(_buildAbsentCard(day));
        }
      }
    }

    return SafeArea(
      child: Scaffold(
        backgroundColor: Color(0xFFF5F6FA),
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(52),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF4CAF50),
                  Color(0xFF66BB6A),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12.withOpacity(0.15),
                  blurRadius: 6,
                ),
              ],
            ),
            child: AppBar(
              backgroundColor: Color(0xFF1B5E20),
              elevation: 0,
              centerTitle: true,
              title: Text(
                "Attendance History",
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  children: [
                    SizedBox(
                      height: 5,
                    ),

                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      margin: EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12.withOpacity(0.06),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 10,
                        runSpacing: 4,
                        children: [
                          _legendItem(Color(0xFF72D58A), "Present"),
                          _legendItem(Color(0xFFF8C74A), "Half Day"),
                          _legendItem(Color(0xFFBF4040), "Half Leave"),
                          _legendItem(Color(0xFFF55D6B), "Absent"),
                          _legendItem(Color(0xFF6294BA), "Permission"),
                          _legendItem(Color(0xFFFD05AE), "Holiday"),
                        ],
                      ),
                    ),

                    // --------------------------------------------------
                    // ⭐ TRENDY NEW CALENDAR UI
                    // --------------------------------------------------
                    Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12.withOpacity(0.06),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TableCalendar(
                        focusedDay: _focusedDay,
                        firstDay: DateTime(2020),
                        lastDay: DateTime(
                            DateTime.now().year, DateTime.now().month + 1, 0),
                        calendarFormat: CalendarFormat.month,
                        rangeStartDay: _rangeStart,
                        rangeEndDay: _rangeEnd,
                        rangeSelectionMode: _rangeSelectionMode,
                        selectedDayPredicate: (d) => isSameDay(_selectedDay, d),

                        // --------------------------------------------------
                        // 🔷 MODERN HEADER
                        // --------------------------------------------------
                        headerStyle: HeaderStyle(
                          titleCentered: true,
                          titleTextStyle: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                          formatButtonVisible: false,
                          leftChevronIcon:
                              Icon(Icons.chevron_left_rounded, size: 22),
                          rightChevronIcon:
                              Icon(Icons.chevron_right_rounded, size: 22),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFF1B5E20),
                                Color(0xFF66BB6A),
                                // Color(0xFF4CAF50),
                                // Color(0xFF66BB6A),
                              ],
                            ),
                            borderRadius:
                                BorderRadius.vertical(top: Radius.circular(10)),
                          ),
                          headerPadding: EdgeInsets.symmetric(vertical: 5),
                          leftChevronMargin: EdgeInsets.only(left: 8),
                          rightChevronMargin: EdgeInsets.only(right: 8),
                        ),

                        // --------------------------------------------------
                        // WEEKDAY STYLING
                        // --------------------------------------------------
                        daysOfWeekStyle: DaysOfWeekStyle(
                          weekdayStyle: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                          weekendStyle: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.redAccent,
                          ),
                        ),

                        // --------------------------------------------------
                        // DAY CELLS (Modern)
                        // --------------------------------------------------
                        calendarStyle: CalendarStyle(
                          outsideDaysVisible: false,
                          defaultTextStyle: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          todayDecoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          selectedDecoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFF4CAF50),
                                Color(0xFF66BB6A),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          cellMargin: EdgeInsets.all(4),
                          cellPadding: EdgeInsets.symmetric(vertical: 4),
                        ),

                        // --------------------------------------------------
                        // CUSTOM MARKERS (Pill Style Under Date)
                        // --------------------------------------------------
                        calendarBuilders: CalendarBuilders(
                          markerBuilder: (context, date, events) {
                            final normalized = normalizeDate(date);

                            final weekday = date.weekday;
                            final isSunday = weekday == DateTime.sunday;
                            final isHoliday =
                                holidayMap.containsKey(normalized);
                            final isPresent =
                                attendanceMap.containsKey(normalized);
                            final isLeave =
                                attendanceMap[normalized]?['leave'] != null;
                            final isPermission = attendanceMap[normalized]
                                    ?['permission'] !=
                                null;
                            final dayStatus =
                                attendanceMap[normalized]?['day_status'] ?? '';

                            Color bgColor;

                            if (isHoliday) {
                              bgColor = Color(0xFFFD05AE);
                            } else if (isLeave && dayStatus == 'Half Day')
                              bgColor = Color(0xFFBF4040);
                            else if (isLeave || dayStatus == 'Absent')
                              bgColor = Color(0xFFF55D6B);
                            else if (isPermission && isPresent)
                              bgColor = Color(0xFFBF4040);
                            else if (isPermission)
                              bgColor = Color(0xFF6294BA);
                            else if (isPresent) {
                              if (dayStatus == 'Full Day') {
                                bgColor = Color(0xFF72D58A);
                              } else if (dayStatus == 'Half Day')
                                bgColor = Color(0xFFF8C74A);
                              else if (dayStatus == 'Short Hours')
                                bgColor = Color(0xFF5DA1F5);
                              else
                                bgColor = Colors.grey.shade600;
                            } else if (isSunday)
                              bgColor = Color(0xFF6294BA);
                            else
                              bgColor = Colors.transparent;

                            return Positioned(
                              bottom: 6,
                              child: Container(
                                width: 22,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: bgColor,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            );
                          },
                        ),

                        // --------------------------------------------------
                        // CALLBACKS
                        // --------------------------------------------------
                        onDaySelected: onDaySelected,
                        onRangeSelected: onRangeSelected,
                        onPageChanged: onPageChanged,
                      ),
                    ),

                    SizedBox(height: 6),

                    // --------------------------------------------------
                    // LIST OF DAILY RECORD CARDS
                    // --------------------------------------------------
                    // ListView(children: details),
                    ...details,
                  ],
                ),
              ),
      ),
    );
  }

  Widget _kpi(String label, String value, Color color) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.fiber_manual_record, size: 14, color: color),
        ),
        SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.black87),
        ),
      ],
    );
  }

  Widget _legendItem(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(fontSize: 11, color: Colors.black87),
        ),
      ],
    );
  }

  Widget _buildDetailCard(DateTime date, Map<String, String> data) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AttendanceDetailPage(
              record: {
                'check_in_latitude': data['check_in_latitude'],
                'check_in_longitude': data['check_in_longitude'],
                'check_out_latitude': data['check_out_latitude'],
                'check_out_longitude': data['check_out_longitude'],
                'check_in_time': data['in'],
                'check_out_time': data['out'],
                'check_in_image': data['check_in_image'],
                'check_out_image': data['check_out_image'],
              },
              selectedDate: date,
            ),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black12.withOpacity(0.06),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Date block
            Container(
              padding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    DateFormat('dd').format(date),
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                  Text(
                    DateFormat('EEE').format(date).toUpperCase(),
                    style: TextStyle(color: Colors.white70, fontSize: 10),
                  ),
                ],
              ),
            ),

            SizedBox(width: 14),

            // Times
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _infoColumn("In", data['in'] ?? '--'),
                  _infoColumn("Out", data['out'] ?? '--'),
                  _infoColumn("Hours", data['total_worked_time'] ?? '--'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _countPresent() {
    int count = 0;
    attendanceMap.forEach((date, data) {
      final status = data['day_status'] ?? '';
      final hasLeave = data['leave'] != null;
      final hasPermission = data['permission'] != null;
      final isHoliday =
          holidayMap.containsKey(date) || date.weekday == DateTime.sunday;

      // Present = has a valid day_status and is not leave/permission/holiday/absent-only
      if (!hasLeave &&
          !hasPermission &&
          !isHoliday &&
          status.isNotEmpty &&
          status != 'Absent') {
        count++;
      }
    });
    return count;
  }

  int _countAbsent() {
    int count = 0;
    attendanceMap.forEach((date, data) {
      final status = data['day_status'] ?? '';
      final hasLeave = data['leave'] != null;
      final hasPermission = data['permission'] != null;
      final isHoliday =
          holidayMap.containsKey(date) || date.weekday == DateTime.sunday;

      // Absent = explicit Absent with no mapped leave/permission and not holiday
      if (status == 'Absent' && !hasLeave && !hasPermission && !isHoliday) {
        count++;
      }
    });
    return count;
  }

  int _countLeave() {
    int count = 0;
    attendanceMap.forEach((date, data) {
      if (data['leave'] != null) {
        count++;
      }
    });
    return count;
  }

  int _countPermission() {
    int count = 0;
    attendanceMap.forEach((date, data) {
      if (data['permission'] != null) {
        count++;
      }
    });
    return count;
  }

  Widget _infoColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[700])),
      ],
    );
  }

  Widget _buildAbsentCard(DateTime date) {
    final leaveStatus = attendanceMap[date]?['leave'];
    final leaveType = attendanceMap[date]?['leave_type'];
    final permissionStatus = attendanceMap[date]?['permission'];
    final holidayName = holidayMap[date];
    final status = attendanceMap[date]?['day_status'];

    String statusText = "Absent";
    Color statusColor = Colors.redAccent;

    if (status != null && status.isNotEmpty) {
      statusText = status;
      if (status == 'Full Day') statusColor = Colors.green;
      if (status == 'Half Day') statusColor = Colors.orange;
      if (status == 'Short Hours') statusColor = Colors.blueGrey;
    }

    if (leaveStatus != null) {
      statusText = "$leaveType Leave ($leaveStatus)";
      statusColor = Colors.orange;
    } else if (permissionStatus != null) {
      statusText = "Permission ($permissionStatus)";
      statusColor = Colors.blue;
    } else if (holidayName != null) {
      statusText = "Holiday ($holidayName)";
      statusColor = Colors.purple;
    } else if (date.weekday == DateTime.sunday) {
      statusText = "Sunday (Holiday)";
      statusColor = Colors.grey;
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  DateFormat('dd').format(date),
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  DateFormat('EEE').format(date).toUpperCase(),
                  style: TextStyle(fontSize: 10),
                ),
              ],
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              statusText,
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildBottomInfoSheet(Map<String, String> info) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            info['leave'] != null
                ? "Leave (${info['leave_type']}) - ${info['leave']}"
                : "Permission - ${info['permission']}",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 8),
          if (info['reason']?.isNotEmpty ?? false)
            Text("Reason: ${info['reason']}"),
          if (info['time']?.isNotEmpty ?? false) Text("Time: ${info['time']}"),
          if (info['submittedAt']?.isNotEmpty ?? false)
            Text("Submitted: ${info['submittedAt']}"),
        ],
      ),
    );
  }

  void onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
      _rangeStart = selectedDay;
      _rangeEnd = selectedDay;
      _rangeSelectionMode = RangeSelectionMode.toggledOff;
    });

    final data = attendanceMap[normalizeDate(selectedDay)];

    if (data != null && (data['leave'] != null || data['permission'] != null)) {
      showModalBottomSheet(
        context: context,
        builder: (_) => buildBottomInfoSheet(data),
      );
    }
  }

  void onRangeSelected(DateTime? start, DateTime? end, DateTime focusedDay) {
    setState(() {
      _rangeStart = start;
      _rangeEnd = end;
      _focusedDay = focusedDay;
      _rangeSelectionMode = RangeSelectionMode.toggledOn;
    });
  }

  void onPageChanged(DateTime focusedDay) {
    setState(() {
      _focusedDay = focusedDay;
      _rangeSelectionMode = RangeSelectionMode.toggledOn;
    });

    fetchAttendanceData();
    fetchLeavePermissionTickets();
    fetchHolidays();
  }
}
