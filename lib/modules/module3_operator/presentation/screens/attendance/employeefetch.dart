import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  final String baseUrl = 'http://125.17.238.158:5000';

  Future<Map<String, dynamic>?> getEmployeeDetails(String empId) async {
    try {
      final normalizedId = _normalizeEmpId(empId);
      final requestUrl = '$baseUrl/get_user_server1/$normalizedId';

      print('Request URL: $requestUrl');

      final response = await http.get(Uri.parse(requestUrl));

      print('Response: ${response.statusCode} ${response.body}');

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }

      if (response.statusCode == 404) {
        print('User not found');
        return null;
      }

      print('Unhandled response: ${response.statusCode}');
      return null;
    } catch (e) {
      print('Error fetching employee details: $e');
      return null;
    }
  }

  String _normalizeEmpId(String empId) {
    final trimmed = empId.trim();

    if (trimmed.startsWith('ZGESPL/')) {
      return trimmed.split('/').last;
    }

    if (int.tryParse(trimmed) != null) {
      return trimmed.padLeft(3, '0');
    }

    throw FormatException('Invalid employee ID format');
  }
}
