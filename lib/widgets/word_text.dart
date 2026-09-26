// Named parameters can't be private, so the render object's constructor
// assigns its fields explicitly.
// ignore_for_file: prefer_initializing_formals

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// How one word is decorated.
@immutable
class WordMark {
  const WordMark({this.fill, this.underline, this.selected = false, this.reading});

  /// Rounded highlight behind the word.
  final Color? fill;

  /// A line under the word, for the "underline" highlight style.
  final Color? underline;

  /// Outlined, while its card is open.
  final bool selected;

  /// Transliteration drawn above the word.
  final String? reading;

  bool get isPlain => fill == null && underline == null && !selected && (reading == null || reading!.isEmpty);

  @override
  bool operator ==(Object other) =>
      other is WordMark &&
      other.fill == fill &&
      other.underline == underline &&
      other.selected == selected &&
      other.reading == reading;

  @override
  int get hashCode => Object.hash(fill, underline, selected, reading);
}

typedef WordCallback = void Function(int word, Rect globalRect);

/// A paragraph of tappable words drawn by a single render object: one text
/// layout, highlights painted as rounded rectangles behind the glyphs, and
/// taps resolved by position. Far cheaper than a widget per word, which is
/// what keeps long texts smooth to scroll.
class WordText extends LeafRenderObjectWidget {
  const WordText({
    super.key,
    required this.text,
    required this.words,
    required this.marks,
    required this.textDirection,
    this.textAlign = TextAlign.start,
    this.readingStyle,
    this.selectedColor = const Color(0xFFFFFFFF),
    this.onTap,
    this.onLongPress,
  });

  final TextSpan text;

  /// Character ranges of the words in [text], in order.
  final List<TextRange> words;

  /// Decoration per word index. Words without an entry are plain.
  final Map<int, WordMark> marks;
  final TextDirection textDirection;
  final TextAlign textAlign;
  final TextStyle? readingStyle;
  final Color selectedColor;
  final WordCallback? onTap;
  final WordCallback? onLongPress;

  @override
  RenderWordText createRenderObject(BuildContext context) => RenderWordText(
    text: text,
    words: words,
    marks: marks,
    textDirection: textDirection,
    textAlign: textAlign,
    textScaler: MediaQuery.textScalerOf(context),
    readingStyle: readingStyle,
    selectedColor: selectedColor,
  )
    ..onTap = onTap
    ..onLongPress = onLongPress;

  @override
  void updateRenderObject(BuildContext context, RenderWordText renderObject) {
    renderObject
      ..text = text
      ..words = words
      ..marks = marks
      ..textDirection = textDirection
      ..textAlign = textAlign
      ..textScaler = MediaQuery.textScalerOf(context)
      ..readingStyle = readingStyle
      ..selectedColor = selectedColor
      ..onTap = onTap
      ..onLongPress = onLongPress;
  }
}

class RenderWordText extends RenderBox {
  RenderWordText({
    required TextSpan text,
    required List<TextRange> words,
    required Map<int, WordMark> marks,
    required TextDirection textDirection,
    required TextAlign textAlign,
    required TextScaler textScaler,
    TextStyle? readingStyle,
    required Color selectedColor,
  }) : _words = words,
       _marks = marks,
       _readingStyle = readingStyle,
       _selectedColor = selectedColor,
       _painter = TextPainter(
         text: text,
         textDirection: textDirection,
         textAlign: textAlign,
         textScaler: textScaler,
       ) {
    _tap = TapGestureRecognizer(debugOwner: this)..onTapUp = _handleTapUp;
    _long = LongPressGestureRecognizer(debugOwner: this)..onLongPressStart = _handleLongPress;
  }

  final TextPainter _painter;
  late final TapGestureRecognizer _tap;
  late final LongPressGestureRecognizer _long;
  WordCallback? onTap;
  WordCallback? onLongPress;

  List<TextRange> _words;
  set words(List<TextRange> v) {
    if (identical(v, _words)) return;
    _words = v;
    _boxes = null;
    markNeedsPaint();
  }

  Map<int, WordMark> _marks;
  set marks(Map<int, WordMark> v) {
    if (_sameMarks(v, _marks)) return;
    final readingsChanged = !_sameReadings(v, _marks);
    _marks = v;
    if (readingsChanged) _readingPainters.clear();
    markNeedsPaint();
  }

  TextStyle? _readingStyle;
  set readingStyle(TextStyle? v) {
    if (v == _readingStyle) return;
    _readingStyle = v;
    _readingPainters.clear();
    markNeedsPaint();
  }

  Color _selectedColor;
  set selectedColor(Color v) {
    if (v == _selectedColor) return;
    _selectedColor = v;
    markNeedsPaint();
  }

  set text(TextSpan v) {
    final cmp = _painter.text?.compareTo(v) ?? RenderComparison.layout;
    if (cmp == RenderComparison.identical) return;
    _painter.text = v;
    _boxes = null;
    _readingPainters.clear();
    if (cmp == RenderComparison.paint) {
      markNeedsPaint();
    } else {
      markNeedsLayout();
    }
    markNeedsSemanticsUpdate();
  }

  set textDirection(TextDirection v) {
    if (_painter.textDirection == v) return;
    _painter.textDirection = v;
    markNeedsLayout();
  }

  set textAlign(TextAlign v) {
    if (_painter.textAlign == v) return;
    _painter.textAlign = v;
    markNeedsLayout();
  }

  set textScaler(TextScaler v) {
    if (_painter.textScaler == v) return;
    _painter.textScaler = v;
    markNeedsLayout();
  }

