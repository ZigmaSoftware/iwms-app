import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:iwms_citizen_app/core/api_config.dart';
import 'package:iwms_citizen_app/core/di.dart';
import 'package:iwms_citizen_app/data/models/daily_assignment_model.dart';
import 'package:iwms_citizen_app/data/repositories/assignment_service.dart';
import 'package:iwms_citizen_app/logic/auth/auth_bloc.dart';
import 'package:iwms_citizen_app/logic/auth/auth_state.dart';
import 'package:iwms_citizen_app/modules/module3_operator/services/locationservices.dart';
import 'package:iwms_citizen_app/modules/module3_operator/utils/assignment_status_store.dart';
import 'package:iwms_citizen_app/router/app_router.dart';

class OperatorQRScanner extends StatefulWidget {
  const OperatorQRScanner({
    super.key,
    this.expectedCustomerId,
    this.expectedCustomerName,
    this.expectedAssignmentId,
    this.returnToAssignments = false,
  });

  final String? expectedCustomerId;
  final String? expectedCustomerName;
  final String? expectedAssignmentId;
  final bool returnToAssignments;

  @override
  State<OperatorQRScanner> createState() => _OperatorQRScannerState();
}

class _OperatorQRScannerState extends State<OperatorQRScanner> {
  final MobileScannerController _camera = MobileScannerController();

  bool _scanned = false;

  String _normalizeId(String value) {
    return value.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
  }

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  /// ---------------------------------------------------------
  /// 🔥 Ensure location ready
  /// ---------------------------------------------------------
  Future<void> _initLocation() async {
    try {
      await LocationService.refresh(timeout: const Duration(seconds: 2));
      debugPrint(
        "📍 Location ready: ${LocationService.latitude}, ${LocationService.longitude}",
      );
    } catch (e) {
      debugPrint("⚠ Location failed: $e");
    }
  }

  /// ---------------------------------------------------------
  /// 🔥 QR Detected → Open Sheet immediately
  /// ---------------------------------------------------------
  void _handleQR(BarcodeCapture capture) async {
    if (_scanned) return;

    final raw = capture.barcodes.first.rawValue ?? "";
    if (raw.isEmpty) return;

    setState(() => _scanned = true);
    await _camera.stop();

    final uid = _extractUid(raw, preferredId: widget.expectedCustomerId);
    if (uid == null) {
      _showMessage("Invalid QR code");
      _restartScanner();
      return;
    }

    DailyAssignmentModel? resolvedAssignment;
    String? effectiveAssignmentId = widget.expectedAssignmentId;
    if (widget.returnToAssignments) {
      if (!mounted) return;
      Navigator.of(context).pop(uid);
      return;
    }

    // Try API fetch (optional)
    final apiCustomer = await _fetchCustomer(uid);
    String canonicalId = uid;
    if (apiCustomer != null) {
      final apiId = apiCustomer['unique_id'] ?? apiCustomer['customer_id'];
      final parsedId = apiId?.toString().trim();
      if (parsedId != null && parsedId.isNotEmpty) {
        canonicalId = parsedId;
      }
    }

    if (!widget.returnToAssignments) {
      final hasAssignmentId = effectiveAssignmentId != null &&
          effectiveAssignmentId!.trim().isNotEmpty;
      if (!hasAssignmentId) {
        resolvedAssignment = await _resolveActiveAssignment();
        effectiveAssignmentId = resolvedAssignment?.uniqueId;
      }
      final normalizedAssignmentId = effectiveAssignmentId?.trim();
      if (normalizedAssignmentId != null && normalizedAssignmentId.isNotEmpty) {
        final statuses = await AssignmentStatusStore.getStatusesFor(
          normalizedAssignmentId,
          {uid, canonicalId},
        );
        final status =
            statuses[canonicalId]?.toLowerCase() ?? statuses[uid]?.toLowerCase();
        if (status == 'collected') {
          _showMessage('Already collected for this assignment.');
          _restartScanner();
          return;
        }
      }
    }

    if (!widget.returnToAssignments &&
        widget.expectedCustomerId != null &&
        widget.expectedCustomerId!.isNotEmpty &&
        _normalizeId(widget.expectedCustomerId!) != _normalizeId(canonicalId)) {
      final expectedLabel =
          widget.expectedCustomerName?.trim().isNotEmpty == true
              ? widget.expectedCustomerName!
              : widget.expectedCustomerId!;
      _showMessage("QR mismatch. Expected $expectedLabel, got $canonicalId.");
      _restartScanner();
      return;
    }

    if (!widget.returnToAssignments &&
        resolvedAssignment != null &&
        resolvedAssignment.assignmentType.toLowerCase() == 'emergency') {
      final emergencyCustomerId = resolvedAssignment.customerId?.trim();
      if (emergencyCustomerId != null &&
          emergencyCustomerId.isNotEmpty &&
          _normalizeId(emergencyCustomerId) != _normalizeId(canonicalId)) {
        _showMessage('This QR does not belong to the emergency assignment.');
        _restartScanner();
        return;
      }
    }

    // Fallback: if API failed, treat QR as valid scanned user
    final customerName = apiCustomer?['customer_name'] ?? "Scanned User";
    final contactNo = apiCustomer?['contact_no'] ?? "";
    final latitude = apiCustomer?['latitude']?.toString() ??
        LocationService.latitude.toString();
    final longitude = apiCustomer?['longitude']?.toString() ??
        LocationService.longitude.toString();

    if (!mounted) return;

    await _showCustomerSheet(
      customerId: canonicalId,
      customerName: customerName,
      contactNo: contactNo,
      latitude: latitude,
      longitude: longitude,
      assignmentId: effectiveAssignmentId?.trim(),
    );
  }

