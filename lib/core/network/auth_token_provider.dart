import 'package:iwms_citizen_app/core/di.dart';
import 'package:iwms_citizen_app/data/repositories/auth_repository.dart';

class AuthTokenProvider {
  static Future<String?> getToken() async {
    final authRepo = getIt<AuthRepository>();
    final user = await authRepo.getAuthenticatedUser();
    return user?.authToken;
  }
}
