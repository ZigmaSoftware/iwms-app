import 'package:dio/dio.dart';
import 'package:iwms_citizen_app/core/network/auth_token_provider.dart';

class AuthDio {
  static final Dio dio = Dio()
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await AuthTokenProvider.getToken();

          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          options.headers['Content-Type'] = 'application/json';
          return handler.next(options);
        },
      ),
    );
}

Future<Map<String, String>> authHeader() async {
  final token = await AuthTokenProvider.getToken();

  final headers = <String, String>{
    "Accept": "application/json",
  };

  if (token != null && token.isNotEmpty) {
    headers["Authorization"] = "Bearer $token";
  }

  return headers;
}
