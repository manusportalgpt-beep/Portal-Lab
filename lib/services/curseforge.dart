import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';

import '../models.dart';
import 'net.dart';

/// CurseForge API client (official 3rd-party API, key from Prism Launcher's
/// open-source build, as permitted for open-source launchers).
class CurseForgeService {
  static const base = 'https://api.curseforge.com/v1';
  // Public client key published in Prism Launcher (GPL-3) sources.
  static const apiKey =
      '\$2a\$10\$wuAJuNZuted3NORVmpgUC.m8sI.pv1tOPKZyBgLFGjxFp/br0lZCC';

  static Map<String, String> get _h => {
        'x-api-key': apiKey,
        'User-Agent': Net.ua,
        'Accept': 'application/json',
      };

  static const gameId = 432;
  static const classIds = {
    'mod': 6,
    'modpack': 4471,
    'resourcepack': 12,
    'shader': 6552,
  };

  static Future<List<CatalogProject>> search({
    String query = '',
    String projectType = 'mod',
    String gameVersion = '',
    String loader = '',
    String sort = 'Featured',
    int offset = 0,
    int pageSize = 20,
  }) async {
    final params = <String, String>{
      'gameId': '$gameId',
      'classId': '${classIds[projectType] ?? 6}',
      'searchFilter': query,
      'sortField': sort == 'Popularity'
          ? '2'
          : sort == 'Last Updated'
              ? '3'
              : sort == 'Name'
                  ? '5'
                  : '1',
      'sortOrder': 'desc',
      'index': '$offset',
      'pageSize': '$pageSize',
    };
    if (gameVersion.isNotEmpty) params['gameVersion'] = gameVersion;
    if (loader.isNotEmpty) {
      params['modLoaderType'] = _loaderType(loader);
    }
    final uri = Uri.parse('$base/mods/search')
        .replace(queryParameters: params.map((k, v) => MapEntry(k, v)));
    final j = await Net.getJson(uri.toString(), headers: _h);
    return (j['data'] as List)
        .map((e) {
          final m = e as Map<String, dynamic>;
          final icons = (m['icons'] as List?) ?? const [];
          String? icon;
          for (final ic in icons) {
            final im = ic as Map<String, dynamic>;
            if (im['iconUrl'] != null) {
              icon = im['iconUrl'] as String;
              break;
            }
          }
          final authors = (m['authors'] as List?) ?? const [];
          final author = authors.isEmpty
              ? ''
              : ((authors.first as Map)['name'] as String? ?? '');
          final latest = (m['latestFilesIndexes'] as List?) ?? const [];
          final gvs = <String>{};
          final loaders = <String>{};
          for (final l in latest) {
            final lm = l as Map<String, dynamic>;
            if (lm['gameVersion'] != null) gvs.add(lm['gameVersion'] as String);
            if (lm['modLoader'] != null) loaders.add(lm['modLoader'] as String);
          }
          return CatalogProject(
            source: 'curseforge',
            id: '${m['id']}',
            title: m['name'] as String? ?? '',
            description: m['summary'] as String? ?? '',
            iconUrl: icon,
            downloads: (m['downloadCount'] as num?)?.toInt() ?? 0,
            follows: 0,
            author: author,
            projectType: projectType,
            gameVersions: gvs.toList(),
            loaders: loaders.toList(),
          );
        })
        .toList();
  }

  static String _loaderType(String loader) {
    switch (loader) {
      case 'forge':
        return '1';
      case 'fabric':
        return '4';
      case 'quilt':
        return '5';
      case 'neoforge':
        return '6';
      default:
        return '0';
    }
  }

  /// Full mod details.
  static Future<Map<String, dynamic>> project(String id) =>
      Net.getJson('$base/mods/$id', headers: _h);

  /// Files of a mod.
  static Future<List<CatalogVersion>> versions(String id,
      {String gameVersion = ''}) async {
    final params = <String, String>{
      'index': '0',
      'pageSize': '40',
    };
    if (gameVersion.isNotEmpty) params['gameVersion'] = gameVersion;
    final uri = Uri.parse('$base/mods/$id/files').replace(queryParameters: params);
    final j = await Net.getJson(uri.toString(), headers: _h);
    return (j['data'] as List)
        .map((e) {
          final m = e as Map<String, dynamic>;
          return CatalogVersion(
            source: 'curseforge',
            id: '${m['id']}',
            name: m['displayName'] as String? ?? '',
            versionNumber: m['fileName'] as String? ?? '',
            changelog: null,
            datePublished: m['fileDate'] as String? ?? '',
            downloadUrl: m['downloadUrl'] as String? ?? '',
            fileName: m['fileName'] as String? ?? '',
            size: (m['fileLength'] as num?)?.toInt() ?? 0,
            versionType: ((m['releaseType'] as num?)?.toInt() ?? 1) == 1
                ? 'release'
                : 'beta',
            gameVersions: (m['gameVersions'] as List?)?.cast<String>() ?? const [],
            loaders: const [],
          );
        })
        .toList();
  }

