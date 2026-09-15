import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class Api {
  static const base = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:3000');
  static String? token;
  static Map<String, dynamic> user = {};
  static Future<dynamic> request(String method, String path, [Map<String, dynamic>? body]) async {
    final req = http.Request(method, Uri.parse('$base$path'));
    req.headers['Content-Type'] = 'application/json';
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    if (body != null) req.body = jsonEncode(body);
    try {
      final response = await http.Response.fromStream(await req.send()).timeout(const Duration(seconds: 15));
      final dynamic data = response.body.isEmpty ? {} : jsonDecode(response.body);
      if (response.statusCode >= 400) {
        final dynamic message = data is Map ? data['message'] : null;
        throw Exception(message is List ? message.join('\n') : message ?? '요청에 실패했습니다.');
      }
      return data;
    } on TimeoutException { throw Exception('서버 응답이 늦습니다. 연결을 확인해주세요.'); }
    on http.ClientException { throw Exception('서버에 연결할 수 없습니다. 백엔드 실행과 API 주소를 확인해주세요.'); }
  }
  static Future<void> login(String email, String password) async {
    token = null; user = {};
    final result = await request('POST', '/auth/login', {'email': email.trim(), 'password': password});
    token = result['accessToken'] as String;
    try { user = Map<String, dynamic>.from(await request('GET', '/community/me')); }
    catch (_) { token = null; rethrow; }
  }
  static void logout() { token = null; user = {}; }
}
