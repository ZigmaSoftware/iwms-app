import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

import 'pending_record.dart';
import 'pending_record_dao.dart';
import 'pending_finalize_record.dart';
import 'pending_finalize_dao.dart';

class OfflineSyncService {
  final PendingRecordDao recordDao;
  final PendingFinalizeDao finalizeDao;
  final String baseUrl;

  StreamSubscription<dynamic>? _connSub;

  OfflineSyncService({
    required this.recordDao,
    required this.finalizeDao,
    required this.baseUrl,
  });

  void start() {
    _connSub = Connectivity().onConnectivityChanged.listen((_) async {
      if (await hasInternet()) {
        await syncAll();
      }
    });
  }

  Future<void> dispose() async {
    await _connSub?.cancel();
  }

  Future<bool> hasInternet() async {
    try {
      final socket = await Socket.connect("8.8.8.8", 53,
          timeout: const Duration(seconds: 2));
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  // -------------------------------------------------------------
  // MASTER SYNC HANDLER
  // -------------------------------------------------------------
  Future<void> syncAll() async {
    // ---- Step 1: Sync ALL sub-records first ----
    final subs = await recordDao.getAll();
    for (final r in subs) {
      final ok = await _syncSubRecord(r);

      if (ok && r.id != null) {
        await recordDao.deleteById(r.id!);
      }
    }

    // ---- Step 2: After subs are synced, sync finalize ----
    final finals = await finalizeDao.getAll();
    for (final f in finals) {
      final ok = await _syncFinalize(f);

      if (ok && f.id != null) {
        await finalizeDao.deleteById(f.id!);
      }
    }
  }

  // -------------------------------------------------------------
  // SYNC SUB-RECORD (INSERT / UPDATE)
  // -------------------------------------------------------------
  Future<bool> _syncSubRecord(PendingRecord r) async {
    final isUpdate = r.isUpdate == true;
    final hasBackendUID = r.uniqueId.startsWith("wcs");

    // If backend UID exists → always UPDATE
    final endpoint =
        isUpdate && hasBackendUID ? "/update-waste-sub/" : "/insert-waste-sub/";

    final url = Uri.parse("$baseUrl$endpoint");

    final req = http.MultipartRequest("POST", url)
      ..fields["screen_unique_id"] = r.screenId
      ..fields["customer_id"] = r.customerId
      ..fields["waste_type"] = r.wasteTypeId
      ..fields["weight"] = r.weight;

    if (r.latitude != null) req.fields["latitude"] = r.latitude.toString();
    if (r.longitude != null) req.fields["longitude"] = r.longitude.toString();

    // *********** For UPDATE ONLY ***********
    if (hasBackendUID) {
      req.fields["unique_id"] = r.uniqueId;
    }

    req.files.add(
      await http.MultipartFile.fromPath("image", r.imagePath),
    );

    http.StreamedResponse resp;
    try {
      resp = await req.send();
    } on SocketException catch (_) {
      return false;
    } on HttpException catch (_) {
      return false;
    } on http.ClientException catch (_) {
      return false;
    }

    final body = await http.Response.fromStream(resp);

    try {
      final data = json.decode(body.body);

      if (data["status"] != "success") return false;

      // ****************************
      // BACKEND RETURNED NEW UNIQUE_ID
      // ****************************
      final backendUID = data["unique_id"]?.toString();

      if (backendUID != null) {
        final updated = r.copyWith(
          uniqueId: backendUID,
          isUpdate: true,
        );

        // overwrite offline record so future sync uses backend UID
        await recordDao.update(updated);
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  // -------------------------------------------------------------
  // SYNC FINALIZE
  // -------------------------------------------------------------
  Future<bool> _syncFinalize(PendingFinalizeRecord r) async {
    final url = Uri.parse("$baseUrl/finalize-waste/");

    final req = http.MultipartRequest("POST", url)
      ..fields["screen_unique_id"] = r.screenId
      ..fields["customer_id"] = r.customerId
      ..fields["entry_type"] = r.entryType
      ..fields["total_waste_collected"] = r.totalWeight.toString();

    http.StreamedResponse resp;
    try {
      resp = await req.send();
    } on SocketException catch (_) {
      return false;
    } on HttpException catch (_) {
      return false;
    } on http.ClientException catch (_) {
      return false;
    }

    final body = await http.Response.fromStream(resp);

    try {
      final data = json.decode(body.body);
      return data["status"] == "success";
    } catch (_) {
      return false;
    }
  }
}
