mobile login fails for "operator_user" and password is "Operator123" kinldy check and fix.


I/flutter (26954): *** DioException ***:
I/flutter (26954): uri: http://10.88.7.226:8000/api/v1/login/
I/flutter (26954): DioException [connection timeout]: The request connection took longer than 0:00:10.000000 and it was aborted. To get rid of this exception, try raising the RequestOptions.connectTimeout above the duration of 0:00:10.000000 or improve the response time of the server.
I/flutter (26954): 
I/flutter (26954): Staff login failed: DioException [connection timeout]: The request connection took longer than 0:00:10.000000 and it was aborted. To get rid of this exception, try raising the RequestOptions.connectTimeout above the duration of 0:00:10.000000 or improve the response time of the server.
I/flutter (26954): #0      DioMixin.fetch (package:dio/src/dio_mixin.dart:523:7)
I/flutter (26954): <asynchronous suspension>
I/flutter (26954): #1      AuthRepository._loginDesktopStaff (package:iwms_citizen_app/data/repositories/auth_repository.dart:190:24)
I/flutter (26954): <asynchronous suspension>
I/flutter (26954): #2      AuthRepository.loginCitizen (package:iwms_citizen_app/data/repositories/auth_repository.dart:142:20)
I/flutter (26954): <asynchronous suspension>
I/flutter (26954): #3      AuthBloc._onCitizenLoginRequested (package:iwms_citizen_app/logic/auth/auth_bloc.dart:80:20)
I/flutter (26954): <asynchronous suspension>
I/flutter (26954): #4      Bloc.on.<anonymous closure>.handleEvent (package:bloc/src/bloc.dart:226:13)
I/flutter (26954): <asynchronous suspension>
I/flutter (26954): 
I/flutter (26954): *** Request ***
I/flutter (26954): uri: http://10.88.7.226:8000/api/v1/login/
I/flutter (26954): method: POST
I/flutter (26954): responseType: ResponseType.json
I/flutter (26954): followRedirects: true
I/flutter (26954): persistentConnection: true
I/flutter (26954): connectTimeout: 0:00:10.000000
I/flutter (26954): sendTimeout: null
I/flutter (26954): receiveTimeout: 0:00:10.000000
I/flutter (26954): receiveDataWhenStatusError: true
I/flutter (26954): extra: {}
I/flutter (26954): headers:
I/flutter (26954):  content-type: application/json
I/flutter (26954): data:
I/flutter (26954): {username: operator_user, password: Operator123, login_type: staff}
I/flutter (26954): 
I/flutter (26954): *** DioException ***:
I/flutter (26954): uri: http://10.88.7.226:8000/api/v1/login/
I/flutter (26954): DioException [connection timeout]: The request connection took longer than 0:00:10.000000 and it was aborted. To get rid of this exception, try raising the RequestOptions.connectTimeout above the duration of 0:00:10.000000 or improve the response time of the server.
I/flutter (26954): 
I/flutter (26954): Staff login failed: DioException [connection timeout]: The request connection took longer than 0:00:10.000000 and it was aborted. To get rid of this exception, try raising the RequestOptions.connectTimeout above the duration of 0:00:10.000000 or improve the response time of the server.
I/flutter (26954): #0      DioMixin.fetch (package:dio/src/dio_mixin.dart:523:7)
I/flutter (26954): <asynchronous suspension>
I/flutter (26954): #1      AuthRepository._loginDesktopStaff (package:iwms_citizen_app/data/repositories/auth_repository.dart:190:24)
I/flutter (26954): <asynchronous suspension>
I/flutter (26954): #2      AuthRepository.loginCitizen (package:iwms_citizen_app/data/repositories/auth_repository.dart:142:20)
I/flutter (26954): <asynchronous suspension>
I/flutter (26954): #3      AuthBloc._onCitizenLoginRequested (package:iwms_citizen_app/logic/auth/auth_bloc.dart:80:20)
I/flutter (26954): <asynchronous suspension>
I/flutter (26954): #4      Bloc.on.<anonymous closure>.handleEvent (package:bloc/src/bloc.dart:226:13)
I/flutter (26954): <asynchronous suspension>
I/flutter (26954): 


Performing system checks...

System check identified no issues (0 silenced).
June 11, 2026 - 17:03:09
Django version 5.2.8, using settings 'config.settings'
Starting development server at http://0.0.0.0:8000/
Quit the server with CONTROL-C.

WARNING: This is a development server. Do not use it in a production setting. Use a production WSGI or ASGI server instead.
For more information on production servers see: https://docs.djangoproject.com/en/5.2/howto/deployment/

backend no hits.