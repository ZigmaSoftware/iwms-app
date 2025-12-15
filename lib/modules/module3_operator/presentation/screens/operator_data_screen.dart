import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
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
import 'package:iwms_citizen_app/modules/module3_operator/services/bluetoothservices.dart';
import 'package:iwms_citizen_app/modules/module3_operator/services/generateunique_id.dart';
import 'package:iwms_citizen_app/modules/module3_operator/services/image_compress_service.dart';
import '../../offline/offline_sync_service.dart';
import '../../offline/pending_record.dart';
import '../../offline/pending_record_dao.dart';

const BorderRadius _kOperatorCardRadius = BorderRadius.all(Radius.circular(18));

class OperatorDataScreen extends StatefulWidget {
  final String customerId;
  final String customerName;
  final String contactNo;
  final String latitude;
  final String longitude;

  const OperatorDataScreen({
    super.key,
    required this.customerId,
    required this.customerName,
    required this.contactNo,
    required this.latitude,
    required this.longitude,
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
  String? activeType; // currently selected waste type
  late final OfflineSyncService _syncService;
  final PendingRecordDao _pendingDao = PendingRecordDao();
  late final CollectionHistoryService _historyService;

  List<Map<String, dynamic>> wasteTypes = [];
  Map<String, Map<String, dynamic>> _wasteData = {};
  final List<Map<String, dynamic>> defaultWasteTypes = [
    {"id": 1, "waste_type_name": "Wet"},
    {"id": 2, "waste_type_name": "Dry"},
    {"id": 3, "waste_type_name": "Mixed"},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    screenUniqueId = UniqueIdService.generateScreenUniqueId();
    _wasteData.clear();

    latestWeight = "--";
    _historyService = getIt<CollectionHistoryService>();

    // 🔁 Bluetooth adapter re-init
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

    _syncService = OfflineSyncService(
      recordDao: _pendingDao,
      finalizeDao: _finalizeDao,
      baseUrl: 'http://10.164.86.186:8000/api/mobile/waste',
    )..start();

    _fetchWasteTypes();
  }

  Future<void> _loadOfflineForScreen() async {
    debugPrint("🔄 Loading offline records for screen: $screenUniqueId");

    final offlineRecords = await _pendingDao.getByScreen(screenUniqueId);

    // nothing to load → just refresh UI
    if (offlineRecords.isEmpty) {
      setState(() {});
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

      final typeKey = type['waste_type_name'].toString().toLowerCase();

      if (!_wasteData.containsKey(typeKey)) continue;

      // Build updated map
      final updated = Map<String, dynamic>.from(_wasteData[typeKey]!);

      // UID must never be null for UI logic
      final safeUid = r.uniqueId ?? "uid_${r.id}";

      updated['isAdded'] = true;
      updated['unique_id'] = safeUid;

      updated['weight'] = r.weight;
      updated['finalWeight'] = r.weight; // always override stale values
      updated['image'] = File(r.imagePath);

      _wasteData = {..._wasteData, typeKey: updated};

      debugPrint(
          "📌 Loaded offline → $typeKey | weight=${r.weight} | uid=$safeUid");
    }

    setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)! as PageRoute);
  }

