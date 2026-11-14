import 'package:flutter/material.dart';

import 'app_state.dart';
import 'store.dart';
import 'theme.dart';
import 'ui/accounts_page.dart';
import 'ui/browse_page.dart';
import 'ui/downloads_page.dart';
import 'ui/home_page.dart';
import 'ui/instances_page.dart';
import 'ui/settings_page.dart';

/// Inherited access to [AppState].
class AppScope extends InheritedWidget {
  final AppState state;
  const AppScope({super.key, required this.state, required super.child});

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.state;

  @override
  bool updateShouldNotify(AppScope old) => old.state != state;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Store.init();
  final state = AppState();
  runApp(PortalLabApp(state: state));
}

class PortalLabApp extends StatelessWidget {
  final AppState state;
  const PortalLabApp({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final brightness = switch (state.themeMode) {
          1 => Brightness.light,
          _ => Brightness.dark,
        };
        final preset = PortalThemes.byId(state.themeId);
        final accent =
            state.accentColor == null ? null : Color(state.accentColor!);
        final pureBlack = state.themeMode == 3;
        return MaterialApp(
          title: 'Portal Lab',
          debugShowCheckedModeBanner: false,
          theme: PortalThemes.build(
              preset: preset,
              accentOverride: accent,
              brightness: Brightness.light,
              pureBlack: false),
          darkTheme: PortalThemes.build(
              preset: preset,
              accentOverride: accent,
              brightness: Brightness.dark,
              pureBlack: pureBlack),
          themeMode: state.themeMode == 0
              ? ThemeMode.system
              : state.themeMode == 1
                  ? ThemeMode.light
                  : ThemeMode.dark,
          home: AppScope(
            state: state,
            child: const RootShell(),
          ),
        );
      },
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context).s;
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          HomePage(),
          InstancesPage(),
          BrowsePage(),
          DownloadsPage(),
          SettingsPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: s['tabHome'],
          ),
          NavigationDestination(
            icon: const Icon(Icons.grid_view_outlined),
            selectedIcon: const Icon(Icons.grid_view),
            label: s['tabInstances'],
          ),
          NavigationDestination(
            icon: const Icon(Icons.extension_outlined),
            selectedIcon: const Icon(Icons.extension),
            label: s['tabBrowse'],
          ),
          NavigationDestination(
            icon: const Icon(Icons.download_outlined),
            selectedIcon: const Icon(Icons.download),
            label: s['tabDownloads'],
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: s['tabSettings'],
          ),
        ],
      ),
    );
  }
}

/// Opens the accounts page from anywhere.
void openAccounts(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const AccountsPage()),
  );
}
