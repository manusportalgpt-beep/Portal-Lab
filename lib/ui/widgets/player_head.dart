import 'dart:io';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models.dart';

/// Square Minecraft-style player head icon.
///
/// Renders the 8x8 face crop (plus the hat layer) of the player skin:
///  * the local override file when present (offline accounts),
///  * otherwise the network skin (Microsoft accounts),
///  * otherwise a deterministic default Steve / Alex face.
class PlayerHead extends StatelessWidget {
  final String? skinUrl;
  final String? skinPath;
  final String name;
  final String uuid;
  final double size;
  final double radius;

  /// Force the default model (Alex) for the fallback face; null = pick by
  /// UUID hash, exactly like vanilla does for unsigned players.
  final bool? slim;

  const PlayerHead({
    super.key,
    this.skinUrl,
    this.skinPath,
    this.name = '',
    this.uuid = '',
    this.size = 44,
    this.radius = 6,
    this.slim,
  });

  factory PlayerHead.of(McAccount acc,
      {double size = 44, double radius = 6, bool? slim}) {
    final m = acc.localSkinModel ?? acc.skinModel;
    return PlayerHead(
      skinUrl: acc.skinUrl,
      skinPath: acc.localSkinPath,
      name: acc.username,
      uuid: acc.uuid,
      size: size,
      radius: radius,
      slim: slim ?? (m == null ? null : m == 'slim'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: _SkinImage(
          url: skinUrl,
          path: skinPath,
          seed: '$uuid|$name',
          slim: slim,
          fullBody: false,
          size: Size(size, size),
        ),
      ),
    );
  }
}

/// Full front-view render of the player model (head + body + arms + legs).
class PlayerBody extends StatelessWidget {
  final String? skinUrl;
  final String? skinPath;
  final String name;
  final String uuid;
  final double height;
  final bool? slim;

  const PlayerBody({
    super.key,
    this.skinUrl,
    this.skinPath,
    this.name = '',
    this.uuid = '',
    this.height = 180,
    this.slim,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: height / 2,
      height: height,
      child: _SkinImage(
        url: skinUrl,
        path: skinPath,
        seed: '$uuid|$name',
        slim: slim,
        fullBody: true,
        size: Size(height / 2, height),
      ),
    );
  }
}

/// Loads a skin texture (file or network) and paints it with the given
/// painter; falls back to the procedural Steve / Alex renderer.
class _SkinImage extends StatefulWidget {
  final String? url;
  final String? path;
  final String seed;
  final bool? slim;
  final bool fullBody;
  final Size size;

  const _SkinImage({
    required this.url,
    required this.path,
    required this.seed,
    required this.slim,
    required this.fullBody,
    required this.size,
  });

  @override
  State<_SkinImage> createState() => _SkinImageState();
}

class _SkinImageState extends State<_SkinImage> {
  ui.Image? _image;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant _SkinImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url || oldWidget.path != widget.path) {
      _resolve();
    }
  }

  @override
  void dispose() {
    _cancel();
    super.dispose();
  }

  void _cancel() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    _stream = null;
    _listener = null;
  }

  void _resolve() {
    _cancel();
    _image = null;
    ImageProvider? provider;
    final p = widget.path;
    if (p != null && p.isNotEmpty && File(p).existsSync()) {
      provider = FileImage(File(p));
    } else {
      final u = widget.url;
      if (u != null &&
          (u.startsWith('http://') || u.startsWith('https://'))) {
        provider = CachedNetworkImageProvider(u);
      }
    }
    if (provider == null) {
      if (mounted) setState(() {});
      return;
    }
    final stream = provider.resolve(const ImageConfiguration());
    final listener = ImageStreamListener((ImageInfo info, bool _) {
      if (!mounted) return;
      setState(() => _image = info.image);
    }, onError: (Object error, StackTrace? stackTrace) {
      if (!mounted) return;
      setState(() => _image = null);
    });
    _stream = stream;
    _listener = listener;
    stream.addListener(listener);
  }

  @override
  Widget build(BuildContext context) {
    final img = _image;
    final CustomPainter painter;
    if (widget.fullBody) {
      painter = img != null
          ? _SkinBodyPainter(img, widget.slim == true)
          : _DefaultBodyPainter(widget.seed, widget.slim);
    } else {
      painter = img != null
          ? _SkinFacePainter(img)
          : _DefaultFacePainter(widget.seed, widget.slim);
    }
    return CustomPaint(size: widget.size, painter: painter);
  }
}

/// Face crop (8x8 + hat layer) of a real skin texture.
class _SkinFacePainter extends CustomPainter {
  final ui.Image image;
  _SkinFacePainter(this.image);

