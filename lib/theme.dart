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

  static ThemePreset byId(String id) =>
      presets.firstWhere((p) => p.id == id, orElse: () => presets.first);

  static const _black = Color(0xFF000000);

  static ThemeData build({
    required ThemePreset preset,
    Color? accentOverride,
    required Brightness brightness,
    required bool pureBlack,
  }) {
    final seed = accentOverride ?? preset.seed;
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    var theme = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: brightness == Brightness.dark && pureBlack
          ? _black
          : null,
      appBarTheme: AppBarTheme(
        backgroundColor: brightness == Brightness.dark && pureBlack
            ? _black
            : scheme.surface,
        scrolledUnderElevation: 2,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: brightness == Brightness.dark && pureBlack
            ? _black
            : null,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: brightness == Brightness.dark && pureBlack
            ? Color(0xFF0D0D0D)
            : scheme.surfaceContainerHighest.withOpacity(0.45),
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
