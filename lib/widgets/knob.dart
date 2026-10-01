import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'ui_kit.dart';

/// A round dial over a fixed set of stops. Drag up or down to turn it, tap
/// to step forward (it wraps around), and screen readers get increase and
/// decrease actions.
class Knob<T> extends StatefulWidget {
  const Knob({
    super.key,
    required this.stops,
    required this.value,
    required this.onChanged,
    required this.label,
    required this.display,
    this.unit,
    this.size = 76,
  });

  final List<T> stops;
  final T value;
  final ValueChanged<T> onChanged;
  final String label;
  final String Function(T v) display;
  final String Function(T v)? unit;
  final double size;

  @override
  State<Knob<T>> createState() => _KnobState<T>();
}

class _KnobState<T> extends State<Knob<T>> {
  double _drag = 0;

  int get _index => max(0, widget.stops.indexOf(widget.value));

  void _step(int by, {bool wrap = false}) {
    final n = widget.stops.length;
    var i = _index + by;
    if (wrap) {
      i %= n;
    } else {
      i = i.clamp(0, n - 1);
    }
    if (i == _index) return;
    Haptic.selection();
    widget.onChanged(widget.stops[i]);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    final v = widget.value;
    final n = widget.stops.length;
    return Semantics(
      label: widget.label,
      value: '${widget.display(v)} ${widget.unit?.call(v) ?? ''}'.trim(),
      increasedValue: _index < n - 1 ? widget.display(widget.stops[_index + 1]) : null,
      decreasedValue: _index > 0 ? widget.display(widget.stops[_index - 1]) : null,
      onIncrease: _index < n - 1 ? () => _step(1) : null,
      onDecrease: _index > 0 ? () => _step(-1) : null,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _step(1, wrap: true),
        onVerticalDragStart: (_) => _drag = 0,
        onVerticalDragUpdate: (d) {
          _drag -= d.delta.dy;
          while (_drag > 14) {
            _drag -= 14;
            _step(1);
          }
          while (_drag < -14) {
            _drag += 14;
            _step(-1);
          }
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: widget.size,
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: n <= 1 ? 1 : _index / (n - 1)),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                builder: (_, t, _) => CustomPaint(
                  painter: _KnobPainter(t: t, stops: n, track: c.bgRaised2, fill: c.accent, tick: c.textTertiary),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(widget.display(v), style: AppTheme.f(widget.size * 0.24, weight: FontWeight.w800, color: c.text, height: 1)),
                        if (widget.unit != null)
                          Text(widget.unit!(v), style: AppTheme.f(10, weight: FontWeight.w600, color: c.textTertiary)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(widget.label, style: AppTheme.f(11.5, weight: FontWeight.w700, color: c.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _KnobPainter extends CustomPainter {
  _KnobPainter({required this.t, required this.stops, required this.track, required this.fill, required this.tick});
  final double t;
  final int stops;
  final Color track;
  final Color fill;
  final Color tick;

  static const _start = pi * 0.75;
  static const _sweep = pi * 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final centre = size.center(Offset.zero);
    const stroke = 6.0;
    final arc = Rect.fromCircle(center: centre, radius: r - stroke / 2 - 4);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arc, _start, _sweep, false, p..color = track);
    if (t > 0) canvas.drawArc(arc, _start, _sweep * t, false, p..color = fill);
    // A dot per stop, just outside the arc.
    final dot = Paint()..color = tick.withValues(alpha: 0.6);
    for (var i = 0; i < stops; i++) {
      final a = _start + _sweep * (stops == 1 ? 0 : i / (stops - 1));
      canvas.drawCircle(centre + Offset(cos(a), sin(a)) * (r - 1.5), 1.4, dot);
    }
    // The pointer.
    final a = _start + _sweep * t;
    canvas.drawCircle(centre + Offset(cos(a), sin(a)) * (r - stroke / 2 - 4), 5, Paint()..color = fill);
  }

  @override
  bool shouldRepaint(_KnobPainter old) => old.t != t || old.fill != fill || old.track != track || old.stops != stops;
}