  /// ---------------------------------------------------------
  /// 🔍 Extract UID from QR
  /// ---------------------------------------------------------
  String? _extractUid(String raw, {String? preferredId}) {
    String? pickPreferred(List<String> candidates, String? preferred) {
      if (candidates.isEmpty) return null;
      if (preferred == null || preferred.trim().isEmpty) {
        return candidates.first;
      }
      final normalizedPreferred =
          preferred.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
      for (final candidate in candidates) {
        if (candidate
                .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
                .toUpperCase() ==
            normalizedPreferred) {
          return candidate;
        }
      }
      final prefixMatch = RegExp(r'^[A-Za-z]+').firstMatch(preferred);
      final prefix = prefixMatch?.group(0)?.toUpperCase();
      if (prefix != null && prefix.isNotEmpty) {
        for (final candidate in candidates) {
          if (candidate.toUpperCase().startsWith(prefix)) {
            return candidate;
          }
        }
      }
      return candidates.first;
    }

    String? fromMap(Map<dynamic, dynamic> map) {
      const keys = [
        'customer_id',
        'customerId',
        'customer_unique_id',
        'id',
        'unique_id',
        'uniqueId',
        'uid',
      ];
      final candidates = <String>[];
      for (final key in keys) {
        final value = map[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          candidates.add(value.toString().trim());
        }
      }
      return pickPreferred(candidates, preferredId);
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final uid = fromMap(decoded);
        if (uid != null) return uid;
      }
    } catch (_) {}

    final uri = Uri.tryParse(raw);
    if (uri != null && uri.queryParameters.isNotEmpty) {
      final uid = fromMap(uri.queryParameters);
      if (uid != null) return uid;
    }

    final regex = RegExp(
      r'(uid|unique_id|customer_id|customerId|uniqueId|id)\s*[:=]\s*([A-Za-z0-9_-]+)',
      caseSensitive: false,
    );
    final match = regex.firstMatch(raw);
    if (match != null && match.groupCount >= 2) {
      final value = match.group(2)?.trim();
      if (value == null || value.isEmpty) {
        return null;
      }
      return pickPreferred([value], preferredId);
    }

