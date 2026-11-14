import 'package:flutter/material.dart';

import '../app_state.dart';
import '../services/pollinations.dart';
import '../theme.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final s = st.s;
    return Scaffold(
      appBar: AppBar(
        title: Text(s['tabSettings'],
            style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // ---- Appearance ----
          Text(s['appearance'],
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          Card(
            child: Column(
              children: [
                // theme mode
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Text(s['themeModeLabel']),
                      const Spacer(),
                      SegmentedButton<int>(
                        segments: [
                          ButtonSegment(
                              value: 0,
                              icon: const Icon(Icons.brightness_auto,
                                  size: 18),
                              tooltip: s['modeSystem']),
                          ButtonSegment(
                              value: 1,
                              icon: const Icon(Icons.light_mode, size: 18),
                              tooltip: s['modeLight']),
                          ButtonSegment(
                              value: 2,
                              icon: const Icon(Icons.dark_mode, size: 18),
                              tooltip: s['modeDark']),
                          ButtonSegment(
                              value: 3,
                              icon: const Icon(Icons.contrast, size: 18),
                              tooltip: s['modeBlack']),
                        ],
                        selected: {st.themeMode},
                        onSelectionChanged: (v) => st.setThemeMode(v.first),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                // palettes
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s['themeLabel']),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: PortalThemes.presets
                            .map((p) => _PaletteDot(
                                  preset: p,
                                  selected: st.themeId == p.id,
                                  onTap: () => st.setThemeId(p.id),
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                // accent
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s['accentLabel']),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _AccentSwatch(
                            color: null,
                            selected: st.accentColor == null,
                            label: s['accentDefault'],
                            onTap: () => st.setAccent(null),
                          ),
                          ...PortalThemes.accents
                              .where((c) =>
                                  c.value !=
                                  PortalThemes.byId(st.themeId).seed.value)
                              .map((c) => _AccentSwatch(
                                    color: c,
                                    selected: st.accentColor == c.value,
                                    onTap: () => st.setAccent(c.value),
                                  )),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                // glass effect
                SwitchListTile(
                  secondary: const Icon(Icons.opacity),
                  title: Text(s['glassLabel']),
                  subtitle: Text(s['glassHint']),
                  value: st.glass,
                  onChanged: (v) => st.setGlass(v),
                ),
              ],
            ),
          ),

          // ---- Language ----
          const SizedBox(height: 18),
          Text(s['language'],
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(s['language']),
                  const Spacer(),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'ru', label: Text('Русский')),
                      ButtonSegment(value: 'en', label: Text('English')),
                    ],
                    selected: {st.lang},
                    onSelectionChanged: (v) => st.setLang(v.first),
                  ),
                ],
              ),
            ),
          ),

          // ---- Portalus ----
          const SizedBox(height: 18),
          Text(s['portalusSection'],
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.auto_awesome),
                  title: Text(s['portalusModel']),
                  subtitle: Text(st.aiModel),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _pickAiModel(context, st),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                SwitchListTile(
                  secondary: const Icon(Icons.travel_explore),
                  title: Text(s['webSearchLabel']),
                  subtitle: Text(s['webSearchHint']),
                  value: st.aiWebSearch,
                  onChanged: (v) => st.setAiWebSearch(v),
                ),
              ],
            ),
          ),

          // ---- Performance ----
          const SizedBox(height: 18),
          Text(s['performanceSection'],
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.image_outlined),
                  title: Text(s['cacheImages']),
                  value: st.cacheImages,
                  onChanged: (v) => st.setCacheImages(v),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.cleaning_services_outlined),
                  title: Text(s['clearCache']),
                  onTap: () {
                    PaintingBinding.instance.imageCache.clear();
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(s['cacheCleared'])));
                  },
                ),
              ],
            ),
          ),

          // ---- Defaults ----
          const SizedBox(height: 18),
          Text(s['defaultsSection'],
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      '${s['defaultMemory']}: ${st.defaultMemoryMb == 0 ? s['memoryAuto'] : '${st.defaultMemoryMb} MB'}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  Slider(
                    value: (st.defaultMemoryMb == 0
                            ? 2048
                            : st.defaultMemoryMb)
                        .toDouble(),
                    min: 512,
                    max: 8192,
                    divisions: 15,
                    label: st.defaultMemoryMb == 0
                        ? s['memoryAuto']
                        : '${st.defaultMemoryMb} MB',
                    onChanged: (v) => st.setDefaultMemory(v.round()),
                  ),
                ],
              ),
            ),
          ),

          // ---- About ----
          const SizedBox(height: 18),
          Text(s['about'],
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(s['aboutText']),
                ),
                ListTile(
                  leading: const Icon(Icons.vpn_key_outlined),
                  title: Text(s['licenses']),
                  subtitle: Text(s['licensesText']),
                ),
                ListTile(
                  leading: const Icon(Icons.tag),
                  title: Text(s['version']),
                  trailing: const Text('2.0.0'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Future<void> _pickAiModel(BuildContext context, AppState st) async {
    final s = st.s;
    final models = await PollinationsService.models();
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Text(s['portalusModel'],
                  style: Theme.of(ctx)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
            ...models.map((m) {
              final selected = m.name == st.aiModel;
              return ListTile(
                leading: Icon(
                    selected ? Icons.check_circle : Icons.circle_outlined,
                    size: 20),
                title: Text(m.name,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(m.description, maxLines: 2),
                onTap: () {
                  st.setAiModel(m.name);
                  Navigator.pop(ctx);
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _PaletteDot extends StatelessWidget {
  final ThemePreset preset;
  final bool selected;
  final VoidCallback onTap;
  const _PaletteDot({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: preset.seed,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected
                    ? Theme.of(context).colorScheme.onSurface
                    : Colors.transparent,
                width: 3,
              ),
            ),
            child: selected
                ? const Icon(Icons.check, color: Colors.white)
                : null,
          ),
        ),
        const SizedBox(height: 4),
        Text(preset.name, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

class _AccentSwatch extends StatelessWidget {
  final Color? color;
  final bool selected;
  final String? label;
  final VoidCallback onTap;
  const _AccentSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    if (color == null) {
      return ChoiceChip(
        label: Text(label ?? ''),
        selected: selected,
        onSelected: (_) => onTap(),
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.onSurface
                : Colors.transparent,
            width: 3,
          ),
        ),
        child: selected
            ? const Icon(Icons.check, color: Colors.white, size: 18)
            : null,
      ),
    );
  }
}
