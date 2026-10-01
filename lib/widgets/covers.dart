import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';

import '../data/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Cover hues: the folder pastels from DESIGN.md §3.5 plus copper and slate.
const coverHues = <Color>[
  Color(0xFFF3C7B1), // peach
  Color(0xFFA78BDA), // lavender
  Color(0xFFA8C99E), // sage
  Color(0xFF9CC2E8), // sky
  Color(0xFFE8CF98), // sand
  Color(0xFFE6A4B9), // rose
  Color(0xFFD9A184), // copper
  Color(0xFFA3ABB6), // slate
];

/// A cover hue adapted to the mode: a deep tone for the paper and a darker
/// one for the ink, so covers sit quietly on either background.
({Color paper, Color ink, Color soft}) coverTone(int hue, SeferColors c) {
  final h = coverHues[hue % coverHues.length];
  if (c.isDark) {
    return (
      paper: Color.lerp(h, Colors.black, 0.52)!,
      ink: Color.lerp(h, Colors.white, 0.1)!,
      soft: Color.lerp(h, Colors.black, 0.35)!,
    );
  }
  return (
    paper: Color.lerp(h, Colors.white, 0.35)!,
    ink: Color.lerp(h, Colors.black, 0.45)!,
    soft: Color.lerp(h, Colors.white, 0.1)!,
  );
}

/// Stock scenes, in picker order. Older libraries may name a retired
/// doodle; [sceneFor] maps it onto one of these.
const doodles = [
  'hills', 'peaks', 'sea', 'city', 'forest', 'dunes', //
  'lake', 'night', 'field', 'coast', 'rain', 'island',
];

/// The scene to draw for a stored doodle id.
String sceneFor(String id) {
  if (doodles.contains(id)) return id;
  const old = {
    'mountain': 'peaks', 'wave': 'sea', 'moon': 'night', 'star': 'night', 'sun': 'dunes', //
    'tree': 'forest', 'leaf': 'forest', 'cloud': 'rain', 'house': 'city', 'fish': 'island',
    'bird': 'coast', 'flower': 'field', 'cat': 'hills', 'cup': 'lake', 'key': 'city', 'book': 'hills',
  };
  return old[id] ?? doodles[id.hashCode.abs() % doodles.length];
}

class StoryCover extends StatelessWidget {
  const StoryCover({
    super.key,
    required this.cover,
    required this.title,
    this.imagePath,
    this.radius = 16,
    this.showTitle = true,
  });

  final Cover cover;
  final String title;

