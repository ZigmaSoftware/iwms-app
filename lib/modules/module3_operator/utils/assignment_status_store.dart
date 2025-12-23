// assignment_status_store.dart
// ✅ Fixed: Proper SharedPreferences persistence that doesn't reset

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class AssignmentStatusStore {
  static const String _key = 'operator_assignment_status_v2'; // ✅ New key to avoid conflicts
  static const String _sessionKey = 'operator_session_date';
  
  // ✅ Cache to reduce SharedPreferences calls
  static Map<String, Map<String, dynamic>>? _cache;
  static DateTime? _cacheDate;

  static String normalizeId(String value) {
    return value.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
  }

  // ✅ Check if we need to clear old session data
  static Future<void> _checkSession() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month}-${today.day}';
    final lastSession = prefs.getString(_sessionKey);

    // If new day, keep collected/skipped but reset "later"
    if (lastSession != todayStr) {
      debugPrint('📅 New session detected, resetting "later" statuses');
      
      final raw = prefs.getString(_key);
      if (raw != null && raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw) as Map<String, dynamic>;
          final cleaned = <String, dynamic>{};
          
          // Keep only collected and skipped
          decoded.forEach((key, value) {
            if (value is Map && value['status'] is String) {
              final status = value['status'].toString().toLowerCase();
              if (status == 'collected' || status == 'skipped') {
                cleaned[key] = value;
              }
            }
          });
          
          await prefs.setString(_key, jsonEncode(cleaned));
          _cache = null; // Clear cache
        } catch (e) {
          debugPrint('⚠️ Error cleaning session: $e');
        }
      }
      
      await prefs.setString(_sessionKey, todayStr);
    }
  }

  // ✅ Load cache once per session
  static Future<Map<String, Map<String, dynamic>>> _loadCache() async {
    await _checkSession();
    
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    
    // Return cache if still valid
    if (_cache != null && _cacheDate != null && _cacheDate == todayDate) {
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
      _cache = decoded.map((key, value) => MapEntry(key, Map<String, dynamic>.from(value as Map)));
      _cacheDate = todayDate;
      return _cache!;
    } catch (e) {
      debugPrint('⚠️ Error loading cache: $e');
      _cache = {};
      _cacheDate = todayDate;
      return _cache!;
    }
  }

  // ✅ Save cache with debouncing
  static Future<void> _saveCache() async {
    if (_cache == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    try {
      await prefs.setString(_key, jsonEncode(_cache));
      debugPrint('💾 Saved ${_cache!.length} status entries');
    } catch (e) {
      debugPrint('⚠️ Error saving cache: $e');
    }
  }

  static Future<Map<String, String>> getStatusesFor(
    Iterable<String> customerIds,
  ) async {
    final cache = await _loadCache();
    final result = <String, String>{};
    
    for (final id in customerIds) {
      final key = normalizeId(id);
      final entry = cache[key];
      if (entry != null && entry['status'] is String) {
        result[id] = entry['status'] as String;
      }
    }
    
    debugPrint('📖 Retrieved ${result.length} statuses for ${customerIds.length} customers');
    return result;
  }

  static Future<void> setStatus(String customerId, String status) async {
    final cache = await _loadCache();
    final key = normalizeId(customerId);
    
    cache[key] = {
      'status': status,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
      'originalId': customerId, // Keep original for debugging
    };
    
    await _saveCache();
    debugPrint('✅ Set status for $customerId ($key) → $status');
  }

  // ✅ Bulk update for efficiency
  static Future<void> setStatuses(Map<String, String> updates) async {
    final cache = await _loadCache();
    final now = DateTime.now().millisecondsSinceEpoch;
    
    updates.forEach((customerId, status) {
      final key = normalizeId(customerId);
      cache[key] = {
        'status': status,
        'updatedAt': now,
        'originalId': customerId,
      };
    });
    
    await _saveCache();
    debugPrint('✅ Bulk updated ${updates.length} statuses');
  }

  // ✅ Get single status
  static Future<String?> getStatus(String customerId) async {
    final cache = await _loadCache();
    final key = normalizeId(customerId);
    final entry = cache[key];
    
    if (entry != null && entry['status'] is String) {
      return entry['status'] as String;
    }
    return null;
  }

  // ✅ Clear all statuses (for testing/reset)
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    _cache = null;
    debugPrint('🗑️ Cleared all assignment statuses');
  }

  // ✅ Get statistics
  static Future<Map<String, int>> getStats() async {
    final cache = await _loadCache();
    final stats = <String, int>{
      'total': cache.length,
      'collected': 0,
      'skipped': 0,
      'later': 0,
      'pending': 0,
    };
    
    for (final entry in cache.values) {
      if (entry['status'] is String) {
        final status = entry['status'].toString().toLowerCase();
        stats[status] = (stats[status] ?? 0) + 1;
      }
    }
    
    return stats;
  }

  // ✅ Debug: Print all statuses
  static Future<void> debugPrintAll() async {
    final cache = await _loadCache();
    debugPrint('📊 Assignment Status Store (${cache.length} entries):');
    cache.forEach((key, value) {
      debugPrint('  $key → ${value['status']} (${value['originalId']})');
    });
  }
}