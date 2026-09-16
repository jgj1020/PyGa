import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class Api {
  static const _configuredBase = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static final http.Client _client = http.Client();

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

    final streamed = await _client.send(req).timeout(const Duration(seconds: 65));
    final response = await http.Response.fromStream(streamed);

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
        rethrow;
      }
    }

    if (lastConnectionError != null) {
      throw Exception('백엔드 서버에 연결할 수 없습니다. 서버가 깨어나는 중이면 잠시 후 다시 시도해주세요.');
    }
    throw Exception('서버 요청에 실패했습니다.');
  }

  /// Render 무료 서버가 잠들어 있을 때 사용자가 입력하는 동안 미리 깨웁니다.
  static Future<void> warmup() async {
    for (final candidate in _baseCandidates) {
      try {
        final response = await _client
            .get(Uri.parse('$candidate/'))
            .timeout(const Duration(seconds: 20));
        if (response.statusCode < 500) {
          _activeBase = candidate;
          return;
        }
      } catch (_) {}
    }
  }

  static Future<void> register(String nickname, String email, String password) async {
    token = null;
    user = {};
    final result = await request('POST', '/auth/register', {
      'nickname': nickname.trim(),
      'email': email.trim().toLowerCase(),
      'password': password,
    });
    token = result['accessToken'] as String;
    user = Map<String, dynamic>.from(result['user'] as Map);
  }

  static Future<void> login(String email, String password) async {
    token = null;
    user = {};
    final result = await request('POST', '/auth/login', {
      'email': email.trim().toLowerCase(),
      'password': password,
    });
    token = result['accessToken'] as String;
    user = Map<String, dynamic>.from(result['user'] as Map);
  }

  static Future<void> adminLogin(String email, String password) async {
    token = null;
    user = {};
    final result = await request('POST', '/auth/admin/login', {
      'email': email.trim().toLowerCase(),
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
