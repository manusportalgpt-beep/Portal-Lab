import 'package:flutter/material.dart';

import 'app_state.dart';
import 'store.dart';
import 'theme.dart';
import 'ui/browse_page.dart';
import 'ui/downloads_page.dart';
import 'ui/home_page.dart';
import 'ui/instances_page.dart';
import 'ui/portalus_page.dart';

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
              pureBlack: false,
              glass: state.glass),
          darkTheme: PortalThemes.build(
              preset: preset,
              accentOverride: accent,
              brightness: Brightness.dark,
              pureBlack: pureBlack,
              glass: state.glass),
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
          PortalusPage(),
          DownloadsPage(),
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
            icon: const Icon(Icons.auto_awesome_outlined),
            selectedIcon: const Icon(Icons.auto_awesome),
            label: s['tabPortalus'],
          ),
          NavigationDestination(
            icon: const Icon(Icons.download_outlined),
            selectedIcon: const Icon(Icons.download),
            label: s['tabDownloads'],
          ),
        ],
      ),
    );
  }
}
