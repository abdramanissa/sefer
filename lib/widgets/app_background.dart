import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The graph-paper backdrop behind every screen (DESIGN.md §3.6).
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.pattern});
  final String pattern; // none | dots | grid

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    if (pattern == 'none') return ColoredBox(color: c.bg);
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _PatternPainter(pattern, c.bg, c.border),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _PatternPainter extends CustomPainter {
  _PatternPainter(this.pattern, this.bg, this.ink);
  final String pattern;
  final Color bg;
  final Color ink;

  static const grid = 26.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = bg);
    if (pattern == 'grid') {
      final p = Paint()
        ..color = ink.withValues(alpha: 0.35)
        ..strokeWidth = 1;
      for (var x = grid; x < size.width; x += grid) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
      }
      for (var y = grid; y < size.height; y += grid) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
      }
    } else {
      final p = Paint()..color = ink.withValues(alpha: 0.5);
      for (var x = grid / 2; x < size.width; x += grid) {
        for (var y = grid / 2; y < size.height; y += grid) {
          canvas.drawCircle(Offset(x, y), 1.1, p);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_PatternPainter old) =>
      old.pattern != pattern || old.bg != bg || old.ink != ink;
}
