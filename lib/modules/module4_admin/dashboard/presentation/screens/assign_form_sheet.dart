import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:iwms_citizen_app/core/api_config.dart';
import 'package:iwms_citizen_app/core/di.dart';
import 'package:iwms_citizen_app/data/repositories/auth_repository.dart';

const Color _primaryGreen = Color(0xFF2E7D32);

class _IdName {
  final String id;
  final String name;
  const _IdName(this.id, this.name);
}

class AssignFormSheet extends StatefulWidget {
  const AssignFormSheet({super.key});

  @override
  State<AssignFormSheet> createState() => _AssignFormSheetState();
}

class _AssignFormSheetState extends State<AssignFormSheet> {
  DateTime _assignmentDate = DateTime.now();
  String _shift = "full_day";
  String _assignmentType = "primary";

  final _shifts = const [
    ("morning", "Morning", Icons.wb_sunny_outlined),
    ("afternoon", "Afternoon", Icons.wb_twilight_outlined),
    ("full_day", "Full Day", Icons.access_time),
  ];

  final _assignmentTypes = const [
    ("primary", "Primary", Icons.stars_rounded, "Regular scheduled assignment"),
    ("temporary", "Temporary", Icons.schedule, "Short-term coverage"),
    ("emergency", "Emergency", Icons.warning_amber_rounded, "Urgent response"),
  ];

  List<_IdName> wards = [];
  List<_IdName> customers = [];
  List<_IdName> drivers = [];
  List<_IdName> operators = [];

  String? wardId;
  String? customerId;
  String? driverId;
  String? operatorId;

  bool loading = true;
  bool submitting = false;
  String? error;
  bool get _isPrimary => _assignmentType == "primary";

  // Use the environment-configured base URL.
  String get desktopBase => ApiConfig.desktopBase;
  
  // Try alternative endpoints that match the allowlist
  String get wardsUrl => "${desktopBase}masters/wards/";  // Resource: "Wards" 
  String get usersUrl => "${desktopBase}user-creation/users-creation/";  // Resource: "UsersCreation"
  String get customersBaseUrl => "${desktopBase}customers/customercreations/";  // Resource: "Customercreations"
  String get assignmentsUrl => ApiConfig.assignments;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ===========================
  // BUILD HEADERS WITH JWT TOKEN
  // ===========================
  Future<Map<String, String>> _buildHeaders() async {
    final headers = <String, String>{
      "Content-Type": "application/json",
    };

    try {
      final authRepo = getIt<AuthRepository>();
      final user = await authRepo.getAuthenticatedUser();

      if (user?.authToken != null && user!.authToken!.isNotEmpty) {
        // Add Bearer token as required by middleware
        headers["Authorization"] = "Bearer ${user.authToken}";
        debugPrint("✅ Auth token added to request");
      } else {
        debugPrint("⚠️ No auth token available");
      }
    } catch (e) {
      debugPrint("❌ Error getting auth token: $e");
    }

    return headers;
  }

  Future<void> _loadData() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      // Always fetch from database - no mock data
      final fetchedWards = await _fetchList(wardsUrl);
      final fetchedDrivers = await _filterUserListByRole("driver");
      final fetchedOperators = await _filterUserListByRole("operator");

