import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../../../core/api_config.dart';
import '../models/waste_period.dart';
import '../models/waste_reports.dart';
import '../models/waste_summary.dart';

class TrackService {
  TrackService({
    this.baseUrl =
        'https://zigma.in/d2d/folders/waste_collected_summary_report/test_waste_collected_data_api.php',
    this.apiKey = 'ZIGMA-DELHI-WEIGHMENT-2025-SECURE',
    http.Client? client,
  })  : _client = client ?? http.Client(),
        citizenSummaryEndpoint = ApiConfig.wasteSummaryEndpoint;

  final String baseUrl;
  final String apiKey;
  final http.Client _client;
  final String citizenSummaryEndpoint;

  Uri _buildUri(String action, Map<String, String> params) {
    return Uri.parse(baseUrl).replace(
      queryParameters: {
        'action': action,
        'key': apiKey,
        ...params,
      },
    );
  }

  Future<Map<String, WasteSummary>> fetchMonthlySummaries(DateTime reference) async {
    final monthKey = DateFormat('yyyy-MM').format(reference);
    final responseJson =
        await _getJson(_buildUri('month_wise_date', {'date': monthKey}));
    final dataList = _mapList(responseJson);

    final Map<String, WasteSummary> freshData = {};
    for (final raw in dataList) {
      final summary = WasteSummary.fromJson(raw);
      freshData[_dateKey(summary.date)] = summary;
    }
    return freshData;
  }

  Future<List<WasteSummary>> fetchDateWiseSummaries(
    DateTime from,
    DateTime to,
  ) async {
    final responseJson = await _getJson(
      _buildUri('date_wise_data', {
        'from_date': _dateKey(from),
        'to_date': _dateKey(to),
      }),
    );
    final dataList = _mapList(responseJson);
    return dataList.map(WasteSummary.fromJson).toList(growable: false);
  }

  Future<List<DayWiseTicket>> fetchDayWiseTickets(DateTime date) async {
    final dayKey = _dateKey(date);
    final responseJson = await _getJson(
      _buildUri('day_wise_data', {
        'from_date': dayKey,
        'to_date': dayKey,
      }),
    );
    final dataList = _mapList(responseJson);
    return dataList.map(DayWiseTicket.fromJson).toList(growable: false);
  }

  Future<List<VehicleWeightReport>> fetchVehicleWiseReport(
      DateTime date) async {
    final dayKey = _dateKey(date);
    final responseJson = await _getJson(
      _buildUri('vehicle_wise_data', {'from_date': dayKey}),
    );
    final dataList = _mapList(responseJson);
    return dataList
        .map(VehicleWeightReport.fromJson)
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final response =
        await _client.get(uri).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch live data (${response.statusCode})');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) return decoded;
    throw Exception('Unexpected response format');
  }

  List<Map<String, dynamic>> _mapList(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().toList(growable: false);
    }
    return const [];
  }

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<WasteSummary?> fetchCitizenSummary({
    required WastePeriod period,
    required DateTime referenceDate,
  }) async {
    final normalized = DateTime(referenceDate.year, referenceDate.month, referenceDate.day);
    final uri = Uri.parse(citizenSummaryEndpoint).replace(
      queryParameters: {
        'period': period.name,
        'date': _dateKey(normalized),
      },
    );

    final response = await _client.get(uri).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch waste summary (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected response payload');
    }
    if (decoded['status'] != 'success') {
      throw Exception('Backend returned error');
    }

    final data = decoded['data'];
    if (data is Map<String, dynamic>) {
      return WasteSummary.fromJson(data);
    }
    return null;
  }
}