  Future<void> _resetBluetooth() async {
    try {
      if (_connection != null) {
        await _connection!.close();
        _connection = null;
        connected = false;
        debugPrint("🔌 Bluetooth connection reset successfully");
      }
    } catch (e) {
      debugPrint("⚠️ Error while resetting Bluetooth: $e");
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    // optional: do not disconnect here if you want persistence
    try {
      _connection?.dispose();
      connected = false;
    } catch (_) {}
    _syncService.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    debugPrint("🔄 Returned → reconnecting");
    _reconnectBluetoothWithRetry();
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
    if (state == AppLifecycleState.resumed && !connected) {
      _initBluetooth();
    }
  }

  // ==================== FETCH WASTE TYPES ====================
  Future<void> _fetchWasteTypes() async {
    try {
      final response = await http.get(
        Uri.parse('http://10.164.86.186:8000/api/mobile/waste/get-waste-types/'),
      );

      final data = json.decode(response.body);

      if (data['status'] == 'success' && data['data'] != null) {
        wasteTypes = List<Map<String, dynamic>>.from(data['data']);
      } else {
        wasteTypes = defaultWasteTypes;
      }
    } catch (e) {
      debugPrint('⚠ Waste type API failed, using fallback defaults');
      wasteTypes = defaultWasteTypes;
    }

    // Build UI base structure
    _wasteData = {
      for (var item in wasteTypes)
        item['waste_type_name'].toString().toLowerCase(): {
          'waste_type_id': item['id'],
          'label': item['waste_type_name'],
          'unique_id': null,
          'image': null,
          'weight': '--',
          'finalWeight': null,
          'isAdded': false,
        }
    };

    setState(() {});
    await _loadOfflineForScreen();
  }

  // ==================== IMAGE CAPTURE ====================
  Future<File?> _captureImage(String type) async {
    final picked = await _picker.pickImage(source: ImageSource.camera);
    if (picked == null) return null;

    final original = File(picked.path);
    final compressed = await ImageCompressService.compress(original);

    setState(() {
      activeType = type;

      // ❌ DO NOT reset other types' weights here
      // 🔸 Just update the current one
      final updated = Map<String, dynamic>.from(_wasteData[type]!);
      updated['image'] = compressed;
      updated['weight'] = latestWeight;
      _wasteData = {
        ..._wasteData,
        type: updated,
      };
    });
    return compressed;
  }

  Future<void> _fetchWasteRecord(String type) async {
    try {
      final uri = Uri.parse(
          'http://10.164.86.186:8000/api/mobile/waste/get-latest-waste/');
      final response = await http.post(uri, body: {
        'screen_unique_id': screenUniqueId,
        'customer_id': widget.customerId,
        'waste_type_id': _wasteData[type]!['waste_type_id'].toString(),
      });

      final data = json.decode(response.body);
      if (data['status'] == 'success' && data['data'] != null) {
        final record = data['data'];

        setState(() {
          final updated = Map<String, dynamic>.from(_wasteData[type]!);
          updated['unique_id'] = record['unique_id']; // store backend record id
          updated['waste_type_id'] =
              _wasteData[type]!['waste_type_id']; // keep numeric type id
          updated['weight'] = record['weight'] ?? '--';
          updated['finalWeight'] = record['weight'] ?? '--';
          updated['isAdded'] = true;

          _wasteData = {..._wasteData, type: updated};
        });

        debugPrint('✅ Backend weight for $type: ${record['weight']}');
        debugPrint('✅ Updated record fetched for $type => ${jsonEncode({
              'unique_id': record['unique_id'],
              'weight': record['weight'],
            })}');
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

    if (image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Capture image for $type first')),
      );
      return;
    }

    if (latestWeight == "--") {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please ensure weight is recorded for $type')),
      );
      return;
    }

    final weight = data['weight'].toString();
    final isUpdate = data['isAdded'] == true;
    final uniqueId = data['unique_id']?.toString();

    setState(() => _isSubmitting = true);