      setState(() {
        wards = fetchedWards;
        drivers = fetchedDrivers;
        operators = fetchedOperators;
        loading = false;
        
        // Show warning if any list is empty
        if (fetchedWards.isEmpty || fetchedDrivers.isEmpty || fetchedOperators.isEmpty) {
          debugPrint("⚠️ Some data is missing:");
          debugPrint("  Wards: ${fetchedWards.length}");
          debugPrint("  Drivers: ${fetchedDrivers.length}");
          debugPrint("  Operators: ${fetchedOperators.length}");
        }
      });
    } catch (e) {
      debugPrint("❌ Load error: $e");
      setState(() {
        loading = false;
        error = 'Unable to load data. Please check your login status.';
      });
    }
  }

  List<Map<String, dynamic>> _extractItems(dynamic decoded) {
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    if (decoded is Map) {
      if (decoded["results"] is List) {
        return (decoded["results"] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      if (decoded["data"] is List) {
        return (decoded["data"] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }

    return [];
  }

  List<_IdName> _decodeIdNames(dynamic decoded) {
    final items = _extractItems(decoded);

    String pick(Map<String, dynamic> map, List<String> keys) {
      for (final key in keys) {
        if (map[key] != null && map[key].toString().trim().isNotEmpty) {
          return map[key].toString();
        }
      }
      return "";
    }

    return items
        .map((m) => _IdName(
              pick(m, ["unique_id", "id", "pk", "staff_id", "customer_id"]),
              pick(m, [
                "staff_name",
                "employee_name",
                "name",
                "customer_name",
                "ward_name",
              ]),
            ))
        .where((e) => e.id.isNotEmpty && e.name.isNotEmpty)
        .toList();
  }

  Future<List<_IdName>> _fetchList(String url) async {
    debugPrint("🔄 FETCH → $url");

    final headers = await _buildHeaders();
    
    try {
      final resp = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 12));

      debugPrint("📡 Response status: ${resp.statusCode}");

      if (resp.statusCode == 401) {
        throw Exception("Unauthorized. Please login again.");
      }

      if (resp.statusCode == 403) {
        // Parse the error to see what the backend expects
        try {
          final error = jsonDecode(resp.body);
          debugPrint("🚫 PERMISSION DENIED:");
          debugPrint("   Module: ${error['module']}");
          debugPrint("   Resource: ${error['resource']}");
          debugPrint("   Reason: ${error['reason']}");
          debugPrint("");
          debugPrint("⚠️ TELL BACKEND TEAM:");
          debugPrint("   Add '${error['resource']}' to MODULE_RESOURCE_ALLOWLIST['${error['module']}']");
        } catch (e) {
          debugPrint("❌ 403 Error: ${resp.body}");
        }
        return [];
      }

      if (resp.statusCode != 200) {
        debugPrint("❌ API ERROR → ${resp.statusCode}, BODY: ${resp.body}");
        return [];
      }

      final decoded = jsonDecode(resp.body);
      return _decodeIdNames(decoded);
    } catch (e) {
      debugPrint("❌ Fetch error: $e");
      return [];
    }
  }

  Future<List<_IdName>> _filterUserListByRole(String targetRole) async {
    debugPrint("🔍 Filtering users by role: $targetRole");

    final headers = await _buildHeaders();
    
    try {
      final resp = await http
          .get(Uri.parse(usersUrl), headers: headers)
          .timeout(const Duration(seconds: 12));

      if (resp.statusCode == 401) {
        throw Exception("Unauthorized. Please login again.");
      }

      if (resp.statusCode == 403) {
        try {
          final error = jsonDecode(resp.body);
          debugPrint("🚫 PERMISSION DENIED:");
          debugPrint("   Module: ${error['module']}");
          debugPrint("   Resource: ${error['resource']}");
          debugPrint("   Reason: ${error['reason']}");
          debugPrint("");
          debugPrint("⚠️ TELL BACKEND TEAM:");
          debugPrint("   Add '${error['resource']}' to MODULE_RESOURCE_ALLOWLIST['${error['module']}']");
        } catch (e) {
          debugPrint("❌ 403 Error: ${resp.body}");
        }
        return [];
      }

      if (resp.statusCode != 200) {
        debugPrint("❌ Users API error: ${resp.statusCode}");
        return [];
      }

      final decoded = jsonDecode(resp.body);
      final rawItems = _extractItems(decoded);
      final displayList = _decodeIdNames(decoded);

      final normalizedTarget = targetRole.toLowerCase();
      final validIds = <String>{};

      for (final m in rawItems) {
        final rawRole = m["staffusertype_name"];
        if (rawRole != null &&
            rawRole.toString().toLowerCase() == normalizedTarget) {
          validIds.add(m["unique_id"].toString());
        }
      }

      debugPrint("✅ Found ${validIds.length} $targetRole(s)");
      return displayList.where((e) => validIds.contains(e.id)).toList();
    } catch (e) {
      debugPrint("❌ Filter error: $e");
      return [];
    }
  }

  Future<void> _loadCustomersForWard(String ward) async {
    setState(() {
      customerId = null;
      customers = [];
    });

    final url = "$customersBaseUrl?ward=$ward";
    final headers = await _buildHeaders();
    
    try {
      final resp = await http.get(Uri.parse(url), headers: headers);
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        final list = _decodeIdNames(decoded);
        setState(() => customers = list);
      }
    } catch (e) {
      debugPrint("❌ Error loading customers: $e");
    }
  }

  Future<bool> _postAssignment() async {
    if (wardId == null || driverId == null || operatorId == null) {
      return false;
    }
    if (_isPrimary && customerId != null) {
      return false;
    }

    final headers = await _buildHeaders();
    final payload = {
      "date": DateFormat('yyyy-MM-dd').format(_assignmentDate),
      "ward": wardId,
      "driver": driverId,
      "operator": operatorId,
      "shift": _shift,
      "assignment_type": _assignmentType,
    };

    if (!_isPrimary && customerId != null) {
      payload["customer"] = customerId;
    }

    debugPrint("📤 POST payload: $payload");

    try {
      final resp = await http.post(
        Uri.parse(assignmentsUrl),
        headers: headers,
        body: jsonEncode(payload),
      );

      debugPrint("📥 Response: ${resp.statusCode} - ${resp.body}");

      return resp.statusCode >= 200 && resp.statusCode < 300;
    } catch (e) {
      debugPrint("❌ POST error: $e");
      return false;
    }
  }

  Future<bool> _checkAssignmentConflict() async {
    if (wardId == null) return false;

    final dateStr = DateFormat('yyyy-MM-dd').format(_assignmentDate);
    final url = "$assignmentsUrl?date=$dateStr&ward_id=$wardId&shift=$_shift";

    try {
      final headers = await _buildHeaders();
      final resp = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode != 200) return false;

      final decoded = jsonDecode(resp.body);
      final List items = decoded is List
          ? decoded
          : (decoded["results"] is List ? decoded["results"] : []);

      return items.isNotEmpty;
    } catch (e) {
      debugPrint("⚠️ Conflict check failed: $e");
      return false;
    }
  }

  Future<void> _showConflictDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFFF6F00)),
            SizedBox(width: 12),
            Text("Assignment Conflict"),
          ],
        ),
        content: const Text(
          "This ward is already assigned for the selected date and shift.\n\n"
          "Please choose a different shift or ward.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon, size: 20) : null,
      filled: true,
      fillColor: Colors.white,
      labelStyle: const TextStyle(
        color: _primaryGreen,
        fontWeight: FontWeight.bold,
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: _primaryGreen.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: _primaryGreen, width: 1.4),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF8F9FB),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: loading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline,
                                  size: 48, color: Colors.red),
                              const SizedBox(height: 16),
                              Text(
                                error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.red),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadData,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: EdgeInsets.only(
                          left: 20,
                          right: 20,
                          top: 20,
                          bottom: 20 + bottomInset,
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF2E7D32),
                                          Color(0xFF1B5E20)
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(
                                      Icons.assignment_ind_rounded,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  const Expanded(
                                    child: Text(
                                      "Create Assignment",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 22,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => Navigator.pop(context),
                                    icon: const Icon(Icons.close_rounded),
                                    style: IconButton.styleFrom(
                                      backgroundColor: const Color(0xFFEEEEEE),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              GestureDetector(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _assignmentDate,
                                    firstDate: DateTime.now()
                                        .subtract(const Duration(days: 7)),
                                    lastDate: DateTime.now()
                                        .add(const Duration(days: 30)),
                                  );
                                  if (picked != null) {
                                    setState(() => _assignmentDate = picked);
                                  }
                                },
                                child: AbsorbPointer(
                                  child: TextFormField(
                                    decoration: _inputDecoration(
                                      "Assignment Date",
                                      icon: Icons.calendar_today_rounded,
                                    ),
                                    controller: TextEditingController(
                                      text: DateFormat('MMM dd, yyyy')
                                          .format(_assignmentDate),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                "Select Shift",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: _shifts.map((s) {
                                  final isSelected = _shift == s.$1;
                                  return Expanded(
                                    child: GestureDetector(
                                      onTap: () =>
                                          setState(() => _shift = s.$1),
                                      child: Container(
                                        margin:
                                            const EdgeInsets.only(right: 8),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? _primaryGreen
                                              : Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          border: Border.all(
                                            color: isSelected
                                                ? _primaryGreen
                                                : const Color(0xFFE0E0E0),
                                            width: 2,
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            Icon(
                                              s.$3,
                                              color: isSelected
                                                  ? Colors.white
                                                  : _primaryGreen,
                                              size: 22,
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              s.$2,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: isSelected
                                                    ? Colors.white
                                                    : const Color(0xFF616161),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                "Assignment Type",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ..._assignmentTypes.map((type) {
                                final isSelected = _assignmentType == type.$1;
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _assignmentType = type.$1;
                                      if (_assignmentType == "primary") {
                                        customerId = null;
                                      }
                                    });
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFFE8F5E9)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isSelected
                                            ? _primaryGreen
                                            : const Color(0xFFE0E0E0),
                                        width: isSelected ? 2 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          type.$3,
                                          color: isSelected
                                              ? _primaryGreen
                                              : const Color(0xFF9E9E9E),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                type.$2,
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w700,
                                                  color: isSelected
                                                      ? _primaryGreen
                                                      : const Color(0xFF212121),
                                                ),
                                              ),
                                              Text(
                                                type.$4,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0xFF757575),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isSelected)
                                          const Icon(
                                            Icons.check_circle,
                                            color: _primaryGreen,
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                decoration: _inputDecoration(
                                  "Select Ward",
                                  icon: Icons.location_on_outlined,
                                ),
                                value: wardId,
                                items: wards
                                    .map((w) => DropdownMenuItem(
                                        value: w.id, child: Text(w.name)))
                                    .toList(),
                                onChanged: (val) {
                                  setState(() => wardId = val);
                                  if (val != null) _loadCustomersForWard(val);
                                },
                              ),
                              const SizedBox(height: 16),
                              if (_assignmentType != "primary") ...[
                                DropdownButtonFormField<String>(
                                  decoration: _inputDecoration(
                                    "Select Customer (Optional)",
                                    icon: Icons.person_outline_rounded,
                                  ),
                                  value: customerId,
                                  items: customers
                                      .map((c) => DropdownMenuItem(
                                          value: c.id, child: Text(c.name)))
                                      .toList(),
                                  onChanged: (val) =>
                                      setState(() => customerId = val),
                                ),
                                const SizedBox(height: 16),
                              ],
                              DropdownButtonFormField<String>(
                                decoration: _inputDecoration(
                                  "Select Driver",
                                  icon: Icons.drive_eta_rounded,
                                ),
                                value: driverId,
                                items: drivers
                                    .map((d) => DropdownMenuItem(
                                        value: d.id, child: Text(d.name)))
                                    .toList(),
                                onChanged: (val) =>
                                    setState(() => driverId = val),
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                decoration: _inputDecoration(
                                  "Select Operator",
                                  icon: Icons.engineering_rounded,
                                ),
                                value: operatorId,
                                items: operators
                                    .map((o) => DropdownMenuItem(
                                        value: o.id, child: Text(o.name)))
                                    .toList(),
                                onChanged: (val) =>
                                    setState(() => operatorId = val),
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: wardId != null &&
                                          driverId != null &&
                                          operatorId != null &&
                                          (_isPrimary
                                              ? customerId == null
                                              : true) &&
                                          !submitting
                                      ? () async {
                                          setState(() => submitting = true);

                                          final hasConflict =
                                              await _checkAssignmentConflict();

                                          if (hasConflict) {
                                            setState(() => submitting = false);
                                            await _showConflictDialog();
                                            return;
                                          }

                                          final ok = await _postAssignment();

                                          if (!mounted) return;

                                          if (ok) {
                                            Navigator.pop(context, true);
                                            return;
                                          }

                                          setState(() => submitting = false);
                                          if (!mounted) return;
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                  'Failed to create assignment'),
                                            ),
                                          );
                                        }
                                      : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _primaryGreen,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 18),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: submitting
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          "Create Assignment",
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
          );
        },
      ),
    );
  }
}