  /// Absolute path of the cover image, when [cover] is an image.
  final String? imagePath;
  final double radius;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    final tone = coverTone(cover.hue, c);
    Widget art;
    if (cover.kind == CoverKind.image && imagePath != null && File(imagePath!).existsSync()) {
      art = Image.file(
        File(imagePath!),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => _pattern(tone),
      );
    } else if (cover.kind == CoverKind.doodle) {
      art = CustomPaint(
        painter: DoodlePainter(cover.doodle, tone.ink, tone.paper, tone.soft),
        child: const SizedBox.expand(),
      );
    } else {
      art = _pattern(tone);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          art,
          if (showTitle && cover.kind == CoverKind.pattern)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Align(
                alignment: AlignmentDirectional.bottomStart,
                child: Text(
                  title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.f(15, weight: FontWeight.w800, color: tone.ink, height: 1.15),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _pattern(({Color paper, Color ink, Color soft}) tone) => CustomPaint(
    painter: PatternCoverPainter(cover.seed, tone.paper, tone.soft, tone.ink),
    child: const SizedBox.expand(),
  );
}

/// Generative covers: a few calm compositions chosen and varied by seed.
class PatternCoverPainter extends CustomPainter {
  PatternCoverPainter(this.seed, this.paper, this.soft, this.ink);
  final int seed;
  final Color paper;
  final Color soft;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Random(seed);
    canvas.drawRect(Offset.zero & size, Paint()..color = paper);
    final w = size.width;
    final h = size.height;
    final softPaint = Paint()..color = soft;
    final line = Paint()
      ..color = ink.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    switch (seed % 5) {
      case 0: // overlapping circles
        for (var i = 0; i < 3; i++) {
          canvas.drawCircle(
            Offset(w * (0.2 + r.nextDouble() * 0.8), h * (0.05 + r.nextDouble() * 0.5)),
            w * (0.25 + r.nextDouble() * 0.3),
            softPaint..color = soft.withValues(alpha: 0.55 + 0.15 * i),
          );
        }
      case 1: // horizon stripes
        final n = 4 + r.nextInt(4);
        for (var i = 0; i < n; i++) {
          final y = h * 0.08 + i * h * 0.55 / n;
          canvas.drawLine(Offset(w * 0.12, y), Offset(w * (0.5 + r.nextDouble() * 0.4), y), line);
        }
        canvas.drawCircle(Offset(w * 0.75, h * 0.25), w * 0.14, softPaint);
      case 2: // arches
        for (var i = 0; i < 4; i++) {
          final rect = Rect.fromCenter(center: Offset(w * 0.5, h * 0.62), width: w * (1.1 - i * 0.22), height: h * (0.9 - i * 0.18));
          canvas.drawArc(rect, pi, pi, false, line..strokeWidth = 1.2 + i * 0.3);
        }
      case 3: // dotted grid with one filled dot
        final cols = 5 + r.nextInt(3);
        final gap = w / (cols + 1);
        final pick = r.nextInt(cols * 3);
        for (var y = 0; y < 3; y++) {
          for (var x = 0; x < cols; x++) {
            final p = Offset(gap * (x + 1), h * 0.12 + y * gap);
            canvas.drawCircle(p, x + y * cols == pick ? gap * 0.32 : 2, x + y * cols == pick ? softPaint : (Paint()..color = ink.withValues(alpha: 0.3)));
          }
        }
      default: // waves
        for (var i = 0; i < 5; i++) {
          final path = Path();
          final y0 = h * (0.1 + i * 0.1);
          final amp = h * (0.02 + r.nextDouble() * 0.03);
          path.moveTo(0, y0);
          for (var x = 0.0; x <= w; x += 4) {
            path.lineTo(x, y0 + sin(x / w * pi * 2 * (1.5 + i * 0.2) + seed) * amp);
          }
          canvas.drawPath(path, line);
        }
    }
  }

  @override
  bool shouldRepaint(PatternCoverPainter old) =>
      old.seed != seed || old.paper != paper || old.ink != ink || old.soft != soft;
}

/// Flat, layered landscapes that fill the cover, drawn in the cover's own
/// tones: [paper] for the sky, [soft] and [ink] for the land.
class DoodlePainter extends CustomPainter {
  DoodlePainter(this.id, this.ink, this.paper, this.soft);
  final String id;
  final Color ink;
  final Color paper;
  final Color soft;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, Paint()..color = paper);
    Paint fill(double t, [double a = 1]) => Paint()..color = Color.lerp(soft, ink, t)!.withValues(alpha: a);
    Paint line(double t, double width) => Paint()
      ..color = Color.lerp(soft, ink, t)!
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    Offset o(double x, double y) => Offset(x * w, y * h);
    Path poly(List<(double, double)> pts) {
      final p = Path()..moveTo(pts.first.$1 * w, pts.first.$2 * h);
      for (final (x, y) in pts.skip(1)) {
        p.lineTo(x * w, y * h);
      }
      return p..close();
    }

    Path wave(double y, double amp, double freq, double phase) {
      final p = Path()..moveTo(0, h);
      for (var x = 0.0; x <= w; x += w / 40) {
        p.lineTo(x, (y + sin(x / w * pi * freq + phase) * amp) * h);
      }
      return p
        ..lineTo(w, h)
        ..close();
    }

    switch (sceneFor(id)) {
      case 'hills':
        canvas.drawCircle(o(0.72, 0.3), w * 0.13, fill(0.15));
        canvas.drawPath(wave(0.62, 0.05, 1.6, 0.4), fill(0.25));
        canvas.drawPath(wave(0.72, 0.04, 2.2, 2.0), fill(0.5));
        canvas.drawPath(wave(0.84, 0.03, 1.4, 4.0), fill(0.8));
      case 'peaks':
        canvas.drawCircle(o(0.25, 0.22), w * 0.08, fill(0.1));
        canvas.drawPath(poly([(0, 0.78), (0.3, 0.38), (0.5, 0.62), (0.72, 0.3), (1, 0.7), (1, 1), (0, 1)]), fill(0.45));
        canvas.drawPath(poly([(0.24, 0.48), (0.3, 0.38), (0.36, 0.48), (0.33, 0.46), (0.3, 0.5), (0.27, 0.46)]), Paint()..color = paper);
        canvas.drawPath(poly([(0.63, 0.43), (0.72, 0.3), (0.8, 0.41), (0.75, 0.39), (0.72, 0.44), (0.68, 0.4)]), Paint()..color = paper);
        canvas.drawPath(wave(0.82, 0.02, 2.0, 1.0), fill(0.8));
      case 'sea':
        canvas.drawCircle(o(0.5, 0.56), w * 0.2, fill(0.15));
        canvas.drawRect(Rect.fromLTRB(0, h * 0.58, w, h), fill(0.55));
        for (var i = 0; i < 5; i++) {
          final y = 0.64 + i * 0.07;
          canvas.drawLine(o(0.18 + (i % 2) * 0.1, y), o(0.82 - (i % 3) * 0.08, y), line(0.15, 2));
        }
      case 'city':
        canvas.drawCircle(o(0.78, 0.2), w * 0.07, fill(0.1));
        final r = Random(7);
        var x = 0.0;
        while (x < 1) {
          final bw = 0.1 + r.nextDouble() * 0.12;
          final top = 0.42 + r.nextDouble() * 0.3;
          canvas.drawRect(Rect.fromLTRB(x * w, top * h, (x + bw) * w, h), fill(0.35 + r.nextDouble() * 0.45));
          for (var wy = top + 0.04; wy < 0.92; wy += 0.06) {
            for (var wx = x + 0.025; wx < x + bw - 0.03; wx += 0.045) {
              if (r.nextDouble() < 0.45) canvas.drawRect(Rect.fromLTWH(wx * w, wy * h, w * 0.018, h * 0.022), Paint()..color = paper.withValues(alpha: 0.7));
            }
          }
          x += bw + 0.01;
        }
      case 'forest':
        canvas.drawPath(wave(0.7, 0.03, 1.2, 0.0), fill(0.3));
        final r = Random(3);
        for (var i = 0; i < 9; i++) {
          final cx = 0.06 + i * 0.11 + r.nextDouble() * 0.03;
          final base = 0.78 + r.nextDouble() * 0.12;
          final th = 0.22 + r.nextDouble() * 0.14;
          canvas.drawPath(poly([(cx - 0.07, base), (cx, base - th), (cx + 0.07, base)]), fill(0.55 + r.nextDouble() * 0.4));
        }
        canvas.drawRect(Rect.fromLTRB(0, h * 0.9, w, h), fill(0.85));
      case 'dunes':
        canvas.drawCircle(o(0.3, 0.3), w * 0.16, fill(0.1));
        canvas.drawPath(Path()..moveTo(0, h * 0.7)..quadraticBezierTo(w * 0.4, h * 0.52, w, h * 0.68)..lineTo(w, h)..lineTo(0, h)..close(), fill(0.3));
        canvas.drawPath(Path()..moveTo(0, h * 0.86)..quadraticBezierTo(w * 0.6, h * 0.66, w, h * 0.82)..lineTo(w, h)..lineTo(0, h)..close(), fill(0.6));
      case 'lake':
        canvas.drawPath(poly([(0, 0.56), (0.28, 0.32), (0.5, 0.5), (0.7, 0.36), (1, 0.56)]), fill(0.45));
        canvas.drawRect(Rect.fromLTRB(0, h * 0.56, w, h), fill(0.15));
        canvas.drawPath(poly([(0, 0.56), (0.28, 0.8), (0.5, 0.62), (0.7, 0.76), (1, 0.56)]), fill(0.3, 0.6));
        canvas.drawLine(o(0.2, 0.86), o(0.5, 0.86), line(0.35, 2));
        canvas.drawLine(o(0.55, 0.92), o(0.8, 0.92), line(0.35, 2));
      case 'night':
        final r = Random(11);
        for (var i = 0; i < 22; i++) {
          canvas.drawCircle(o(r.nextDouble(), r.nextDouble() * 0.55), 0.6 + r.nextDouble() * 1.4, fill(0.6));
        }
        canvas.drawCircle(o(0.7, 0.24), w * 0.11, fill(0.25));
        canvas.drawCircle(o(0.75, 0.21), w * 0.1, Paint()..color = paper);
        canvas.drawPath(wave(0.74, 0.04, 1.8, 1.2), fill(0.7));
      case 'field':
        canvas.drawCircle(o(0.2, 0.25), w * 0.09, fill(0.12));
        canvas.drawRect(Rect.fromLTRB(0, h * 0.55, w, h), fill(0.35));
        for (var i = -4; i <= 4; i++) {
          canvas.drawLine(o(0.5 + i * 0.03, 0.55), o(0.5 + i * 0.3, 1.0), line(0.65, 1.6));
        }
        canvas.drawLine(o(0.78, 0.55), o(0.78, 0.42), line(0.85, 3));
        canvas.drawCircle(o(0.78, 0.38), w * 0.08, fill(0.75));
      case 'coast':
        canvas.drawRect(Rect.fromLTRB(0, h * 0.66, w, h), fill(0.4));
        canvas.drawPath(poly([(0.42, 1), (0.52, 0.52), (0.72, 0.48), (1, 0.5), (1, 1)]), fill(0.75));
        canvas.drawRect(Rect.fromLTRB(w * 0.76, h * 0.3, w * 0.84, h * 0.49), fill(0.2));
        canvas.drawPath(poly([(0.75, 0.3), (0.8, 0.24), (0.85, 0.3)]), fill(0.9));
        canvas.drawPath(poly([(0.84, 0.27), (1, 0.2), (1, 0.33)]), Paint()..color = soft.withValues(alpha: 0.5));
        canvas.drawLine(o(0.08, 0.76), o(0.3, 0.76), line(0.15, 2));
      case 'rain':
        for (final (x, y, r0) in [(0.3, 0.26, 0.14), (0.5, 0.2, 0.17), (0.7, 0.27, 0.13)]) {
          canvas.drawCircle(o(x, y), w * r0, fill(0.35));
        }
        canvas.drawRect(Rect.fromLTRB(w * 0.18, h * 0.26, w * 0.82, h * 0.36), fill(0.35));
        for (var i = 0; i < 9; i++) {
          final x = 0.2 + i * 0.075;
          canvas.drawLine(o(x, 0.44 + (i % 3) * 0.04), o(x - 0.03, 0.56 + (i % 3) * 0.04), line(0.55, 1.8));
        }
        canvas.drawPath(wave(0.84, 0.015, 3, 0.5), fill(0.7));
      default: // island
        canvas.drawCircle(o(0.24, 0.24), w * 0.1, fill(0.12));
        canvas.drawRect(Rect.fromLTRB(0, h * 0.7, w, h), fill(0.45));
        canvas.drawOval(Rect.fromCenter(center: o(0.58, 0.71), width: w * 0.6, height: h * 0.1), fill(0.7));
        final trunk = Path()..moveTo(w * 0.6, h * 0.69)..quadraticBezierTo(w * 0.62, h * 0.55, w * 0.68, h * 0.45);
        canvas.drawPath(trunk, line(0.85, 3.5));
        for (final a in [-2.6, -1.9, -1.2, -0.5, 0.2]) {
          final end = o(0.68, 0.45) + Offset(cos(a), sin(a) * 0.6 + 0.25) * w * 0.17;
          canvas.drawPath(Path()..moveTo(w * 0.68, h * 0.45)..quadraticBezierTo((w * 0.68 + end.dx) / 2, h * 0.4, end.dx, end.dy), line(0.8, 3));
        }
        canvas.drawLine(o(0.1, 0.84), o(0.3, 0.84), line(0.2, 2));
    }
  }

  @override
  bool shouldRepaint(DoodlePainter old) =>
      old.id != id || old.ink != ink || old.paper != paper || old.soft != soft;
}