    try {
      // ------------------------------------------------------------
      // 🔗 SELECT ENDPOINT
      // ------------------------------------------------------------
      final uri = Uri.parse(
        isUpdate
            ? 'http://10.164.86.186:8000/api/mobile/waste/update-waste-sub/'
            : 'http://10.164.86.186:8000/api/mobile/waste/insert-waste-sub/',
      );

      debugPrint(
          "▶️ _handleAdd($type) → isUpdate=$isUpdate, unique_id=$uniqueId");

      // ------------------------------------------------------------
      // 📨 BUILD REQUEST
      // ------------------------------------------------------------
      final request = http.MultipartRequest('POST', uri)
        ..fields['screen_unique_id'] = screenUniqueId
        ..fields['customer_id'] = widget.customerId
        ..fields['waste_type_id'] = data['waste_type_id'].toString()
        ..fields['weight'] = weight
        ..fields['latitude'] = widget.latitude
        ..fields['longitude'] = widget.longitude;

      // 👉 Only send unique_id for update
      if (isUpdate && uniqueId != null) {
        debugPrint("📡 Sending UPDATE with unique_id=$uniqueId");
        request.fields['unique_id'] = uniqueId;
      }

      // Attach image
      request.files.add(await http.MultipartFile.fromPath('image', image.path));

      // ------------------------------------------------------------
      // 🚀 SEND REQUEST
      // ------------------------------------------------------------
      final streamed = await request.send();

      if (streamed.statusCode >= 400) {
        throw Exception("Server error ${streamed.statusCode}");
      }

      final response = await http.Response.fromStream(streamed);
      debugPrint("📩 RAW RESPONSE => ${response.body}");

      dynamic result;
      try {
        result = json.decode(response.body);
      } catch (_) {
        debugPrint("❌ Invalid JSON from server");
        throw Exception("Invalid JSON from backend");
      }

      if (result['status'] != 'success') {
        throw Exception(result['message'] ?? "Unknown server error");
      }

      // ------------------------------------------------------------
      // 🎯 SUCCESS → UPDATE LOCAL STATE
      // ------------------------------------------------------------
      final backendUnique = result['unique_id']?.toString();

      setState(() {
        final updated = Map<String, dynamic>.from(data);
        updated['isAdded'] = true;
        updated['finalWeight'] = weight;

        if (backendUnique != null) {
          updated['unique_id'] = backendUnique; // overwrite offline uid
        }

        _wasteData[type] = updated;
      });

      // Reload in case new data arrives
      await _fetchWasteRecord(type);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isUpdate
                ? "$type updated successfully"
                : "$type added successfully",
          ),
        ),
      );

      return; // DONE ✔️
    }

    // ------------------------------------------------------------
    // 📴 OFFLINE FALLBACK
    // ------------------------------------------------------------
    catch (err) {
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

      // Save or update offline
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("$type saved offline — will sync automatically"),
        ),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _resetUI() async {
    final oldId = screenUniqueId;

    setState(() {
      latestWeight = "--";
      activeType = null;

      // Regenerate screen unique ID for next operation
      screenUniqueId = UniqueIdService.generateScreenUniqueId();

      // Clear waste data structure
      _wasteData = {
        for (var item in wasteTypes)
          item['waste_type_name'].toString().toLowerCase(): {
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
    setState(() => _isSubmitting = true);

    final totalWeight = _calculateTotalWeight();
    final summary = _buildSummarySnapshot();

    try {
      debugPrint('🔎 total waste before submit: $totalWeight');

      // if (totalWeight <= 0) {
      //   _showDialog('Warning',
      //       'Please add at least one waste entry before submitting.');
      //   return;
      // }

      final uri = Uri.parse(
          'http://10.164.86.186:8000/api/mobile/waste/finalize-waste/');

      final request = http.MultipartRequest('POST', uri)
        ..fields['screen_unique_id'] = screenUniqueId
        ..fields['customer_id'] = widget.customerId
        ..fields['entry_type'] = 'app'
        ..fields['total_waste_collected'] = totalWeight.toString();

      final response = await request.send();
      final result =
          json.decode((await http.Response.fromStream(response)).body);

      if (result['status'] == 'success') {
        await _recordCollectionHistory(totalWeight);
        await _showSuccessSheet(totalWeight, summary);
        _resetUI();
        await _fetchWasteTypes();
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

      // Prevent crash if internet is OFF
      try {
        if (await _syncService.hasInternet()) {
          await _syncService.syncAll();
        }
      } catch (err) {
        debugPrint("⚠️ Sync attempt failed: $err");
      }

      // Reset UI like online mode
      await _recordCollectionHistory(totalWeight);
      await _showSuccessSheet(totalWeight, summary, offline: true);
      _resetUI();
      await _fetchWasteTypes();
    } finally {
      setState(() => _isSubmitting = false);
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

      // Always include the weight, even if it's 0
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        return Padding(
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

  // ==================== DIALOG ====================
  void _showDialog(String title, String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          )
        ],
      ),
    );
  }

  // ==================== UI HELPERS ====================
  Widget _buildCustomerInfo() => Card(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: _kOperatorCardRadius,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoTile('Customer Name', widget.customerName),
            _infoTile('Customer ID', widget.customerId),
            _infoTile('Contact No', widget.contactNo),
          ],
        ),
      );

  Widget _infoTile(String label, String value) => ListTile(
        title: Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          value,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
      );

  Widget _buildWasteSection(String type, String displayName) {
    final item = _wasteData[type]!;
    final image = item['image'] as File?;
    final isAdded = item['isAdded'] as bool;
    final displayWeight =
        item['finalWeight'] != null && item['finalWeight'] != '--'
            ? item['finalWeight']
            : item['weight'];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10),
      shape: RoundedRectangleBorder(
        borderRadius: _kOperatorCardRadius,
        side: BorderSide(
          color: (type == activeType) ? AppColors.primary : Colors.black12,
          width: (type == activeType) ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              displayName,
              style: AppTextStyles.heading2,
            ),
            const SizedBox(height: 8),

            // IMAGE
            if (image != null)
              GestureDetector(
                onTap: () => _showPreview(image),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(image,
                      width: double.infinity, height: 180, fit: BoxFit.cover),
                ),
              )
            else
              Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.accentLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.camera_alt_outlined,
                    size: 48, color: Colors.grey),
              ),

            const SizedBox(height: 8),

            Text(
              "Weight: ${displayWeight == '--' ? '--' : '$displayWeight kg'}",
              style: AppTextStyles.bodyMedium.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked =
                          await _picker.pickImage(source: ImageSource.camera);
                      if (picked == null) return;

                      final original = File(picked.path);
                      final compressed =
                          await ImageCompressService.compress(original);

                      setState(() {
                        final updated = Map<String, dynamic>.from(item);
                        updated['image'] = compressed;
                        updated['weight'] = latestWeight;

                        _wasteData = {
                          ..._wasteData,
                          type: updated,
                        };

                        activeType = type;
                      });
                    },
                    icon: const Icon(Icons.camera_alt, size: 18),
                    label: Text(
                      "Capture",
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
                      backgroundColor:
                          isAdded ? Colors.orange.shade600 : AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => _handleAdd(type),
                    icon: Icon(
                      isAdded ? Icons.refresh : Icons.add,
                      size: 18,
                    ),
                    label: Text(
                      isAdded ? "Update" : "Add",
                      style: AppTextStyles.labelLarge.copyWith(
                        fontSize: 13,
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            // Prefer router navigation back to operator home tabbar.
            final navigator = Navigator.of(context);
            if (navigator.canPop()) {
              navigator.pop();
            } else {
              // Fallback to route if opened fresh.
              context.go(AppRoutePaths.operatorHome);
            }
          },
        ),
        title: Text(
          "Customer Details",
          style: AppTextStyles.heading2.copyWith(color: Colors.white),
        ),
      ),
      body: wasteTypes.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  color: AppColors.accentLight,
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Text(
                    "📟 Live Weight: ${latestWeight == '--' ? '--' : '$latestWeight kg'}",
                    style: AppTextStyles.heading2.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildCustomerInfo(),
                        const SizedBox(height: 12),
                        ...wasteTypes.map((w) {
                          final type =
                              w['waste_type_name'].toString().toLowerCase();
                          final name = w['waste_type_name'];
                          return KeyedSubtree(
                            key: ValueKey(
                                "wastecard_${type}_${_wasteData[type]!['unique_id']}_${_wasteData[type]!['weight']}"),
                            child: _buildWasteSection(type, name),
                          );
                        }),
                        const SizedBox(height: 20),
                        _isSubmitting
                            ? const CircularProgressIndicator()
                            : ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      const Color.fromRGBO(0, 61, 125, 0.8),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 40, vertical: 12),
                                ),
                                onPressed: _submitForm,
                                child: Text(
                                  'Submit',
                                  style: AppTextStyles.labelLarge.copyWith(
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                      ],
                    ),
                  ),
                ),
              ],
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

