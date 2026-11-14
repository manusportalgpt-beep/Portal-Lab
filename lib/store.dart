import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// File-system persistence for instances and accounts.
class Store {
  static late Directory root;
  static late SharedPreferences prefs;

  static Directory get instancesDir => Directory('${root.path}/instances');
  static Directory get exportsDir => Directory('${root.path}/exports');
  static File get accountsFile => File('${root.path}/accounts.json');

  static Future<void> init() async {
    root = await getApplicationDocumentsDirectory();
    prefs = await SharedPreferences.getInstance();
    await instancesDir.create(recursive: true);
    await exportsDir.create(recursive: true);
  }

  static String newId() =>
      DateTime.now().millisecondsSinceEpoch.toRadixString(36) +
      (DateTime.now().microsecond % 1000).toRadixString(36);

  // ---- Instances ----

  static Future<List<GameInstance>> loadInstances() async {
    final out = <GameInstance>[];
    if (!await instancesDir.exists()) return out;
    for (final ent in instancesDir.listSync()) {
      if (ent is! Directory) continue;
      final f = File('${ent.path}/instance.json');
      if (!await f.exists()) continue;
      try {
        final j =
            jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        out.add(GameInstance.fromJson(j));
      } catch (_) {
        // skip corrupted instance
      }
    }
    out.sort((a, b) => b.created.compareTo(a.created));
    return out;
  }

  static Future<void> saveInstance(GameInstance inst) async {
    final d = Directory('${instancesDir.path}/${inst.id}');
    await d.create(recursive: true);
    for (final sub in ['mods', 'resourcepacks', 'saves', 'config', 'shaderpacks']) {
      await Directory('${d.path}/$sub').create(recursive: true);
    }
    final f = File('${d.path}/instance.json');
    await f.writeAsString(const JsonEncoder.withIndent('  ').convert(inst.toJson()));
  }

  static Future<void> deleteInstance(String id) async {
    final d = Directory('${instancesDir.path}/$id');
    if (await d.exists()) await d.delete(recursive: true);
  }

  static Directory instanceDir(String id) =>
      Directory('${instancesDir.path}/$id');

  // ---- Accounts ----

  static Future<List<McAccount>> loadAccounts() async {
    if (!await accountsFile.exists()) return [];
    try {
      final j = jsonDecode(await accountsFile.readAsString()) as List;
      return j
          .map((e) => McAccount.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveAccounts(List<McAccount> accounts) async {
    await accountsFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(accounts.map((a) => a.toJson()).toList()));
  }
}
