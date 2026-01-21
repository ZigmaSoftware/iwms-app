import 'package:dio/dio.dart';
import 'package:iwms_citizen_app/core/di.dart';
import 'package:iwms_citizen_app/data/repositories/auth_repository.dart';

Dio _cloneBaseDio() {
  final base = getIt<Dio>();
  base.options.headers.remove('Authorization');

  final headers = Map<String, dynamic>.from(base.options.headers);
  headers.remove('Authorization');

  final options = BaseOptions(
    baseUrl: base.options.baseUrl,
    connectTimeout: base.options.connectTimeout,
    receiveTimeout: base.options.receiveTimeout,
    sendTimeout: base.options.sendTimeout,
    headers: headers,
    contentType: base.options.contentType,
    responseType: base.options.responseType,
    followRedirects: base.options.followRedirects,
    validateStatus: base.options.validateStatus,
    receiveDataWhenStatusError: base.options.receiveDataWhenStatusError,
  );

  final dio = Dio(options);
  dio.interceptors.addAll(base.interceptors);
  dio.httpClientAdapter = base.httpClientAdapter;
  return dio;
}

Future<Dio> authorizedDio() async {
  final dio = _cloneBaseDio();
  final authRepo = getIt<AuthRepository>();

  final user = await authRepo.getAuthenticatedUser();
  dio.options.headers['Content-Type'] = 'application/json';

  if (user?.authToken != null && user!.authToken!.isNotEmpty) {
    dio.options.headers['Authorization'] = 'Bearer ${user.authToken}';
  } else {
    dio.options.headers.remove('Authorization');
  }

  return dio;
}
