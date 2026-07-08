// operator_data_screen.dart
// 🚀 FIXED: Prevents UI from disappearing if API returns empty list
// ✅ Retains the 1-second Bluetooth delay you added
// ✅ Keeps Customer Details visible at all times

import 'dart:convert';
import 'dart:io';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:iwms_citizen_app/core/di.dart';
import 'package:iwms_citizen_app/core/theme/app_colors.dart';
import 'package:iwms_citizen_app/core/theme/app_text_styles.dart';
import 'package:iwms_citizen_app/router/route_observer.dart';
import 'package:iwms_citizen_app/router/app_router.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:iwms_citizen_app/shared/models/collection_history.dart';
import 'package:iwms_citizen_app/shared/services/collection_history_service.dart';
import 'package:iwms_citizen_app/modules/module3_operator/offline/pending_finalize_dao.dart';
import 'package:iwms_citizen_app/modules/module3_operator/offline/pending_finalize_record.dart';
import 'package:iwms_citizen_app/modules/module3_operator/offline/offline_sync_service.dart';
import 'package:iwms_citizen_app/modules/module3_operator/offline/pending_record.dart';
import 'package:iwms_citizen_app/modules/module3_operator/offline/pending_record_dao.dart';
import 'package:iwms_citizen_app/modules/module3_operator/services/bluetoothservices.dart';
import 'package:iwms_citizen_app/modules/module3_operator/services/generateunique_id.dart';
import 'package:iwms_citizen_app/modules/module3_operator/services/image_compress_service.dart';
import 'package:iwms_citizen_app/modules/module2_driver/presentation/theme/captain_theme.dart';
import 'package:iwms_citizen_app/core/network/authorized_dio.dart';
import 'package:iwms_citizen_app/core/api_config.dart';
import 'package:iwms_citizen_app/data/repositories/auth_repository.dart';
import 'package:iwms_citizen_app/modules/module3_operator/utils/assignment_status_store.dart';

const BorderRadius _kOperatorCardRadius = BorderRadius.all(Radius.circular(18));

class OperatorDataScreen extends StatefulWidget {
  final String customerId;
  final String customerName;
  final String contactNo;
  final String latitude;
  final String longitude;
  final bool skipBluetoothInit;
  final String? assignmentId;

  const OperatorDataScreen({
    super.key,
    required this.customerId,
    required this.customerName,
    required this.contactNo,
    required this.latitude,
    required this.longitude,
    this.skipBluetoothInit = false,
    this.assignmentId,
  });

  @override
  State<OperatorDataScreen> createState() => _OperatorDataScreenState();
}

