import 'package:flutter/material.dart';

/// A named theme palette.
class ThemePreset {
  final String id;
  final String name;
  final Color seed;
  const ThemePreset(this.id, this.name, this.seed);
}

class PortalThemes {
  static const presets = <ThemePreset>[
    ThemePreset('portal', 'Portal', Color(0xFF5C6BC0)),
    ThemePreset('emerald', 'Emerald', Color(0xFF2E9E6B)),
    ThemePreset('crimson', 'Crimson', Color(0xFFD3455B)),
    ThemePreset('ocean', 'Ocean', Color(0xFF1E88C7)),
    ThemePreset('amber', 'Amber', Color(0xFFC77D1F)),
    ThemePreset('violet', 'Violet', Color(0xFF8450C9)),
    ThemePreset('rose', 'Rose', Color(0xFFC94F7C)),
    ThemePreset('teal', 'Teal', Color(0xFF00897B)),
    ThemePreset('lime', 'Lime', Color(0xFF6BA32D)),
    ThemePreset('slate', 'Slate', Color(0xFF5B7C99)),
  ];

  /// Extra accent colors the user can pick on top of a palette.
  static const accents = <Color>[
    Color(0xFF5C6BC0), Color(0xFF3949AB), Color(0xFF1E88E5), Color(0xFF00ACC1),
    Color(0xFF00897B), Color(0xFF43A047), Color(0xFF7CB342), Color(0xFFFDD835),
    Color(0xFFFFB300), Color(0xFFF4511E), Color(0xFFE53935), Color(0xFFD81B60),
    Color(0xFF8E24AA), Color(0xFF5E35B1), Color(0xFF6D4C41), Color(0xFF546E7A),
  ];

  /// Named instance icons (id -> Material icon).
  static const instanceIcons = <String, IconData>{
    'grass': Icons.grass,
    'diamond': Icons.diamond_outlined,
    'pickaxe': Icons.hardware,
    'creeper': Icons.bug_report,
    'ender': Icons.blur_on,
    'nether': Icons.local_fire_department,
    'cave': Icons.landscape,
    'redstone': Icons.bolt,
    'potion': Icons.science,
    'crafting': Icons.apps,
    'chest': Icons.inventory_2,
    'portal': Icons.crop_square,
  };

  static ThemePreset byId(String id) =>
      presets.firstWhere((p) => p.id == id, orElse: () => presets.first);

  static const _black = Color(0xFF000000);

  static ThemeData build({
    required ThemePreset preset,
    Color? accentOverride,
    required Brightness brightness,
    required bool pureBlack,
    bool glass = false,
  }) {
    final seed = accentOverride ?? preset.seed;
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    final dark = brightness == Brightness.dark;
    final surface = dark && pureBlack ? _black : scheme.surface;
    final cardColor = dark && pureBlack
        ? const Color(0xFF0D0D0D)
        : glass
            ? scheme.surfaceContainerHighest.withOpacity(
                dark ? 0.35 : 0.45)
            : scheme.surfaceContainerHighest.withOpacity(0.45);
    var theme = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: surface,
      appBarTheme: AppBarTheme(
        backgroundColor:
            glass ? surface.withOpacity(dark ? 0.72 : 0.8) : surface,
        scrolledUnderElevation: 2,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: glass
            ? surface.withOpacity(dark ? 0.78 : 0.86)
            : (dark && pureBlack ? _black : null),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        margin: const EdgeInsets.symmetric(vertical: 5),
      ),
      listTileTheme: const ListTileThemeData(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16))),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        filled: true,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      splashFactory: InkSparkle.splashFactory,
    );
    return theme;
  }
}

/// Helper for compact formatted numbers: 12.4K / 3.2M.
String fmtCount(int n) {
  if (n >= 1000000000) return '${(n / 1000000000).toStringAsFixed(1)}B';
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return n.toString();
}

/// Helper for file sizes.
String fmtSize(int bytes) {
  if (bytes >= 1073741824) return '${(bytes / 1073741824).toStringAsFixed(2)} GB';
  if (bytes >= 1048576) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '$bytes B';
}

