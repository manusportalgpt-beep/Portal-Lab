import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Brand-colored badges for catalog sources and mod loaders.

class SourceBadge extends StatelessWidget {
  final String source; // modrinth | curseforge | local
  final double size;
  const SourceBadge({super.key, required this.source, this.size = 22});

  @override
  Widget build(BuildContext context) {
    switch (source) {
      case 'modrinth':
        return _Badge(
          size: size,
          color: const Color(0xFF1BD96A),
          label: 'M',
        );
      case 'curseforge':
        return _Badge(
          size: size,
          color: const Color(0xFFF16436),
          label: 'CF',
          fontSize: size * 0.36,
        );
      default:
        return _Badge(
          size: size,
          color: Colors.blueGrey,
          label: 'L',
        );
    }
  }
}

class _Badge extends StatelessWidget {
  final double size;
  final Color color;
  final String label;
  final double? fontSize;
  const _Badge(
      {required this.size,
      required this.color,
      required this.label,
      this.fontSize});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize ?? size * 0.5,
          fontWeight: FontWeight.w800,
          height: 1.0,
        ),
      ),
    );
  }
}

/// The Portalus assistant avatar: a violet portal swirl.
class PortalusAvatar extends StatelessWidget {
  final double size;
  final bool thinking;
  const PortalusAvatar({super.key, this.size = 36, this.thinking = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF9C5EEB), Color(0xFF6C3FD8)],
        ),
        boxShadow: thinking
            ? [
                BoxShadow(
                  color: const Color(0xFF9C5EEB).withOpacity(0.5),
                  blurRadius: size * 0.3,
                  spreadRadius: size * 0.05,
                )
              ]
            : null,
      ),
      child: CustomPaint(
        painter: _PortalSwirlPainter(
          color: Colors.white,
          progress: thinking ? null : 0.0,
        ),
      ),
    );
  }
}

class _PortalSwirlPainter extends CustomPainter {
  final Color color;
  final double? progress; // null = animated look (static snapshot)
  _PortalSwirlPainter({required this.color, this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.07
      ..strokeCap = StrokeCap.round;
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.32;
    // Spiral of arcs: three arcs with increasing radius and rotation.
    var start = -math.pi / 2;
    for (var i = 0; i < 3; i++) {
      final radius = r * (1.0 - i * 0.28);
      final sweep = math.pi * (0.9 + i * 0.25);
      canvas.drawArc(Rect.fromCircle(center: c, radius: radius), start, sweep,
          false, paint);
      start += sweep + 0.5;
    }
    // Center dot.
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(c, size.width * 0.05, paint);
  }

  @override
  bool shouldRepaint(covariant _PortalSwirlPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Loader badge: colored circle with the loader initial letter.
class LoaderBadge extends StatelessWidget {
  final String loader;
  final double size;
  const LoaderBadge({super.key, required this.loader, this.size = 36});

  (Color, String) get _style => switch (loader) {
        'fabric' => (const Color(0xFFDBB55A), 'F'),
        'quilt' => (const Color(0xFF9C5EEB), 'Q'),
        'forge' => (const Color(0xFF6B7A2E), 'Fr'),
        'neoforge' => (const Color(0xFFFF9B50), 'N'),
        _ => (const Color(0xFF5B8731), 'V'),
      };

  @override
  Widget build(BuildContext context) {
    final (color, letter) = _style;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.18),
        border: Border.all(color: color.withOpacity(0.55), width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: letter.length > 1 ? size * 0.32 : size * 0.42,
          height: 1.0,
        ),
      ),
    );
  }
}
