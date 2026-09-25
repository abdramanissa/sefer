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

/// Stock doodle ids, in picker order.
const doodles = [
  'book', 'cup', 'cat', 'leaf', 'moon', 'mountain', 'wave', 'sun', //
  'star', 'house', 'fish', 'flower', 'key', 'cloud', 'tree', 'bird',
];

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

/// Hand-drawn style line doodles on a 100 × 100 grid, round caps and joins.
class DoodlePainter extends CustomPainter {
  DoodlePainter(this.id, this.ink, this.paper, this.soft, {this.background = true});
  final String id;
  final Color ink;
  final Color paper;
  final Color soft;
  final bool background;

  @override
  void paint(Canvas canvas, Size size) {
    if (background) canvas.drawRect(Offset.zero & size, Paint()..color = paper);
    final s = min(size.width, size.height) * 0.62;
    canvas.save();
    canvas.translate((size.width - s) / 2, (size.height - s) / 2 - size.height * 0.04);
    canvas.scale(s / 100);
    final stroke = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = soft;
    canvas.drawCircle(const Offset(58, 58), 36, fill);
    for (final p in doodlePaths(id)) {
      canvas.drawPath(p, stroke);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(DoodlePainter old) =>
      old.id != id || old.ink != ink || old.paper != paper || old.soft != soft;
}

List<Path> doodlePaths(String id) {
  Path p() => Path();
  switch (id) {
    case 'cup':
      return [
        p()..moveTo(22, 40)..lineTo(28, 80)..quadraticBezierTo(29, 86, 36, 86)..lineTo(58, 86)..quadraticBezierTo(65, 86, 66, 80)..lineTo(72, 40)..close(),
        p()..moveTo(71, 48)..quadraticBezierTo(88, 48, 86, 60)..quadraticBezierTo(84, 70, 68, 70),
        p()..moveTo(38, 30)..quadraticBezierTo(33, 22, 38, 14),
        p()..moveTo(52, 30)..quadraticBezierTo(47, 22, 52, 14),
      ];
    case 'cat':
      return [
        p()..moveTo(24, 50)..lineTo(22, 22)..lineTo(40, 36)..quadraticBezierTo(50, 32, 60, 36)..lineTo(78, 22)..lineTo(76, 50)..quadraticBezierTo(76, 78, 50, 80)..quadraticBezierTo(24, 78, 24, 50)..close(),
        p()..addOval(Rect.fromCircle(center: const Offset(40, 52), radius: 2.5)),
        p()..addOval(Rect.fromCircle(center: const Offset(60, 52), radius: 2.5)),
        p()..moveTo(46, 62)..lineTo(50, 66)..lineTo(54, 62),
        p()..moveTo(30, 62)..lineTo(12, 60)..moveTo(30, 67)..lineTo(13, 70)..moveTo(70, 62)..lineTo(88, 60)..moveTo(70, 67)..lineTo(87, 70),
      ];
    case 'leaf':
      return [
        p()..moveTo(20, 82)..quadraticBezierTo(18, 24, 82, 18)..quadraticBezierTo(84, 80, 20, 82)..close(),
        p()..moveTo(20, 82)..quadraticBezierTo(44, 58, 70, 30),
        p()..moveTo(42, 60)..lineTo(40, 44)..moveTo(55, 46)..lineTo(54, 34)..moveTo(42, 60)..lineTo(58, 62)..moveTo(55, 46)..lineTo(68, 48),
      ];
    case 'moon':
      return [
        p()..moveTo(60, 14)..arcToPoint(const Offset(60, 86), radius: const Radius.circular(36), clockwise: false)..arcToPoint(const Offset(60, 14), radius: const Radius.circular(30)),
        p()..moveTo(76, 30)..lineTo(76, 38)..moveTo(72, 34)..lineTo(80, 34),
        p()..moveTo(84, 54)..lineTo(84, 60)..moveTo(81, 57)..lineTo(87, 57),
      ];
    case 'mountain':
      return [
        p()..moveTo(8, 80)..lineTo(38, 30)..lineTo(56, 58)..lineTo(66, 44)..lineTo(92, 80)..close(),
        p()..moveTo(30, 43)..lineTo(38, 48)..lineTo(46, 43),
        p()..addOval(Rect.fromCircle(center: const Offset(74, 22), radius: 7)),
      ];
    case 'wave':
      return [
        for (var i = 0; i < 3; i++)
          p()
            ..moveTo(10, 34.0 + i * 16)
            ..quadraticBezierTo(22, 24.0 + i * 16, 34, 34.0 + i * 16)
            ..quadraticBezierTo(46, 44.0 + i * 16, 58, 34.0 + i * 16)
            ..quadraticBezierTo(70, 24.0 + i * 16, 82, 34.0 + i * 16)
            ..quadraticBezierTo(88, 39.0 + i * 16, 92, 36.0 + i * 16),
      ];
    case 'sun':
      return [
        p()..addOval(Rect.fromCircle(center: const Offset(50, 50), radius: 17)),
        for (var i = 0; i < 8; i++)
          p()
            ..moveTo(50 + cos(i * pi / 4) * 27, 50 + sin(i * pi / 4) * 27)
            ..lineTo(50 + cos(i * pi / 4) * 38, 50 + sin(i * pi / 4) * 38),
      ];
    case 'star':
      final path = p();
      for (var i = 0; i < 10; i++) {
        final r = i.isEven ? 38.0 : 16.0;
        final a = -pi / 2 + i * pi / 5;
        final pt = Offset(50 + cos(a) * r, 52 + sin(a) * r);
        i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
      }
      return [path..close()];
    case 'house':
      return [
        p()..moveTo(14, 48)..lineTo(50, 18)..lineTo(86, 48),
        p()..moveTo(24, 40)..lineTo(24, 84)..lineTo(76, 84)..lineTo(76, 40),
        p()..moveTo(42, 84)..lineTo(42, 62)..lineTo(58, 62)..lineTo(58, 84),
        p()..moveTo(64, 30)..lineTo(64, 16)..lineTo(72, 16)..lineTo(72, 37),
      ];
    case 'fish':
      return [
        p()..moveTo(14, 50)..quadraticBezierTo(40, 20, 70, 50)..quadraticBezierTo(40, 80, 14, 50)..close(),
        p()..moveTo(70, 50)..lineTo(88, 36)..lineTo(88, 64)..close(),
        p()..addOval(Rect.fromCircle(center: const Offset(30, 47), radius: 2.5)),
        p()..moveTo(44, 38)..quadraticBezierTo(50, 50, 44, 62),
      ];
    case 'flower':
      return [
        for (var i = 0; i < 6; i++)
          p()..addOval(Rect.fromCenter(center: Offset(50 + cos(i * pi / 3) * 16, 40 + sin(i * pi / 3) * 16), width: 18, height: 18)),
        p()..addOval(Rect.fromCircle(center: const Offset(50, 40), radius: 6)),
        p()..moveTo(50, 62)..lineTo(50, 90),
        p()..moveTo(50, 78)..quadraticBezierTo(38, 68, 30, 72)..quadraticBezierTo(38, 82, 50, 78),
      ];
    case 'key':
      return [
        p()..addOval(Rect.fromCircle(center: const Offset(30, 50), radius: 16)),
        p()..addOval(Rect.fromCircle(center: const Offset(30, 50), radius: 5)),
        p()..moveTo(46, 50)..lineTo(88, 50)..moveTo(78, 50)..lineTo(78, 62)..moveTo(68, 50)..lineTo(68, 60),
      ];
    case 'cloud':
      return [
        p()
          ..moveTo(24, 70)
          ..quadraticBezierTo(8, 70, 10, 56)
          ..quadraticBezierTo(12, 44, 26, 46)
          ..quadraticBezierTo(28, 26, 48, 28)
          ..quadraticBezierTo(62, 28, 66, 42)
          ..quadraticBezierTo(90, 40, 90, 56)
          ..quadraticBezierTo(90, 70, 76, 70)
          ..close(),
        p()..moveTo(34, 80)..lineTo(30, 90)..moveTo(50, 80)..lineTo(46, 90)..moveTo(66, 80)..lineTo(62, 90),
      ];
    case 'tree':
      return [
        p()..addOval(Rect.fromCircle(center: const Offset(50, 38), radius: 26)),
        p()..moveTo(50, 64)..lineTo(50, 90)..moveTo(50, 76)..lineTo(40, 66)..moveTo(50, 72)..lineTo(60, 62),
        p()..moveTo(30, 90)..lineTo(70, 90),
      ];
    case 'bird':
      return [
        p()..moveTo(20, 60)..quadraticBezierTo(24, 36, 50, 38)..quadraticBezierTo(62, 38, 66, 30)..quadraticBezierTo(78, 26, 82, 36)..lineTo(92, 40)..lineTo(82, 44)..quadraticBezierTo(80, 74, 46, 72)..quadraticBezierTo(28, 72, 20, 60)..close(),
        p()..moveTo(34, 54)..quadraticBezierTo(50, 66, 62, 52),
        p()..addOval(Rect.fromCircle(center: const Offset(74, 36), radius: 2)),
        p()..moveTo(46, 72)..lineTo(44, 84)..moveTo(56, 72)..lineTo(56, 84),
      ];
    default: // book
      return [
        p()..moveTo(50, 28)..quadraticBezierTo(34, 20, 14, 24)..lineTo(14, 78)..quadraticBezierTo(34, 74, 50, 82)..close(),
        p()..moveTo(50, 28)..quadraticBezierTo(66, 20, 86, 24)..lineTo(86, 78)..quadraticBezierTo(66, 74, 50, 82),
        p()..moveTo(22, 38)..quadraticBezierTo(32, 36, 42, 40)..moveTo(22, 50)..quadraticBezierTo(32, 48, 42, 52)..moveTo(58, 40)..quadraticBezierTo(68, 36, 78, 38),
      ];
  }
}
