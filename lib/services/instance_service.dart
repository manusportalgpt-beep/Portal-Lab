import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';

import '../models.dart';
import '../store.dart';
import 'curseforge.dart';
import 'download_manager.dart';
import 'modrinth.dart';
import 'mojang.dart';

/// A pending mod update.
class ModUpdate {
  final ModEntry mod;
  final CatalogVersion version;
  const ModUpdate(this.mod, this.version);
}

/// High-level instance operations.
class InstanceService {
  static final dm = DownloadManager.instance;

  /// Target folder inside the instance for a project type.
  static String folderForType(String projectType) => switch (projectType) {
        'resourcepack' => 'resourcepacks',
        'shader' => 'shaderpacks',
        'datapack' => 'datapacks',
        _ => 'mods',
      };

  static Future<GameInstance> create({
    required String name,
    required String gameVersion,
    required String loader,
    required String loaderVersion,
    String icon = 'grass',
    int memoryMb = 0,
    String javaArgs = '',
  }) async {
    final inst = GameInstance(
      id: Store.newId(),
      name: name,
      gameVersion: gameVersion,
      loader: loader,
      loaderVersion: loaderVersion,
      created: DateTime.now().toIso8601String(),
      icon: icon,
      memoryMb: memoryMb,
      javaArgs: javaArgs,
    );
    await Store.saveInstance(inst);
    return inst;
  }

  /// Queue a download of [v] into the instance [folder].
  /// When [replace] is set, the old file is removed once the download ends.
  static void installMod(
    GameInstance inst,
    CatalogVersion v, {
    String? title,
    String? iconUrl,
    String? author,
    String? versionNumber,
    String? description,
    String? downloadUrl,
    String folder = 'mods',
    ModEntry? replace,
    void Function()? onDone,
  }) {
    final url = downloadUrl ?? v.downloadUrl;
    dm.add(
      title: title ?? '${v.name} → ${inst.name}',
      url: url,
      destPath: '${Store.instanceDir(inst.id).path}/$folder/${v.fileName}',
      tag: inst.id,
      iconUrl: iconUrl,
      onDone: () async {
        if (replace != null && replace.fileName != v.fileName) {
          await removeModFile(inst, replace.fileName,
              folder: replace.folder);
        }
        onDone?.call();
      },
    );
  }

  /// List the files of a folder with their enabled state.
  static Future<List<ModEntry>> scanFolder(
      GameInstance inst, String folder) async {
    final d = Directory('${Store.instanceDir(inst.id).path}/$folder');
    if (!await d.exists()) return const [];
    final known = {
      for (final m in inst.mods.where((m) => m.folder == folder))
        m.fileName: m
    };
    final out = <ModEntry>[];
    final names = d
        .listSync()
        .whereType<File>()
        .map((f) => f.path.split('/').last)
        .toList()
      ..sort();
    for (final n in names) {
      if (n.startsWith('.')) continue;
      final knownEntry = known[n];
      if (knownEntry != null) {
        out.add(knownEntry);
        continue;
      }
      out.add(ModEntry(
        source: 'local',
        projectId: '',
        versionId: '',
        name: n.replaceAll('.disabled', ''),
        fileName: n,
        folder: folder,
        enabled: !n.endsWith('.disabled'),
      ));
    }
    return out;
  }

  /// Legacy helper: just mod file names.
  static Future<List<String>> modFiles(GameInstance inst) async {
    final entries = await scanFolder(inst, 'mods');
    return entries.map((e) => e.fileName).toList();
  }

  /// Enable or disable a mod by renaming the file.
  static Future<void> setModEnabled(
      GameInstance inst, ModEntry m, bool enabled) async {
    final base = Store.instanceDir(inst.id).path;
    final target = enabled ? m.activeFileName : '${m.activeFileName}.disabled';
    if (target != m.fileName) {
      final f = File('$base/${m.folder}/${m.fileName}');
      if (await f.exists()) {
        await f.rename('$base/${m.folder}/$target');
      }
    }
    m.fileName = target;
    m.enabled = enabled;
    final stored = inst.mods
        .where((x) => x.folder == m.folder && x.activeFileName == m.activeFileName)
        .toList();
    if (stored.isEmpty) {
      inst.mods.add(m);
    } else {
      for (final s in stored) {
        s.fileName = target;
        s.enabled = enabled;
      }
    }
    await Store.saveInstance(inst);
  }

