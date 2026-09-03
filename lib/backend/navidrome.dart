import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:music_client/backend/types.dart';

// ┌─────────────────────────────────────────────────────────────┐
// │ NOTE                                                        │
// │                                                             │
// │ Top tracks require Navidrome's native API, since the        │
// │ Subsonic API does not expose this functionality.            │
// │                                                             │
// │ The native API is less stable than the Subsonic API.        │
// └─────────────────────────────────────────────────────────────┘

String get _baseUrl => dotenv.env['SUBSONIC_URL']!;
String get _user => dotenv.env['SUBSONIC_USER']!;
String get _password => dotenv.env['SUBSONIC_PASSWORD']!;

String? _jwtToken;
Future<String>? _loginFuture;

Future<String> _login() {
  return _loginFuture ??= _performLogin();
}

Future<String> _performLogin() async {
  final response = await http.post(
    Uri.parse('$_baseUrl/auth/login'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'username': _user, 'password': _password}),
  );

  if (response.statusCode != 200) {
    _loginFuture = null;
    throw Exception('Navidrome login failed: HTTP ${response.statusCode}');
  }

  final json =
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  final token = json['token'] as String?;
  if (token == null || token.isEmpty) {
    _loginFuture = null;
    throw Exception('Navidrome login response missing token');
  }

  _jwtToken = token;
  return token;
}

Future<String> _ensureToken() async {
  final token = _jwtToken;
  if (token != null) return token;
  return _login();
}

void _captureRotatedToken(http.Response response) {
  final rotated = response.headers['x-nd-authorization'];
  if (rotated == null || rotated.isEmpty) return;
  _jwtToken = rotated.startsWith('Bearer ')
      ? rotated.substring('Bearer '.length)
      : rotated;
}

Future<http.Response> _nativeGet(
  String path,
  Map<String, String> params,
) async {
  Future<http.Response> attempt() async {
    final token = await _ensureToken();
    final uri = Uri.parse(
      '$_baseUrl/api/$path',
    ).replace(queryParameters: params);
    return http.get(uri, headers: {'x-nd-authorization': 'Bearer $token'});
  }

  var response = await attempt();

  if (response.statusCode == 401) {
    // Token may be stale/expired: force a fresh login and retry once.
    _jwtToken = null;
    _loginFuture = null;
    response = await attempt();
  }

  if (response.statusCode != 200) {
    throw Exception('HTTP ${response.statusCode} for /api/$path');
  }

  _captureRotatedToken(response);
  return response;
}

Future<(List<Track>, int)> getTopTracks({
  required int offset,
  int size = 50,
}) async {
  final response = await _nativeGet('song', {
    '_sort': 'rating',
    '_order': 'DESC',
    '_start': '$offset',
    '_end': '${offset + size}',
  });

  final totalCount = response.headers['x-total-count'];

  final body = utf8.decode(response.bodyBytes);
  final list = jsonDecode(body) as List<dynamic>;
  return (
    list.map((e) => Track.fromJson(e as Map<String, dynamic>)).toList(),
    int.tryParse(totalCount ?? '0') ?? 0,
  );
}