    for (final line in raw.split('\n')) {
      final parts = line.split(':');
      if (parts.length == 2) {
        final value = parts[1].trim();
        if (value.isNotEmpty) return value;
      }
    }

    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    return pickPreferred([trimmed], preferredId);
  }

  /// ---------------------------------------------------------
  /// Optional API request (non-blocking)
  /// ---------------------------------------------------------
  Future<Map<String, dynamic>?> _fetchCustomer(String uid) async {
    final uri = Uri.parse("${ApiConfig.desktopBase}waste/customer/")
        .replace(queryParameters: {"unique_id": uid});
    try {
      final resp = await http.get(uri).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return null;

      final payload = jsonDecode(resp.body);
      if (payload is! Map || payload["status"] != "success") return null;

      final data = payload["data"];
      return (data is Map<String, dynamic>) ? data : null;
    } catch (_) {
      return null;
    }
  }

  Future<DailyAssignmentModel?> _resolveActiveAssignment() async {
    try {
      final authState = context.read<AuthBloc>().state;
      if (authState is! AuthStateAuthenticated) return null;
      final operatorId = authState.userId.trim();
      if (operatorId.isEmpty) return null;

      final repository = getIt<AssignmentRepository>();
      final assignments =
          await repository.fetchAssignmentsForOperator(operatorId: operatorId);
      if (assignments.isEmpty) return null;

      final completed = await AssignmentStatusStore.getCompletedAssignments();
      for (final assignment in assignments) {
        if (!assignment.isActive) continue;
        final key = AssignmentStatusStore.normalizeId(assignment.uniqueId);
        if (completed.contains(key)) continue;
        return assignment;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  /// ---------------------------------------------------------
  /// 🔽 Customer Bottom Sheet
  /// ---------------------------------------------------------
  Future<void> _showCustomerSheet({
    required String customerId,
    required String customerName,
    required String contactNo,
    required String latitude,
    required String longitude,
    String? assignmentId,
  }) async {
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Confirm customer',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text("ID: $customerId"),
              const SizedBox(height: 4),
              Text(
                customerName,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (contactNo.isNotEmpty) Text("Contact: $contactNo"),
              const SizedBox(height: 16),

              /// BUTTONS
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Collect'),
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        context
                            .push(
                              AppRoutePaths.operatorData,
                              extra: {
                                'customerId': customerId,
                                'customerName': customerName,
                                'contactNo': contactNo,
                                'latitude': latitude,
                                'longitude': longitude,
                                'skipBluetoothInit': true,
                                if (assignmentId != null &&
                                    assignmentId.trim().isNotEmpty)
                                  'assignmentId': assignmentId,
                              },
                            )
                            .then((_) {
                          if (widget.returnToAssignments && mounted) {
                            Navigator.of(context).pop(true);
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        _showMessage("Marked as not available");
                        _restartScanner();
                      },
                      child: const Text("Not available"),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        _showMessage("Collect later");
                        _restartScanner();
                      },
                      child: const Text("Collect later"),
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

  /// ---------------------------------------------------------
  /// Helpers
  /// ---------------------------------------------------------
  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _restartScanner() async {
    setState(() {
      _scanned = false;
    });
    try {
      await _camera.start();
    } catch (_) {}
  }

  /// ---------------------------------------------------------
  /// UI
  /// ---------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          MobileScanner(
            controller: _camera,
            fit: BoxFit.cover,
            onDetect: _handleQR,
          ),
          Positioned(
            top: 40,
            left: 12,
            child: IconButton(
              icon: const Icon(Icons.cancel, size: 32, color: Colors.white),
              onPressed: () {
                _camera.stop();
                if (widget.returnToAssignments) {
                  Navigator.of(context).pop(false);
                } else {
                  context.go(AppRoutePaths.operatorHome);
                }
              },
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black54,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.flash_on, color: Colors.white),
                label: const Text("Toggle Flash"),
                onPressed: () => _camera.toggleTorch(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