  @override
  void paint(Canvas canvas, Size size) {
    final sc = image.width / 64.0;
    final paint = Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false;
    final dst = Offset.zero & size;
    canvas.drawImageRect(
        image, Rect.fromLTWH(8 * sc, 8 * sc, 8 * sc, 8 * sc), dst, paint);
    canvas.drawImageRect(
        image, Rect.fromLTWH(40 * sc, 8 * sc, 8 * sc, 8 * sc), dst, paint);
  }

  @override
  bool shouldRepaint(covariant _SkinFacePainter oldDelegate) =>
      oldDelegate.image != image;
}

/// Full front view assembled from a real skin texture. Understands the
/// modern 64x64 layout, HD skins (128x128) and the legacy 64x32 layout.
class _SkinBodyPainter extends CustomPainter {
  final ui.Image image;
  final bool slim;
  _SkinBodyPainter(this.image, this.slim);

  @override
  void paint(Canvas canvas, Size size) {
    final sc = image.width / 64.0;
    final legacy = image.width == 2 * image.height;
    final paint = Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false;
    final ux = size.width / 16;
    final uy = size.height / 32;

    Rect dst(double dx, double dy, double dw, double dh) =>
        Rect.fromLTWH(dx * ux, dy * uy, dw * ux, dh * uy);

    void part(double sx, double sy, double sw, double sh, double dx,
        double dy, double dw, double dh) {
      canvas.drawImageRect(image, Rect.fromLTWH(sx * sc, sy * sc, sw * sc, sh * sc),
          dst(dx, dy, dw, dh), paint);
    }

    void partMirror(double sx, double sy, double sw, double sh, double dx,
        double dy, double dw, double dh) {
      final r = dst(dx, dy, dw, dh);
      canvas.save();
      canvas.translate(r.right, r.top);
      canvas.scale(-1, 1);
      canvas.drawImageRect(
          image,
          Rect.fromLTWH(sx * sc, sy * sc, sw * sc, sh * sc),
          Rect.fromLTWH(0, 0, r.width, r.height),
          paint);
      canvas.restore();
    }

    final aw = slim ? 3.0 : 4.0; // arm width
    final rax = 4 - aw; // right arm x (0 classic, 1 slim)

    // Base layer: legs, arms, body, head.
    part(4, 20, 4, 12, 4, 20, 4, 12); // right leg
    part(44, 20, aw, 12, rax, 8, aw, 12); // right arm
    part(20, 20, 8, 12, 4, 8, 8, 12); // body
    part(8, 8, 8, 8, 4, 0, 8, 8); // head
    if (!legacy) {
      part(20, 52, 4, 12, 8, 20, 4, 12); // left leg
      part(36, 52, aw, 12, 12, 8, aw, 12); // left arm
    } else {
      // 64x32 skins have no left parts — mirror the right ones.
      partMirror(4, 20, 4, 12, 8, 20, 4, 12);
      partMirror(44, 20, aw, 12, 12, 8, aw, 12);
    }

    // Overlay layer (hat, jacket, sleeves, pants) — transparent on legacy.
    if (!legacy) {
      part(4, 36, 4, 12, 4, 20, 4, 12); // right pants
      part(4, 52, 4, 12, 8, 20, 4, 12); // left pants
      part(44, 36, aw, 12, rax, 8, aw, 12); // right sleeve
      part(52, 52, aw, 12, 12, 8, aw, 12); // left sleeve
      part(20, 36, 8, 12, 4, 8, 8, 12); // jacket
      part(40, 8, 8, 8, 4, 0, 8, 8); // hat
    }
  }

  @override
  bool shouldRepaint(covariant _SkinBodyPainter oldDelegate) =>
      oldDelegate.image != image || oldDelegate.slim != slim;
}

/// Procedural Steve / Alex fallback faces (8x8 pixel maps).
class _DefaultFacePainter extends CustomPainter {
  final String seed;
  final bool? slim;
  _DefaultFacePainter(this.seed, this.slim);

  static const _steveFace = <String>[
    'HHHHHHHH',
    'hhhhhhhh',
    'hSSSSSSh',
    'SBBSSBBS',
    'SWISSIWS',
    'SSSNNSSS',
    'SSMMMMSS',
    'SSSSSSSS',
  ];
  static const _stevePal = <String, Color>{
    'H': Color(0xFF36261A),
    'h': Color(0xFF46331F),
    'S': Color(0xFFC4906C),
    'B': Color(0xFF3F2B1C),
    'W': Color(0xFFE4E4E4),
    'I': Color(0xFF4A3C9E),
    'N': Color(0xFFA5714F),
    'M': Color(0xFF6E4428),
  };

