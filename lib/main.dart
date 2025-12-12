import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:iwms_citizen_app/core/di.dart';
import 'package:iwms_citizen_app/localization/app_localizations.dart';
import 'package:iwms_citizen_app/logic/auth/auth_bloc.dart';
import 'package:iwms_citizen_app/logic/locale/locale_cubit.dart';
import 'package:iwms_citizen_app/logic/theme/theme_cubit.dart';
import 'package:iwms_citizen_app/router/app_router.dart';
import 'package:iwms_citizen_app/router/go_router_refresh_stream.dart';
import 'package:iwms_citizen_app/router/route_observer.dart';
import 'package:iwms_citizen_app/shared/services/notification_service.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupDI(); // Await the DI setup
  await getIt<NotificationService>().initialize();

  final authBloc = getIt<AuthBloc>();
  final appRouter = AppRouter(
    authBloc: authBloc, // Pass the BLoC instance
    routeObserver: routeObserver,
    refreshListenable: GoRouterRefreshStream(authBloc.stream),
  );

  runApp(
    MyApp(
      appRouter: appRouter.router,
      authBloc: authBloc,
    ),
  );
}

class MyApp extends StatelessWidget {
  final GoRouter appRouter;
  final AuthBloc authBloc;

  const MyApp({super.key, required this.appRouter, required this.authBloc});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: authBloc),
        BlocProvider<ThemeCubit>(create: (_) => ThemeCubit()),
        BlocProvider<LocaleCubit>(create: (_) => LocaleCubit()),
      ],
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, themeMode) {
          return BlocBuilder<LocaleCubit, Locale>(
            builder: (context, locale) {
              return MaterialApp.router(
                debugShowCheckedModeBanner: false,
                title: 'IWMS',
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: themeMode,
                routerConfig: appRouter,
                locale: locale,
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
              );
            },
          );
        },
      ),
    );
  }
}
