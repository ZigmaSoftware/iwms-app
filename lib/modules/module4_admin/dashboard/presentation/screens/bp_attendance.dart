import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

const Color darkGreen = Color(0xFF0B5D1E);

class AttendanceRecord {
  final String empId;
  final String name;
  final String capturedImagePath;
  final String latitude;
  final String longitude;
  final String recognitionDate;
  final int recognitionTime;
  final String records;
  final double similarityScore;
  final String locationName;

  AttendanceRecord({
    required this.empId,
    required this.name,
    required this.locationName,
    required this.capturedImagePath,
    required this.latitude,
    required this.longitude,
    required this.recognitionDate,
    required this.recognitionTime,
    required this.records,
    required this.similarityScore,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      empId: json['emp_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      capturedImagePath: json['captured_image_path']?.toString() ?? '',
      latitude: json['latitude']?.toString() ?? '',
      longitude: json['longitude']?.toString() ?? '',
      locationName: json['location_name']?.toString() ??
          json['location']?.toString() ??
          json['address']?.toString() ??
          '',
      recognitionDate: json['recognition_date']?.toString() ?? '',
      recognitionTime:
          int.tryParse(json['recognition_time']?.toString() ?? '0') ?? 0,
      records: json['records']?.toString() ?? '',
      similarityScore:
          double.tryParse(json['similarity_score']?.toString() ?? '0') ?? 0.0,
    );
  }

  String get imageUrl {
    if (capturedImagePath.isEmpty) return '';

    final cleanPath = capturedImagePath.replaceAll('\\', '/');

    return 'http://zigfly.in:5001/$cleanPath';
  }

  DateTime? get recordDateTime {
    return DateTime.tryParse(records);
  }
}

class AttendanceSummary {
  final String empId;
  final String name;
  final AttendanceRecord checkIn;
  final AttendanceRecord checkOut;

  AttendanceSummary({
    required this.empId,
    required this.name,
    required this.checkIn,
    required this.checkOut,
  });

  bool get hasCheckOut {
    return checkIn.records != checkOut.records;
  }

