import 'dart:developer' as developer;

import 'package:dio/dio.dart';

import 'package:iwms_citizen_app/core/api_config.dart';
import 'package:iwms_citizen_app/core/network/authorized_dio.dart';
import 'package:iwms_citizen_app/data/models/operator_trip_models.dart';

/// Thrown by the operator-trip repository for actionable, user-facing errors.
///
/// `code` matches the backend's error codes (NO_ACTIVE_TRIP, WRONG_WASTE_TYPE,
/// WRONG_PANCHAYAT, ALREADY_COLLECTED, BIN_NOT_FOUND, etc) so the UI can map
/// to localized messages without parsing strings.
class OperatorTripException implements Exception {
  final String code;
  final String message;
  final int? statusCode;

  OperatorTripException({
    required this.code,
    required this.message,
    this.statusCode,
  });

  @override
  String toString() => '[$code] $message';
}

class OperatorTripRepository {
  Future<OperatorTripToday?> fetchMyTripToday() async {
    final dio = await authorizedDio();
    try {
      final resp = await dio.get(ApiConfig.operatorMyTripToday);
      final data = resp.data;
      if (data is! Map<String, dynamic>) {
        return null;
      }
      return OperatorTripToday.fromJson(data);
    } on DioException catch (e) {
      _throwDio(e);
    }
  }

  Future<BinScanValidateResult> validateBinQr(String binQr) async {
    final dio = await authorizedDio();
    try {
      final resp = await dio.post(
        ApiConfig.operatorValidateBinQr,
        data: {'bin_qr': binQr},
      );
      return BinScanValidateResult.fromJson(
        Map<String, dynamic>.from(resp.data as Map),
      );
    } on DioException catch (e) {
      _throwDio(e);
    }
  }

  Future<BinScanSubmitResult> scanBin({
    required String binQr,
    required double weightKg,
    double? latitude,
    double? longitude,
    String? notes,
  }) async {
    final dio = await authorizedDio();
    try {
      final resp = await dio.post(
        ApiConfig.operatorScanBin,
        data: {
          'bin_qr': binQr,
          'weight_kg': weightKg.toStringAsFixed(2),
          if (latitude != null) 'latitude': latitude.toStringAsFixed(6),
          if (longitude != null) 'longitude': longitude.toStringAsFixed(6),
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
      );
      return BinScanSubmitResult.fromJson(
        Map<String, dynamic>.from(resp.data as Map),
      );
    } on DioException catch (e) {
      _throwDio(e);
    }
  }

  Future<List<OperatorTripHistorySummary>> fetchHistory({
    DateTime? from,
    DateTime? to,
  }) async {
    final dio = await authorizedDio();
    try {
      final resp = await dio.get(
        ApiConfig.operatorTripHistory,
        queryParameters: {
          if (from != null) 'from': _formatDate(from),
          if (to != null) 'to': _formatDate(to),
        },
      );
      final data = resp.data;
      final results = data is Map && data['results'] is List
          ? data['results'] as List
          : const <dynamic>[];
      return results
          .map((e) => OperatorTripHistorySummary.fromJson(
                Map<String, dynamic>.from(e as Map),
              ))
          .toList();
    } on DioException catch (e) {
      _throwDio(e);
    }
  }

  Future<OperatorTripHistoryDetail> fetchHistoryDetail(String tripId) async {
    final dio = await authorizedDio();
    try {
      final resp = await dio.get('${ApiConfig.operatorTripHistory}$tripId/');
      return OperatorTripHistoryDetail.fromJson(
        Map<String, dynamic>.from(resp.data as Map),
      );
    } on DioException catch (e) {
      _throwDio(e);
    }
  }

  // ---------------------------------------------------------------------------
  /// Converts a Dio failure into an `OperatorTripException` so the UI gets a
  /// consistent shape regardless of whether the error is a network problem,
  /// a 4xx with a JSON body, or a 5xx without one.
  Never _throwDio(DioException e) {
    final resp = e.response;
    final status = resp?.statusCode;
    final data = resp?.data;

    developer.log(
      'operator-trip Dio failure: type=${e.type} url=${e.requestOptions.uri} '
      'status=$status body=$data',
      name: 'OperatorTripRepository',
      error: e,
    );

    if (data is Map && data['code'] is String) {
      throw OperatorTripException(
        code: data['code'] as String,
        message: (data['detail'] ?? data['message'] ?? '').toString(),
        statusCode: status,
      );
    }

    // Network / connection-level failures (no HTTP response from server).
    if (resp == null) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          throw OperatorTripException(
            code: 'NETWORK_TIMEOUT',
            message:
                'Server did not respond. Check your connection and try again.',
          );
        case DioExceptionType.connectionError:
          throw OperatorTripException(
            code: 'NETWORK_UNREACHABLE',
            message:
                'Could not reach the IWMS server at ${e.requestOptions.uri.host}. Check Wi-Fi / VPN.',
          );
        case DioExceptionType.cancel:
          throw OperatorTripException(
            code: 'REQUEST_CANCELLED',
            message: 'Request was cancelled.',
          );
        case DioExceptionType.badCertificate:
          throw OperatorTripException(
            code: 'BAD_CERTIFICATE',
            message: 'Server certificate is not trusted.',
          );
        default:
          throw OperatorTripException(
            code: 'NETWORK_ERROR',
            message: 'Network error: ${e.message ?? e.type.name}',
          );
      }
    }

    // HTTP error without our expected JSON shape.
    if (status == 401 || status == 403) {
      throw OperatorTripException(
        code: 'UNAUTHORIZED',
        message: 'Your session is not authorised for this action. Please log in again.',
        statusCode: status,
      );
    }
    if (status != null && status >= 500) {
      throw OperatorTripException(
        code: 'SERVER_ERROR',
        message: 'Server error ($status). Please try again shortly.',
        statusCode: status,
      );
    }
    throw OperatorTripException(
      code: 'HTTP_$status',
      message: data is String && data.isNotEmpty
          ? data
          : 'Request failed with status $status.',
      statusCode: status,
    );
  }

  String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
