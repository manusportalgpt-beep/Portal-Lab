import 'dart:convert';
import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

import '../models.dart';
import '../store.dart';

/// Integration with PojavLauncher (the Java runtime host on Android):
/// opening the app, installing it, and exporting control layouts in the
/// PojavLauncher control-layout JSON format.
class PojavService {
  static const packageName = 'net.kdt.pojavlaunch';
  static const playUrl =
      'https://play.google.com/store/apps/details?id=$packageName';

  /// Try to open PojavLauncher; falls back to the Play Store page.
  static Future<bool> openOrInstall() async {
    // url_launcher supports intent:// URIs on Android.
    final intent = Uri.parse(
        'intent://#Intent;action=android.intent.action.MAIN;package=$packageName;end');
    try {
      if (await canLaunchUrl(intent)) {
        return await launchUrl(intent, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
    final store = Uri.parse(playUrl);
    try {
      return await launchUrl(store, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// Open the PojavLauncher Play Store page (install flow).
  static Future<bool> openStore() async {
    final store = Uri.parse(playUrl);
    try {
      return await launchUrl(store, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// Export the control layout as a PojavLauncher-compatible JSON file.
  /// Returns the written file path.
  static Future<String> exportControlsLayout(
      ControlsProfile profile, List<ControlButton> buttons) async {
    final list = buttons.map((b) {
      final cx = (b.x.clamp(0.0, 100.0)) / 100.0;
      final cy = (b.y.clamp(0.0, 100.0)) / 100.0;
      final w = b.size;
      final h = b.size;
      return {
        'bgColor': 1291845632, // semi-transparent dark gray, ARGB
        'cornerRadius': (b.size / 2).round(),
        'dynamicX':
            '\${screen_width} * ${_fmt(cx)} - \${width} / 2',
        'dynamicY':
            '\${screen_height} * ${_fmt(cy)} - \${height} / 2',
        'height': h.round(),
        'isDynamicBtn': false,
        'isHideable': true,
        'isSwipeable': false,
        'isToggle': b.isToggle,
        'keycodes': [b.keycode, 0, 0, 0],
        'name': b.name,
        'opacity': profile.opacity,
        'passThruEnabled': false,
        'strokeColor': -1,
        'strokeWidth': 0,
        'width': w.round(),
      };
    }).toList();
    final j = {'mControlDataList': list, 'scaledAt': 1};
    final dir = Store.exportsDir;
    await dir.create(recursive: true);
    final f = File(
        '${dir.path}/${_sanitize(profile.name)}-controls.json');
    await f.writeAsString(const JsonEncoder.withIndent('  ').convert(j));
    return f.path;
  }

  static String _fmt(double v) =>
      v.toStringAsFixed(3).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');

  static String _sanitize(String s) =>
      s.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
}
