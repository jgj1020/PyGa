import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class Api {
  static const _configuredBase = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  // 웹 개발 환경에서 localhost가 IPv4/IPv6로 다르게 해석되어도
  // 로그인/페이지 이동이 막히지 않도록 실제 연결에 성공한 주소를 기억합니다.
  static String _activeBase = _configuredBase.isNotEmpty
      ? _normalizeBase(_configuredBase)
      : 'http://127.0.0.1:3000';

  static String get base => _activeBase;

  static String? token;
  static Map<String, dynamic> user = {};

  static String _normalizeBase(String value) {
    final trimmed = value.trim();
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }

  static List<String> get _baseCandidates {
    if (_configuredBase.trim().isNotEmpty) {
      final configured = _normalizeBase(_configuredBase);
      final uri = Uri.tryParse(configured);

      // 예전에 안내한 --dart-define=...localhost:3000 으로 실행해도
      // localhost/127.0.0.1 중 실제로 열려 있는 쪽을 자동 재시도합니다.
      if (uri != null && (uri.host == 'localhost' || uri.host == '127.0.0.1')) {
        final alternateHost = uri.host == 'localhost' ? '127.0.0.1' : 'localhost';
        final alternate = uri.replace(host: alternateHost).toString();
        return [configured, _normalizeBase(alternate)];
      }
      return [configured];
    }
    return const [
      'http://127.0.0.1:3000',
      'http://localhost:3000',
    ];
  }

  static Future<dynamic> _send(
    String baseUrl,
    String method,
    String path,
    Map<String, dynamic>? body,
  ) async {
    final req = http.Request(method, Uri.parse('$baseUrl$path'));
    req.headers['Content-Type'] = 'application/json';
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    if (body != null) req.body = jsonEncode(body);

    final response = await http.Response.fromStream(
      await req.send(),
    ).timeout(const Duration(seconds: 7));

    dynamic data = <String, dynamic>{};
    if (response.body.isNotEmpty) {
      try {
        data = jsonDecode(response.body);
      } on FormatException {
        data = {'message': response.body};
      }
    }

    if (response.statusCode >= 400) {
      final dynamic message = data is Map ? data['message'] : null;
      throw Exception(
        message is List
            ? message.join('\n')
            : message ?? '요청에 실패했습니다. (${response.statusCode})',
      );
    }

    return data;
  }

  static Future<dynamic> request(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    Object? lastConnectionError;

    for (final candidate in _baseCandidates) {
      try {
        final result = await _send(candidate, method, path, body);
        _activeBase = candidate;
        return result;
      } on TimeoutException catch (e) {
        lastConnectionError = e;
      } on http.ClientException catch (e) {
        lastConnectionError = e;
      } on Exception {
        // 서버가 응답한 400/401/403 등의 실제 오류는 다른 주소로 재시도하지 않습니다.
        rethrow;
      }
    }

    if (lastConnectionError != null) {
      throw Exception(
        '백엔드 서버에 연결할 수 없습니다. 서버가 실행 중인지 확인해주세요. '
        '(기본 주소: http://127.0.0.1:3000)',
      );
    }

    throw Exception('서버 요청에 실패했습니다.');
  }

  static Future<void> login(String email, String password) async {
    token = null;
    user = {};
    final result = await request('POST', '/auth/login', {
      'email': email.trim(),
      'password': password,
    });
    token = result['accessToken'] as String;
    try {
      user = Map<String, dynamic>.from(await request('GET', '/community/me'));
    } catch (_) {
      token = null;
      rethrow;
    }
  }

  static Future<void> adminLogin(String email, String password) async {
    token = null;
    user = {};
    final result = await request('POST', '/auth/admin/login', {
      'email': email.trim(),
      'password': password,
    });
    token = result['accessToken'] as String;
    user = Map<String, dynamic>.from(result['user'] as Map);
  }

  static void logout() {
    token = null;
    user = {};
  }
}