  static Future<void> removeModFile(GameInstance inst, String fileName,
      {String folder = 'mods'}) async {
    final f =
        File('${Store.instanceDir(inst.id).path}/$folder/$fileName');
    if (await f.exists()) await f.delete();
    inst.mods.removeWhere(
        (m) => m.fileName == fileName && m.folder == folder);
    await Store.saveInstance(inst);
  }

  /// Duplicate an instance with its whole folder.
  static Future<GameInstance> duplicate(GameInstance inst) async {
    final copy = GameInstance(
      id: Store.newId(),
      name: '${inst.name} 2',
      gameVersion: inst.gameVersion,
      loader: inst.loader,
      loaderVersion: inst.loaderVersion,
      created: DateTime.now().toIso8601String(),
      lastPlayed: '',
      icon: inst.icon,
      notes: inst.notes,
      memoryMb: inst.memoryMb,
      javaArgs: inst.javaArgs,
      mods: inst.mods
          .map((m) => ModEntry.fromJson(
              jsonDecode(jsonEncode(m.toJson())) as Map<String, dynamic>))
          .toList(),
    );
    final src = Store.instanceDir(inst.id);
    final dst = Store.instanceDir(copy.id);
    await dst.create(recursive: true);
    if (await src.exists()) {
      await _copyTree(src, dst, skip: {'instance.json'});
    }
    await Store.saveInstance(copy);
    return copy;
  }

  /// Change the game version / loader of an instance.
  static Future<void> changeVersion(GameInstance inst,
      {required String gameVersion,
      required String loader,
      required String loaderVersion}) async {
    inst.gameVersion = gameVersion;
    inst.loader = loader;
    inst.loaderVersion = loaderVersion;
    await Store.saveInstance(inst);
  }

  static Future<void> markPlayed(GameInstance inst) async {
    inst.lastPlayed = DateTime.now().toIso8601String();
    await Store.saveInstance(inst);
  }

  /// Check mod updates against the catalogs.
  static Future<List<ModUpdate>> checkUpdates(GameInstance inst) async {
    final out = <ModUpdate>[];
    for (final m in inst.mods) {
      if (m.source == 'local' || m.projectId.isEmpty) continue;
      try {
        List<CatalogVersion> versions;
        if (m.source == 'modrinth') {
          versions = await ModrinthService.versions(m.projectId);
        } else {
          versions = await CurseForgeService.versions(m.projectId);
        }
        CatalogVersion? best;
        for (final v in versions) {
          final gvOk =
              v.gameVersions.isEmpty || v.gameVersions.contains(inst.gameVersion);
          final loaderOk = v.loaders.isEmpty ||
              inst.loader == 'vanilla' ||
              v.loaders.contains(inst.loader);
          if (gvOk && loaderOk) {
            best = v;
            break;
          }
        }
        if (best != null &&
            best.id != m.versionId &&
            best.fileName != m.activeFileName) {
          out.add(ModUpdate(m, best));
        }
      } catch (_) {
        // network hiccup for one mod should not stop the rest
      }
    }
    return out;
  }

  /// Apply a single update.
  static void applyUpdate(GameInstance inst, ModUpdate u) {
    installMod(
      inst,
      u.version,
      title: '${u.mod.name} → ${u.version.versionNumber}',
      iconUrl: u.mod.iconUrl,
      author: u.mod.author,
      versionNumber: u.version.versionNumber,
      description: u.mod.description,
      folder: u.mod.folder,
      replace: u.mod,
      onDone: () {},
    );
    u.mod.versionId = u.version.id;
    u.mod.fileName = u.version.fileName;
    u.mod.versionNumber = u.version.versionNumber;
    u.mod.gameVersions = u.version.gameVersions;
    u.mod.loaders = u.version.loaders;
    u.mod.downloadUrl = u.version.downloadUrl;
    u.mod.fileSize = u.version.size;
    u.mod.enabled = true;
  }

