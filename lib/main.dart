import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:iwms_citizen_app/localization/app_localizations.dart';
import 'package:iwms_citizen_app/core/di.dart';
import 'package:iwms_citizen_app/logic/auth/auth_bloc.dart';
import 'package:iwms_citizen_app/logic/theme/theme_cubit.dart';
import 'package:iwms_citizen_app/logic/locale/locale_cubit.dart';
import 'package:iwms_citizen_app/router/app_router.dart';
import 'package:iwms_citizen_app/router/go_router_refresh_stream.dart';
import 'package:iwms_citizen_app/router/route_observer.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await setupDI();

  final authBloc = getIt<AuthBloc>();

  final appRouter = AppRouter(
    authBloc: authBloc,
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

  const MyApp({
    super.key,
    required this.appRouter,
    required this.authBloc,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: authBloc),
        BlocProvider(create: (_) => ThemeCubit()),
        BlocProvider(create: (_) => LocaleCubit()), // ✅ FIX
      ],
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, themeMode) {
          return MaterialApp.router(
            debugShowCheckedModeBanner: false,
            title: 'IWMS',
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en'),
              Locale('hi'),
              Locale('ta'),
            ],
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeMode,
            routerConfig: appRouter,
          );
        },
      ),
    );
  }
}
