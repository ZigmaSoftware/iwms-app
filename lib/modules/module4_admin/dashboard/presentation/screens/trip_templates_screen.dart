import 'package:flutter/material.dart';

import 'package:iwms_citizen_app/core/api_config.dart';
import 'package:iwms_citizen_app/core/network/authorized_dio.dart';

const _templateTextColor = Color(0xFF1B1D1F);
const _templateHintColor = Color(0xFF6B7280);

ThemeData _templatesTheme(BuildContext context) {
  final base = Theme.of(context);
  return base.copyWith(
    brightness: Brightness.light,
    canvasColor: Colors.white,
    iconTheme: base.iconTheme.copyWith(color: _templateTextColor),
    textTheme: base.textTheme.apply(
      bodyColor: _templateTextColor,
      displayColor: _templateTextColor,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      labelStyle: const TextStyle(color: _templateTextColor),
      hintStyle: const TextStyle(color: _templateHintColor),
    ),
  );
}

class TripTemplatesScreen extends StatefulWidget {
  const TripTemplatesScreen({super.key});

  @override
  State<TripTemplatesScreen> createState() => _TripTemplatesScreenState();
}

class _TripTemplatesScreenState extends State<TripTemplatesScreen> {
  final _api = _TemplateApi();
  bool _loading = true;
  String? _error;
  List<_CollectionTemplate> _templates = [];

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await _api.list(ApiConfig.tripCollectionPoints);
      final templates = items.map(_CollectionTemplate.fromJson).toList();
      setState(() {
        _templates = templates;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load templates: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _templatesTheme(context),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F7),
        appBar: AppBar(
          title: const Text('Templates'),
          backgroundColor: const Color(0xFF2E7D32),
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: _loadTemplates,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  )
                : _templates.isEmpty
                    ? const Center(
                        child: Text('No templates created yet.'),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadTemplates,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _templates.length,
                          itemBuilder: (context, index) {
                            final template = _templates[index];
                            return _TemplateCard(template: template);
                          },
                        ),
                      ),
      ),
    );
  }
}

class _TemplateApi {
  Future<List<Map<String, dynamic>>> list(String url) async {
    final dio = await authorizedDio();
    final resp = await dio.get(url);
    return _extractItems(resp.data);
  }

  List<Map<String, dynamic>> _extractItems(dynamic decoded) {
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    if (decoded is Map) {
      if (decoded['results'] is List) {
        return (decoded['results'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      if (decoded['data'] is List) {
        return (decoded['data'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }

    return [];
  }
}

class _CollectionTemplate {
  final String id;
  final String propertyType;
  final String subpropertyName;
  final String wardName;
  final String zoneName;
  final String expectedTime;
  final String latitude;
  final String longitude;
  final bool isActive;

  const _CollectionTemplate({
    required this.id,
    required this.propertyType,
    required this.subpropertyName,
    required this.wardName,
    required this.zoneName,
    required this.expectedTime,
    required this.latitude,
    required this.longitude,
    required this.isActive,
  });

  static String _str(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }

  factory _CollectionTemplate.fromJson(Map<String, dynamic> json) {
    return _CollectionTemplate(
      id: _str(json['unique_id'] ?? json['id']),
      propertyType: _str(json['property_type']),
      subpropertyName: _str(json['subproperty_name']),
      wardName: _str(json['ward_name']),
      zoneName: _str(json['zone_name']),
      expectedTime: _str(json['expected_collection_time']),
      latitude: _str(json['latitude']),
      longitude: _str(json['longitude']),
      isActive: json['is_active'] == true,
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.template});

  final _CollectionTemplate template;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  template.subpropertyName.isNotEmpty
                      ? template.subpropertyName
                      : 'Collection Point',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: template.isActive
                      ? const Color(0xFFE8F5E9)
                      : const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  template.isActive ? 'Active' : 'Inactive',
                  style: TextStyle(
                    color: template.isActive
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFFC62828),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            template.id,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          const SizedBox(height: 12),
          _DetailRow(label: 'Property Type', value: template.propertyType),
          _DetailRow(label: 'Ward', value: template.wardName),
          _DetailRow(label: 'Zone', value: template.zoneName),
          _DetailRow(label: 'Expected Time (s)', value: template.expectedTime),
          _DetailRow(
            label: 'Lat / Lng',
            value: '${template.latitude}, ${template.longitude}',
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : '-',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
