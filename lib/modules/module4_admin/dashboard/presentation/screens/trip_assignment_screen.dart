import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'package:iwms_citizen_app/core/api_config.dart';
import 'package:iwms_citizen_app/core/network/authorized_dio.dart';
import 'package:iwms_citizen_app/modules/module4_admin/dashboard/presentation/screens/trip_templates_screen.dart';

const _fieldTextColor = Color(0xFF1B1D1F);
const _fieldHintColor = Color.fromARGB(255, 255, 255, 255);
const _fieldBorderColor = Color(0xFFE0E3E7);
const _fieldFocusColor = Color(0xFF2E7D32);

ThemeData _formTheme(BuildContext context) {
  final base = Theme.of(context);
  return base.copyWith(
    brightness: Brightness.light,
    canvasColor: Colors.white,
    iconTheme: base.iconTheme.copyWith(color: _fieldTextColor),
    textTheme: base.textTheme.apply(
      bodyColor: _fieldTextColor,
      displayColor: _fieldTextColor,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      labelStyle: const TextStyle(color: _fieldTextColor),
      hintStyle: const TextStyle(color: Color.fromARGB(255, 255, 255, 255)),
      floatingLabelStyle: const TextStyle(color: _fieldFocusColor),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: _fieldBorderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: _fieldFocusColor, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      border: OutlineInputBorder(
        borderSide: const BorderSide(color: _fieldBorderColor),
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  );
}

class TripAssignmentScreen extends StatelessWidget {
  const TripAssignmentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 8,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F7),
        appBar: AppBar(
          title: const Text('Trip Assignment'),
          backgroundColor: const Color(0xFF2E7D32),
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              tooltip: 'Templates',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TripTemplatesScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.more_vert),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              const Tab(text: 'Trips'),
              const Tab(text: 'Staff Templates'),
              const Tab(text: 'Shifts'),
              const Tab(text: 'Collection Points'),
              const Tab(text: 'Route Plans'),
              const Tab(text: 'Planned Stops'),
              const Tab(text: 'Geometry Cache'),
              const Tab(text: 'Execution Stops'),
            ],
          ),
        ),
        body: Theme(
          data: _formTheme(context),
          child: const TabBarView(
            children: [
              _TripForm(),
              _StaffTemplateForm(),
              _ShiftForm(),
              _CollectionPointForm(),
              _RoutePlanForm(),
              _PlannedStopForm(),
              _GeometryForm(),
              _ExecutionStopForm(),
            ],
          ),
        ),
      ),
    );
  }
}

class _TripAssignmentApi {
  Future<List<Map<String, dynamic>>> list(String url) async {
    final dio = await authorizedDio();
    final resp = await dio.get(url);
    final decoded = resp.data;
    return _extractItems(decoded);
  }

  Future<Map<String, dynamic>> create(
    String url,
    Map<String, dynamic> payload,
  ) async {
    final dio = await authorizedDio();
    final resp = await dio.post(url, data: payload);
    if (resp.data is Map<String, dynamic>) {
      return Map<String, dynamic>.from(resp.data as Map);
    }
    return {'status': resp.statusCode};
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

class _LookupItem {
  final String id;
  final String label;

  const _LookupItem(this.id, this.label);
}

class _WardLookup {
  final String id;
  final String label;
  final String? zoneId;

  const _WardLookup(this.id, this.label, this.zoneId);
}

class _FormCard extends StatelessWidget {
  const _FormCard({
    required this.title,
    this.subtitle,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.label,
    required this.onPressed,
    this.submitting = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool submitting;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: submitting ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2E7D32),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: submitting
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(label),
      ),
    );
  }
}

class _TripForm extends StatefulWidget {
  const _TripForm();

  @override
  State<_TripForm> createState() => _TripFormState();
}

class _TripFormState extends State<_TripForm> {
  final _api = _TripAssignmentApi();
  final _supervisorId = TextEditingController();
  List<_LookupItem> _shifts = [];
  List<_LookupItem> _vehicles = [];
  List<_LookupItem> _staffTemplates = [];
  String? _selectedShiftId;
  String? _selectedVehicleId;
  String? _selectedStaffTemplateId;
  bool _loadingLookups = true;
  String? _lookupError;
  bool _submitting = false;

  @override
  void dispose() {
    _supervisorId.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadLookups();
  }