//   Future<void> _initBluetooth() async {
//     if (connected) return;

//     await [
//       Permission.bluetooth,
//       Permission.bluetoothConnect,
//       Permission.bluetoothScan,
//       Permission.locationWhenInUse,
//     ].request();

//     final devices = await FlutterBluetoothSerial.instance.getBondedDevices();
//     if (devices.isEmpty) {
//       debugPrint("⚠️ No bonded Bluetooth devices found.");
//       return;
//     }

//     final hc05 = devices.firstWhere(
//       (d) => (d.name ?? "").toUpperCase().contains("HC"),
//       orElse: () => devices.first,
//     );

//     try {
//       debugPrint("🔌 Connecting to ${hc05.name}...");
//       final conn = await BluetoothConnection.toAddress(hc05.address);
//       setState(() {
//         _connection = conn;
//         connected = true;
//       });

//       String buffer = "";
//       conn.input?.listen((Uint8List data) {
//         final text = utf8.decode(data);
//         buffer += text;
//         if (buffer.contains('\n')) {
//           final parts = buffer.split('\n');
//           for (var line in parts.take(parts.length - 1)) {
//             final trimmed = line.trim();
//             // if (trimmed.isNotEmpty) {
//             //   bluetooth.updateWeight(trimmed);
//             //   setState(() {
//             //     latestWeight = trimmed;
//             //     if (activeType != null && _wasteData.containsKey(activeType)) {
//             //       _wasteData[activeType]!['weight'] = trimmed;
//             //     }
//             //   });
//             // }
//             if (trimmed.isNotEmpty) {
//   bluetooth.updateWeight(trimmed);
//   setState(() {
//     latestWeight = trimmed;

