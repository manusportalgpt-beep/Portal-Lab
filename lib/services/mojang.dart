import 'dart:io';

import 'package:http/http.dart' as http;

import '../models.dart';
import 'net.dart';

/// Mojang version manifest + loader metadata (Fabric / Quilt / Forge / NeoForge).
class MojangService {
  static const manifestUrl =
      'https://launchermeta.mojang.com/mc/game/version_manifest_v2.json';

  static List<MojangVersion>? _cache;
  static DateTime _cacheTime = DateTime.fromMillisecondsSinceEpoch(0);

  static Future<List<MojangVersion>> versions({bool force = false}) async {
    if (!force &&
        _cache != null &&
        DateTime.now().difference(_cacheTime) < const Duration(minutes: 30)) {
      return _cache!;
    }
    final j = await Net.getJson(manifestUrl);
    final list = (j['versions'] as List)
        .map((e) => MojangVersion(
              id: e['id'] as String,
              type: e['type'] as String,
              releaseTime: e['releaseTime'] as String? ?? '',
              url: e['url'] as String,
            ))
        .toList();
    _cache = list;
    _cacheTime = DateTime.now();
    return list;
  }

  /// Loader versions available for a game version, newest first.
  static Future<List<String>> loaderVersions(
      String gameVersion, String loader) async {
    switch (loader) {
      case 'fabric':
        return _fabricMeta(
            'https://meta.fabricmc.net/v2/versions/loader/$gameVersion');
      case 'quilt':
        return _fabricMeta(
            'https://meta.quiltmc.org/v3/versions/loader/$gameVersion');
      case 'forge':
        return _forgeVersions(gameVersion);
      case 'neoforge':
        return _neoForgeVersions(gameVersion);
      default:
        return [];
    }
  }

  static Future<List<String>> _fabricMeta(String url) async {
    final j = await Net.getJsonList(url);
    return j
        .map((e) => ((e as Map)['loader'] as Map)['version'] as String)
        .toList();
  }

  static Future<List<String>> _forgeVersions(String gv) async {
    final j = await Net.getJson(
        'https://files.minecraftforge.net/net/minecraftforge/forge/promotions_slim.json');
    final promos = j['promos'] as Map<String, dynamic>;
    final out = <String>[];
    promos.forEach((k, v) {
      if (k.startsWith('$gv-') && v is String) out.add(v);
    });
    out.sort((a, b) {
      final ra = promos['$gv-recommended'] == a ? 0 : 1;
      final rb = promos['$gv-recommended'] == b ? 0 : 1;
      if (ra != rb) return ra - rb;
      return b.compareTo(a);
    });
    return out;
  }

  static Future<List<String>> _neoForgeVersions(String gv) async {
    final j = await Net.getJson(
        'https://maven.neoforged.net/api/maven/versions/releases/net/neoforged/neoforge');
    final vs = (j['versions'] as List).cast<String>();
    // MC 1.21.1 -> NeoForge 21.1.x ; 1.20.1 -> 20.1.x
    final prefix = gv.startsWith('1.') ? gv.substring(2) : gv;
    final filtered = vs.where((v) => v.startsWith(prefix)).toList()
      ..sort((a, b) => b.compareTo(a));
    return filtered;
  }

  /// Download a file with progress callback.
  static Future<void> downloadFile(
      String url, String destPath, void Function(int, int) onProgress) async {
    final req = http.Request('GET', Uri.parse(url));
    req.headers['User-Agent'] = Net.ua;
    final resp = await http.Client().send(req);
    if (resp.statusCode != 200) throw HttpError(resp.statusCode, '');
    final total = resp.contentLength ?? 0;
    final sink = File(destPath).openWrite();
    var received = 0;
    try {
      await for (final chunk in resp.stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress(received, total);
      }
    } finally {
      await sink.close();
    }
  }
}
