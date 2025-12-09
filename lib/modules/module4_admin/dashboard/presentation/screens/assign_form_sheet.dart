import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:iwms_citizen_app/core/api_config.dart';

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
  List<_IdName> wards = [];
  List<_IdName> customers = [];
  List<_IdName> drivers = [];
  List<_IdName> operators = [];

  String? wardId;
  String? customerId;
  String? driverId;
  String? operatorId;

  bool loading = true;
  String? error;

  // Correct backend endpoints
  String get wardsUrl => "${ApiConfig.desktopBase}wards/";

  String get usersUrl => "${ApiConfig.desktopBase}users-creation/";

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final fetchedWards = await _fetchList(wardsUrl);

      // Fetch drivers and operators separately using correct filtering
      final fetchedDrivers = await _filterUserListByRole("driver");
      final fetchedOperators = await _filterUserListByRole("operator");

      setState(() {
        wards = fetchedWards;
        drivers = fetchedDrivers;
        operators = fetchedOperators;
        loading = false;
      });
    } catch (e) {
      setState(() {
        loading = false;
        error = 'Unable to load assignment data';
      });
    }
  }

  // Extract items from JSON
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
              pick(
                m,
                [
                  "staff_name",
                  "employee_name",
                  "name",
                  "customer_name",
                  "ward_name",
                ],
              ),
            ))
        .where((e) => e.id.isNotEmpty && e.name.isNotEmpty)
        .toList();
  }

  // ===========================
  // FETCH LIST FROM API
  // ===========================
  Future<List<_IdName>> _fetchList(String url) async {
    print("FETCH → $url");

    final resp =
        await http.get(Uri.parse(url)).timeout(const Duration(seconds: 12));

    if (resp.statusCode != 200) {
      print("API ERROR → ${resp.statusCode}, BODY: ${resp.body}");
      return [];
    }

    final decoded = jsonDecode(resp.body);
    return _decodeIdNames(decoded);
  }

  // ===========================
  // FILTER USERS BY ROLE
  // ===========================

  // Improved version: re-fetch raw items to inspect staffusertype
  Future<List<_IdName>> _filterUserListByRole(String targetRole) async {
    print("=== FILTER ROLE START → $targetRole ===");

    final resp = await http
        .get(Uri.parse(usersUrl))
        .timeout(const Duration(seconds: 12));

    print("RAW USERS → ${resp.body}");

    if (resp.statusCode != 200) return [];

    final decoded = jsonDecode(resp.body);
    final rawItems = _extractItems(decoded);
    final displayList = _decodeIdNames(decoded);

    final normalizedTarget = targetRole.toLowerCase();
    final validIds = <String>{};

    for (final m in rawItems) {
      final rawRole = m["staffusertype_name"]; // <-- THE REAL FIELD IN YOUR API

      print("CHECK ROLE → $rawRole");

      if (rawRole != null &&
          rawRole.toString().toLowerCase() == normalizedTarget) {
        validIds.add(m["unique_id"].toString());
        print("MATCH FOUND → ${m["unique_id"]}");
      }
    }

    print("MATCHED IDS → $validIds");
    print("=== FILTER ROLE END ===");

    return displayList.where((e) => validIds.contains(e.id)).toList();
  }

  Future<void> _loadCustomersForWard(String ward) async {
    setState(() {
      customerId = null;
      customers = [];
    });

    final url =
        "${ApiConfig.desktopBase}customers/customercreations/?ward=$ward";

    final resp = await http.get(Uri.parse(url));
    if (resp.statusCode == 200) {
      final decoded = jsonDecode(resp.body);
      final list = _decodeIdNames(decoded);
      setState(() => customers = list);
    }
  }

  Future<bool> _postAssignment() async {
    final payload = {
      "ward": wardId,
      "customer": customerId,
      "driver": driverId,
      "operator": operatorId,
    };

    final resp = await http.post(
      Uri.parse(ApiConfig.assignments),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(payload),
    );

    print("POST → $payload");
    print("RESP → ${resp.statusCode} ${resp.body}");

    return resp.statusCode >= 200 && resp.statusCode < 300;
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      labelStyle: const TextStyle(
        color: _primaryGreen,
        fontWeight: FontWeight.bold,
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: _primaryGreen.withOpacity(0.3)),
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
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: 12 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      "Assign Driver & Operator",
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),

                // --------------------------
                // Ward
                // --------------------------
                DropdownButtonFormField<String>(
                  decoration: _inputDecoration("Select Ward"),
                  value: wardId,
                  items: wards
                      .map((w) =>
                          DropdownMenuItem(value: w.id, child: Text(w.name)))
                      .toList(),
                  onChanged: (val) {
                    setState(() => wardId = val);
                    if (val != null) _loadCustomersForWard(val);
                  },
                ),
                const SizedBox(height: 10),

                // --------------------------
                // Customer
                // --------------------------
                DropdownButtonFormField<String>(
                  decoration: _inputDecoration("Select Citizen (optional)"),
                  value: customerId,
                  items: customers
                      .map((c) =>
                          DropdownMenuItem(value: c.id, child: Text(c.name)))
                      .toList(),
                  onChanged: (val) => setState(() => customerId = val),
                ),
                const SizedBox(height: 10),

                // --------------------------
                // Driver
                // --------------------------
                DropdownButtonFormField<String>(
                  decoration: _inputDecoration("Select Driver"),
                  value: driverId,
                  items: drivers
                      .map((d) =>
                          DropdownMenuItem(value: d.id, child: Text(d.name)))
                      .toList(),
                  onChanged: (val) => setState(() => driverId = val),
                ),
                const SizedBox(height: 10),

                // --------------------------
                // Operator
                // --------------------------
                DropdownButtonFormField<String>(
                  decoration: _inputDecoration("Select Operator"),
                  value: operatorId,
                  items: operators
                      .map((o) =>
                          DropdownMenuItem(value: o.id, child: Text(o.name)))
                      .toList(),
                  onChanged: (val) => setState(() => operatorId = val),
                ),
                const SizedBox(height: 14),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        wardId != null && driverId != null && operatorId != null
                            ? () async {
                                final ok = await _postAssignment();
                                if (ok) Navigator.pop(context);
                              }
                            : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryGreen,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text("Assign"),
                  ),
                ),
              ],
            ),
    );
  }
}
