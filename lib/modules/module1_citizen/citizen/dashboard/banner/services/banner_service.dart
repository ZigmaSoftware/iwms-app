import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/banner_slide.dart';

class BannerService {
  BannerService({
    http.Client? client,
    this.feedUrl =
        'https://raw.githubusercontent.com/ZigmaSoftware/iwms-banners/refs/heads/main/banners.json',
    this.cacheKey = 'citizen_banner_feed_v1',
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String feedUrl;
  final String cacheKey;

  Future<List<BannerSlide>> loadCached() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(cacheKey);
    if (cached == null) return const [];
    return _parseBannerFeed(cached);
  }

  Future<List<BannerSlide>> fetchRemote() async {
    final response = await _client
        .get(Uri.parse(feedUrl))
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return const [];

    final slides = _parseBannerFeed(response.body);
    if (slides.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(cacheKey, response.body);
    }
    return slides;
  }

  List<BannerSlide> _parseBannerFeed(String rawJson) {
    try {
      final decoded = jsonDecode(rawJson);
      final Iterable<dynamic>? items;
      if (decoded is Map<String, dynamic>) {
        items = decoded['items'] as Iterable<dynamic>?;
      } else if (decoded is Iterable) {
        items = decoded;
      } else {
        return const [];
      }
      if (items == null) return const [];

      return items
          .whereType<Map<String, dynamic>>()
          .map((item) {
            final String? title = (item['title'] as String?)?.trim();
            if (title == null || title.isEmpty) return null;

            final String subtitle =
                (item['subtitle'] as String?)?.trim() ?? '';
            final String chipLabel =
                (item['chipLabel'] as String?)?.trim().toUpperCase() ?? 'TIP';
            final List<Color> colors = _parseColorList(item['colors']) ??
                const [Color(0xFF1B5E20), Color(0xFF43A047)];
            final IconData icon =
                _iconFromName(item['icon'] as String?) ?? Icons.eco_outlined;
            final String? imageUrl = (item['imageUrl'] as String?)?.trim();
            final double? subtitleFontSize =
                (item['subtitleFontSize'] as num?)?.toDouble();

            return BannerSlide(
              chipLabel: chipLabel.isEmpty ? 'TIP' : chipLabel,
              title: title,
              subtitle: subtitle,
              colors: colors,
              icon: icon,
              backgroundImage: imageUrl,
              subtitleFontSize: subtitleFontSize,
              isNetworkImage: imageUrl != null && imageUrl.startsWith('http'),
            );
          })
          .whereType<BannerSlide>()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  List<Color>? _parseColorList(dynamic value) {
    if (value is List) {
      final colors = value
          .map((entry) => _parseColorString(entry as String?))
          .whereType<Color>()
          .toList();
      if (colors.length >= 2) return colors;
      if (colors.length == 1) {
        final base = colors.first;
        return [base, base.withValues(alpha: 0.8)];
      }
    } else if (value is String) {
      final color = _parseColorString(value);
      if (color != null) {
        return [color, color.withValues(alpha: 0.8)];
      }
    }
    return null;
  }

  Color? _parseColorString(String? raw) {
    if (raw == null) return null;
    String value = raw.trim();
    if (value.isEmpty) return null;
    if (value.startsWith('#')) value = value.substring(1);
    if (value.toLowerCase().startsWith('0x')) {
      value = value.substring(2);
    }
    if (value.length == 6) {
      value = 'FF$value';
    }
    if (value.length != 8) return null;
    final int? parsed = int.tryParse(value, radix: 16);
    if (parsed == null) return null;
    return Color(parsed);
  }

  IconData? _iconFromName(String? name) {
    if (name == null) return null;
    switch (name.toLowerCase()) {
      case 'support':
      case 'help':
        return Icons.support_agent;
      case 'map':
      case 'track':
        return Icons.map_outlined;
      case 'star':
      case 'reward':
        return Icons.star_rate_outlined;
      case 'segregation':
      case 'tips':
        return Icons.auto_awesome;
      case 'clean':
      case 'eco':
        return Icons.eco_outlined;
      default:
        return null;
    }
  }
}