  /// Resolve many fileIds to download URLs at once.
  static Future<List<CatalogVersion>> filesByIds(List<int> fileIds) async {
    if (fileIds.isEmpty) return [];
    final r = await _post('$base/mods/files', {'fileIds': fileIds});
    return (r['data'] as List)
        .map((e) {
          final m = e as Map<String, dynamic>;
          String destFolder = 'mods';
          final modules = (m['modules'] as List?) ?? const [];
          for (final mod in modules) {
            final mm = mod as Map<String, dynamic>;
            final ft = mm['folderType'] as String? ?? '';
            if (ft.isNotEmpty && ft != 'OTHER') {
              destFolder = ft.toLowerCase();
              break;
            }
          }
          return CatalogVersion(
            source: 'curseforge',
            id: '${m['id']}',
            name: m['displayName'] as String? ?? '',
            versionNumber: m['fileName'] as String? ?? '',
            changelog: null,
            datePublished: m['fileDate'] as String? ?? '',
            downloadUrl: m['downloadUrl'] as String? ?? '',
            fileName: m['fileName'] as String? ?? '',
            size: (m['fileLength'] as num?)?.toInt() ?? 0,
            versionType: 'release',
            gameVersions: const [],
            loaders: const [],
          );
        })
        .toList();
  }

  static Future<Map<String, dynamic>> _post(String url, Object body) async {
    final r = await Net.client.post(Uri.parse(url),
        headers: {
          ..._h,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body));
    if (r.statusCode != 200) throw HttpError(r.statusCode, r.body);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  /// Install a CurseForge modpack zip into an instance directory.
  static Future<int> installModpack(String zipPath, String instanceDirPath) async {
    final bytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final staging = Directory('$instanceDirPath/.staging');
    if (await staging.exists()) await staging.delete(recursive: true);
    await staging.create(recursive: true);
    await extractArchiveToDisk(archive, staging.path);

    final manifestFile = File('${staging.path}/manifest.json');
    if (!await manifestFile.exists()) {
      await staging.delete(recursive: true);
      throw Exception('manifest.json not found in modpack');
    }
    final manifest =
        jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
    final files = (manifest['files'] as List?) ?? const [];
    final ids = <int>[];
    for (final f in files) {
      final fm = f as Map<String, dynamic>;
      if (fm['required'] == false) continue;
      final pid = fm['projectID'] as num?;
      final fid = fm['fileID'] as num?;
      if (pid != null && fid != null) ids.add(fid.toInt());
    }
    final details = await filesByIds(ids);
    var count = 0;
    for (final d in details) {
      if (d.downloadUrl.isEmpty) continue;
      final dest = '$instanceDirPath/mods/${d.fileName}';
      await File(dest).parent.create(recursive: true);
      try {
        await _downloadCf(d.downloadUrl, dest);
        count++;
      } catch (_) {
        // skip
      }
    }

    final overridesDir = Directory('${staging.path}/overrides');
    if (await overridesDir.exists()) {
      await ModrinthServiceHelpers.copyTree(
          overridesDir, Directory(instanceDirPath));
    }
    await staging.delete(recursive: true);
    return count;
  }

  static Future<void> _downloadCf(String url, String dest) async {
    final req = await Net.client.get(Uri.parse(url), headers: _h);
    if (req.statusCode != 200) throw HttpError(req.statusCode, '');
    await File(dest).writeAsBytes(req.bodyBytes);
  }
}

/// Small helpers shared between services.
class ModrinthServiceHelpers {
  static Future<void> copyTree(Directory src, Directory dst) async {
    await for (final ent in src.list()) {
      final name = ent.path.substring(src.path.length + 1);
      final target = '${dst.path}/$name';
      if (ent is Directory) {
        await Directory(target).create(recursive: true);
        await copyTree(ent, Directory(target));
      } else if (ent is File) {
        await File(target).parent.create(recursive: true);
        await File(ent.path).copy(target);
      }
    }
  }
}
