import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../models.dart';
import 'msa.dart';
import 'net.dart';
import '../store.dart';

/// A skin texture resolved from the Mojang session servers.
class PlayerSkin {
  final String url;
  final String variant; // classic | slim
  const PlayerSkin({required this.url, required this.variant});
}

/// Skin management.
///
///  * Microsoft accounts: the skin is changed through the official
///    Minecraft Services API (api.minecraftservices.com) — the new skin is
///    stored on the Mojang servers and every player sees it.
///  * Offline accounts: a local override stored on this device only. The
///    player who changed it sees the new skin in the launcher, everyone else
///    (and the servers) still see the standard offline skin by nickname.
class SkinService {
  static const _api = 'https://api.minecraftservices.com';
  static const _sessionServer =
      'https://sessionserver.mojang.com/session/minecraft/profile';

  static final Map<String, PlayerSkin> _skinCache = {};

  // ------------------------------------------------------------------
  // Lookups (any player by name / UUID)
  // ------------------------------------------------------------------

  /// UUID of an online player by nickname, or null when not found.
  static Future<String?> uuidByName(String name) async {
    final n = name.trim();
    if (n.isEmpty) return null;
    // Legacy Mojang endpoint (name -> UUID).
    try {
      final r = await http
          .get(Uri.parse('https://api.mojang.com/users/profiles/minecraft/'
              '${Uri.encodeComponent(n)}'))
          .timeout(const Duration(seconds: 20));
      if (r.statusCode == 200) {
        final j = jsonDecode(r.body) as Map<String, dynamic>;
        final id = j['id'] as String?;
        if (id != null && id.length == 32) return dashed(id);
      }
    } catch (_) {}
    // Modern bulk lookup on the services API.
    try {
      final r = await http
          .post(Uri.parse('$_api/minecraft/profile/lookup/bulk/byname'),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                'User-Agent': Net.ua,
              },
              body: jsonEncode([n]))
          .timeout(const Duration(seconds: 20));
      if (r.statusCode == 200) {
        final j = jsonDecode(r.body) as List;
        for (final e in j) {
          final id = (e as Map)['id'] as String?;
          if (id != null && id.length == 32) return dashed(id);
        }
      }
    } catch (_) {}
    return null;
  }

  /// Active skin of any online player by UUID (session server).
  static Future<PlayerSkin?> skinByUuid(String uuid) async {
    final u = dashed(uuid);
    final cached = _skinCache[u];
    if (cached != null) return cached;
    try {
      final j = await Net.getJson('$_sessionServer/$u');
      final props = (j['properties'] as List?) ?? const [];
      for (final p in props) {
        final pm = p as Map<String, dynamic>;
        if (pm['name'] != 'textures') continue;
        final decoded =
            utf8.decode(base64Decode(pm['value'] as String));
        final t = jsonDecode(decoded) as Map<String, dynamic>;
        final textures = (t['textures'] as Map?) ?? {};
        final skin = textures['SKIN'] as Map?;
        if (skin == null) continue;
        final url = skin['url'] as String?;
        if (url == null) continue;
        final model =
            ((skin['metadata'] as Map?)?['model'] as String?) ?? 'classic';
        final ps = PlayerSkin(url: url, variant: model);
        _skinCache[u] = ps;
        return ps;
      }
    } catch (_) {}
    return null;
  }

  /// Active skin of any online player by nickname.
  static Future<PlayerSkin?> skinByName(String name) async {
    final uuid = await uuidByName(name);
    if (uuid == null) return null;
    return skinByUuid(uuid);
  }

  /// Own profile of the signed-in Microsoft account.
  static Future<Map<String, dynamic>> ownProfile(String token) =>
      Net.getJson('$_api/minecraft/profile',
          headers: {'Authorization': 'Bearer $token'});

  // ------------------------------------------------------------------
  // Microsoft skin management (visible to everyone)
  // ------------------------------------------------------------------

  /// Change the Microsoft account skin from a URL.
  /// Returns the updated profile JSON.
  static Future<Map<String, dynamic>> uploadFromUrl(
      String token, String url, String variant) async {
    final prof = await Net.postJson('$_api/minecraft/profile/skins',
        {'url': url, 'variant': variant},
        headers: {'Authorization': 'Bearer $token'});
    return prof;
  }

  /// Change the Microsoft account skin from a local PNG file
  /// (multipart upload). Returns the updated profile JSON.
  static Future<Map<String, dynamic>> uploadFromFile(
      String token, File png, String variant) async {
    final bytes = await png.readAsBytes();
    validateSkinPng(bytes, strict: true);
    final boundary = 'portallab${DateTime.now().millisecondsSinceEpoch}';
    final body = <int>[];
    void part(String s) => body.addAll(utf8.encode(s));
    part('--$boundary\r\n');
    part('Content-Disposition: form-data; name="variant"\r\n\r\n');
    part('$variant\r\n');
    part('--$boundary\r\n');
    part('Content-Disposition: form-data; name="file"; '
        'filename="skin.png"\r\n');
    part('Content-Type: image/png\r\n\r\n');
    body.addAll(bytes);
    part('\r\n--$boundary--\r\n');
    final r = await http
        .post(Uri.parse('$_api/minecraft/profile/skins'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'multipart/form-data; boundary=$boundary',
              'Accept': 'application/json',
            },
            body: body)
        .timeout(const Duration(seconds: 60));
    if (r.statusCode >= 400) throw HttpError(r.statusCode, r.body);
    return _parseOrEmpty(r.bodyBytes);
  }

  /// Reset the Microsoft account skin to the default (Steve / Alex).
  static Future<Map<String, dynamic>> resetToDefault(String token) async {
    var r = await http
        .delete(Uri.parse('$_api/minecraft/profile/skins/active'), headers: {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    }).timeout(const Duration(seconds: 30));
    if (r.statusCode >= 400 &&
        r.statusCode != 404 &&
        r.statusCode != 405) {
      throw HttpError(r.statusCode, r.body);
    }
    if (r.statusCode >= 400) {
      // Older flow: POST on the same path with a variant body.
      r = await http
          .post(Uri.parse('$_api/minecraft/profile/skins/active'),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: jsonEncode({'variant': 'classic'}))
          .timeout(const Duration(seconds: 30));
      if (r.statusCode >= 400) throw HttpError(r.statusCode, r.body);
    }
    return _parseOrEmpty(r.bodyBytes);
  }

  /// Run a token-dependent call, refreshing the Microsoft token once on 401.
  /// Returns the call result plus a refreshed account (when a refresh
  /// happened) so the caller can persist the new tokens.
  static Future<(Map<String, dynamic>, McAccount?)> withTokenRefresh(
      McAccount acc,
      Future<Map<String, dynamic>> Function(String token) fn) async {
    final token = acc.accessToken;
    if (token == null) throw Exception('no access token');
    try {
      return (await fn(token), null);
    } on HttpError catch (e) {
      if (e.code != 401) rethrow;
      final fresh = await MsaService.refresh(acc);
      final t = fresh?.accessToken;
      if (t == null) rethrow;
      return (await fn(t), fresh);
    }
  }

  /// Copy profile fields (name, active skin, model) onto an account.
  static McAccount applyProfile(McAccount acc, Map<String, dynamic> prof) {
    final skins = (prof['skins'] as List?) ?? const [];
    for (final s in skins) {
      final sm = s as Map<String, dynamic>;
      if (sm['state'] == 'ACTIVE') {
        acc.skinUrl = sm['url'] as String?;
        final v = sm['variant'] as String?;
        acc.skinModel =
            (v == null || v.isEmpty) ? null : v.toLowerCase();
        break;
      }
    }
    final name = prof['name'] as String?;
    if (name != null && name.isNotEmpty) acc.username = name;
    return acc;
  }

  // ------------------------------------------------------------------
  // Local (device-only) overrides for offline accounts
  // ------------------------------------------------------------------

  /// The visible folder that holds local skin overrides.
  static Directory get skinsDir {
    final d = Directory('${Store.exportsDir.path}/skins');
    if (!d.existsSync()) d.createSync(recursive: true);
    return d;
  }

  static File localSkinFile(String uuid) => File(
      '${skinsDir.path}/${uuid.replaceAll(RegExp(r'[^0-9a-zA-Z-]'), '_')}'
      '.png');

  /// Store a local skin override for an offline account.
  /// Returns the written file path.
  static Future<String> applyLocalSkin(
      McAccount acc, List<int> pngBytes, String model) async {
    validateSkinPng(pngBytes, strict: false);
    final f = localSkinFile(acc.uuid);
    await f.writeAsBytes(pngBytes);
    acc.localSkinPath = f.path;
    acc.localSkinModel = model;
    return f.path;
  }

  /// Remove the local override of an account.
  static Future<void> clearLocalSkin(McAccount acc) async {
    final path = acc.localSkinPath;
    if (path != null) {
      final f = File(path);
      if (await f.exists()) await f.delete();
    }
    acc.localSkinPath = null;
    acc.localSkinModel = null;
  }

  /// Download raw skin bytes from a texture URL.
  static Future<List<int>> downloadSkinBytes(String url) async {
    final r = await http
        .get(Uri.parse(url), headers: Net.baseHeaders)
        .timeout(const Duration(seconds: 40));
    if (r.statusCode != 200) throw HttpError(r.statusCode, r.body);
    return r.bodyBytes;
  }

  // ------------------------------------------------------------------
  // Helpers
  // ------------------------------------------------------------------

  /// The UUID an offline (cracked) server assigns to a nickname:
  /// MD5 of "OfflinePlayer:<name>", formatted as UUID v3.
  static String offlineUuid(String name) {
    final h = md5.convert(utf8.encode('OfflinePlayer:$name')).bytes.toList();
    h[6] = (h[6] & 0x0f) | 0x30; // version 3
    h[8] = (h[8] & 0x3f) | 0x80; // IETF variant
    String hex(int i) => h[i].toRadixString(16).padLeft(2, '0');
    final s = [for (var i = 0; i < 16; i++) hex(i)].join();
    return '${s.substring(0, 8)}-${s.substring(8, 12)}-'
        '${s.substring(12, 16)}-${s.substring(16, 20)}-${s.substring(20)}';
  }

  /// Default model for a UUID (vanilla picks Alex for roughly half of the
  /// players): deterministic by UUID hash.
  static bool defaultSlim(String uuid) => (uuid.hashCode & 1) == 1;

  /// Throws [FormatException] when the bytes are not a valid skin PNG.
  /// Strict mode (Microsoft upload) accepts only 64x64 / 64x32; the local
  /// override also accepts HD (128x128 / 128x64) skins.
  static void validateSkinPng(List<int> bytes, {bool strict = true}) {
    const sig = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
    if (bytes.length < 33) {
      throw const FormatException('not a png');
    }
    for (var i = 0; i < 8; i++) {
      if (bytes[i] != sig[i]) {
        throw const FormatException('not a png');
      }
    }
    int be32(int o) => (bytes[o] << 24) |
        (bytes[o + 1] << 16) |
        (bytes[o + 2] << 8) |
        bytes[o + 3];
    final w = be32(16);
    final h = be32(20);
    final ok = strict
        ? (w == 64 && (h == 64 || h == 32))
        : ((w == 64 && (h == 64 || h == 32)) ||
            (w == 128 && (h == 128 || h == 64)));
    if (!ok) {
      throw FormatException('unsupported skin size ${w}x$h');
    }
  }

  static String dashed(String uuid) {
    final s = uuid.replaceAll('-', '').toLowerCase();
    if (s.length != 32) return uuid;
    return '${s.substring(0, 8)}-${s.substring(8, 12)}-'
        '${s.substring(12, 16)}-${s.substring(16, 20)}-${s.substring(20)}';
  }

  static Map<String, dynamic> _parseOrEmpty(List<int> body) {
    if (body.isEmpty) return <String, dynamic>{};
    try {
      return jsonDecode(utf8.decode(body)) as Map<String, dynamic>;
    } catch (_) {
      return <String, dynamic>{};
    }
  }
}
