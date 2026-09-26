import 'package:flutter/widgets.dart';

/// How the app is laid out, as opposed to how it's coloured: spacing, corner
/// radii, density, and how much secondary detail shows. Each feel places the
/// same blocks differently.
@immutable
class Feel {
  const Feel({
    required this.id,
    required this.label,
    required this.blurb,
    required this.gutter,
    required this.gap,
    required this.section,
    required this.cardPad,
    required this.radius,
    required this.rowHeight,
    required this.titleSize,
    required this.kickers,
    required this.meta,
    required this.decor,
    required this.libraryView,
  });

  final String id;
  final String label;
  final String blurb;

  /// Page side padding.
  final double gutter;

  /// Space between related blocks.
  final double gap;

  /// Space before a new section.
  final double section;
  final double cardPad;

  /// Multiplier for every corner radius (before the roundness setting).
  final double radius;

  /// Minimum height of list and settings rows.
  final double rowHeight;

  /// Tab title size.
  final double titleSize;

  /// Uppercase labels above titles and sections.
  final bool kickers;

  /// Secondary lines: subtitles, counts, stats under items.
  final bool meta;

  /// Decorative touches: background pattern, glows, badges on covers.
  final bool decor;

  /// Library layout this feel suggests when picked.
  final String libraryView;

  /// Radius scaled by the feel and the user's roundness setting.
  double r(double base) => base * radius * _roundness;

  /// Radius for fully rounded controls of height [h].
  double pill(double h) => _roundness >= 0.9 ? h / 2 : h / 2 * _roundness * 0.7;

  static double _roundness = 1;

  Feel withRoundness(double roundness) {
    _roundness = roundness;
    return this;
  }

  static const classic = Feel(
    id: 'classic',
    label: 'Classic',
    blurb: 'Covers, labels and stats. The full picture.',
    gutter: 20,
    gap: 14,
    section: 30,
    cardPad: 20,
    radius: 1,
    rowHeight: 52,
    titleSize: 28,
    kickers: true,
    meta: true,
    decor: true,
    libraryView: 'grid',
  );

  static const minimal = Feel(
    id: 'minimal',
    label: 'Minimal',
    blurb: 'Only what you act on. Quiet titles, no extras.',
    gutter: 24,
    gap: 16,
    section: 34,
    cardPad: 20,
    radius: 1,
    rowHeight: 54,
    titleSize: 24,
    kickers: false,
    meta: false,
    decor: false,
    libraryView: 'titles',
  );

  static const compact = Feel(
    id: 'compact',
    label: 'Compact',
    blurb: 'Dense lists and tight spacing. More on screen.',
    gutter: 14,
    gap: 8,
    section: 20,
    cardPad: 14,
    radius: 0.7,
    rowHeight: 44,
    titleSize: 22,
    kickers: true,
    meta: true,
    decor: false,
    libraryView: 'list',
  );

  static const airy = Feel(
    id: 'airy',
    label: 'Airy',
    blurb: 'Big covers, generous space, softer corners.',
    gutter: 26,
    gap: 20,
    section: 40,
    cardPad: 26,
    radius: 1.25,
    rowHeight: 60,
    titleSize: 32,
    kickers: true,
    meta: true,
    decor: true,
    libraryView: 'shelf',
  );

  static const all = [classic, minimal, compact, airy];

  static Feel byId(String id) => all.firstWhere((f) => f.id == id, orElse: () => classic);
}

class FeelScope extends InheritedWidget {
  const FeelScope({super.key, required this.feel, required this.roundness, required super.child});
  final Feel feel;
  final double roundness;

  @override
  bool updateShouldNotify(FeelScope old) => old.feel.id != feel.id || old.roundness != roundness;
}

extension FeelContext on BuildContext {
  Feel get feel {
    final s = dependOnInheritedWidgetOfExactType<FeelScope>();
    return (s?.feel ?? Feel.classic).withRoundness(s?.roundness ?? 1);
  }
}