  Future<void> _loadLookups() async {
    setState(() {
      _loadingLookups = true;
      _lookupError = null;
    });

    try {
      final shifts = await _api.list(ApiConfig.tripShifts);
      final vehicles = await _api.list(ApiConfig.vehicles);
      final staffTemplates = await _api.list(ApiConfig.staffTemplates);

      setState(() {
        _shifts = _mapShifts(shifts);
        _vehicles = _mapVehicles(vehicles);
        _staffTemplates = _mapStaffTemplates(staffTemplates);
        _loadingLookups = false;
      });
    } catch (e) {
      setState(() {
        _lookupError = 'Unable to load data for trip creation.';
        _loadingLookups = false;
      });
    }
  }

  String _pick(Map<String, dynamic> item, List<String> keys) {
    for (final key in keys) {
      final value = item[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return '';
  }

  List<_LookupItem> _mapShifts(List<Map<String, dynamic>> items) {
    return items
        .map((item) {
          final id = _pick(item, ['unique_id', 'id']);
          final name = _pick(item, ['shift_name', 'name']);
          return _LookupItem(id, name);
        })
        .where((item) => item.id.isNotEmpty && item.label.isNotEmpty)
        .toList();
  }

  List<_LookupItem> _mapVehicles(List<Map<String, dynamic>> items) {
    return items
        .map((item) {
          final id = _pick(item, ['unique_id', 'id']);
          final number = _pick(item, ['vehicle_no', 'vehicle_number', 'name']);
          final label = number.isNotEmpty ? '$number • $id' : id;
          return _LookupItem(id, label);
        })
        .where((item) => item.id.isNotEmpty && item.label.isNotEmpty)
        .toList();
  }

  List<_LookupItem> _mapStaffTemplates(List<Map<String, dynamic>> items) {
    return items
        .map((item) {
          final id = _pick(item, ['unique_id', 'id']);
          return _LookupItem(id, id);
        })
        .where((item) => item.id.isNotEmpty)
        .toList();
  }

  Future<void> _submit() async {
    if (_selectedShiftId == null ||
        _selectedVehicleId == null ||
        _selectedStaffTemplateId == null ||
        _selectedShiftId!.isEmpty ||
        _selectedVehicleId!.isEmpty ||
        _selectedStaffTemplateId!.isEmpty) {
      _notify('Shift, vehicle, and staff template are required.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final payload = <String, dynamic>{
        'shift_id': _selectedShiftId!,
        'vehicle_id': _selectedVehicleId!,
        'staff_template_id': _selectedStaffTemplateId!,
      };

      if (_supervisorId.text.trim().isNotEmpty) {
        payload['supervisor_id'] = _supervisorId.text.trim();
      }

      final result = await _api.create(ApiConfig.tripAssignments, payload);
      final tripId = result['unique_id'] ?? 'OK';
      _notify('Trip created: $tripId');
    } catch (e) {
      _notify('Failed to create trip: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _notify(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: _FormCard(
        title: 'Create Trip',
        subtitle: 'Who is working, with which vehicle, in which shift.',
        child: Column(
          children: [
            if (_loadingLookups)
              const LinearProgressIndicator(minHeight: 2)
            else if (_lookupError != null)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _lookupError!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                  TextButton(
                    onPressed: _loadLookups,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            if (!_loadingLookups && _lookupError == null) ...[
              DropdownButtonFormField<String>(
                value: _selectedShiftId,
                decoration: const InputDecoration(labelText: 'Shift'),
                hint: const Text('Select shift'),
                items: _shifts
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.id,
                        child: Text(item.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() => _selectedShiftId = value);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedVehicleId,
                decoration: const InputDecoration(labelText: 'Vehicle'),
                hint: const Text('Select vehicle'),
                items: _vehicles
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.id,
                        child: Text(item.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() => _selectedVehicleId = value);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedStaffTemplateId,
                decoration:
                    const InputDecoration(labelText: 'Staff Template'),
                hint: const Text('Select staff template'),
                items: _staffTemplates
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.id,
                        child: Text(item.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() => _selectedStaffTemplateId = value);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _supervisorId,
                decoration: const InputDecoration(
                  labelText: 'Supervisor ID (optional)',
                  hintText: 'USER-xxxx',
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Status: PLANNED',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _SubmitButton(
                label: 'Create Trip',
                submitting: _submitting,
                onPressed: _submit,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StaffTemplateForm extends StatefulWidget {
  const _StaffTemplateForm();

  @override
  State<_StaffTemplateForm> createState() => _StaffTemplateFormState();
}

class _StaffTemplateFormState extends State<_StaffTemplateForm> {
  final _api = _TripAssignmentApi();
  final _extraStaff = TextEditingController();
  List<_LookupItem> _drivers = [];
  List<_LookupItem> _operators = [];
  String? _primaryDriverId;
  String? _primaryOperatorId;
  String? _secondaryDriverId;
  String? _secondaryOperatorId;
  bool _loadingStaff = true;
  String? _staffError;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  @override
  void dispose() {
    _extraStaff.dispose();
    super.dispose();
  }

  Future<void> _loadStaff() async {
    setState(() {
      _loadingStaff = true;
      _staffError = null;
    });

    try {
      final users = await _api.list(ApiConfig.users);
      final drivers = <_LookupItem>[];
      final operators = <_LookupItem>[];

      for (final user in users) {
        final role = (user['staffusertype_name'] ?? '').toString().toLowerCase();
        final id = _pick(user, ['unique_id', 'id']);
        if (id.isEmpty) continue;

        final name = _pick(user, ['staff_name', 'employee_name', 'name']);
        final label = name.isNotEmpty ? '$name • $id' : id;

        if (role == 'driver') {
          drivers.add(_LookupItem(id, label));
        } else if (role == 'operator') {
          operators.add(_LookupItem(id, label));
        }
      }

      setState(() {
        _drivers = drivers;
        _operators = operators;
        _loadingStaff = false;
      });
    } catch (e) {
      setState(() {
        _staffError = 'Unable to load staff list.';
        _loadingStaff = false;
      });
    }
  }

  String _pick(Map<String, dynamic> item, List<String> keys) {
    for (final key in keys) {
      final value = item[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return '';
  }

  Future<void> _submit() async {
    if (_primaryDriverId == null ||
        _primaryOperatorId == null ||
        _primaryDriverId!.isEmpty ||
        _primaryOperatorId!.isEmpty) {
      _notify('Primary driver and operator are required.');
      return;
    }

    final extraIds = _extraStaff.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final payload = <String, dynamic>{
      'primary_driver_id': _primaryDriverId!,
      'primary_operator_id': _primaryOperatorId!,
      'extra_staff_ids': extraIds,
    };

    if (_secondaryDriverId != null && _secondaryDriverId!.isNotEmpty) {
      payload['secondary_driver_id'] = _secondaryDriverId!;
    }
    if (_secondaryOperatorId != null && _secondaryOperatorId!.isNotEmpty) {
      payload['secondary_operator_id'] = _secondaryOperatorId!;
    }

    setState(() => _submitting = true);
    try {
      final result = await _api.create(ApiConfig.staffTemplates, payload);
      _notify('Template created: ${result['unique_id'] ?? 'OK'}');
      _extraStaff.clear();
    } catch (e) {
      _notify('Failed to create template: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _notify(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: _FormCard(
        title: 'Create Staff Template',
        subtitle: 'Reusable crew definition for trips.',
        child: Column(
          children: [
            if (_loadingStaff)
              const LinearProgressIndicator(minHeight: 2)
            else if (_staffError != null)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _staffError!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                  TextButton(
                    onPressed: _loadStaff,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            if (!_loadingStaff && _staffError == null) ...[
              DropdownButtonFormField<String>(
                value: _primaryDriverId,
                decoration: const InputDecoration(
                  labelText: 'Primary Driver',
                ),
                hint: const Text('Select driver'),
                items: _drivers
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.id,
                        child: Text(item.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() => _primaryDriverId = value);
                },
              ),
              if (_drivers.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'No drivers available.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _primaryOperatorId,
                decoration: const InputDecoration(
                  labelText: 'Primary Operator',
                ),
                hint: const Text('Select operator'),
                items: _operators
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.id,
                        child: Text(item.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() => _primaryOperatorId = value);
                },
              ),
              if (_operators.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'No operators available.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _secondaryDriverId ?? '',
                decoration: const InputDecoration(
                  labelText: 'Secondary Driver (optional)',
                ),
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('None'),
                  ),
                  ..._drivers.map(
                    (item) => DropdownMenuItem(
                      value: item.id,
                      child: Text(item.label),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _secondaryDriverId =
                        (value == null || value.isEmpty) ? null : value;
                  });
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _secondaryOperatorId ?? '',
                decoration: const InputDecoration(
                  labelText: 'Secondary Operator (optional)',
                ),
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('None'),
                  ),
                  ..._operators.map(
                    (item) => DropdownMenuItem(
                      value: item.id,
                      child: Text(item.label),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _secondaryOperatorId =
                        (value == null || value.isEmpty) ? null : value;
                  });
                },
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _extraStaff,
              decoration: const InputDecoration(
                labelText: 'Extra Staff IDs (comma separated)',
                hintText: 'USER-1, USER-2',
              ),
            ),
            const SizedBox(height: 12),
            _SubmitButton(
              label: 'Create Template',
              submitting: _submitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _ShiftForm extends StatefulWidget {
  const _ShiftForm();

  @override
  State<_ShiftForm> createState() => _ShiftFormState();
}

class _ShiftFormState extends State<_ShiftForm> {
  final _api = _TripAssignmentApi();
  final _shiftName = TextEditingController();
  final _startTime = TextEditingController();
  final _endTime = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _shiftName.dispose();
    _startTime.dispose();
    _endTime.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_shiftName.text.trim().isEmpty ||
        _startTime.text.trim().isEmpty ||
        _endTime.text.trim().isEmpty) {
      _notify('Shift name, start time, and end time are required.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final result = await _api.create(
        ApiConfig.tripShifts,
        {
          'shift_name': _shiftName.text.trim(),
          'start_time': _startTime.text.trim(),
          'end_time': _endTime.text.trim(),
        },
      );
      _notify('Shift created: ${result['unique_id'] ?? 'OK'}');
    } catch (e) {
      _notify('Failed to create shift: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _notify(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: _FormCard(
        title: 'Create Shift',
        subtitle: 'Time boundary for trips (HH:MM).',
        child: Column(
          children: [
            TextField(
              controller: _shiftName,
              decoration: const InputDecoration(
                labelText: 'Shift Name',
                hintText: 'Morning / Evening',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _startTime,
              decoration: const InputDecoration(
                labelText: 'Start Time',
                hintText: '06:00',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _endTime,
              decoration: const InputDecoration(
                labelText: 'End Time',
                hintText: '14:00',
              ),
            ),
            const SizedBox(height: 16),
            _SubmitButton(
              label: 'Create Shift',
              submitting: _submitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _CollectionPointForm extends StatefulWidget {
  const _CollectionPointForm();

  @override
  State<_CollectionPointForm> createState() => _CollectionPointFormState();
}

class _CollectionPointFormState extends State<_CollectionPointForm> {
  final _api = _TripAssignmentApi();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  final _expectedTime = TextEditingController();
  String _propertyType = 'house';
  List<_LookupItem> _subproperties = [];
  List<_LookupItem> _wards = [];
  List<_LookupItem> _zones = [];
  String? _selectedSubpropertyId;
  String? _selectedWardId;
  String? _selectedZoneId;
  bool _loadingLookups = true;
  String? _lookupError;
  bool _isActive = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadLookups();
  }

  @override
  void dispose() {
    _latitude.dispose();
    _longitude.dispose();
    _expectedTime.dispose();
    super.dispose();
  }

  Future<void> _loadLookups() async {
    setState(() {
      _loadingLookups = true;
      _lookupError = null;
    });

    try {
      final subproperties = await _api.list(ApiConfig.subproperties);
      final wards = await _api.list(ApiConfig.wards);
      final zones = await _api.list(ApiConfig.zones);

      setState(() {
        _subproperties = _mapSubproperties(subproperties);
        _wards = _mapWards(wards);
        _zones = _mapZones(zones);
        _loadingLookups = false;
      });
    } catch (e) {
      setState(() {
        _lookupError = 'Unable to load lookup data.';
        _loadingLookups = false;
      });
    }
  }

  String _pick(Map<String, dynamic> item, List<String> keys) {
    for (final key in keys) {
      final value = item[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return '';
  }

  List<_LookupItem> _mapSubproperties(List<Map<String, dynamic>> items) {
    return items
        .map((item) {
          final id = _pick(item, ['unique_id', 'id']);
          final name = _pick(item, ['sub_property_name', 'name']);
          final propertyName = _pick(item, ['property_name']);
          final label =
              propertyName.isNotEmpty ? '$name • $propertyName' : name;
          return _LookupItem(id, label);
        })
        .where((item) => item.id.isNotEmpty && item.label.isNotEmpty)
        .toList();
  }

  List<_LookupItem> _mapWards(List<Map<String, dynamic>> items) {
    return items
        .map((item) {
          final id = _pick(item, ['unique_id', 'id']);
          final name = _pick(item, ['name', 'ward_name']);
          final zoneName = _pick(item, ['zone_name']);
          final label = zoneName.isNotEmpty ? '$name • $zoneName' : name;
          return _LookupItem(id, label);
        })
        .where((item) => item.id.isNotEmpty && item.label.isNotEmpty)
        .toList();
  }

  List<_LookupItem> _mapZones(List<Map<String, dynamic>> items) {
    return items
        .map((item) {
          final id = _pick(item, ['unique_id', 'id']);
          final name = _pick(item, ['name', 'zone_name']);
          return _LookupItem(id, name);
        })
        .where((item) => item.id.isNotEmpty && item.label.isNotEmpty)
        .toList();
  }

  Future<void> _submit() async {
    if (_selectedSubpropertyId == null ||
        _selectedWardId == null ||
        _selectedZoneId == null ||
        _selectedSubpropertyId!.isEmpty ||
        _selectedWardId!.isEmpty ||
        _selectedZoneId!.isEmpty ||
        _latitude.text.trim().isEmpty ||
        _longitude.text.trim().isEmpty ||
        _expectedTime.text.trim().isEmpty) {
      _notify('All fields are required for collection points.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final result = await _api.create(
        ApiConfig.tripCollectionPoints,
        {
          'property_type': _propertyType,
          'subproperty_id': _selectedSubpropertyId!,
          'latitude': _latitude.text.trim(),
          'longitude': _longitude.text.trim(),
          'expected_collection_time': _expectedTime.text.trim(),
          'ward_id': _selectedWardId!,
          'zone_id': _selectedZoneId!,
          'is_active': _isActive,
        },
      );
      _notify(
        'Template saved: ${result['unique_id'] ?? 'Collection point created'}',
      );
    } catch (e) {
      _notify('Failed to create collection point: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _notify(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: _FormCard(
        title: 'Create Collection Point',
        subtitle: 'Static pickup locations (no sequencing).',
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _propertyType,
              decoration: const InputDecoration(labelText: 'Property Type'),
              items: const [
                DropdownMenuItem(value: 'house', child: Text('House')),
                DropdownMenuItem(value: 'industry', child: Text('Industry')),
                DropdownMenuItem(value: 'commercial', child: Text('Commercial')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _propertyType = value);
              },
            ),
            const SizedBox(height: 12),
            if (_loadingLookups)
              const LinearProgressIndicator(minHeight: 2)
            else if (_lookupError != null)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _lookupError!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                  TextButton(
                    onPressed: _loadLookups,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            if (!_loadingLookups && _lookupError == null) ...[
              DropdownButtonFormField<String>(
                value: _selectedSubpropertyId,
                decoration: const InputDecoration(
                  labelText: 'Subproperty',
                ),
                hint: const Text('Select subproperty'),
                items: _subproperties
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.id,
                        child: Text(item.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() => _selectedSubpropertyId = value);
                },
              ),
              if (_subproperties.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'No subproperties available.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _latitude,
              decoration: const InputDecoration(
                labelText: 'Latitude',
                hintText: '11.012345',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _longitude,
              decoration: const InputDecoration(
                labelText: 'Longitude',
                hintText: '76.987654',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _expectedTime,
              decoration: const InputDecoration(
                labelText: 'Expected Collection Time (seconds)',
                hintText: '180',
              ),
            ),
            if (!_loadingLookups && _lookupError == null) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedWardId,
                decoration: const InputDecoration(
                  labelText: 'Ward',
                ),
                hint: const Text('Select ward'),
                items: _wards
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.id,
                        child: Text(item.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() => _selectedWardId = value);
                },
              ),
              if (_wards.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'No wards available.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedZoneId,
                decoration: const InputDecoration(
                  labelText: 'Zone',
                ),
                hint: const Text('Select zone'),
                items: _zones
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.id,
                        child: Text(item.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() => _selectedZoneId = value);
                },
              ),
              if (_zones.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'No zones available.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
            ],
            const SizedBox(height: 12),
            SwitchListTile(
              value: _isActive,
              onChanged: (value) => setState(() => _isActive = value),
              title: const Text('Active'),
            ),
            const SizedBox(height: 8),
            _SubmitButton(
              label: 'Create Collection Point',
              submitting: _submitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _RoutePlanForm extends StatefulWidget {
  const _RoutePlanForm();

  @override
  State<_RoutePlanForm> createState() => _RoutePlanFormState();
}

class _RoutePlanFormState extends State<_RoutePlanForm> {
  final _api = _TripAssignmentApi();
  final _parentRoutePlan = TextEditingController();
  final _vehicleType = TextEditingController();
  List<_LookupItem> _trips = [];
  List<_LookupItem> _zones = [];
  List<_WardLookup> _wards = [];
  String? _selectedTripId;
  String? _selectedZoneId;
  List<String> _selectedWardIds = [];
  String _propertyFilter = 'all';
  bool _loadingLookups = true;
  String? _lookupError;
  bool _submitting = false;

  @override
  void dispose() {
    _parentRoutePlan.dispose();
    _vehicleType.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadLookups();
  }

  Future<void> _loadLookups() async {
    setState(() {
      _loadingLookups = true;
      _lookupError = null;
    });

    try {
      final trips = await _api.list(ApiConfig.tripAssignments);
      final zones = await _api.list(ApiConfig.zones);
      final wards = await _api.list(ApiConfig.wards);

      setState(() {
        _trips = _mapTrips(trips);
        _zones = _mapZones(zones);
        _wards = _mapWards(wards);
        _loadingLookups = false;
      });
    } catch (e) {
      setState(() {
        _lookupError = 'Unable to load data for route planning.';
        _loadingLookups = false;
      });
    }
  }

  String _pick(Map<String, dynamic> item, List<String> keys) {
    for (final key in keys) {
      final value = item[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return '';
  }

  List<_LookupItem> _mapTrips(List<Map<String, dynamic>> items) {
    return items
        .map((item) {
          final id = _pick(item, ['unique_id', 'id']);
          final vehicle = _pick(item, ['vehicle_no', 'vehicle_number']);
          final shift = _pick(item, ['shift_name']);
          final status = _pick(item, ['status']);
          final parts = [
            if (vehicle.isNotEmpty) vehicle,
            if (shift.isNotEmpty) shift,
            if (status.isNotEmpty) status,
          ];
          final label = parts.isNotEmpty ? '${parts.join(' • ')} • $id' : id;
          return _LookupItem(id, label);
        })
        .where((item) => item.id.isNotEmpty && item.label.isNotEmpty)
        .toList();
  }

  List<_LookupItem> _mapZones(List<Map<String, dynamic>> items) {
    return items
        .map((item) {
          final id = _pick(item, ['unique_id', 'id']);
          final name = _pick(item, ['name', 'zone_name']);
          return _LookupItem(id, name);
        })
        .where((item) => item.id.isNotEmpty && item.label.isNotEmpty)
        .toList();
  }

  List<_WardLookup> _mapWards(List<Map<String, dynamic>> items) {
    return items
        .map((item) {
          final id = _pick(item, ['unique_id', 'id']);
          final name = _pick(item, ['name', 'ward_name']);
          final zoneName = _pick(item, ['zone_name']);
          final label = zoneName.isNotEmpty ? '$name • $zoneName' : name;
          final zoneId = _pick(item, ['zone_id']);
          return _WardLookup(id, label, zoneId.isEmpty ? null : zoneId);
        })
        .where((item) => item.id.isNotEmpty && item.label.isNotEmpty)
        .toList();
  }

  List<_WardLookup> get _filteredWards {
    if (_selectedZoneId == null || _selectedZoneId!.isEmpty) {
      return _wards;
    }
    return _wards.where((ward) => ward.zoneId == _selectedZoneId).toList();
  }

  Future<void> _openWardPicker() async {
    final selected = Set<String>.from(_selectedWardIds);
    final available = _filteredWards;
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Select Wards',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    child: available.isEmpty
                        ? Center(
                            child: Text(
                              'No wards available.',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          )
                        : ListView.builder(
                            itemCount: available.length,
                            itemBuilder: (context, index) {
                              final ward = available[index];
                              final checked = selected.contains(ward.id);
                              return CheckboxListTile(
                                value: checked,
                                title: Text(ward.label),
                                onChanged: (value) {
                                  setSheetState(() {
                                    if (value == true) {
                                      selected.add(ward.id);
                                    } else {
                                      selected.remove(ward.id);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              selected.clear();
                              setSheetState(() {});
                            },
                            child: const Text('Clear'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2E7D32),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Apply'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (!mounted) return;
    setState(() {
      _selectedWardIds = selected.toList();
    });
  }

  Future<void> _submit() async {
    if (_selectedTripId == null || _selectedTripId!.isEmpty) {
      _notify('Trip is required.');
      return;
    }
    if (_vehicleType.text.trim().isEmpty) {
      _notify('Vehicle type is required.');
      return;
    }
    if (_selectedZoneId == null || _selectedZoneId!.isEmpty) {
      _notify('Zone is required.');
      return;
    }
    if (_selectedWardIds.isEmpty) {
      _notify('Select at least one ward.');
      return;
    }

    final payload = {
      'trip_id': _selectedTripId!,
      'vehicle_type': _vehicleType.text.trim(),
      'zone_id': _selectedZoneId!,
      'ward_ids': _selectedWardIds,
      'property_type_filter': _propertyFilter,
      'generated_by': 'ORS',
      'generated_reason': 'AUTO',
    };

    if (_parentRoutePlan.text.trim().isNotEmpty) {
      payload['parent_route_plan_id'] = _parentRoutePlan.text.trim();
    }

    setState(() => _submitting = true);
    try {
      final result =
          await _api.create(ApiConfig.tripRoutePlanGenerate, payload);
      final plan = result['route_plan'] as Map?;
      final planId = plan?['unique_id'] ?? 'OK';
      final stopCount = (result['planned_stops'] as List?)?.length ?? 0;
      _notify('Route plan $planId created with $stopCount stops');
    } on DioException catch (e) {
      _notify(_formatDioError(e));
    } catch (e) {
      _notify('Failed to generate route plan: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _formatDioError(DioException error) {
    final data = error.response?.data;
    if (data is Map) {
      final detail = data['detail'];
      if (detail != null) {
        return detail.toString();
      }
      if (data.isNotEmpty) {
        final firstValue = data.values.first;
        if (firstValue is List && firstValue.isNotEmpty) {
          return firstValue.first.toString();
        }
        if (firstValue != null) {
          return firstValue.toString();
        }
      }
    }
    return error.message ?? 'Request failed. Please try again.';
  }

  void _notify(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: _FormCard(
        title: 'Generate Route Plan',
        subtitle: 'Select trip, property filter, zone, and wards.',
        child: Column(
          children: [
            if (_loadingLookups)
              const LinearProgressIndicator(minHeight: 2)
            else if (_lookupError != null)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _lookupError!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                  TextButton(
                    onPressed: _loadLookups,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            if (!_loadingLookups && _lookupError == null) ...[
              DropdownButtonFormField<String>(
                value: _selectedTripId,
                decoration: const InputDecoration(labelText: 'Trip'),
                hint: const Text('Select trip'),
                items: _trips
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.id,
                        child: Text(item.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() => _selectedTripId = value);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _propertyFilter,
                decoration: const InputDecoration(labelText: 'Property Filter'),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All')),
                  DropdownMenuItem(value: 'house', child: Text('House')),
                  DropdownMenuItem(value: 'industry', child: Text('Industry')),
                  DropdownMenuItem(value: 'commercial', child: Text('Commercial')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _propertyFilter = value);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _vehicleType,
                decoration: const InputDecoration(
                  labelText: 'Vehicle Type',
                  hintText: 'Compactor',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedZoneId,
                decoration: const InputDecoration(labelText: 'Zone'),
                hint: const Text('Select zone'),
                items: _zones
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.id,
                        child: Text(item.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedZoneId = value;
                    _selectedWardIds = _selectedWardIds
                        .where(
                          (id) => _filteredWards.any((ward) => ward.id == id),
                        )
                        .toList();
                  });
                },
              ),
              if (_zones.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'No zones available.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Wards',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_selectedWardIds.isEmpty)
                    Text(
                      'No wards selected',
                      style: TextStyle(color: Colors.grey.shade600),
                    )
                  else
                    ..._selectedWardIds.map(
                      (id) => Chip(
                        label: Text(
                          _filteredWards
                              .firstWhere(
                                (w) => w.id == id,
                                orElse: () => _WardLookup(id, id, null),
                              )
                              .label,
                        ),
                        onDeleted: () {
                          setState(() {
                            _selectedWardIds.remove(id);
                          });
                        },
                      ),
                    ),
                  ActionChip(
                    label: const Text('Select Wards'),
                    onPressed: _openWardPicker,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _parentRoutePlan,
                decoration: const InputDecoration(
                  labelText: 'Parent Route Plan ID (optional)',
                  hintText: 'ROUTEPLAN-xxxx',
                ),
              ),
              const SizedBox(height: 16),
              _SubmitButton(
                label: 'Generate Route Plan',
                submitting: _submitting,
                onPressed: _submit,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlannedStopForm extends StatefulWidget {
  const _PlannedStopForm();

  @override
  State<_PlannedStopForm> createState() => _PlannedStopFormState();
}

class _PlannedStopFormState extends State<_PlannedStopForm> {
  final _api = _TripAssignmentApi();
  final _routePlanId = TextEditingController();
  final _collectionPointId = TextEditingController();
  final _sequenceNumber = TextEditingController();
  final _plannedEta = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _routePlanId.dispose();
    _collectionPointId.dispose();
    _sequenceNumber.dispose();
    _plannedEta.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_routePlanId.text.trim().isEmpty ||
        _collectionPointId.text.trim().isEmpty ||
        _sequenceNumber.text.trim().isEmpty) {
      _notify('Route plan, collection point, and sequence are required.');
      return;
    }

    final payload = <String, dynamic>{
      'route_plan_id': _routePlanId.text.trim(),
      'collection_point_id': _collectionPointId.text.trim(),
      'planned_sequence_number': _sequenceNumber.text.trim(),
    };

    if (_plannedEta.text.trim().isNotEmpty) {
      payload['planned_eta'] = _plannedEta.text.trim();
    }

    setState(() => _submitting = true);
    try {
      final result = await _api.create(ApiConfig.tripPlannedStops, payload);
      _notify('Planned stop created: ${result['unique_id'] ?? 'OK'}');
    } catch (e) {
      _notify('Failed to create planned stop: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _notify(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: _FormCard(
        title: 'Create Planned Route Stop',
        subtitle: 'Manual stop creation (sequence is contextual).',
        child: Column(
          children: [
            TextField(
              controller: _routePlanId,
              decoration: const InputDecoration(
                labelText: 'Route Plan ID',
                hintText: 'ROUTEPLAN-xxxx',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _collectionPointId,
              decoration: const InputDecoration(
                labelText: 'Collection Point ID',
                hintText: 'CP-xxxx',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _sequenceNumber,
              decoration: const InputDecoration(
                labelText: 'Planned Sequence Number',
                hintText: '1',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _plannedEta,
              decoration: const InputDecoration(
                labelText: 'Planned ETA (optional)',
                hintText: 'YYYY-MM-DD HH:MM',
              ),
            ),
            const SizedBox(height: 16),
            _SubmitButton(
              label: 'Create Planned Stop',
              submitting: _submitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _GeometryForm extends StatefulWidget {
  const _GeometryForm();

  @override
  State<_GeometryForm> createState() => _GeometryFormState();
}

class _GeometryFormState extends State<_GeometryForm> {
  final _api = _TripAssignmentApi();
  final _routePlanId = TextEditingController();
  final _encodedPolyline = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _routePlanId.dispose();
    _encodedPolyline.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_routePlanId.text.trim().isEmpty ||
        _encodedPolyline.text.trim().isEmpty) {
      _notify('Route plan ID and encoded polyline are required.');
      return;
    }

    setState(() => _submitting = true);
    try {
      await _api.create(
        ApiConfig.tripRouteGeometry,
        {
          'route_plan_id': _routePlanId.text.trim(),
          'encoded_polyline': _encodedPolyline.text.trim(),
        },
      );
      _notify('Geometry cached successfully.');
    } catch (e) {
      _notify('Failed to cache geometry: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _notify(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class _ExecutionStopForm extends StatefulWidget {
  const _ExecutionStopForm();

  @override
  State<_ExecutionStopForm> createState() => _ExecutionStopFormState();
}

class _ExecutionStopFormState extends State<_ExecutionStopForm> {
  final _api = _TripAssignmentApi();
  final _tripId = TextEditingController();
  final _plannedStopId = TextEditingController();
  final _actualSequence = TextEditingController();
  final _arrivedAt = TextEditingController();
  final _collectedAt = TextEditingController();
  final _skippedReason = TextEditingController();
  final _wasteQuantity = TextEditingController();
  final _gpsLat = TextEditingController();
  final _gpsLng = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _tripId.dispose();
    _plannedStopId.dispose();
    _actualSequence.dispose();
    _arrivedAt.dispose();
    _collectedAt.dispose();
    _skippedReason.dispose();
    _wasteQuantity.dispose();
    _gpsLat.dispose();
    _gpsLng.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_tripId.text.trim().isEmpty) {
      _notify('Trip ID is required.');
      return;
    }

    final payload = <String, dynamic>{
      'trip_id': _tripId.text.trim(),
    };

    if (_plannedStopId.text.trim().isNotEmpty) {
      payload['planned_route_stop_id'] = _plannedStopId.text.trim();
    }
    if (_actualSequence.text.trim().isNotEmpty) {
      payload['actual_sequence_number'] = _actualSequence.text.trim();
    }
    if (_arrivedAt.text.trim().isNotEmpty) {
      payload['arrived_at'] = _arrivedAt.text.trim();
    }
    if (_collectedAt.text.trim().isNotEmpty) {
      payload['collected_at'] = _collectedAt.text.trim();
    }
    if (_skippedReason.text.trim().isNotEmpty) {
      payload['skipped_reason'] = _skippedReason.text.trim();
    }
    if (_wasteQuantity.text.trim().isNotEmpty) {
      payload['waste_quantity'] = _wasteQuantity.text.trim();
    }
    if (_gpsLat.text.trim().isNotEmpty) {
      payload['gps_lat'] = _gpsLat.text.trim();
    }
    if (_gpsLng.text.trim().isNotEmpty) {
      payload['gps_lng'] = _gpsLng.text.trim();
    }

    setState(() => _submitting = true);
    try {
      final result = await _api.create(ApiConfig.tripExecutionStops, payload);
      _notify('Execution stop logged: ${result['unique_id'] ?? 'OK'}');
    } catch (e) {
      _notify('Failed to log execution stop: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _notify(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
