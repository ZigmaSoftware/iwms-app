import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:iwms_citizen_app/core/api_config.dart';
import 'package:iwms_citizen_app/core/di.dart';
import 'package:iwms_citizen_app/data/models/daily_assignment_model.dart';
import 'package:iwms_citizen_app/data/repositories/assignment_service.dart';
import 'package:iwms_citizen_app/data/repositories/auth_repository.dart';
import 'package:iwms_citizen_app/logic/auth/auth_bloc.dart';
import 'package:iwms_citizen_app/logic/auth/auth_state.dart';
import 'package:iwms_citizen_app/modules/module2_driver/presentation/theme/captain_theme.dart';
import 'package:iwms_citizen_app/modules/module3_operator/services/locationservices.dart';
import 'package:iwms_citizen_app/modules/module3_operator/utils/assignment_status_store.dart';
import 'package:iwms_citizen_app/modules/module2_driver/presentation/screens/operator_data_screen.dart';

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
          effectiveAssignmentId.trim().isNotEmpty;
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
        final status = statuses[canonicalId]?.toLowerCase() ??
            statuses[uid]?.toLowerCase();
        if (status == 'collected' || status == 'skipped') {
          _showMessage('Already completed for this assignment.');
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
        if (candidate.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase() ==
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

  Future<Map<String, dynamic>?> _fetchCustomer(String uid) async {
    final uri = Uri.parse("${ApiConfig.desktopBase}waste/customer/")
        .replace(queryParameters: {"unique_id": uid});
    try {
      final resp = await http
          .get(uri, headers: await _authHeaders())
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return null;

      final payload = jsonDecode(resp.body);
      if (payload is! Map || payload["status"] != "success") return null;

      final data = payload["data"];
      return (data is Map<String, dynamic>) ? data : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _markHouseholdStatus({
    required String customerId,
    required String status,
    required String reason,
  }) async {
    final headers = {
      'Content-Type': 'application/json',
      ...await _authHeaders(),
    };
    final response = await http
        .post(
          Uri.parse(ApiConfig.householdCollectionMarkStatus),
          headers: headers,
          body: jsonEncode({
            'customer_id': customerId,
            'status': status,
            'reason': reason,
            'latitude': LocationService.latitude.toString(),
            'longitude': LocationService.longitude.toString(),
          }),
        )
        .timeout(const Duration(seconds: 12));

    if (response.statusCode >= 200 && response.statusCode < 300) return;

    String message = 'Unable to update household collection status.';
    try {
      final payload = jsonDecode(response.body);
      if (payload is Map && payload['detail'] != null) {
        message = payload['detail'].toString();
      } else if (payload is Map && payload['message'] != null) {
        message = payload['message'].toString();
      }
    } catch (_) {}
    throw Exception(message);
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

    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: CaptainTheme.surface,
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
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: CaptainTheme.strongText,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "ID: $customerId",
                style: TextStyle(color: CaptainTheme.mutedText),
              ),
              const SizedBox(height: 4),
              Text(
                customerName,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: CaptainTheme.strongText,
                ),
              ),
              if (contactNo.isNotEmpty)
                Text(
                  "Contact: $contactNo",
                  style: TextStyle(color: CaptainTheme.mutedText),
                ),
              const SizedBox(height: 16),

              /// BUTTONS
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          Navigator.of(sheetContext).pop('collect');
                        },
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: CaptainTheme.accentGradient,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_outline,
                                  color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                'Collect',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: CaptainTheme.strongText,
                        side: BorderSide(color: CaptainTheme.hairline),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () {
                        Navigator.of(sheetContext).pop('not_available');
                      },
                      child: const Text("Not available"),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: CaptainTheme.strongText,
                        side: BorderSide(color: CaptainTheme.hairline),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () {
                        Navigator.of(sheetContext).pop('collect_later');
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

    if (!mounted) return;
    await _waitForModalTeardown();
    if (!mounted) return;
    switch (action) {
      case 'collect':
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OperatorDataScreen(
              customerId: customerId,
              customerName: customerName,
              contactNo: contactNo,
              latitude: latitude,
              longitude: longitude,
              skipBluetoothInit: false,
              assignmentId:
                  (assignmentId != null && assignmentId.trim().isNotEmpty)
                      ? assignmentId
                      : null,
            ),
          ),
        );
        if (!mounted) return;
        Navigator.of(context).pop(widget.returnToAssignments ? true : null);
        break;
      case 'not_available':
        final saved = await _showStatusReasonSheet(
          customerId: customerId,
          customerName: customerName,
          assignmentId: assignmentId,
          localStatus: 'skipped',
          status: 'Missed',
          title: 'Why is this household not available?',
          quickReasons: const [
            'Door locked',
            'Customer not home',
            'Refused collection',
            'QR not accessible',
          ],
        );
        if (!mounted) return;
        if (saved) {
          await _finishScanner(true);
        } else {
          await _restartScanner(waitForModalTeardown: true);
        }
        break;
      case 'collect_later':
        final saved = await _showStatusReasonSheet(
          customerId: customerId,
          customerName: customerName,
          assignmentId: assignmentId,
          localStatus: 'later',
          status: 'Skipped',
          title: 'Why collect this household later?',
          quickReasons: const [
            'Asked to return later',
            'Waste not ready',
            'Street blocked',
            'Vehicle capacity issue',
          ],
        );
        if (!mounted) return;
        if (saved) {
          await _finishScanner(true);
        } else {
          await _restartScanner(waitForModalTeardown: true);
        }
        break;
      default:
        await _finishScanner(widget.returnToAssignments ? false : null);
    }
  }

  Future<bool> _showStatusReasonSheet({
    required String customerId,
    required String customerName,
    required String? assignmentId,
    required String localStatus,
    required String status,
    required String title,
    required List<String> quickReasons,
  }) async {
    final controller = TextEditingController();
    String? selectedReason;
    String? errorText;
    var submitting = false;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: CaptainTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> submit() async {
              final reason = controller.text.trim();
              if (reason.isEmpty) {
                setSheetState(() {
                  errorText = 'Enter a reason before saving.';
                });
                return;
              }

              setSheetState(() {
                submitting = true;
                errorText = null;
              });

              try {
                await _markHouseholdStatus(
                  customerId: customerId,
                  status: status,
                  reason: reason,
                );
                if (!sheetContext.mounted) return;
                FocusScope.of(sheetContext).unfocus();
                await Future<void>.delayed(const Duration(milliseconds: 80));
                if (!sheetContext.mounted) return;
                Navigator.of(sheetContext).pop(true);
              } catch (e) {
                if (!sheetContext.mounted) return;
                setSheetState(() {
                  submitting = false;
                  errorText = e.toString().replaceFirst('Exception: ', '');
                });
              }
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: CaptainTheme.strongText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$customerName • $customerId',
                    style: TextStyle(color: CaptainTheme.mutedText),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: quickReasons.map((reason) {
                      final selected = selectedReason == reason;
                      return ChoiceChip(
                        label: Text(reason),
                        selected: selected,
                        selectedColor: CaptainTheme.accentSoft,
                        backgroundColor: CaptainTheme.surface,
                        disabledColor: CaptainTheme.surfaceMuted,
                        checkmarkColor: CaptainTheme.accentDeep,
                        labelStyle: TextStyle(
                          color: selected
                              ? CaptainTheme.accentDeep
                              : CaptainTheme.strongText,
                          fontWeight: FontWeight.w700,
                        ),
                        side: BorderSide(
                          color: selected
                              ? CaptainTheme.accent
                              : CaptainTheme.hairline,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        onSelected: submitting
                            ? null
                            : (_) {
                                setSheetState(() {
                                  selectedReason = reason;
                                  controller.text = reason;
                                  errorText = null;
                                });
                              },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    enabled: !submitting,
                    cursorColor: CaptainTheme.accent,
                    style: TextStyle(
                      color: CaptainTheme.strongText,
                      fontWeight: FontWeight.w600,
                    ),
                    minLines: 2,
                    maxLines: 4,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: 'Reason',
                      labelStyle: TextStyle(color: CaptainTheme.mutedText),
                      hintStyle: TextStyle(color: CaptainTheme.mutedText),
                      hintText: 'Enter what happened at this household',
                      errorText: errorText,
                      filled: true,
                      fillColor: CaptainTheme.surfaceMuted,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: CaptainTheme.hairline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: CaptainTheme.accent,
                          width: 1.4,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: CaptainTheme.danger),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: CaptainTheme.danger,
                          width: 1.4,
                        ),
                      ),
                    ),
                    onChanged: (_) {
                      if (errorText != null) {
                        setSheetState(() => errorText = null);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CaptainTheme.accentDeep,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: CaptainTheme.surfaceMuted,
                        disabledForegroundColor: CaptainTheme.mutedText,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: submitting ? null : submit,
                      icon: submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(submitting ? 'Saving...' : 'Save status'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    controller.dispose();

    if (saved == true) {
      final trimmedAssignmentId = assignmentId?.trim();
      if (trimmedAssignmentId != null && trimmedAssignmentId.isNotEmpty) {
        try {
          await AssignmentStatusStore.setStatusForAssignment(
            trimmedAssignmentId,
            customerId,
            localStatus,
          );
        } catch (e) {
          debugPrint('Failed to cache household status: $e');
        }
      }
    }
    return saved == true;
  }

  /// ---------------------------------------------------------
  /// Helpers
  /// ---------------------------------------------------------
  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _finishScanner(Object? result) async {
    await _waitForModalTeardown();
    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  Future<void> _waitForModalTeardown() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 350));
  }

  Future<void> _restartScanner({bool waitForModalTeardown = false}) async {
    if (waitForModalTeardown) {
      await _waitForModalTeardown();
      if (!mounted) return;
    }
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
                Navigator.of(context)
                    .pop(widget.returnToAssignments ? false : null);
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
