// import 'dart:convert';

// import 'package:dio/dio.dart';

// /// Thin client around the server-side chat proxy.
// ///
// /// NOTE: The actual AI key should stay on your server (PHP, Firebase, etc.).
// /// This class just calls the proxy endpoint so the mobile app never touches
// /// secrets directly.
// class ChatProxyApi {
//   ChatProxyApi({
//     Dio? httpClient,
//     String? baseUrl,
//   })  : _dio = httpClient ?? Dio(),
//         _baseUrl = baseUrl ?? _defaultBaseUrl;

//   static const String _defaultBaseUrl =
//       'https://your-domain.com/api/chat_proxy.php';

//   final Dio _dio;
//   final String _baseUrl;

//   Future<String> sendPrompt({
//     required List<Map<String, String>> messages,
//     String? authToken,
//   }) async {
//     final response = await _dio.post<Map<String, dynamic>>(
//       _baseUrl,
//       data: jsonEncode({'prompt': messages}),
//       options: Options(
//         headers: {
//           'Content-Type': 'application/json',
//           if (authToken != null) 'Authorization': 'Bearer $authToken',
//         },
//       ),
//     );

//     if (response.data == null) {
//       throw const ChatProxyException('Empty response from chat proxy');
//     }

//     final contents = response.data!;

//     if (contents.containsKey('error')) {
//       throw ChatProxyException(contents['error'].toString());
//     }

//     final result = contents['message'] ?? contents['response'];
//     if (result is String && result.isNotEmpty) {
//       return result;
//     }

//     throw const ChatProxyException('chat proxy returned malformed payload');
//   }
// }

// class ChatProxyException implements Exception {
//   const ChatProxyException(this.message);
//   final String message;

//   @override
//   String toString() => 'ChatProxyException: $message';
// }