  /// Download a Modrinth modpack and install it as a new instance.
  static Future<GameInstance> installModrinthModpack(
      String name, String mrpackUrl) async {
    final tmp = Directory.systemTemp.createTempSync('portal_lab');
    final zipPath = '${tmp.path}/pack.mrpack';
    await MojangService.downloadFile(mrpackUrl, zipPath, (_, __) {});
    final indexJson = await _peekZipJson(zipPath, 'modrinth.index.json');
    final gv = (indexJson['dependencies'] as Map?)?['minecraft'] as String? ??
        '1.20.1';
    var loader = 'vanilla';
    var loaderVersion = '';
    final deps = indexJson['dependencies'] as Map? ?? const {};
    if (deps['fabric-loader'] != null) {
      loader = 'fabric';
      loaderVersion = deps['fabric-loader'] as String;
    } else if (deps['quilt-loader'] != null) {
      loader = 'quilt';
      loaderVersion = deps['quilt-loader'] as String;
    } else if (deps['neoforge'] != null) {
      loader = 'neoforge';
      loaderVersion = deps['neoforge'] as String;
    } else if (deps['forge'] != null) {
      loader = 'forge';
      loaderVersion = deps['forge'] as String;
    }
    final inst = await create(
        name: name,
        gameVersion: gv,
        loader: loader,
        loaderVersion: loaderVersion);
    await ModrinthService.installModpack(
        zipPath, Store.instanceDir(inst.id).path);
    await tmp.delete(recursive: true);
    return inst;
  }

  /// Download a CurseForge modpack and install it as a new instance.
  static Future<GameInstance> installCurseForgeModpack(
      String name, String zipUrl) async {
    final tmp = Directory.systemTemp.createTempSync('portal_lab');
    final zipPath = '${tmp.path}/pack.zip';
    await MojangService.downloadFile(zipUrl, zipPath, (_, __) {});
    final manifest = await _peekZipJson(zipPath, 'manifest.json');
    final mc = manifest['minecraft'] as Map? ?? const {};
    final gv = mc['version'] as String? ?? '1.20.1';
    var loader = 'vanilla';
    var loaderVersion = '';
    final modLoaders = (mc['modLoaders'] as List?) ?? const [];
    for (final ml in modLoaders) {
      final id = ((ml as Map)['id'] as String?) ?? '';
      if (id.startsWith('forge-')) {
        loader = 'forge';
        loaderVersion = id.substring(6);
        break;
      } else if (id.startsWith('neoforge-')) {
        loader = 'neoforge';
        loaderVersion = id.substring(9);
        break;
      } else if (id.startsWith('fabric-')) {
        loader = 'fabric';
        loaderVersion = id.substring(7);
        break;
      } else if (id.startsWith('quilt-')) {
        loader = 'quilt';
        loaderVersion = id.substring(6);
        break;
      }
    }
    final inst = await create(
        name: name,
        gameVersion: gv,
        loader: loader,
        loaderVersion: loaderVersion);
    await CurseForgeService.installModpack(
        zipPath, Store.instanceDir(inst.id).path);
    await tmp.delete(recursive: true);
    return inst;
  }

  static Future<Map<String, dynamic>> _peekZipJson(
      String zipPath, String entryName) async {
    final bytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    for (final f in archive) {
      if (f.name == entryName) {
        return jsonDecode(utf8.decode(f.content as List<int>))
            as Map<String, dynamic>;
      }
    }
    throw Exception('$entryName not found');
  }

  /// Export an instance as a raw zip into the exports folder.
  static Future<String> exportZip(GameInstance inst) async {
    final dir = Store.instanceDir(inst.id);
    final encoder = ZipFileEncoder();
    final out = '${Store.exportsDir.path}/${_sanitize(inst.name)}.zip';
    if (await File(out).exists()) await File(out).delete();
    encoder.create(out);
    await _addDirToZip(encoder, dir);
    encoder.closeSync();
    return out;
  }

