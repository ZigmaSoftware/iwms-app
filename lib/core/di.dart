import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:iwms_citizen_app/data/repositories/assignment_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:iwms_citizen_app/data/repositories/auth_repository.dart';
import 'package:iwms_citizen_app/data/repositories/operator_trip_repository.dart';
import 'package:iwms_citizen_app/logic/auth/auth_bloc.dart';
import 'package:iwms_citizen_app/modules/module3_operator/logic/operator_trip_bloc.dart';
import 'package:iwms_citizen_app/modules/module5_supervisor/data/supervisor_repository.dart';
import 'package:iwms_citizen_app/shared/services/collection_history_service.dart';
import 'package:iwms_citizen_app/shared/services/notification_service.dart';
import 'package:iwms_citizen_app/modules/module1_citizen/citizen/dashboard/notifications/controllers/notification_controller.dart';
import 'package:iwms_citizen_app/data/repositories/site_repository.dart';

// --- Vehicle Tracking Imports ---
import 'package:iwms_citizen_app/data/repositories/vehicle_repository.dart';
import 'package:iwms_citizen_app/logic/vehicle_tracking/vehicle_bloc.dart';
// --- End Vehicle Tracking Imports ---

import 'api_config.dart';

final getIt = GetIt.instance;

Future<void> setupDI() async {
  // --- External ---
  getIt.registerSingleton<Dio>(createDioClient());

  final prefs = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(prefs);

  // --- Services ---
  getIt.registerLazySingleton(
    () => CollectionHistoryService(getIt<SharedPreferences>()),
  );
  getIt.registerLazySingleton(() => NotificationService());
  getIt.registerLazySingleton(
    () => NotificationController(getIt<NotificationService>()),
  );
  await getIt<CollectionHistoryService>().initialize();
  await getIt<NotificationService>().initialize();

  // --- Repositories ---
  getIt.registerLazySingleton(() => AuthRepository(
        // This one uses POSITIONAL arguments
        getIt<Dio>(),
        getIt<SharedPreferences>(),
      ));

  // --- Register your VehicleRepository ---
  getIt.registerLazySingleton(() => VehicleRepository(
        dioClient: getIt<Dio>(),
      ));

  // --- Site polygons repository (Alpha/Beta/Gamma) ---
  getIt.registerLazySingleton(() => SiteRepository(
        dioClient: getIt<Dio>(),
      ));

  // --- BLoCs ---
  getIt.registerFactory(() => AuthBloc(
        authRepository: getIt<AuthRepository>(),
      ));

  // --- Register your VehicleBloc ---
  getIt.registerFactory(() => VehicleBloc(
        getIt<VehicleRepository>(),
      ));
      getIt.registerLazySingleton<AssignmentRepository>(
  () => AssignmentRepository(getIt<Dio>()),
);

  // --- Operator-mobile flow ---
  getIt.registerLazySingleton<OperatorTripRepository>(
    () => OperatorTripRepository(),
  );
  getIt.registerFactory<OperatorTripBloc>(
    () => OperatorTripBloc(repository: getIt<OperatorTripRepository>()),
  );

  // --- Supervisor module ---
  getIt.registerLazySingleton<SupervisorRepository>(
    () => SupervisorRepository(),
  );
}
