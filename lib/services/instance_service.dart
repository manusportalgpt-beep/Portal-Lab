import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';

import '../models.dart';
import '../store.dart';
import 'curseforge.dart';
import 'download_manager.dart';
import 'modrinth.dart';
import 'mojang.dart';

/// High-level instance operations.
class InstanceService {
  static final dm = DownloadManager.instance;

  static Future<GameInstance> create({
    required String name,
    required String gameVersion,
    required String loader,
    required String loaderVersion,
  }) async {
    final inst = GameInstance(
      id: Store.newId(),
      name: name,
      gameVersion: gameVersion,
      loader: loader,
      loaderVersion: loaderVersion,
      created: DateTime.now().toIso8601String(),
    );
    await Store.saveInstance(inst);
    return inst;
  }

  static Future<void> installMod(GameInstance inst, CatalogVersion v,
      {String? title}) async {
    dm.add(
      title: title ?? '${v.name} → ${inst.name}',
      url: v.downloadUrl,
      destPath: '${Store.instanceDir(inst.id).path}/mods/${v.fileName}',
      tag: inst.id,
    );
  }

  static Future<List<String>> modFiles(GameInstance inst) async {
    final d = Directory('${Store.instanceDir(inst.id).path}/mods');
    if (!await d.exists()) return [];
    return d
        .listSync()
        .whereType<File>()
        .map((f) => f.path.split('/').last)
        .toList()
      ..sort();
  }

  static Future<void> removeModFile(GameInstance inst, String fileName) async {
    final f = File('${Store.instanceDir(inst.id).path}/mods/$fileName');
    if (await f.exists()) await f.delete();
    inst.mods.removeWhere((m) => m.fileName == fileName);
    await Store.saveInstance(inst);
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

  /// Export an instance as a zip into the exports folder.
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

  static String _sanitize(String s) =>
      s.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
}
