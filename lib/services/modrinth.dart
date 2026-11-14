import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';

import '../models.dart';
import 'net.dart';

/// Modrinth API v2 client.
class ModrinthService {
  static const base = 'https://api.modrinth.com/v2';

  static Future<List<CatalogProject>> search({
    String query = '',
    String projectType = 'mod',
    List<String> categories = const [],
    List<String> loaders = const [],
    List<String> gameVersions = const [],
    String sort = 'relevance',
    int offset = 0,
    int limit = 20,
  }) async {
    final facets = <List<String>>[
      ['project_type:$projectType'],
      for (final c in categories) ['categories:$c'],
      for (final l in loaders) ['categories:$l'],
      for (final v in gameVersions) ['versions:$v'],
    ];
    final uri = Uri.parse('$base/search').replace(queryParameters: {
      'query': query,
      'index': sort,
      'offset': '$offset',
      'limit': '$limit',
      'facets': jsonFacets(facets),
    });
    final j = await Net.getJson(uri.toString());
    return (j['hits'] as List)
        .map((e) {
          final m = e as Map<String, dynamic>;
          return CatalogProject(
            source: 'modrinth',
            id: (m['slug'] ?? m['id']) as String,
            title: m['title'] as String? ?? '',
            description: m['description'] as String? ?? '',
            iconUrl: m['icon_url'] as String?,
            downloads: (m['downloads'] as num?)?.toInt() ?? 0,
            follows: (m['follows'] as num?)?.toInt() ?? 0,
            author: m['author'] as String? ?? '',
            projectType: projectType,
            gameVersions: (m['versions'] as List?)?.cast<String>() ?? const [],
            loaders: (m['display_categories'] as List?)?.cast<String>() ??
                const [],
          );
        })
        .toList();
  }

  static String jsonFacets(List<List<String>> facets) {
    final parts = facets.map((f) => '[${f.map((e) => '"$e"').join(',')}]');
    return '[${parts.join(',')}]';
  }

  /// Full project details.
  static Future<Map<String, dynamic>> project(String idOrSlug) =>
      Net.getJson('$base/project/$idOrSlug');

  /// Versions of a project (newest first).
  static Future<List<CatalogVersion>> versions(String idOrSlug) async {
    final j = await Net.getJsonList('$base/project/$idOrSlug/version');
    return j.map((e) {
      final m = e as Map<String, dynamic>;
      String url = '';
      String fileName = '';
      int size = 0;
      final files = (m['files'] as List?) ?? const [];
      for (final f in files) {
        final fm = f as Map<String, dynamic>;
        if (fm['primary'] == true || url.isEmpty) {
          url = fm['url'] as String? ?? '';
          fileName = fm['filename'] as String? ?? '';
          size = (fm['size'] as num?)?.toInt() ?? 0;
        }
        if (fm['primary'] == true) break;
      }
      return CatalogVersion(
        source: 'modrinth',
        id: m['id'] as String? ?? '',
        name: m['name'] as String? ?? '',
        versionNumber: m['version_number'] as String? ?? '',
        changelog: m['changelog'] as String?,
        datePublished: m['date_published'] as String? ?? '',
        downloadUrl: url,
        fileName: fileName,
        size: size,
        versionType: m['version_type'] as String? ?? 'release',
        gameVersions: (m['game_versions'] as List?)?.cast<String>() ?? const [],
        loaders: (m['loaders'] as List?)?.cast<String>() ?? const [],
      );
    }).toList();
  }

  /// Install a Modrinth modpack (.mrpack) into an instance directory.
  /// Returns the number of files downloaded.
  static Future<int> installModpack(String mrpackPath, String instanceDirPath) async {
    final bytes = await File(mrpackPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    // Extract everything into a temp staging dir.
    final staging = Directory('$instanceDirPath/.staging');
    if (await staging.exists()) await staging.delete(recursive: true);
    await staging.create(recursive: true);
    await extractArchiveToDisk(archive, staging.path);

    final indexFile = File('${staging.path}/modrinth.index.json');
    if (!await indexFile.exists()) {
      await staging.delete(recursive: true);
      throw Exception('modrinth.index.json not found in modpack');
    }
    final index =
        jsonDecode(await indexFile.readAsString()) as Map<String, dynamic>;
    final files = (index['files'] as List?) ?? const [];
    var count = 0;
    for (final f in files) {
      final fm = f as Map<String, dynamic>;
      final path = fm['path'] as String? ?? '';
      final downloads = (fm['downloads'] as List?)?.cast<String>() ?? const [];
      if (downloads.isEmpty || path.isEmpty) continue;
      final dest = _safeJoin(instanceDirPath, path);
      if (dest == null) continue;
      await File(dest).parent.create(recursive: true);
      try {
        await MojangService.downloadFile(downloads.first, dest, (_, __) {});
        count++;
      } catch (_) {
        // skip failed file, continue installing the rest
      }
    }

    // overrides/
    final overridesDir = Directory('${staging.path}/overrides');
    if (await overridesDir.exists()) {
      await _copyTree(overridesDir, Directory(instanceDirPath));
    }
    await staging.delete(recursive: true);
    return count;
  }

  /// Guard against path traversal in archives.
  static String? _safeJoin(String base, String rel) {
    final normalized = rel.replaceAll('\\', '/');
    if (normalized.startsWith('/') || normalized.contains('..')) return null;
    return base.endsWith('/') ? '$base$normalized' : '$base/$normalized';
  }

  static Future<void> _copyTree(Directory src, Directory dst) async {
    await for (final ent in src.list()) {
      final name = ent.path.substring(src.path.length + 1);
      final target = '${dst.path}/$name';
      if (ent is Directory) {
        await Directory(target).create(recursive: true);
        await _copyTree(ent, Directory(target));
      } else if (ent is File) {
        await File(target).parent.create(recursive: true);
        await File(ent.path).copy(target);
      }
    }
  }
}
