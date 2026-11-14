import 'dart:convert';

import 'package:http/http.dart' as http;

/// Shared HTTP helpers.
class Net {
  static const ua =
      'PortalLab/1.0.0 (github.com/manusportalgpt-beep/Portal-Lab)';

  static final client = http.Client();

  static Map<String, String> get baseHeaders => {
        'User-Agent': ua,
        'Accept': 'application/json',
      };

  static Future<Map<String, dynamic>> getJson(String url,
      {Map<String, String>? headers, Duration timeout = const Duration(seconds: 20)}) async {
    final r = await client
        .get(Uri.parse(url), headers: {...baseHeaders, ...?headers})
        .timeout(timeout);
    if (r.statusCode != 200) {
      throw HttpError(r.statusCode, r.body);
    }
    return jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
  }

  static Future<List<dynamic>> getJsonList(String url,
      {Map<String, String>? headers}) async {
    final r = await client
        .get(Uri.parse(url), headers: {...baseHeaders, ...?headers})
        .timeout(const Duration(seconds: 25));
    if (r.statusCode != 200) {
      throw HttpError(r.statusCode, r.body);
    }
    return jsonDecode(utf8.decode(r.bodyBytes)) as List<dynamic>;
  }

  static Future<Map<String, dynamic>> postJson(String url, Object? body,
      {Map<String, String>? headers}) async {
    final r = await client
        .post(Uri.parse(url),
            headers: {
              'User-Agent': ua,
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              ...?headers,
            },
            body: jsonEncode(body))
        .timeout(const Duration(seconds: 25));
    if (r.statusCode >= 400) {
      throw HttpError(r.statusCode, r.body);
    }
    return jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
  }
}

class HttpError implements Exception {
  final int code;
  final String body;
  HttpError(this.code, this.body);
  @override
  String toString() => 'HTTP $code: ${body.length > 200 ? body.substring(0, 200) : body}';
}
