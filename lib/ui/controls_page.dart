import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../models.dart';
import '../services/pojav.dart';
import '../store.dart';
import '../theme.dart';

/// Editor of the desktop Minecraft control overlay: sprint, inventory,
/// chat, sneak, ESC, cursor and more. Layouts export to PojavLauncher.
class ControlsPage extends StatefulWidget {
  const ControlsPage({super.key});

  @override
  State<ControlsPage> createState() => _ControlsPageState();
}

/// Button catalog: (i18n key, GLFW keycode, toggle).
const _buttonCatalog = <String, (String, int, bool)>{
  'buttonSprint': ('buttonSprint', 341, true),
  'buttonInventory': ('buttonInventory', 69, false),
  'buttonChat': ('buttonChat', 84, false),
  'buttonSneak': ('buttonSneak', 340, true),
  'buttonEsc': ('buttonEsc', 256, false),
  'buttonCursor': ('buttonCursor', -2, true),
  'buttonJump': ('buttonJump', 32, false),
  'buttonDrop': ('buttonDrop', 81, false),
  'buttonDebug': ('buttonDebug', 292, false),
  'buttonThird': ('buttonThird', 294, false),
  'buttonTab': ('buttonTab', 258, false),
};

class _ControlsPageState extends State<ControlsPage> {
  ControlsProfile _profile = ControlsProfile();
  List<ControlButton> _buttons = [];
  String? _selected;

  @override
  void initState() {
    super.initState();
    final (profile, buttons) = Store.loadControls();
    _profile = profile;
    _buttons = buttons;
  }

  Future<void> _save() => Store.saveControls(_profile, _buttons);

  static const _presetLabelKeys = {
    'Sprint': 'buttonSprint',
    'Inv': 'buttonInventory',
    'Chat': 'buttonChat',
    'Sneak': 'buttonSneak',
    'ESC': 'buttonEsc',
    'Cursor': 'buttonCursor',
    'Jump': 'buttonJump',
    'Drop': 'buttonDrop',
    'F3': 'buttonDebug',
    'View': 'buttonThird',
    'Tab': 'buttonTab',
  };

  void _applyPreset(String id) {
    final preset = controlPresets[id];
    if (preset == null) return;
    final s = AppScope.of(context).s;
    setState(() {
      _buttons = preset
          .map((b) {
            final raw = b['name'] as String;
            final key = _presetLabelKeys[raw];
            return ControlButton(
              name: key == null ? raw : s[key],
              keycode: b['keycode'] as int,
              x: (b['x'] as num).toDouble(),
              y: (b['y'] as num).toDouble(),
              size: (b['size'] as num).toDouble(),
              isToggle: b['isToggle'] as bool,
            );
          })
          .toList();
      _selected = null;
    });
    _save();
  }

  void _addButton(String i18nKey, (String, int, bool) def) {
    final s = AppScope.of(context).s;
    setState(() {
      _buttons.add(ControlButton(
        name: s[i18nKey],
        keycode: def.$2,
        x: 50,
        y: 50,
        size: 54,
        isToggle: def.$3,
      ));
      _selected = _buttons.last.name;
    });
    _save();
  }

  void _removeSelected() {
    if (_selected == null) return;
    setState(() {
      _buttons.removeWhere((b) => b.name == _selected);
      _selected = null;
    });
    _save();
  }

