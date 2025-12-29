import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AssignmentStatusStore {
  static const String _key = 'operator_assignment_status_v3';
  static const String _sessionKey = 'operator_status_session_date';
  static const String _assignmentPrefix = 'a:';
  static const String _completePrefix = 'c:';

  static final ValueNotifier<int> notifier = ValueNotifier<int>(0);

  static Map<String, Map<String, dynamic>>? _cache;
  static DateTime? _cacheDate;

  static String normalizeId(String value) {
    return value.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
  }

  static String _assignmentKey(String assignmentId, String customerId) {
    return '$_assignmentPrefix${normalizeId(assignmentId)}:${normalizeId(customerId)}';
  }

  static String _completedKey(String assignmentId) {
    return '$_completePrefix${normalizeId(assignmentId)}';
  }

  static Future<void> _checkSession() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month}-${today.day}';
    final lastSession = prefs.getString(_sessionKey);

    if (lastSession == todayStr) return;

    final raw = prefs.getString(_key);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        final cleaned = <String, dynamic>{};

        decoded.forEach((key, value) {
          if (value is Map && value['status'] is String) {
            final status = value['status'].toString().toLowerCase();
            if (status != 'later') {
              cleaned[key] = value;
            }
          } else if (key.startsWith(_completePrefix)) {
            cleaned[key] = value;
          }
        });

        await prefs.setString(_key, jsonEncode(cleaned));
        _cache = null;
      } catch (_) {
        _cache = null;
      }
    }

    await prefs.setString(_sessionKey, todayStr);
  }

  static Future<Map<String, Map<String, dynamic>>> _loadCache() async {
    await _checkSession();
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    if (_cache != null && _cacheDate == todayDate) {
      return _cache!;
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) {
      _cache = {};
      _cacheDate = todayDate;
      return _cache!;
    }

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final migrated = <String, Map<String, dynamic>>{};

      decoded.forEach((key, value) {
        if (value is! Map) return;
        final entry = Map<String, dynamic>.from(value);
        if (key.startsWith(_assignmentPrefix) ||
            key.startsWith(_completePrefix)) {
          migrated[key] = entry;
          return;
        }
      });

      _cache = migrated;
      _cacheDate = todayDate;
      return _cache!;
    } catch (_) {
      _cache = {};
      _cacheDate = todayDate;
      return _cache!;
    }
  }

  static Future<void> _saveCache() async {
    if (_cache == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_cache));
    notifier.value = notifier.value + 1;
  }

  static Future<Map<String, String>> getStatusesFor(
    String assignmentId,
    Iterable<String> customerIds,
  ) async {
    final cache = await _loadCache();
    final result = <String, String>{};

    for (final id in customerIds) {
      final assignmentEntry = cache[_assignmentKey(assignmentId, id)];
      if (assignmentEntry != null && assignmentEntry['status'] is String) {
        result[id] = assignmentEntry['status'] as String;
      }
    }

    return result;
  }

  static Future<void> setStatusForAssignment(
    String assignmentId,
    String customerId,
    String status,
  ) async {
    final cache = await _loadCache();
    cache[_assignmentKey(assignmentId, customerId)] = {
      'status': status,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
      'originalId': customerId,
    };
    await _saveCache();
  }

  static Future<void> setAssignmentCompleted(String assignmentId) async {
    final cache = await _loadCache();
    cache[_completedKey(assignmentId)] = {
      'status': 'completed',
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
    await _saveCache();
  }

  static Future<bool> isAssignmentCompleted(String assignmentId) async {
    final cache = await _loadCache();
    final entry = cache[_completedKey(assignmentId)];
    return entry != null;
  }

  static Future<Set<String>> getCompletedAssignments() async {
    final cache = await _loadCache();
    final out = <String>{};
    for (final key in cache.keys) {
      if (key.startsWith(_completePrefix)) {
        out.add(key.substring(_completePrefix.length));
      }
    }
    return out;
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    _cache = null;
    notifier.value = notifier.value + 1;
  }
}
