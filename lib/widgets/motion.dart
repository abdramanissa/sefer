import 'package:flutter/material.dart';

import 'ui_kit.dart';

/// Content that rises into place: fade, move up 22 px, scale from 0.97
/// (DESIGN.md §8.3). [index] staggers siblings; capped at 7.
class Rise extends StatefulWidget {
  const Rise({super.key, required this.child, this.index = 0, this.enabled = true});
  final Widget child;
  final int index;
  final bool enabled;

  @override
  State<Rise> createState() => _RiseState();
}

class _RiseState extends State<Rise> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 560),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!widget.enabled || Motion.reduced(context) || !RiseScope.shouldPlay(context)) {
      _c.value = 1;
      return;
    }
    Future.delayed(Duration(milliseconds: 40 + widget.index.clamp(0, 7) * 70), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    child: widget.child,
    builder: (context, child) {
      final t = Curves.easeOutCubic.transform(_c.value);
      if (t == 1) return child!;
      return Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 22 * (1 - t)),
          child: Transform.scale(scale: 0.97 + 0.03 * t, child: child),
        ),
      );
    },
  );
}

/// Plays [Rise] once per screen per app session, so entrances greet you but
/// don't repeat on every tab switch.
class RiseScope extends InheritedWidget {
  const RiseScope({super.key, required this.id, required super.child});
  final String id;

  static final Set<String> _played = {};

  static bool shouldPlay(BuildContext context) {
    final s = context.getInheritedWidgetOfExactType<RiseScope>();
    if (s == null) return true;
    return !_played.contains(s.id);
  }

  static void markPlayed(String id) => _played.add(id);

  @override
  bool updateShouldNotify(RiseScope oldWidget) => false;
}

/// Wraps [children] in staggered [Rise]s, skipping plain spacers.
List<Widget> riseAll(List<Widget> children) {
  var i = 0;
  return [
    for (final c in children)
      if (c is SizedBox && c.child == null) c else Rise(index: i++, child: c),
  ];
}

/// Text whose characters roll vertically when the value changes
/// (DESIGN.md §8.6). Digits get fixed-width cells so numbers don't jitter.
class RollingText extends StatefulWidget {
  const RollingText(this.text, {super.key, required this.style, this.semanticsLabel});
  final String text;
  final TextStyle style;
  final String? semanticsLabel;

  @override
  State<RollingText> createState() => _RollingTextState();
}

class _RollingTextState extends State<RollingText> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    value: 1,
  );
  String _from = '';
  bool _up = true;
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void didUpdateWidget(RollingText old) {
    super.didUpdateWidget(old);
    if (old.text == widget.text) return;
    final now = DateTime.now();
    final fast = now.difference(_last).inMilliseconds < 180;
    _last = now;
    if (fast || Motion.reduced(context)) {
      _c.value = 1;
      return;
    }
    _from = old.text;
    final a = num.tryParse(old.text.replaceAll(RegExp(r'[^0-9.\-]'), ''));
    final b = num.tryParse(widget.text.replaceAll(RegExp(r'[^0-9.\-]'), ''));
    _up = a == null || b == null || b >= a;
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _digitWidth(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    var w = 0.0;
    for (var d = 0; d < 10; d++) {
      final tp = TextPainter(
        text: TextSpan(text: '$d', style: widget.style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout();
      if (tp.width > w) w = tp.width;
    }
    return w;
  }

  @override
  Widget build(BuildContext context) {
    final dw = _digitWidth(context);
    final to = widget.text;
    final n = to.length > _from.length ? to.length : _from.length;
    final from = _from.padLeft(n);
    final target = to.padLeft(n);
    return Semantics(
      label: widget.semanticsLabel ?? to,
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = Curves.easeOutCubic.transform(_c.value);
          final cells = <Widget>[];
          for (var i = 0; i < target.length; i++) {
            final a = from[i];
            final b = target[i];
            final isDigit = RegExp(r'\d').hasMatch(b) || RegExp(r'\d').hasMatch(a);
            Widget glyph(String s) => Text(s, style: widget.style, textScaler: MediaQuery.textScalerOf(context));
            Widget cell;
            if (a == b || t == 1) {
              cell = glyph(b);
            } else {
              final dir = _up ? 1.0 : -1.0;
              cell = ClipRect(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    FractionalTranslation(translation: Offset(0, -dir * t), child: glyph(a)),
                    FractionalTranslation(translation: Offset(0, dir * (1 - t)), child: glyph(b)),
                  ],
                ),
              );
            }
            if (b == ' ' && t == 1) continue;
            cells.add(isDigit ? SizedBox(width: dw, child: Center(child: cell)) : cell);
          }
          return Row(mainAxisSize: MainAxisSize.min, children: cells);
        },
      ),
    );
  }
}

/// A number that counts up from zero the first time it appears.
class RollIn extends StatefulWidget {
  const RollIn({super.key, required this.value, required this.style, this.format});
  final num value;
  final TextStyle style;
  final String Function(num v)? format;

  @override
  State<RollIn> createState() => _RollInState();
}

class _RollInState extends State<RollIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1150),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.isAnimating || _c.value > 0) return;
    if (Motion.reduced(context) || widget.value == 0 || !RiseScope.shouldPlay(context)) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  String _fmt(num v) => widget.format?.call(v) ?? v.round().toString();

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, _) {
      if (_c.value == 1) {
        return RollingText(_fmt(widget.value), style: widget.style);
      }
      final t = Curves.easeOutCubic.transform(_c.value);
      return Semantics(
        label: _fmt(widget.value),
        excludeSemantics: true,
        child: Text(_fmt(widget.value * t), style: widget.style),
      );
    },
  );
}