  Future<void> _export() async {
    final s = AppScope.of(context).s;
    try {
      final path =
          await PojavService.exportControlsLayout(_profile, _buttons);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${s['layoutExported']}: $path')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${s['error']}: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final s = st.s;
    final cs = Theme.of(context).colorScheme;
    final selectedBtn =
        _buttons.where((b) => b.name == _selected).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(s['controlsTitle'],
            style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            tooltip: s['resetLayout'],
            icon: const Icon(Icons.restart_alt),
            onPressed: () {
              setState(() {
                _profile = ControlsProfile();
                _buttons = Store.defaultControls();
                _selected = null;
              });
              _save();
            },
          ),
          IconButton(
            tooltip: s['exportLayout'],
            icon: const Icon(Icons.file_download_outlined),
            onPressed: _export,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Text(s['controlsHint'],
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 10),

          // ---- Preview overlay ----
          Text(s['dragHint'],
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: LayoutBuilder(builder: (context, box) {
                return Container(
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withOpacity(0.35),
                    border: Border.all(
                        color: cs.outlineVariant.withOpacity(0.5)),
                  ),
                  child: Stack(
                    children: [
                      // subtle grid
                      CustomPaint(
                        size: Size.infinite,
                        painter: _GridPainter(color: cs.outlineVariant
                            .withOpacity(0.25)),
                      ),
                      ..._buttons.map((b) {
                        final isSelected = b.name == _selected;
                        final px = b.x / 100 * (box.maxWidth - b.size);
                        final py = b.y / 100 * (box.maxHeight - b.size);
                        return Positioned(
                          left: px,
                          top: py,
                          child: GestureDetector(
                            onPanUpdate: (d) {
                              setState(() {
                                b.x = ((b.x / 100 *
                                            (box.maxWidth - b.size) +
                                        d.delta.dx) /
                                    (box.maxWidth - b.size) *
                                    100)
                                    .clamp(0.0, 100.0);
                                b.y = ((b.y / 100 *
                                            (box.maxHeight - b.size) +
                                        d.delta.dy) /
                                    (box.maxHeight - b.size) *
                                    100)
                                    .clamp(0.0, 100.0);
                              });
                            },
                            onPanEnd: (_) => _save(),
                            onTap: () {
                              if (_profile.haptics) {
                                HapticFeedback.lightImpact();
                              }
                              setState(() => _selected = b.name);
                            },
                            child: Container(
                              width: b.size,
                              height: b.size,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: (isSelected
                                        ? cs.primary
                                        : cs.secondaryContainer)
                                    .withOpacity(
                                        b.opacity * _profile.opacity + 0.08),
                                border: Border.all(
                                  color: isSelected
                                      ? cs.primary
                                      : cs.outline.withOpacity(0.4),
                                  width: 2,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                b.name,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: b.size * 0.19,
                                  height: 1.05,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected
                                      ? cs.onPrimary
                                      : cs.onSecondaryContainer,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                );
              }),
            ),
          ),

          // ---- Selected button controls ----
          if (selectedBtn.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            selectedBtn.first.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                        Text(
                            'keycode ${selectedBtn.first.keycode}',
                            style:
                                Theme.of(context).textTheme.bodySmall),
                        IconButton(
                          tooltip: s['removeButton'],
                          icon: const Icon(Icons.delete_outline),
                          onPressed: _removeSelected,
                        ),
                      ],
                    ),
                    Text('${s['sizeLabel']}: ${selectedBtn.first.size.round()}',
                        style: const TextStyle(fontSize: 12)),
                    Slider(
                      value: selectedBtn.first.size,
                      min: 36,
                      max: 90,
                      onChanged: (v) {
                        setState(() => selectedBtn.first.size = v);
                      },
                      onChangeEnd: (_) => _save(),
                    ),
                    Text(
                        '${s['opacityLabel']}: ${(selectedBtn.first.opacity * 100).round()}%',
                        style: const TextStyle(fontSize: 12)),
                    Slider(
                      value: selectedBtn.first.opacity,
                      onChanged: (v) {
                        setState(() => selectedBtn.first.opacity = v);
                      },
                      onChangeEnd: (_) => _save(),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Toggle', style: TextStyle(fontSize: 13)),
                      value: selectedBtn.first.isToggle,
                      onChanged: (v) {
                        setState(() => selectedBtn.first.isToggle = v);
                        _save();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],

          // ---- Global settings ----
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      '${s['opacityLabel']}: ${(_profile.opacity * 100).round()}%',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  Slider(
                    value: _profile.opacity,
                    onChanged: (v) =>
                        setState(() => _profile.opacity = v),
                    onChangeEnd: (_) => _save(),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(s['hapticsLabel'],
                        style: const TextStyle(fontSize: 13)),
                    value: _profile.haptics,
                    onChanged: (v) {
                      setState(() => _profile.haptics = v);
                      _save();
                    },
                  ),
                ],
              ),
            ),
          ),

          // ---- Presets ----
          const SizedBox(height: 10),
          Text(s['presetLabel'],
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.gamepad_outlined, size: 18),
                label: Text(s['presetClassic']),
                onPressed: () => _applyPreset('classic'),
              ),
              ActionChip(
                avatar: const Icon(Icons.sports_esports, size: 18),
                label: Text(s['presetPvP']),
                onPressed: () => _applyPreset('pvp'),
              ),
              ActionChip(
                avatar: const Icon(Icons.construction, size: 18),
                label: Text(s['presetBuilder']),
                onPressed: () => _applyPreset('builder'),
              ),
            ],
          ),

          // ---- Add buttons ----
          const SizedBox(height: 14),
          Text(s['addButton'],
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _buttonCatalog.entries
                .map((e) => ActionChip(
                      label: Text(s[e.key] ?? e.key),
                      onPressed: () => _addButton(e.key, e.value),
                    ))
                .toList(),
          ),

          const SizedBox(height: 14),
          FilledButton.icon(
            style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50)),
            onPressed: _export,
            icon: const Icon(Icons.file_download_outlined),
            label: Text(s['exportLayout']),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              s['layoutExportHint'],
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

}

class _GridPainter extends CustomPainter {
  final Color color;
  _GridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.6;
    const step = 40.0;
    for (var x = step; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = step; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) =>
      oldDelegate.color != color;
}
