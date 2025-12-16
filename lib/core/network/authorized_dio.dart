import 'package:dio/dio.dart';
import 'package:iwms_citizen_app/core/di.dart';
import 'package:iwms_citizen_app/data/repositories/auth_repository.dart';

Future<Dio> authorizedDio() async {
  final dio = getIt<Dio>();
  final authRepo = getIt<AuthRepository>();

  final user = await authRepo.getAuthenticatedUser();

  if (user?.authToken != null && user!.authToken!.isNotEmpty) {
    dio.options.headers['Authorization'] =
        'Bearer ${user.authToken}';
  }

  dio.options.headers['Content-Type'] = 'application/json';
  return dio;
}