  static const _alexFace = <String>[
    'HHHHHHHH',
    'HHHHHHHH',
    'HSSSSSSH',
    'HSSSSSSH',
    'HWISSIWH',
    'HSSNNSSH',
    'HSSMMSSH',
    'SSSSSSSS',
  ];
  static const _alexPal = <String, Color>{
    'H': Color(0xFFD87A35),
    'S': Color(0xFFF0C8A2),
    'W': Color(0xFFE4E4E4),
    'I': Color(0xFF3F8F45),
    'N': Color(0xFFDDA87F),
    'M': Color(0xFFB06A48),
  };

  @override
  void paint(Canvas canvas, Size size) {
    final alex = slim ?? (seed.hashCode & 1) == 1;
    final rows = alex ? _alexFace : _steveFace;
    final pal = alex ? _alexPal : _stevePal;
    final px = size.width / 8;
    final py = size.height / 8;
    for (var y = 0; y < 8; y++) {
      final row = rows[y];
      for (var x = 0; x < 8; x++) {
        final c = pal[row[x]];
        if (c == null) continue;
        canvas.drawRect(
            Rect.fromLTWH(x * px, y * py, px + 0.5, py + 0.5), Paint()..color = c);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DefaultFacePainter oldDelegate) =>
      oldDelegate.seed != seed || oldDelegate.slim != slim;
}

/// Procedural Steve / Alex fallback full body.
class _DefaultBodyPainter extends CustomPainter {
  final String seed;
  final bool? slim;
  _DefaultBodyPainter(this.seed, this.slim);

  @override
  void paint(Canvas canvas, Size size) {
    final alex = slim ?? (seed.hashCode & 1) == 1;
    final ux = size.width / 16;
    final uy = size.height / 32;
    void fill(double dx, double dy, double dw, double dh, Color c) {
      canvas.drawRect(
          Rect.fromLTWH(dx * ux, dy * uy, dw * ux, dh * uy), Paint()..color = c);
    }

    // Head (8x8 face) drawn precisely at the head position.
    canvas.save();
    canvas.translate(4 * ux, 0);
    _DefaultFacePainter(seed, alex).paint(canvas, Size(8 * ux, 8 * uy));
    canvas.restore();

    const skin = Color(0xFFC4906C);
    const skinShadow = Color(0xFFB07E5C);
    const alexSkin = Color(0xFFF0C8A2);
    const alexSkinShadow = Color(0xFFDDA87F);

    final aw = alex ? 3.0 : 4.0;
    final rax = 4 - aw;

    if (alex) {
      // Tunic.
      fill(4, 8, 8, 10, const Color(0xFF82A94B));
      fill(4, 18, 8, 2, const Color(0xFF4B3A28)); // belt
      // Arms: short sleeves + bare skin.
      fill(rax, 8, aw, 4, const Color(0xFF82A94B));
      fill(rax, 12, aw, 8, alexSkin);
      fill(rax, 20, aw, 1, alexSkinShadow);
      fill(12, 8, aw, 4, const Color(0xFF82A94B));
      fill(12, 12, aw, 8, alexSkin);
      fill(12, 20, aw, 1, alexSkinShadow);
      // Legs + boots.
      fill(4, 20, 4, 9, const Color(0xFF3F4048));
      fill(8, 20, 4, 9, const Color(0xFF3F4048));
      fill(4, 29, 4, 3, const Color(0xFF6E4A2E));
      fill(8, 29, 4, 3, const Color(0xFF6E4A2E));
    } else {
      // Steve: teal shirt.
      fill(4, 8, 8, 11, const Color(0xFF00A8A8));
      fill(4, 19, 8, 1, const Color(0xFF008B8B));
      // Bare arms.
      fill(rax, 8, aw, 11, skin);
      fill(rax, 19, aw, 1, skinShadow);
      fill(12, 8, aw, 11, skin);
      fill(12, 19, aw, 1, skinShadow);
      // Blue pants + gray shoes.
      fill(4, 20, 4, 10, const Color(0xFF4051B5));
      fill(8, 20, 4, 10, const Color(0xFF4051B5));
      fill(4, 30, 4, 2, const Color(0xFF6E6E6E));
      fill(8, 30, 4, 2, const Color(0xFF6E6E6E));
    }
  }

  @override
  bool shouldRepaint(covariant _DefaultBodyPainter oldDelegate) =>
      oldDelegate.seed != seed || oldDelegate.slim != slim;
}