  static bool _sameMarks(Map<int, WordMark> a, Map<int, WordMark> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }

  static bool _sameReadings(Map<int, WordMark> a, Map<int, WordMark> b) {
    for (final e in a.entries) {
      if (b[e.key]?.reading != e.value.reading) return false;
    }
    for (final e in b.entries) {
      if (a[e.key]?.reading != e.value.reading) return false;
    }
    return true;
  }

  /// Glyph boxes per word, computed once per layout and only for words that
  /// need them (decorated ones, or one being hit-tested).
  Map<int, List<TextBox>>? _boxes;
  final Map<int, TextPainter> _readingPainters = {};

  List<TextBox> _boxesFor(int i) {
    final cache = _boxes ??= {};
    return cache.putIfAbsent(i, () {
      final r = _words[i];
      return _painter.getBoxesForSelection(
        TextSelection(baseOffset: r.start, extentOffset: r.end),
        boxHeightStyle: ui.BoxHeightStyle.tight,
      );
    });
  }

  @override
  void performLayout() {
    _painter.layout(minWidth: 0, maxWidth: constraints.maxWidth);
    _boxes = null;
    size = constraints.constrain(Size(constraints.maxWidth, _painter.height));
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    _painter.layout(maxWidth: width);
    return _painter.height;
  }

  @override
  double computeMaxIntrinsicHeight(double width) => computeMinIntrinsicHeight(width);

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    if (event is PointerDownEvent) {
      if (onTap != null) _tap.addPointer(event);
      if (onLongPress != null) _long.addPointer(event);
    }
  }

  /// The word under [local], allowing a little slack around its glyphs.
  int? wordAt(Offset local) {
    if (_words.isEmpty) return null;
    final pos = _painter.getPositionForOffset(local).offset;
    // Binary search for the word containing pos (or ending at it).
    var lo = 0, hi = _words.length - 1;
    int? found;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      final r = _words[mid];
      if (pos < r.start) {
        hi = mid - 1;
      } else if (pos > r.end) {
        lo = mid + 1;
      } else {
        found = mid;
        break;
      }
    }
    if (found == null) return null;
    for (final b in _boxesFor(found)) {
      if (b.toRect().inflate(8).contains(local)) return found;
    }
    return null;
  }

  /// The word's bounds in global coordinates.
  Rect globalRectOf(int i) => _globalRect(i);

  /// The plain text being shown.
  String get plainText => _painter.text?.toPlainText() ?? '';

  Rect _globalRect(int i) {
    final boxes = _boxesFor(i);
    if (boxes.isEmpty) return Rect.zero;
    var r = boxes.first.toRect();
    for (final b in boxes.skip(1)) {
      r = r.expandToInclude(b.toRect());
    }
    return MatrixUtils.transformRect(getTransformTo(null), r);
  }

  void _handleTapUp(TapUpDetails d) {
    final i = wordAt(d.localPosition);
    if (i != null) onTap?.call(i, _globalRect(i));
  }

  void _handleLongPress(LongPressStartDetails d) {
    final i = wordAt(d.localPosition);
    if (i != null) onLongPress?.call(i, _globalRect(i));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    final fill = Paint();
    final radius = Radius.circular(math.max(4, _painter.preferredLineHeight * 0.18));
    for (final e in _marks.entries) {
      if (e.key >= _words.length) continue;
      final m = e.value;
      if (m.fill == null && m.underline == null && !m.selected) continue;
      for (final b in _boxesFor(e.key)) {
        final rect = b.toRect().shift(offset).inflate(2.5);
        if (m.fill != null) {
          canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), fill..color = m.fill!);
        }
        if (m.underline != null) {
          final y = rect.bottom - 1;
          canvas.drawLine(
            Offset(rect.left + 2, y),
            Offset(rect.right - 2, y),
            Paint()
              ..color = m.underline!
              ..strokeWidth = 2
              ..strokeCap = StrokeCap.round,
          );
        }
        if (m.selected) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, radius),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5
              ..color = _selectedColor,
          );
        }
      }
    }
    _painter.paint(canvas, offset);
    // Readings above their words, shrunk when wider than the word.
    final rs = _readingStyle;
    if (rs == null) return;
    for (final e in _marks.entries) {
      final reading = e.value.reading;
      if (reading == null || reading.isEmpty || e.key >= _words.length) continue;
      final boxes = _boxesFor(e.key);
      if (boxes.isEmpty) continue;
      final box = boxes.first.toRect();
      final tp = _readingPainters.putIfAbsent(e.key, () {
        final p = TextPainter(
          text: TextSpan(text: reading, style: rs),
          textDirection: TextDirection.ltr,
          textScaler: _painter.textScaler,
          maxLines: 1,
        )..layout();
        final room = box.width + 10;
        if (p.width > room && p.width > 0) {
          final shrink = math.max(0.6, room / p.width);
          p.text = TextSpan(text: reading, style: rs.copyWith(fontSize: (rs.fontSize ?? 10) * shrink));
          p.layout();
        }
        return p;
      });
      tp.paint(canvas, offset + Offset(box.center.dx - tp.width / 2, box.top - tp.height - 1));
    }
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config
      ..isSemanticBoundary = true
      ..label = _painter.text?.toPlainText() ?? ''
      ..textDirection = _painter.textDirection;
  }

  @override
  void dispose() {
    _tap.dispose();
    _long.dispose();
    _painter.dispose();
    for (final p in _readingPainters.values) {
      p.dispose();
    }
    super.dispose();
  }
}
