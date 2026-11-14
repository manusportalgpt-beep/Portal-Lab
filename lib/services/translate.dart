import 'dart:convert';

import 'package:http/http.dart' as http;

import 'net.dart';

/// Google Translate client for mod descriptions.
///
/// Uses the public gtx endpoints; falls back to the Chrome dictionary
/// endpoint and finally to a Pollinations model translation, so the
/// "Translate description" button keeps working everywhere.
class TranslateService {
  static const _maxLength = 1400;

  /// Translate [text] into [target] (e.g. 'ru' / 'en').
  /// Returns the translated string; throws on total failure.
  static Future<String> translate(String text, String target) async {
    final chunks = _chunk(text);
    final out = <String>[];
    for (final c in chunks) {
      out.add(await _translateChunk(c, target));
    }
    return out.join('\n');
  }

  static List<String> _chunk(String text) {
    final paragraphs = text.split('\n');
    final chunks = <String>[];
    var current = '';
    for (final p in paragraphs) {
      if (current.length + p.length + 1 > _maxLength) {
        if (current.isNotEmpty) chunks.add(current);
        // Hard-split an extremely long paragraph.
        var rest = p;
        while (rest.length > _maxLength) {
          chunks.add(rest.substring(0, _maxLength));
          rest = rest.substring(_maxLength);
        }
        current = rest;
      } else {
        current = current.isEmpty ? p : '$current\n$p';
      }
    }
    if (current.isNotEmpty) chunks.add(current);
    return chunks.isEmpty ? [''] : chunks;
  }

  static Future<String> _translateChunk(String text, String target) async {
    final q = Uri.encodeComponent(text);
    // 1. Classic gtx "single" endpoint.
    try {
      final r = await http
          .get(
              Uri.parse(
                  'https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=$target&dt=t&q=$q'),
              headers: {'User-Agent': 'Mozilla/5.0 (Android 14) PortalLab'})
          .timeout(const Duration(seconds: 20));
      if (r.statusCode == 200) {
        final j = jsonDecode(r.body);
        if (j is List && j.isNotEmpty && j[0] is List) {
          final buf = StringBuffer();
          for (final seg in (j[0] as List)) {
            if (seg is List && seg.isNotEmpty && seg[0] is String) {
              buf.write(seg[0] as String);
            }
          }
          final out = buf.toString().trim();
          if (out.isNotEmpty) return out;
        }
      }
    } catch (_) {}
    // 2. clients5 chrome dictionary endpoint.
    try {
      final r = await http
          .get(
              Uri.parse(
                  'https://clients5.google.com/translate_a/t?client=dict-chrome-ex&sl=auto&tl=$target&q=$q'),
              headers: {'User-Agent': 'Mozilla/5.0 (Android 14) PortalLab'})
          .timeout(const Duration(seconds: 20));
      if (r.statusCode == 200) {
        final j = jsonDecode(r.body);
        if (j is List && j.isNotEmpty) {
          if (j[0] is List && (j[0] as List).isNotEmpty) {
            final first = (j[0] as List).first;
            if (first is String && first.trim().isNotEmpty) return first;
          } else if (j[0] is String) {
            return j[0] as String;
          }
        }
      }
    } catch (_) {}
    // 3. Last resort: ask a Pollinations model to translate.
    try {
      final r = await http
          .post(
              Uri.parse('https://text.pollinations.ai/openai'),
              headers: {
                'User-Agent': Net.ua,
                'Content-Type': 'application/json',
              },
              body: jsonEncode({
                'model': 'openai-fast',
                'stream': false,
                'messages': [
                  {
                    'role': 'system',
                    'content':
                        'You are a translation engine. Translate the user text into ${target == 'ru' ? 'Russian' : 'English'}. Output ONLY the translation, preserving line breaks. No emojis.'
                  },
                  {'role': 'user', 'content': text},
                ],
              }))
          .timeout(const Duration(seconds: 90));
      if (r.statusCode == 200) {
        final j = jsonDecode(utf8.decode(r.bodyBytes));
        final choices = j['choices'] as List?;
        if (choices != null && choices.isNotEmpty) {
          final msg = (choices.first as Map)['message'] as Map?;
          var content = (msg?['content'] as String?)?.trim() ?? '';
          content = content
              .replaceAll(
                  RegExp(r'<think>[\s\S]*?</think>', caseSensitive: false),
                  '')
              .trim();
          if (content.isNotEmpty) return content;
        }
      }
    } catch (_) {}
    throw Exception('translation failed');
  }
}