/// Preset control layouts for the Controls page.
Map<String, List<Map<String, dynamic>>> get controlPresets => {
      'classic': [
        {'name': 'Sprint', 'keycode': 341, 'x': 78.0, 'y': 68.0, 'size': 60.0, 'isToggle': true},
        {'name': 'Inv', 'keycode': 69, 'x': 78.0, 'y': 52.0, 'size': 60.0, 'isToggle': false},
        {'name': 'Chat', 'keycode': 84, 'x': 90.0, 'y': 36.0, 'size': 54.0, 'isToggle': false},
        {'name': 'Sneak', 'keycode': 340, 'x': 64.0, 'y': 84.0, 'size': 60.0, 'isToggle': true},
        {'name': 'ESC', 'keycode': 256, 'x': 50.0, 'y': 8.0, 'size': 50.0, 'isToggle': false},
        {'name': 'Cursor', 'keycode': -2, 'x': 6.0, 'y': 8.0, 'size': 54.0, 'isToggle': true},
        {'name': 'Jump', 'keycode': 32, 'x': 92.0, 'y': 84.0, 'size': 64.0, 'isToggle': false},
        {'name': 'Drop', 'keycode': 81, 'x': 50.0, 'y': 84.0, 'size': 50.0, 'isToggle': false},
        {'name': 'F3', 'keycode': 292, 'x': 38.0, 'y': 8.0, 'size': 44.0, 'isToggle': false},
        {'name': 'View', 'keycode': 294, 'x': 6.0, 'y': 20.0, 'size': 44.0, 'isToggle': false},
      ],
      'pvp': [
        {'name': 'Sprint', 'keycode': 341, 'x': 76.0, 'y': 70.0, 'size': 64.0, 'isToggle': true},
        {'name': 'Inv', 'keycode': 69, 'x': 88.0, 'y': 54.0, 'size': 58.0, 'isToggle': false},
        {'name': 'Chat', 'keycode': 84, 'x': 6.0, 'y': 8.0, 'size': 48.0, 'isToggle': false},
        {'name': 'Sneak', 'keycode': 340, 'x': 62.0, 'y': 86.0, 'size': 60.0, 'isToggle': true},
        {'name': 'ESC', 'keycode': 256, 'x': 50.0, 'y': 8.0, 'size': 48.0, 'isToggle': false},
        {'name': 'Cursor', 'keycode': -2, 'x': 6.0, 'y': 22.0, 'size': 52.0, 'isToggle': true},
        {'name': 'Drop', 'keycode': 81, 'x': 50.0, 'y': 88.0, 'size': 52.0, 'isToggle': false},
        {'name': 'Slot 1', 'keycode': 49, 'x': 20.0, 'y': 88.0, 'size': 40.0, 'isToggle': false},
        {'name': 'Slot 2', 'keycode': 50, 'x': 30.0, 'y': 88.0, 'size': 40.0, 'isToggle': false},
        {'name': 'Slot 3', 'keycode': 51, 'x': 40.0, 'y': 88.0, 'size': 40.0, 'isToggle': false},
      ],
      'builder': [
        {'name': 'Sprint', 'keycode': 341, 'x': 80.0, 'y': 66.0, 'size': 58.0, 'isToggle': true},
        {'name': 'Inv', 'keycode': 69, 'x': 80.0, 'y': 50.0, 'size': 58.0, 'isToggle': false},
        {'name': 'Chat', 'keycode': 84, 'x': 92.0, 'y': 34.0, 'size': 50.0, 'isToggle': false},
        {'name': 'Sneak', 'keycode': 340, 'x': 66.0, 'y': 82.0, 'size': 58.0, 'isToggle': true},
        {'name': 'ESC', 'keycode': 256, 'x': 50.0, 'y': 8.0, 'size': 48.0, 'isToggle': false},
        {'name': 'Cursor', 'keycode': -2, 'x': 6.0, 'y': 8.0, 'size': 52.0, 'isToggle': true},
        {'name': 'Jump', 'keycode': 32, 'x': 94.0, 'y': 82.0, 'size': 60.0, 'isToggle': false},
        {'name': 'Tab', 'keycode': 258, 'x': 38.0, 'y': 8.0, 'size': 44.0, 'isToggle': false},
        {'name': 'F3', 'keycode': 292, 'x': 6.0, 'y': 22.0, 'size': 42.0, 'isToggle': false},
        {'name': 'View', 'keycode': 294, 'x': 16.0, 'y': 22.0, 'size': 42.0, 'isToggle': false},
      ],
    };
