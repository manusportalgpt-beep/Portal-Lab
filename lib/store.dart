import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// File-system persistence for instances, accounts, favorites and AI data.
class Store {
  static late Directory root;
  static late SharedPreferences prefs;
  static Directory? _externalRoot;

  static Directory get instancesDir => Directory('${root.path}/instances');

  /// Exports live in a shared-friendly place: on Android the primary
  /// external app directory, so file managers and PojavLauncher can see them.
  static Directory get exportsDir {
    if (_externalRoot != null) {
      final d = Directory('${_externalRoot!.path}/PortalLab');
      if (!d.existsSync()) d.createSync(recursive: true);
      return d;
    }
    return Directory('${root.path}/exports');
  }

  /// Generated Portalus images.
  static Directory get imagesDir {
    final d = Directory('${root.path}/portalus_images');
    if (!d.existsSync()) d.createSync(recursive: true);
    return d;
  }

  static File get accountsFile => File('${root.path}/accounts.json');
  static File get favoritesFile => File('${root.path}/favorites.json');
  static File get chatFile => File('${root.path}/portalus_chat.json');
  static File get imagesFile => File('${root.path}/portalus_images.json');
  static File get controlsFile => File('${root.path}/controls.json');

  static Future<void> init() async {
    root = await getApplicationDocumentsDirectory();
    prefs = await SharedPreferences.getInstance();
    await instancesDir.create(recursive: true);
    try {
      // Try to use the shared external dir on Android.
      final ext = await getExternalStorageDirectories();
      if (ext != null && ext.isNotEmpty) {
        _externalRoot = ext.first;
        await exportsDir.create(recursive: true);
      }
    } catch (_) {
      // Not supported on this platform — keep the internal dir.
    }
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
    for (final sub in [
      'mods',
      'resourcepacks',
      'saves',
      'config',
      'shaderpacks',
      'datapacks',
    ]) {
      await Directory('${d.path}/$sub').create(recursive: true);
    }
    final f = File('${d.path}/instance.json');
    await f.writeAsString(
        const JsonEncoder.withIndent('  ').convert(inst.toJson()));
  }

  static Future<void> deleteInstance(String id) async {
    final d = Directory('${instancesDir.path}/$id');
    if (await d.exists()) await d.delete(recursive: true);
  }

  static Directory instanceDir(String id) =>
      Directory('${instancesDir.path}/$id');

  /// Total size of an instance folder in bytes.
  static int instanceSizeBytes(String id) {
    final d = instanceDir(id);
    if (!d.existsSync()) return 0;
    var total = 0;
    for (final ent in d.listSync(recursive: true, followLinks: false)) {
      if (ent is File) {
        try {
          total += ent.lengthSync();
        } catch (_) {}
      }
    }
    return total;
  }

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
    await accountsFile.writeAsString(const JsonEncoder.withIndent('  ')
        .convert(accounts.map((a) => a.toJson()).toList()));
  }

  // ---- Favorites ----

  static Future<List<FavoriteProject>> loadFavorites() async {
    if (!await favoritesFile.exists()) return [];
    try {
      final j = jsonDecode(await favoritesFile.readAsString()) as List;
      return j
          .map((e) => FavoriteProject.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveFavorites(List<FavoriteProject> list) async {
    await favoritesFile.writeAsString(const JsonEncoder.withIndent('  ')
        .convert(list.map((e) => e.toJson()).toList()));
  }

  // ---- Portalus chat ----

  static Future<List<ChatMessage>> loadChat() async {
    if (!await chatFile.exists()) return [];
    try {
      final j = jsonDecode(await chatFile.readAsString()) as List;
      return j
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveChat(List<ChatMessage> msgs) async {
    // Keep the history bounded to stay fast and small.
    final trimmed = msgs.length > 60 ? msgs.sublist(msgs.length - 60) : msgs;
    await chatFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(trimmed.map((m) => m.toJson()).toList()));
  }

  // ---- Portalus images ----

  static Future<List<AiImageItem>> loadImages() async {
    if (!await imagesFile.exists()) return [];
    try {
      final j = jsonDecode(await imagesFile.readAsString()) as List;
      return j
          .map((e) => AiImageItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveImages(List<AiImageItem> list) async {
    final trimmed = list.length > 40 ? list.sublist(0, 40) : list;
    await imagesFile.writeAsString(const JsonEncoder.withIndent('  ')
        .convert(trimmed.map((e) => e.toJson()).toList()));
  }

  // ---- Controls profile ----

  static (ControlsProfile, List<ControlButton>) loadControls() {
    try {
      if (controlsFile.existsSync()) {
        final j = jsonDecode(controlsFile.readAsStringSync())
            as Map<String, dynamic>;
        final profile = ControlsProfile.fromJson(
            (j['profile'] as Map).cast<String, dynamic>());
        final buttons = ((j['buttons'] as List?) ?? [])
            .map((e) => ControlButton.fromJson((e as Map).cast<String, dynamic>()))
            .toList();
        if (buttons.isNotEmpty) return (profile, buttons);
      }
    } catch (_) {}
    return (ControlsProfile(), defaultControls());
  }

  static Future<void> saveControls(
      ControlsProfile profile, List<ControlButton> buttons) async {
    final j = {
      'profile': profile.toJson(),
      'buttons': buttons.map((b) => b.toJson()).toList(),
    };
    await controlsFile
        .writeAsString(const JsonEncoder.withIndent('  ').convert(j));
  }

  /// The factory-default control layout.
  static List<ControlButton> defaultControls() {
    return const [
      _PresetButton('Sprint', 341, 78, 68, 60, true),
      _PresetButton('Inv', 69, 78, 52, 60, false),
      _PresetButton('Chat', 84, 90, 36, 54, false),
      _PresetButton('Sneak', 340, 64, 84, 60, true),
      _PresetButton('ESC', 256, 50, 8, 50, false),
      _PresetButton('Cursor', -2, 6, 8, 54, true),
      _PresetButton('Jump', 32, 92, 84, 64, false),
      _PresetButton('Drop', 81, 50, 84, 50, false),
    ].map((b) => b.toControlButton()).toList();
  }
}

class _PresetButton {
  final String name;
  final int keycode;
  final double x;
  final double y;
  final double size;
  final bool isToggle;
  const _PresetButton(this.name, this.keycode, this.x, this.y, this.size,
      this.isToggle);
  ControlButton toControlButton() => ControlButton(
      name: name,
      keycode: keycode,
      x: x,
      y: y,
      size: size,
      isToggle: isToggle);
}

@visibleForTesting
void debugPrintStoreRoot() {
  debugPrint('Store root: ${Store.root.path}');
}