  Duration get totalDuration {
    final inTime = checkIn.recordDateTime;
    final outTime = checkOut.recordDateTime;

    if (inTime == null || outTime == null || !hasCheckOut) {
      return Duration.zero;
    }

    return outTime.difference(inTime);
  }
}

class AttendanceApiService {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'http://zigfly.in/attendance-api/api/',
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      headers: {
        'X-API-KEY': 'ZIGFLY_SYNC_2025',
        'Accept': 'application/json',
      },
    ),
  );

  Future<List<AttendanceRecord>> fetchRecognizedAttendance({
    required String fromDate,
    required String toDate,
  }) async {
    try {
      final response = await _dio.get(
        'sync/recognized',
        queryParameters: {
          'from_date': fromDate,
          'to_date': toDate,
        },
      );

      final data = response.data;

      if (data is List) {
        return data
            .map((e) => AttendanceRecord.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }

      if (data is Map && data['data'] is List) {
        return (data['data'] as List)
            .map((e) => AttendanceRecord.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }

      return [];
    } on DioException catch (e) {
      throw Exception(
        e.response?.data?.toString() ??
            e.message ??
            'Failed to fetch attendance data',
      );
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }
}

class AttendanceSummaryCard extends StatelessWidget {
  const AttendanceSummaryCard({
    super.key,
    required this.summary,
  });

  final AttendanceSummary summary;

  String formatDateTime(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return '--';
    return DateFormat('dd MMM yyyy, hh:mm a').format(date);
  }

  String formatTime(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return '--';
    return DateFormat('hh:mm a').format(date);
  }

  String formatDuration(Duration duration) {
    if (duration == Duration.zero) return '--';

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    return '${hours}h ${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final checkIn = summary.checkIn;
    final checkOut = summary.checkOut;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipOval(
                  child: checkIn.imageUrl.isNotEmpty
                      ? Image.network(
                          checkIn.imageUrl,
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _defaultAvatar();
                          },
                        )
                      : _defaultAvatar(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        summary.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Emp ID: ${summary.empId}',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: summary.hasCheckOut
                        ? Colors.green.shade50
                        : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: summary.hasCheckOut ? Colors.green : Colors.orange,
                    ),
                  ),
                  child: Text(
                    summary.hasCheckOut ? 'Present' : 'Only In',
                    style: TextStyle(
                      color: summary.hasCheckOut ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _InfoRow(
              icon: Icons.login,
              label: 'Check In',
              value: formatTime(checkIn.records),
            ),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.logout,
              label: 'Check Out',
              value: summary.hasCheckOut ? formatTime(checkOut.records) : '--',
            ),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.timer,
              label: 'Total Hours',
              value: formatDuration(summary.totalDuration),
            ),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.calendar_today,
              label: 'Date',
              value: formatDateTime(checkIn.records),
            ),

            // _InfoRow(
            //   icon: Icons.location_on,
            //   label: 'Location',
            //   value: '${checkIn.latitude}, ${checkIn.longitude}',
            // ),
          ],
        ),
      ),
    );
  }

  Widget _defaultAvatar() {
    return Container(
      width: 52,
      height: 52,
      color: Colors.green,
      child: const Icon(
        Icons.person,
        color: Colors.white,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.green),
        const SizedBox(width: 8),
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class AttendanceDataScreen extends StatefulWidget {
  const AttendanceDataScreen({super.key});

  @override
  State<AttendanceDataScreen> createState() => _AttendanceDataScreenState();
}

class _AttendanceDataScreenState extends State<AttendanceDataScreen> {
  final AttendanceApiService _apiService = AttendanceApiService();

  late Future<List<AttendanceRecord>> _attendanceFuture;
  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();
  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  void _loadAttendance() {
    final fromDate = DateFormat('yyyy-MM-dd').format(_fromDate);
    final toDate = DateFormat('yyyy-MM-dd').format(_toDate);

    _attendanceFuture = _apiService.fetchRecognizedAttendance(
      fromDate: fromDate,
      toDate: toDate,
    );
  }

  Future<void> _refreshData() async {
    setState(() {
      _loadAttendance();
    });
  }

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _fromDate = picked;

        if (_toDate.isBefore(_fromDate)) {
          _toDate = _fromDate;
        }
      });
    }
  }

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate,
      firstDate: _fromDate,
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _toDate = picked;
      });
    }
  }

  void _fetchAttendance() {
    setState(() {
      _loadAttendance();
    });
  }

  List<AttendanceSummary> buildAttendanceSummary(
      List<AttendanceRecord> records) {
    final Map<String, List<AttendanceRecord>> grouped = {};

    for (final record in records) {
      if (record.empId.isEmpty) continue;

      grouped.putIfAbsent(record.empId, () => []);
      grouped[record.empId]!.add(record);
    }

    final summaries = <AttendanceSummary>[];

    grouped.forEach((empId, empRecords) {
      empRecords.sort((a, b) {
        final aTime = a.recordDateTime ?? DateTime(1900);
        final bTime = b.recordDateTime ?? DateTime(1900);
        return aTime.compareTo(bTime);
      });

      final firstRecord = empRecords.first;
      final lastRecord = empRecords.last;

      summaries.add(
        AttendanceSummary(
          empId: empId,
          name: firstRecord.name,
          checkIn: firstRecord,
          checkOut: lastRecord,
        ),
      );
    });

    summaries.sort((a, b) {
      final aTime = a.checkIn.recordDateTime ?? DateTime(1900);
      final bTime = b.checkIn.recordDateTime ?? DateTime(1900);
      return aTime.compareTo(bTime);
    });

    return summaries;
  }

  @override
  Widget build(BuildContext context) {
    final todayText = DateFormat('dd MMM yyyy').format(DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        backgroundColor: darkGreen,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!context.mounted) return;

              if (context.canPop()) {
                context.pop();
              }
            });
          },
        ),
        title: const Text(
          'Attendance Summary',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: FutureBuilder<List<AttendanceRecord>>(
          future: _attendanceFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              return ListView(
                children: [
                  const SizedBox(height: 160),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: Text(
                        snapshot.error.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }

            final records = snapshot.data ?? [];
            final summaries = buildAttendanceSummary(records);

            if (summaries.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 160),
                  Center(
                    child: Column(
                      children: [
                        const Icon(
                          Icons.event_busy,
                          size: 56,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No attendance records found for $todayText',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }
            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _DateFilterCard(
                  fromDate: _fromDate,
                  toDate: _toDate,
                  onFromTap: _pickFromDate,
                  onToTap: _pickToDate,
                  onFetchTap: _fetchAttendance,
                ),
                const SizedBox(height: 12),
                ...summaries.map((item) {
                  return AttendanceSummaryCard(summary: item);
                }),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DateFilterCard extends StatelessWidget {
  const _DateFilterCard({
    required this.fromDate,
    required this.toDate,
    required this.onFromTap,
    required this.onToTap,
    required this.onFetchTap,
  });

  final DateTime fromDate;
  final DateTime toDate;
  final VoidCallback onFromTap;
  final VoidCallback onToTap;
  final VoidCallback onFetchTap;

  @override
  Widget build(BuildContext context) {
    final fromText = DateFormat('dd MMM yyyy').format(fromDate);
    final toText = DateFormat('dd MMM yyyy').format(toDate);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: darkGreen.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filter Attendance',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: darkGreen,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _DateBox(
                  label: 'From Date',
                  value: fromText,
                  onTap: onFromTap,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DateBox(
                  label: 'To Date',
                  value: toText,
                  onTap: onToTap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: onFetchTap,
              icon: const Icon(Icons.search),
              label: const Text(
                'Fetch Attendance',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: darkGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateBox extends StatelessWidget {
  const _DateBox({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F7F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_month, size: 18, color: darkGreen),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
