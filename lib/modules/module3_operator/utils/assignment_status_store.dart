import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class AssignmentStatusStore {
  static const String _key = 'operator_assignment_status';

  static String normalizeId(String value) {
    return value.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
  }

  static Future<Map<String, String>> getStatusesFor(
    Iterable<String> customerIds,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) {
      return {};
    }

    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }

    final result = <String, String>{};
    for (final id in customerIds) {
      final key = normalizeId(id);
      final entry = decoded[key];
      if (entry is Map && entry['status'] is String) {
        result[id] = entry['status'] as String;
      }
    }
    return result;
  }

  static Future<void> setStatus(String customerId, String status) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    Map<String, dynamic> decoded = {};
    if (raw != null && raw.isNotEmpty) {
      try {
        decoded = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        decoded = {};
      }
    }
    decoded[normalizeId(customerId)] = {
      'status': status,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
    await prefs.setString(_key, jsonEncode(decoded));
  }
}