class _OperatorDataScreenState extends State<OperatorDataScreen>
    with WidgetsBindingObserver, RouteAware {
  final ImagePicker _picker = ImagePicker();
  late String screenUniqueId;
  final PendingFinalizeDao _finalizeDao = PendingFinalizeDao();
  final bluetooth = BluetoothService();
  bool connected = false;
  String latestWeight = "--";
  bool _isSubmitting = false;
  BluetoothConnection? _connection;
  // Classic Bluetooth SPP (flutter_bluetooth_serial) is Android-only. On iOS we
  // hide the scale UI and use manual entry. The scale modules (HC-05 / AEBT)
  // are not Apple-MFi, so iOS classic SPP is not possible.
  bool get _bluetoothSupported => Platform.isAndroid;
  bool _btConnecting = false;
  String? _connectedDeviceName;
  String? activeType; // currently selected waste type
  late final OfflineSyncService _syncService;
  final PendingRecordDao _pendingDao = PendingRecordDao();
  late final CollectionHistoryService _historyService;
  bool _collectionSubmitted = false;
  bool _routeObserverSubscribed = false;
  final Map<String, TextEditingController> _manualWeightControllers = {};

  List<Map<String, dynamic>> wasteTypes = [];
  Map<String, Map<String, dynamic>> _wasteData = {};

  bool _canApplyLiveWeight(String type) {
    final item = _wasteData[type];
    if (item == null) return false;
    return item['isAdded'] != true || item['finalWeight'] == null;
  }

  // ✅ Define defaults as final so we can reuse them safely
  final List<Map<String, dynamic>> defaultWasteTypes = [
    {"id": 1, "waste_type_name": "Wet"},
    {"id": 2, "waste_type_name": "Dry"},
    {"id": 3, "waste_type_name": "Mixed"},
  ];

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  /// Bearer token for the logged-in operator. The `/api/v1/waste/...`
  /// endpoints are auth-only on the backend, so every request must carry it.
  Future<Map<String, String>> _authHeaders() async {
    try {
      final user = await getIt<AuthRepository>().getAuthenticatedUser();
      final token = user?.authToken?.trim();
      if (token != null && token.isNotEmpty) {
        return {'Authorization': 'Bearer $token'};
      }
    } catch (_) {}
    return const {};
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    screenUniqueId = UniqueIdService.generateScreenUniqueId();
    _wasteData.clear();

    latestWeight = "--";
    _historyService = getIt<CollectionHistoryService>();

    // ✅ Initialize with defaults immediately so UI is never empty
    _applyWasteTypes(defaultWasteTypes);

    if (_bluetoothSupported && !widget.skipBluetoothInit) {
      // 🔁 Bluetooth adapter re-init with 1s Delay (Android only)
      Future.delayed(const Duration(seconds: 1), () async {
        if (!await _ensureBluetoothPermissions()) return;
        debugPrint("♻️ Reinitializing Bluetooth adapter...");
        await FlutterBluetoothSerial.instance.cancelDiscovery();
        final isEnabled =
            await FlutterBluetoothSerial.instance.isEnabled ?? false;
        if (!isEnabled) {
          try {
            await FlutterBluetoothSerial.instance.requestEnable();
          } catch (e) {
            debugPrint("⚠️ Unable to prompt for Bluetooth enable: $e");
          }
        }
        await _resetBluetooth();
        await _initBluetooth();
      });
    }

    _syncService = OfflineSyncService(
      recordDao: _pendingDao,
      finalizeDao: _finalizeDao,
      baseUrl: '${ApiConfig.desktopBase}waste',
    )..start();

    // Fetch latest types from API
    _fetchWasteTypes();
  }

  // ==================== FETCH WASTE TYPES ====================
  Future<void> _fetchWasteTypes() async {
    // Start with defaults. We only overwrite if API gives valid NON-EMPTY data.
    List<Map<String, dynamic>> resolvedTypes = defaultWasteTypes;

    try {
      final response = await http
          .get(
            Uri.parse(
              '${ApiConfig.desktopBase}waste/get-waste-types/',
            ),
            headers: await _authHeaders(),
          )
          .timeout(const Duration(seconds: 5));

      final data = json.decode(response.body);

      if (data['status'] == 'success' && data['data'] != null) {
        final fetched = List<Map<String, dynamic>>.from(data['data']);

        // ✅ CRITICAL FIX: Only use API data if it's NOT empty.
        // If API returns [], we keep the defaults.
        if (fetched.isNotEmpty) {
          resolvedTypes = fetched;
        } else {
          debugPrint(
              '⚠️ API returned empty waste types list. Keeping defaults.');
        }
      }
    } catch (e) {
      debugPrint('⚠ Waste type API failed, using fallback defaults: $e');
      // resolvedTypes remains defaultWasteTypes
    }

    if (!mounted) return;
    _applyWasteTypes(resolvedTypes);
    _safeSetState(() {});

    // Load offline data after the first paint to keep the screen responsive.
    Future.microtask(_loadOfflineForScreen);
  }

  Future<void> _loadOfflineForScreen() async {
    debugPrint("🔄 Loading offline records for screen: $screenUniqueId");

    final offlineRecords = await _pendingDao.getByScreen(screenUniqueId);

    // nothing to load → just refresh UI
    if (offlineRecords.isEmpty) {
      _safeSetState(() {});
      return;
    }

    for (var r in offlineRecords) {
      // only records for this screen
      if (r.screenId != screenUniqueId) continue;

      final type = wasteTypes.firstWhere(
        (w) => w['id'].toString() == r.wasteTypeId,
        orElse: () => {},
      );
      if (type.isEmpty) continue;

      final typeKey = type['waste_type_name'].toString().trim().toLowerCase();

      if (!_wasteData.containsKey(typeKey)) continue;

      // Build updated map
      final updated = Map<String, dynamic>.from(_wasteData[typeKey]!);

      // UID must never be null for UI logic
      final safeUid = r.uniqueId;

      updated['isAdded'] = true;
      updated['unique_id'] = safeUid;

      updated['weight'] = r.weight;
      updated['finalWeight'] = r.weight; // always override stale values
      updated['image'] = File(r.imagePath);

      _wasteData = {..._wasteData, typeKey: updated};
      _syncManualWeightController(typeKey, r.weight.toString());

      debugPrint(
          "📌 Loaded offline → $typeKey | weight=${r.weight} | uid=$safeUid");
    }

    _safeSetState(() {});
  }

  void _syncManualWeightController(String type, String? value) {
    final controller = _manualWeightControllers[type];
    if (controller == null) return;
    final text = value?.toString() ?? '';
    if (controller.text != text) {
      controller.text = text;
    }
  }

  String _weightTextFor(String type) {
    final item = _wasteData[type];
    if (item == null) return '';
    final value = item['finalWeight'] ?? item['weight'];
    return value == '--' || value == null ? '' : value.toString();
  }

  void _updateManualWeight(String type, String raw) {
    final trimmed = raw.trim();
    if (!_wasteData.containsKey(type)) return;
    final updated = Map<String, dynamic>.from(_wasteData[type]!);
    updated['weight'] = trimmed.isEmpty ? '--' : trimmed;
    updated['finalWeight'] = trimmed.isEmpty ? null : trimmed;
    _wasteData = {
      ..._wasteData,
      type: updated,
    };
    if (trimmed.isNotEmpty) {
      latestWeight = trimmed;
    }
  }

  void _startEditingAddedWeight(String type) {
    if (!_wasteData.containsKey(type)) return;
    final current = _wasteData[type]!;
    if (current['isAdded'] != true) return;

    final updated = Map<String, dynamic>.from(current);
    updated['finalWeight'] = null;
    if (latestWeight != '--') {
      updated['weight'] = latestWeight;
    }

    _wasteData = {
      ..._wasteData,
      type: updated,
    };
    activeType = type;
    _syncManualWeightController(type, _weightTextFor(type));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (!_routeObserverSubscribed && route is PageRoute) {
      routeObserver.subscribe(this, route);
      _routeObserverSubscribed = true;
    }
  }

  Future<void> _resetBluetooth() async {
    try {
      if (_connection != null) {
        await _connection!.close();
        _connection = null;
        connected = false;
        _connectedDeviceName = null;
        debugPrint("🔌 Bluetooth connection reset successfully");
      }
    } catch (e) {
      debugPrint("⚠️ Error while resetting Bluetooth: $e");
    }
  }

  @override
  void dispose() {
    if (_routeObserverSubscribed) {
      routeObserver.unsubscribe(this);
      _routeObserverSubscribed = false;
    }
    WidgetsBinding.instance.removeObserver(this);
    try {
      _connection?.dispose();
      connected = false;
    } catch (_) {}
    for (final controller in _manualWeightControllers.values) {
      controller.dispose();
    }
    _syncService.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    debugPrint("🔄 Returned → reconnecting");
    if (_bluetoothSupported && !connected) {
      _reconnectBluetoothWithRetry();
    }
  }

  Future<void> _reconnectBluetoothWithRetry({int retries = 3}) async {
    for (int i = 0; i < retries; i++) {
      await Future.delayed(const Duration(seconds: 2));
      try {
        await _resetBluetooth();
        await _initBluetooth();
        if (connected) {
          debugPrint("✅ Reconnected on attempt ${i + 1}");
          return;
        }
      } catch (e) {
        debugPrint("⚠️ Retry ${i + 1} failed: $e");
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_bluetoothSupported &&
        state == AppLifecycleState.resumed &&
        !connected) {
      _initBluetooth();
    }
  }

  void _applyWasteTypes(List<Map<String, dynamic>> types) {
    wasteTypes = types;
    _wasteData = {
      for (var item in wasteTypes)
        item['waste_type_name'].toString().trim().toLowerCase(): {
          'waste_type_id': item['id'],
          'label': item['waste_type_name'],
          'unique_id': null,
          'image': null,
          'weight': '--',
          'finalWeight': null,
          'isAdded': false,
        }
    };

    _manualWeightControllers.clear();
    for (final type in _wasteData.keys) {
      _manualWeightControllers[type] =
          TextEditingController(text: _weightTextFor(type));
    }
  }

  Future<void> _fetchWasteRecord(String type) async {
    try {
      final uri = Uri.parse('${ApiConfig.desktopBase}waste/get-latest-waste/');
      final response =
          await http.post(uri, headers: await _authHeaders(), body: {
        'screen_unique_id': screenUniqueId,
        'customer_id': widget.customerId,
        'waste_type': _wasteData[type]!['waste_type_id'].toString(),
        'waste_type_id': _wasteData[type]!['waste_type_id'].toString(),
      });

      final data = json.decode(response.body);
      if (data['status'] == 'success' && data['data'] != null) {
        final record = data['data'];

        _safeSetState(() {
          final updated = Map<String, dynamic>.from(_wasteData[type]!);
          updated['unique_id'] = record['unique_id'];
          updated['waste_type_id'] = _wasteData[type]!['waste_type_id'];
          updated['weight'] = record['weight'] ?? '--';
          updated['finalWeight'] = record['weight'] ?? '--';
          updated['isAdded'] = true;

          _wasteData = {..._wasteData, type: updated};
          _syncManualWeightController(type, updated['weight']?.toString());
        });

        debugPrint('✅ Backend weight for $type: ${record['weight']}');
      } else {
        debugPrint('⚠️ No record found for $type: ${data['message']}');
      }
    } catch (e) {
      debugPrint('⚠️ Error fetching record for $type: $e');
    }
  }

  Future<void> _handleAdd(String type) async {
    final data = _wasteData[type]!;
    final image = data['image'] as File?;
    final wasteTypeId = data['waste_type_id']?.toString() ?? '';

    if (image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Capture image for $type first')),
      );
      return;
    }

    if (wasteTypeId.isEmpty || wasteTypeId == 'null') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Missing waste type for $type')),
      );
      return;
    }

    final weightValue = data['weight']?.toString() ?? '--';
    if (weightValue.isEmpty || weightValue == "--") {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please ensure weight is recorded for $type')),
      );
      return;
    }

    final weight = weightValue;
    final isUpdate = data['isAdded'] == true;
    final uniqueId = data['unique_id']?.toString();

    _safeSetState(() => _isSubmitting = true);

    try {
      final uri = Uri.parse(
        isUpdate
            ? '${ApiConfig.desktopBase}waste/update-waste-sub/'
            : '${ApiConfig.desktopBase}waste/insert-waste-sub/',
      );

      debugPrint(
          "▶️ _handleAdd($type) → isUpdate=$isUpdate, unique_id=$uniqueId");

      final request = http.MultipartRequest('POST', uri)
        ..headers.addAll(await _authHeaders())
        ..fields['screen_unique_id'] = screenUniqueId
        ..fields['customer_id'] = widget.customerId
        ..fields['waste_type'] = wasteTypeId
        ..fields['waste_type_id'] = wasteTypeId
        ..fields['weight'] = weight
        ..fields['latitude'] = widget.latitude
        ..fields['longitude'] = widget.longitude;

      if (isUpdate && uniqueId != null) {
        request.fields['unique_id'] = uniqueId;
      }

      request.files.add(await http.MultipartFile.fromPath('image', image.path));

      final streamed = await request.send();

      if (streamed.statusCode >= 400) {
        throw Exception("Server error ${streamed.statusCode}");
      }

      final response = await http.Response.fromStream(streamed);
      dynamic result;
      try {
        result = json.decode(response.body);
      } catch (_) {
        throw Exception("Invalid JSON from backend");
      }

      if (result['status'] != 'success') {
        throw Exception(result['message'] ?? "Unknown server error");
      }

      final backendUnique = result['unique_id']?.toString();

      _safeSetState(() {
        final updated = Map<String, dynamic>.from(data);
        updated['isAdded'] = true;
        updated['finalWeight'] = weight;

        if (backendUnique != null) {
          updated['unique_id'] = backendUnique;
        }

        _wasteData[type] = updated;
        if (activeType == type) {
          activeType = null;
        }
      });

      await _fetchWasteRecord(type);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isUpdate
                ? "$type updated successfully"
                : "$type added successfully",
          ),
        ),
      );

      return;
    } catch (err) {
      debugPrint("⚠️ _handleAdd offline mode triggered: $err");

      final record = PendingRecord(
        screenId: screenUniqueId,
        customerId: widget.customerId,
        customerName: widget.customerName,
        contactNo: widget.contactNo,
        wasteTypeId: data['waste_type_id'].toString(),
        weight: weight,
        latitude: double.tryParse(widget.latitude),
        longitude: double.tryParse(widget.longitude),
        imagePath: image.path,
        isUpdate: isUpdate,
        uniqueId: uniqueId ?? "uid_${DateTime.now().millisecondsSinceEpoch}",
      );

      final existing = await _pendingDao.findByTypeAndScreen(
        wasteTypeId: data['waste_type_id'].toString(),
        screenId: screenUniqueId,
      );

      if (existing != null) {
        await _pendingDao.update(
          existing.copyWith(
            weight: weight,
            imagePath: image.path,
            isUpdate: true,
            uniqueId: existing.uniqueId,
          ),
        );
      } else {
        await _pendingDao.insert(record);
      }

      await _loadOfflineForScreen();
      if (activeType == type) {
        _safeSetState(() => activeType = null);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("$type saved offline — will sync automatically"),
        ),
      );
    } finally {
      _safeSetState(() => _isSubmitting = false);
    }
  }

  Future<void> _resetUI() async {
    _safeSetState(() {
      latestWeight = "--";
      activeType = null;
      screenUniqueId = UniqueIdService.generateScreenUniqueId();

      _wasteData = {
        for (var item in wasteTypes)
          item['waste_type_name'].toString().trim().toLowerCase(): {
            'waste_type_id': item['id'],
            'unique_id': null,
            'image': null,
            'weight': '--',
            'finalWeight': null,
            'isAdded': false,
          }
      };
    });
    debugPrint("🔄 UI reset completed. Ready for next customer.");
  }

  // ==================== SUBMIT MAIN FORM ====================
  Future<void> _submitForm() async {
    _safeSetState(() => _isSubmitting = true);

    final totalWeight = _calculateTotalWeight();
    final summary = _buildSummarySnapshot();
    Future<void> syncLog(String status) async {
      if (!ApiConfig.legacyRoleAssignEnabled) return;
      if (widget.assignmentId == null || widget.assignmentId!.trim().isEmpty) {
        return;
      }
      try {
        final dio = await authorizedDio();
        final latitude = widget.latitude.trim();
        final longitude = widget.longitude.trim();
        await dio.post(
          ApiConfig.assignmentCustomerStatuses,
          data: {
            'assignment': widget.assignmentId,
            'customer': widget.customerId,
            'status': status == 'collection_completed' ? 'collected' : status,
            if (latitude.isNotEmpty) 'latitude': latitude,
            if (longitude.isNotEmpty) 'longitude': longitude,
          },
        );
      } catch (_) {
        // best-effort; ignore
      }
    }

    try {
      final uri = Uri.parse('${ApiConfig.desktopBase}waste/finalize-waste/');

      final request = http.MultipartRequest('POST', uri)
        ..headers.addAll(await _authHeaders())
        ..fields['screen_unique_id'] = screenUniqueId
        ..fields['customer_id'] = widget.customerId
        ..fields['entry_type'] = 'app'
        ..fields['total_waste_collected'] = totalWeight.toString();

      final response = await request.send();
      final result =
          json.decode((await http.Response.fromStream(response)).body);

      if (result['status'] == 'success') {
        await _recordCollectionHistory(totalWeight);
        _collectionSubmitted = true;
        if (widget.assignmentId != null &&
            widget.assignmentId!.trim().isNotEmpty) {
          await AssignmentStatusStore.setStatusForAssignment(
            widget.assignmentId!,
            widget.customerId,
            'collected',
          );
          await syncLog('collection_completed');
          await _maybeCompleteAssignmentFromStore(widget.assignmentId!);
        }
        await _showSuccessSheet(totalWeight, summary);
        _resetUI();
        // Fetch types again just in case, but keep defaults if fail
        _fetchWasteTypes();
      } else {
        throw Exception(result['message']);
      }
    } catch (e) {
      debugPrint("⚠️ Finalize failed, storing offline: $e");

      final pendingFinalize = PendingFinalizeRecord(
        screenId: screenUniqueId,
        customerId: widget.customerId,
        totalWeight: _calculateTotalWeight(),
        entryType: "app",
      );

      await _finalizeDao.insert(pendingFinalize);
      _collectionSubmitted = true;

      try {
        if (await _syncService.hasInternet()) {
          await _syncService.syncAll();
        }
      } catch (err) {
        debugPrint("⚠️ Sync attempt failed: $err");
      }

      await _recordCollectionHistory(totalWeight);
      if (widget.assignmentId != null &&
          widget.assignmentId!.trim().isNotEmpty) {
        await AssignmentStatusStore.setStatusForAssignment(
          widget.assignmentId!,
          widget.customerId,
          'collected',
        );
        await syncLog('collection_completed');
        await _maybeCompleteAssignmentFromStore(widget.assignmentId!);
      }
      await _showSuccessSheet(totalWeight, summary, offline: true);
      _resetUI();
      _fetchWasteTypes();
    } finally {
      _safeSetState(() => _isSubmitting = false);
    }
  }

  double _calculateTotalWeight() {
    return _wasteData.values.fold<double>(0, (sum, e) {
      final w = double.tryParse(
              e['finalWeight']?.toString() ?? e['weight'].toString()) ??
          0;
      return sum + w;
    });
  }

  Future<void> _maybeCompleteAssignmentFromStore(String assignmentId) async {
    final trimmedId = assignmentId.trim();
    if (trimmedId.isEmpty) return;
    final alreadyCompleted =
        await AssignmentStatusStore.isAssignmentCompleted(trimmedId);
    if (alreadyCompleted) return;

    final customerIds = await _fetchAssignmentCustomerIds(trimmedId);
    if (customerIds.isEmpty) return;

    final statuses =
        await AssignmentStatusStore.getStatusesFor(trimmedId, customerIds);
    final allDone = customerIds.every((id) {
      final status = statuses[id]?.toLowerCase();
      return status == 'collected' || status == 'skipped';
    });
    if (!allDone) return;

    await AssignmentStatusStore.setAssignmentCompleted(trimmedId);
    await _markAssignmentComplete(trimmedId);
  }

  Future<List<String>> _fetchAssignmentCustomerIds(String assignmentId) async {
    if (!ApiConfig.legacyRoleAssignEnabled) return [];

    try {
      final dio = await authorizedDio();
      final assignmentResp =
          await dio.get('${ApiConfig.assignments}$assignmentId/');
      final assignmentData = assignmentResp.data;
      String wardId = '';
      if (assignmentData is Map) {
        wardId = (assignmentData['ward'] ?? assignmentData['ward_id'] ?? '')
            .toString();
      }
      if (wardId.trim().isEmpty) return [];

      List<dynamic> list = [];

      Future<void> fetchWithParam(String paramKey) async {
        final resp = await dio.get(
          ApiConfig.customerList,
          queryParameters: {paramKey: wardId},
        );
        final decoded = resp.data;
        list = decoded is List
            ? decoded
            : (decoded is Map
                ? (decoded['results'] ?? decoded['data'] ?? [])
                : []);
      }

      try {
        await fetchWithParam('ward');
        if (list.isEmpty) {
          await fetchWithParam('ward_id');
        }
      } catch (_) {
        // ignore
      }

      final ids = <String>[];
      for (final entry in list) {
        if (entry is! Map) continue;
        final id =
            (entry['unique_id'] ?? entry['customer_id'] ?? '').toString();
        if (id.isEmpty) continue;
        ids.add(id);
      }
      return ids;
    } catch (_) {
      return [];
    }
  }

  Future<void> _markAssignmentComplete(String assignmentId) async {
    if (!ApiConfig.legacyRoleAssignEnabled) return;

    try {
      final dio = await authorizedDio();
      await dio.post('${ApiConfig.assignments}$assignmentId/complete/');
    } catch (_) {
      // best-effort
    }
  }

  Future<void> _recordCollectionHistory(double totalWeight) async {
    final sections = _wasteData.entries
        .map((entry) {
          final resolvedWeight = _weightFromEntry(entry.value);
          if (resolvedWeight <= 0) return null;
          final label =
              entry.value['label']?.toString() ?? entry.key.toUpperCase();
          final image = entry.value['image'] as File?;
          return CollectionHistorySection(
            type: label,
            weight: resolvedWeight.toStringAsFixed(2),
            imagePath: image?.path,
          );
        })
        .whereType<CollectionHistorySection>()
        .toList();

    if (sections.isEmpty) return;

    final entry = CollectionHistoryEntry(
      customerId: widget.customerId,
      customerName: widget.customerName,
      collectedAt: DateTime.now(),
      sections: sections,
      totalWeight: totalWeight,
    );

    await _historyService.addEntry(entry);
  }

  double _weightFromEntry(Map<String, dynamic> entry) {
    final source = entry['finalWeight'] ?? entry['weight'];
    if (source == null) return 0;
    return double.tryParse(source.toString()) ?? 0;
  }

  Map<String, double> _buildSummarySnapshot() {
    final Map<String, double> totals = {'wet': 0, 'dry': 0, 'mixed': 0};

    _wasteData.forEach((key, value) {
      final weight = _weightFromEntry(value);

      if (key.contains('wet')) {
        totals['wet'] = (totals['wet'] ?? 0) + weight;
      } else if (key.contains('dry')) {
        totals['dry'] = (totals['dry'] ?? 0) + weight;
      } else {
        totals['mixed'] = (totals['mixed'] ?? 0) + weight;
      }
    });

    return totals;
  }

  Future<void> _showSuccessSheet(
    double totalWeight,
    Map<String, double> summary, {
    bool offline = false,
  }) async {
    if (!mounted) return;
    final theme = Theme.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: true,
      showDragHandle: true,
      isScrollControlled: true, // Allow full height
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        return SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      offline ? Icons.cloud_off : Icons.check_circle,
                      color: offline ? Colors.orange : Colors.green,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      offline ? 'Saved offline' : 'Collection recorded',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Total: ${totalWeight.toStringAsFixed(2)} kg',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    _pill('Wet', summary['wet'] ?? 0, Colors.blue),
                    _pill('Dry', summary['dry'] ?? 0, Colors.green),
                    _pill('Mixed', summary['mixed'] ?? 0, Colors.orange),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          context.go(AppRoutePaths.operatorHome);
                        },
                        icon: const Icon(Icons.home),
                        label: const Text('Back to home'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                        },
                        child: const Text('Close'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _pill(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        '$label ${value.toStringAsFixed(2)} kg',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildCollectionHeader({
    required int addedCount,
    required double totalWeight,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: CaptainTheme.headerGradient,
        borderRadius: CaptainTheme.cardRadius,
        boxShadow: CaptainTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                child: const Icon(Icons.scale, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Live Weight',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.white.withValues(alpha: 0.76),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      latestWeight == '--' ? '-- kg' : '$latestWeight kg',
                      style: AppTextStyles.heading2.copyWith(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: CaptainTheme.chipRadius,
                ),
                child: Text(
                  '$addedCount/${wasteTypes.length} added',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildBluetoothBar(inverted: true),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _headerMetric(
                  icon: Icons.person_pin_circle_outlined,
                  label: 'Customer',
                  value: widget.customerId.isEmpty ? '-' : widget.customerId,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _headerMetric(
                  icon: Icons.inventory_2_outlined,
                  label: 'Total',
                  value: '${totalWeight.toStringAsFixed(2)} kg',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerMetric({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.82)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Bluetooth scale status + connect control. Android only — on iOS the scale
  /// uses classic SPP which Apple does not allow, so operators enter weight
  /// manually (the manual field stays available on every platform).
  Widget _buildBluetoothBarContent({required bool inverted}) {
    if (!_bluetoothSupported) {
      return Row(
        children: [
          Icon(
            Icons.edit,
            size: 18,
            color: inverted
                ? Colors.white.withValues(alpha: 0.82)
                : CaptainTheme.mutedText,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Enter weight manually below.',
              style: TextStyle(
                color: inverted
                    ? Colors.white.withValues(alpha: 0.82)
                    : CaptainTheme.mutedText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );
    }

    final Color statusColor = connected
        ? (inverted ? const Color(0xFF7EF59F) : CaptainTheme.success)
        : (_btConnecting
            ? CaptainTheme.warning
            : (inverted ? const Color(0xFFFFB4B4) : CaptainTheme.danger));
    final String statusText = connected
        ? 'Scale connected${_connectedDeviceName != null ? ' · $_connectedDeviceName' : ''}'
        : (_btConnecting ? 'Connecting...' : 'Scale not connected');

    return Row(
      children: [
        Icon(
          connected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
          size: 18,
          color: statusColor,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            statusText,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: statusColor, fontWeight: FontWeight.w700),
          ),
        ),
        if (_btConnecting)
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: inverted ? Colors.white : CaptainTheme.accent,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            onPressed: connected ? _disconnectScale : _connectScalePressed,
            icon: Icon(connected ? Icons.link_off : Icons.bluetooth_searching,
                size: 18),
            label: Text(connected ? 'Disconnect' : 'Connect'),
          ),
      ],
    );
  }

  Widget _buildBluetoothBar({bool inverted = false}) {
    return _buildBluetoothBarContent(inverted: inverted);
  }

  /// Manual Connect tap: ensure adapter on, then auto-match or show picker.
  Future<void> _connectScalePressed() async {
    if (!_bluetoothSupported) return;
    if (!await _ensureBluetoothPermissions()) return;
    try {
      await FlutterBluetoothSerial.instance.cancelDiscovery();
      final isEnabled =
          await FlutterBluetoothSerial.instance.isEnabled ?? false;
      if (!isEnabled) {
        await FlutterBluetoothSerial.instance.requestEnable();
      }
    } catch (e) {
      debugPrint("⚠️ Adapter enable skipped: $e");
    }
    await _resetBluetooth();
    await _initBluetooth();
  }

  Future<void> _disconnectScale() async {
    await _resetBluetooth();
    _safeSetState(() {
      connected = false;
      _connectedDeviceName = null;
    });
  }

  Widget _buildCustomerInfo() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: CaptainTheme.surface,
          borderRadius: CaptainTheme.cardRadius,
          border: Border.all(color: CaptainTheme.hairline),
          boxShadow: CaptainTheme.softShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: CaptainTheme.accentSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.home_work_outlined,
                    color: CaptainTheme.accent,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.customerName.trim().isEmpty
                        ? 'Scanned household'
                        : widget.customerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.heading2.copyWith(
                      color: CaptainTheme.strongText,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _infoTile('Customer Name', widget.customerName),
            _infoTile('Customer ID', widget.customerId),
            if (widget.contactNo.trim().isNotEmpty)
              _infoTile('Contact No', widget.contactNo),
          ],
        ),
      );

  Widget _infoTile(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 112,
              child: Text(
                label,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: CaptainTheme.mutedText,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value.trim().isEmpty ? '-' : value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w800,
                  color: CaptainTheme.strongText,
                ),
              ),
            ),
          ],
        ),
      );

  Color _wasteAccent(String type) {
    if (type.contains('wet')) return const Color(0xFF0EA5E9);
    if (type.contains('dry')) return CaptainTheme.warning;
    return CaptainTheme.accent;
  }

  IconData _wasteIcon(String type) {
    if (type.contains('wet')) return Icons.water_drop_outlined;
    if (type.contains('dry')) return Icons.inventory_2_outlined;
    return Icons.recycling_outlined;
  }

  Widget _statusChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: CaptainTheme.chipRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWasteSection(String type, String displayName) {
    final item = _wasteData[type]!;
    final image = item['image'] as File?;
    final isAdded = item['isAdded'] as bool;
    final accent = _wasteAccent(type);
    final isEditingAdded =
        isAdded && activeType == type && item['finalWeight'] == null;
    final displayWeight =
        item['finalWeight'] != null && item['finalWeight'] != '--'
            ? item['finalWeight']
            : item['weight'];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: CaptainTheme.surface,
        borderRadius: _kOperatorCardRadius,
        border: Border.all(
          color: (type == activeType) ? accent : CaptainTheme.hairline,
          width: (type == activeType) ? 1.6 : 1,
        ),
        boxShadow: CaptainTheme.softShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.11),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_wasteIcon(type), color: accent, size: 21),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.heading2.copyWith(
                          color: CaptainTheme.strongText,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        image == null ? 'Photo required' : 'Photo captured',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: CaptainTheme.mutedText,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                _statusChip(
                  icon: isAdded ? Icons.check_circle : Icons.schedule,
                  label: isAdded ? 'Added' : 'Pending',
                  color:
                      isAdded ? CaptainTheme.success : CaptainTheme.warning,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (image != null)
              GestureDetector(
                onTap: () => _showPreview(image),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    children: [
                      Image.file(
                        image,
                        width: double.infinity,
                        height: 154,
                        fit: BoxFit.cover,
                      ),
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.58),
                            borderRadius: CaptainTheme.chipRadius,
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.visibility_outlined,
                                  size: 14, color: Colors.white),
                              SizedBox(width: 5),
                              Text(
                                'Preview',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Container(
                height: 132,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: CaptainTheme.surfaceMuted,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: CaptainTheme.hairline,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.camera_alt_outlined,
                        size: 34, color: CaptainTheme.mutedText),
                    const SizedBox(height: 8),
                    Text(
                      'Capture waste photo',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: CaptainTheme.mutedText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CaptainTheme.surfaceMuted,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.monitor_weight_outlined,
                            size: 19, color: accent),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            displayWeight == '--'
                                ? 'Weight not set'
                                : '$displayWeight kg',
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: CaptainTheme.strongText,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 104,
                    height: 40,
                    child: TextField(
                      controller: _manualWeightControllers[type],
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}$'),
                        ),
                      ],
                      decoration: InputDecoration(
                        hintText: 'kg',
                        isDense: true,
                        filled: true,
                        fillColor: CaptainTheme.surface,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: CaptainTheme.hairline),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: CaptainTheme.hairline),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: accent, width: 1.4),
                        ),
                      ),
                      onChanged: (value) => setState(
                        () => _updateManualWeight(type, value),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: CaptainTheme.primary,
                      side: BorderSide(color: CaptainTheme.hairline),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () async {
                      final picked =
                          await _picker.pickImage(source: ImageSource.camera);
                      if (picked == null) return;

                      final original = File(picked.path);
                      final compressed =
                          await ImageCompressService.compress(original);

                      _safeSetState(() {
                        final updated = Map<String, dynamic>.from(item);
                        updated['image'] = compressed;
                        if (_canApplyLiveWeight(type)) {
                          updated['weight'] = latestWeight;
                        }

                        _wasteData = {
                          ..._wasteData,
                          type: updated,
                        };

                        if (_canApplyLiveWeight(type)) {
                          activeType = type;
                        }
                        _syncManualWeightController(
                          type,
                          _weightTextFor(type),
                        );
                      });
                    },
                    icon: const Icon(Icons.camera_alt_outlined, size: 18),
                    label: Text(
                      image == null ? "Capture" : "Retake",
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isAdded
                          ? CaptainTheme.warning
                          : CaptainTheme.accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      if (isAdded && !isEditingAdded) {
                        setState(() => _startEditingAddedWeight(type));
                        return;
                      }
                      _handleAdd(type);
                    },
                    icon: Icon(
                      isAdded
                          ? (isEditingAdded ? Icons.save : Icons.refresh)
                          : Icons.add,
                      size: 18,
                    ),
                    label: Text(
                      isAdded ? (isEditingAdded ? "Save" : "Update") : "Add",
                      style: AppTextStyles.labelLarge.copyWith(
                        fontSize: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showPreview(File image) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.file(image),
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close')),
          ],
        ),
      ),
    );
  }

  // ==================== MAIN UI ====================
  @override
  Widget build(BuildContext context) {
    final totalWeight = _calculateTotalWeight();
    final addedCount =
        _wasteData.values.where((item) => item['isAdded'] == true).length;

    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop(_collectionSubmitted);
        return false;
      },
      child: Scaffold(
        backgroundColor: CaptainTheme.background,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: CaptainTheme.primary,
          foregroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.white),
          flexibleSpace: DecoratedBox(
            decoration: BoxDecoration(gradient: CaptainTheme.headerGradient),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(_collectionSubmitted),
          ),
          title: const Text(
            "Household Collection",
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          centerTitle: false,
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCollectionHeader(
                      addedCount: addedCount,
                      totalWeight: totalWeight,
                    ),
                    const SizedBox(height: 14),
                    _buildCustomerInfo(),
                    const SizedBox(height: 18),
                    Text(
                      'Waste entries',
                      style: AppTextStyles.heading2.copyWith(
                        color: CaptainTheme.strongText,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Capture photo, confirm weight, then add each waste type.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: CaptainTheme.mutedText,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (wasteTypes.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: CaptainTheme.surface,
                          borderRadius: CaptainTheme.cardRadius,
                          border: Border.all(color: CaptainTheme.hairline),
                        ),
                        child: Text(
                          "No waste types configured.",
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: CaptainTheme.mutedText,
                          ),
                        ),
                      )
                    else
                      ...wasteTypes.asMap().entries.map((entry) {
                        final index = entry.key;
                        final w = entry.value;
                        final type = w['waste_type_name']
                            .toString()
                            .trim()
                            .toLowerCase();
                        final name = w['waste_type_name'].toString();
                        return KeyedSubtree(
                          key: ValueKey("wastecard_${index}_$type"),
                          child: _buildWasteSection(type, name),
                        );
                      }),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            decoration: BoxDecoration(
              color: CaptainTheme.surface,
              border: Border(top: BorderSide(color: CaptainTheme.hairline)),
              boxShadow: CaptainTheme.softShadow,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total waste',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: CaptainTheme.mutedText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${totalWeight.toStringAsFixed(2)} kg',
                        style: AppTextStyles.heading2.copyWith(
                          color: CaptainTheme.strongText,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CaptainTheme.accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _isSubmitting ? null : _submitForm,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle_outline, size: 20),
                    label: Text(
                      _isSubmitting ? 'Submitting' : 'Submit',
                      style: AppTextStyles.labelLarge.copyWith(
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== BLUETOOTH INIT ====================

  Future<bool> _ensureBluetoothPermissions() async {
    final statuses = await [
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.locationWhenInUse,
    ].request();

    final granted = statuses.values.every((status) => status.isGranted);
    if (!granted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Bluetooth permissions are required to capture weight.'),
        ),
      );
    }
    return granted;
  }

  // Known name fragments for the weighing-scale serial modules used in the
  // field (HC-05 / HC-06 / AEBT, plus generic scale labels). Matched
  // case-insensitively against the bonded device name.
  static const List<String> _scaleNameHints = [
    "AEBT",
    "HC-05",
    "HC-06",
    "HC05",
    "HC06",
    "HC",
    "WEIGH",
    "SCALE",
    "BT",
  ];

  BluetoothDevice? _pickScaleDevice(List<BluetoothDevice> devices) {
    for (final hint in _scaleNameHints) {
      for (final d in devices) {
        if ((d.name ?? "").toUpperCase().contains(hint)) {
          return d;
        }
      }
    }
    return null;
  }

  /// Auto-connect to the weighing scale (Android only). Tries to match a known
  /// scale module by name; if none matches, prompts the operator to pick the
  /// paired device manually so it works with any module label.
  Future<void> _initBluetooth() async {
    if (!_bluetoothSupported || connected || _btConnecting) return;

    if (!await _ensureBluetoothPermissions()) return;

    final devices = await FlutterBluetoothSerial.instance.getBondedDevices();
    if (devices.isEmpty) {
      debugPrint("⚠️ No bonded Bluetooth devices found.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No paired Bluetooth scale found. Pair the weighing machine in '
              'phone Settings, then tap Connect.',
            ),
          ),
        );
      }
      return;
    }

    final device = _pickScaleDevice(devices);
    if (device == null) {
      // No confident auto-match — let the operator choose.
      await _promptDevicePicker(devices);
      return;
    }
    await _connectToDevice(device);
  }

  /// Bottom sheet listing the paired devices so the operator can select the
  /// exact weighing machine when auto-detect can't identify it.
  Future<void> _promptDevicePicker(List<BluetoothDevice> devices) async {
    if (!mounted) return;
    final selected = await showModalBottomSheet<BluetoothDevice>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Text(
                  'Select weighing scale',
                  style: AppTextStyles.heading2,
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  'Choose the paired Bluetooth weighing machine.',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
              ...devices.map(
                (d) => ListTile(
                  leading: const Icon(Icons.scale, color: AppColors.primary),
                  title: Text(d.name ?? 'Unknown device'),
                  subtitle: Text(d.address),
                  onTap: () => Navigator.of(sheetContext).pop(d),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (selected != null) {
      await _connectToDevice(selected);
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    if (connected || _btConnecting) return;
    _safeSetState(() => _btConnecting = true);
    try {
      debugPrint("🔌 Connecting to ${device.name}...");
      final conn = await BluetoothConnection.toAddress(device.address);
      _safeSetState(() {
        _connection = conn;
        connected = true;
        _btConnecting = false;
        _connectedDeviceName = device.name ?? device.address;
      });

      String buffer = "";
      conn.input?.listen((Uint8List data) {
        final text = utf8.decode(data);
        buffer += text;
        if (buffer.contains('\n')) {
          final parts = buffer.split('\n');
          for (var line in parts.take(parts.length - 1)) {
            final trimmed = line.trim();
            if (trimmed.isEmpty) continue;

            bluetooth.updateWeight(trimmed);

            _safeSetState(() {
              latestWeight = trimmed;

              if (activeType != null &&
                  _wasteData.containsKey(activeType) &&
                  _canApplyLiveWeight(activeType!)) {
                final current = _wasteData[activeType!]!;
                final updated = Map<String, dynamic>.from(current);
                updated['weight'] = trimmed;
                updated['finalWeight'] = null;
                _wasteData = {
                  ..._wasteData,
                  activeType!: updated,
                };
                _syncManualWeightController(activeType!, trimmed);
              }
            });
          }
          buffer = parts.last;
        }
      }).onDone(() {
        _safeSetState(() {
          connected = false;
          _connectedDeviceName = null;
        });
      });
    } catch (e) {
      debugPrint("⚠️ Bluetooth connection error: $e");
      _safeSetState(() => _btConnecting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not connect to ${device.name}. $e')),
        );
      }
    }
  }
}