//     if (activeType != null && _wasteData.containsKey(activeType)) {
//       // ✅ Replace the entire map entry with a new copy
//       final updated = Map<String, dynamic>.from(_wasteData[activeType]!);
//       updated['weight'] = trimmed;
//       _wasteData = Map<String, Map<String, dynamic>>.from(_wasteData)
//         ..[activeType!] = updated;
//     }
//   });
// }

//           }
//           buffer = parts.last;
//         }
//       }).onDone(() {
//         setState(() => connected = false);
//       });
//     } catch (e) {
//       debugPrint("⚠️ Bluetooth connection error: $e");
//     }
//   }
  Future<void> _initBluetooth() async {
    if (connected) return;

    if (!await _ensureBluetoothPermissions()) return;

    final devices = await FlutterBluetoothSerial.instance.getBondedDevices();
    if (devices.isEmpty) {
      debugPrint("⚠️ No bonded Bluetooth devices found.");
      return;
    }

    final hc05 = devices.firstWhere(
      (d) => (d.name ?? "").toUpperCase().contains("AEBT"),
      orElse: () => devices.first,
    );

    try {
      debugPrint("🔌 Connecting to ${hc05.name}...");
      final conn = await BluetoothConnection.toAddress(hc05.address);
      setState(() {
        _connection = conn;
        connected = true;
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

            setState(() {
              latestWeight = trimmed;

              // ✅ Only update the *currently active* waste type if it's not frozen
              if (activeType != null && _wasteData.containsKey(activeType)) {
                final current = _wasteData[activeType!]!;
                final updated = Map<String, dynamic>.from(current);
                updated['weight'] = trimmed; // 🔥 Always update
                updated['finalWeight'] = null; // Keep editable until upload
                _wasteData = {
                  ..._wasteData,
                  activeType!: updated,
                };
              }
            });
          }
          buffer = parts.last;
        }
      }).onDone(() {
        setState(() => connected = false);
      });
    } catch (e) {
      debugPrint("⚠️ Bluetooth connection error: $e");
    }
  }
}