  /// Export an instance as a Modrinth .mrpack modpack (importable by
  /// PojavLauncher and other launchers). Files with a known download URL
  /// are referenced; everything else is packed into overrides/.
  static Future<String> exportMrpack(GameInstance inst) async {
    final dir = Store.instanceDir(inst.id);
    final archive = Archive();

    final files = <Map<String, dynamic>>[];
    final trackedLocalPaths = <String>{};
    for (final m in inst.mods) {
      if (m.downloadUrl == null || m.downloadUrl!.isEmpty) continue;
      final local =
          File('${dir.path}/${m.folder}/${m.activeFileName}');
      String? hash;
      int? size;
      if (await local.exists()) {
        try {
          final bytes = await local.readAsBytes();
          hash = sha1.convert(bytes).toString();
          size = bytes.length;
        } catch (_) {}
      }
      size ??= m.fileSize ?? 0;
      trackedLocalPaths.add('${m.folder}/${m.activeFileName}');
      files.add({
        'path': '${m.folder}/${m.activeFileName}',
        'hashes': {'sha1': hash ?? ''},
        'env': {'client': 'required', 'server': 'unsupported'},
        'downloads': [m.downloadUrl!],
        'fileSize': size,
      });
    }

    final index = {
      'formatVersion': 1,
      'game': 'minecraft',
      'versionId': _sanitize(inst.name),
      'name': inst.name,
      'summary': inst.notes,
      'files': files,
      'dependencies': {
        'minecraft': inst.gameVersion,
        if (inst.loader == 'fabric') 'fabric-loader': inst.loaderVersion,
        if (inst.loader == 'quilt') 'quilt-loader': inst.loaderVersion,
        if (inst.loader == 'forge') 'forge': inst.loaderVersion,
        if (inst.loader == 'neoforge') 'neoforge': inst.loaderVersion,
      },
    };
    archive.addFile(ArchiveFile.string('modrinth.index.json',
        const JsonEncoder.withIndent('  ').convert(index)));

    // Everything not tracked by URL goes into overrides/.
    final prefix = dir.path;
    final overridesRoot = Directory.systemTemp.createTempSync('pl_ovr');
    var overrideCount = 0;
    await for (final ent in dir.list(recursive: true, followLinks: false)) {
      if (ent is! File) continue;
      final rel = ent.path.substring(prefix.length + 1);
      if (rel == 'instance.json' || rel.startsWith('.staging')) continue;
      if (trackedLocalPaths.contains(rel)) continue;
      final target = File('${overridesRoot.path}/$rel');
      await target.parent.create(recursive: true);
      await File(ent.path).copy(target.path);
      overrideCount++;
    }
    if (overrideCount > 0) {
      final ovArchive = _dirToArchive(overridesRoot, base: overridesRoot.path);
      for (final f in ovArchive) {
        archive.addFile(ArchiveFile('overrides/${f.name}', f.size, f.content));
      }
    }
    await overridesRoot.delete(recursive: true);

    final out = '${Store.exportsDir.path}/${_sanitize(inst.name)}.mrpack';
    final bytes = ZipEncoder().encode(archive) ?? <int>[];
    await File(out).writeAsBytes(bytes);
    return out;
  }

  static Archive _dirToArchive(Directory dir, {required String base}) {
    final archive = Archive();
    for (final ent in dir.listSync(recursive: true, followLinks: false)) {
      if (ent is! File) continue;
      final rel = ent.path.substring(base.length + 1);
      final bytes = File(ent.path).readAsBytesSync();
      archive.addFile(ArchiveFile(rel, bytes.length, bytes));
    }
    return archive;
  }

  static Future<void> _addDirToZip(ZipFileEncoder encoder, Directory dir) async {
    await for (final ent in dir.list()) {
      if (ent is File) {
        if (ent.path.endsWith('instance.json')) continue;
        encoder.addFile(ent);
      } else if (ent is Directory) {
        await _addDirToZip(encoder, ent);
      }
    }
  }

  static Future<void> _copyTree(Directory src, Directory dst,
      {Set<String>? skip}) async {
    await for (final ent in src.list()) {
      final name = ent.path.substring(src.path.length + 1);
      if (skip != null && skip.contains(name)) continue;
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

  static String _sanitize(String s) =>
      s.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
}
