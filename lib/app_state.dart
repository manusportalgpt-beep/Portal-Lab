import 'package:flutter/material.dart';

import 'i18n.dart';
import 'models.dart';
import 'store.dart';

/// Inherited access to [AppState] from anywhere in the widget tree.
class AppScope extends InheritedWidget {
  final AppState state;
  const AppScope({super.key, required this.state, required super.child});

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.state;

  @override
  bool updateShouldNotify(AppScope oldWidget) => oldWidget.state != state;
}

/// Global application state: settings, accounts, instances.
class AppState extends ChangeNotifier {
  // ---- settings ----
  String lang = 'ru'; // ru | en
  int themeMode = 0; // 0 system | 1 light | 2 dark | 3 black (amoled)
  String themeId = 'portal';
  int? accentColor; // nullable override

  // ---- data ----
  List<McAccount> accounts = [];
  String? activeAccountUuid;
  List<GameInstance> instances = [];

  AppState() {
    lang = Store.prefs.getString('lang') ?? 'ru';
    themeMode = Store.prefs.getInt('themeMode') ?? 0;
    themeId = Store.prefs.getString('themeId') ?? 'portal';
    accentColor = Store.prefs.getInt('accentColor');
    activeAccountUuid = Store.prefs.getString('activeAccount');
    _load();
  }

  Future<void> _load() async {
    accounts = await Store.loadAccounts();
    if (activeAccountUuid == null && accounts.isNotEmpty) {
      activeAccountUuid = accounts.first.uuid;
    }
    instances = await Store.loadInstances();
    notifyListeners();
  }

  S get s => lang == 'ru' ? S.ru : S.en;

  // ---- setters ----

  Future<void> setLang(String v) async {
    lang = v;
    await Store.prefs.setString('lang', v);
    notifyListeners();
  }

  Future<void> setThemeMode(int v) async {
    themeMode = v;
    await Store.prefs.setInt('themeMode', v);
    notifyListeners();
  }

  Future<void> setThemeId(String v) async {
    themeId = v;
    accentColor = null;
    await Store.prefs.setString('themeId', v);
    await Store.prefs.remove('accentColor');
    notifyListeners();
  }

  Future<void> setAccent(int? color) async {
    accentColor = color;
    if (color == null) {
      await Store.prefs.remove('accentColor');
    } else {
      await Store.prefs.setInt('accentColor', color);
    }
    notifyListeners();
  }

  // ---- accounts ----

  McAccount? get activeAccount {
    for (final a in accounts) {
      if (a.uuid == activeAccountUuid) return a;
    }
    return accounts.isEmpty ? null : accounts.first;
  }

  Future<void> addAccount(McAccount acc) async {
    accounts.removeWhere((a) => a.uuid == acc.uuid);
    accounts.add(acc);
    activeAccountUuid = acc.uuid;
    await Store.saveAccounts(accounts);
    await Store.prefs.setString('activeAccount', acc.uuid);
    notifyListeners();
  }

  Future<void> setActiveAccount(String uuid) async {
    activeAccountUuid = uuid;
    await Store.prefs.setString('activeAccount', uuid);
    notifyListeners();
  }

  Future<void> updateAccount(McAccount acc) async {
    final i = accounts.indexWhere((a) => a.uuid == acc.uuid);
    if (i >= 0) accounts[i] = acc;
    await Store.saveAccounts(accounts);
    notifyListeners();
  }

  Future<void> removeAccount(String uuid) async {
    accounts.removeWhere((a) => a.uuid == uuid);
    if (activeAccountUuid == uuid) {
      activeAccountUuid = accounts.isEmpty ? null : accounts.first.uuid;
      if (activeAccountUuid != null) {
        await Store.prefs.setString('activeAccount', activeAccountUuid!);
      } else {
        await Store.prefs.remove('activeAccount');
      }
    }
    await Store.saveAccounts(accounts);
    notifyListeners();
  }

  // ---- instances ----

  Future<void> reloadInstances() async {
    instances = await Store.loadInstances();
    notifyListeners();
  }

  Future<void> addInstance(GameInstance inst) async {
    await Store.saveInstance(inst);
    instances.removeWhere((i) => i.id == inst.id);
    instances.insert(0, inst);
    notifyListeners();
  }

  Future<void> saveInstance(GameInstance inst) async {
    await Store.saveInstance(inst);
    notifyListeners();
  }

  Future<void> deleteInstance(String id) async {
    await Store.deleteInstance(id);
    instances.removeWhere((i) => i.id == id);
    notifyListeners();
  }
}
