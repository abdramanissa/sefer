import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Type helpers and [ThemeData] construction. See DESIGN.md §2.
class AppTheme {
  AppTheme._();

  static const String disp = 'Nunito';
  static const String sans = 'Nunito';
  static const String round = 'Nunito';

  /// Scripts Nunito doesn't cover fall back to these bundled faces, so Greek,
  /// Hebrew (with nikkud) and Arabic (with harakat) titles render everywhere.
  static const List<String> fallback = [
    'NotoSerif',
    'NotoSansHebrew',
    'NotoNaskhArabic',
  ];

  /// UI text: titles, labels, buttons, numbers.
  static TextStyle f(
    double size, {
    FontWeight weight = FontWeight.w700,
    Color? color,
    double height = 1.15,
    double? letterSpacing,
  }) => TextStyle(
    fontFamily: round,
    fontFamilyFallback: fallback,
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );

  /// Running text and small captions.
  static TextStyle s(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color? color,
    double height = 1.35,
    double? letterSpacing,
  }) => TextStyle(
    fontFamily: sans,
    fontFamilyFallback: fallback,
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );

  /// Display and tabular figures: chart axes, big numbers.
  static TextStyle d(
    double size, {
    FontWeight weight = FontWeight.w700,
    Color? color,
    double height = 1.0,
    double? letterSpacing,
  }) => TextStyle(
    fontFamily: disp,
    fontFamilyFallback: fallback,
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static ThemeData build(SeferColors c) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: c.brightness,
      fontFamily: sans,
      fontFamilyFallback: fallback,
    );
    return base.copyWith(
      scaffoldBackgroundColor: c.bg,
      canvasColor: c.bg,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      splashFactory: NoSplash.splashFactory,
      colorScheme: base.colorScheme.copyWith(
        brightness: c.brightness,
        primary: c.accent,
        onPrimary: c.onEmber,
        secondary: c.brass,
        surface: c.bgRaised,
        onSurface: c.text,
        error: const Color(0xFFE5563B),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.accent,
        selectionColor: c.accentSoft,
        selectionHandleColor: c.accent,
      ),
      textTheme: base.textTheme.apply(
        fontFamily: sans,
        bodyColor: c.text,
        displayColor: c.text,
      ),
      iconTheme: IconThemeData(color: c.textSecondary),
      sliderTheme: SliderThemeData(
        activeTrackColor: c.ember,
        inactiveTrackColor: c.bgRaised2,
        thumbColor: c.ember,
        overlayColor: Colors.transparent,
        trackHeight: 4,
      ),
      extensions: [c],
    );
  }
}

/// A face the reader can use. [family] must match pubspec.yaml.
class ReaderFont {
  const ReaderFont(this.id, this.label, this.family, this.note);
  final String id;
  final String label;
  final String family;
  final String note;
}

const readerFonts = <ReaderFont>[
  ReaderFont('nunito', 'Nunito', 'Nunito', 'Rounded, friendly'),
  ReaderFont('literata', 'Literata', 'Literata', 'Book serif, Greek and Cyrillic'),
  ReaderFont('notoserif', 'Noto Serif', 'NotoSerif', 'Wide script coverage'),
  ReaderFont('atkinson', 'Atkinson Hyperlegible', 'Atkinson', 'Easy letterforms'),
  ReaderFont('notohebrew', 'Noto Sans Hebrew', 'NotoSansHebrew', 'Hebrew with nikkud'),
  ReaderFont('frankruhl', 'Frank Ruhl Libre', 'FrankRuhl', 'Classic Hebrew serif'),
  ReaderFont('naskh', 'Noto Naskh Arabic', 'NotoNaskhArabic', 'Arabic, Persian, Urdu'),
  ReaderFont('amiri', 'Amiri', 'Amiri', 'Arabic with full harakat'),
];

ReaderFont readerFontById(String id) =>
    readerFonts.firstWhere((f) => f.id == id, orElse: () => readerFonts[1]);

/// Fallback chain for the reader. Whatever face is chosen, words in a script it
/// lacks still render in a bundled font that handles their marks.
const readerFallback = <String>[
  'NotoSerif',
  'NotoSansHebrew',
  'NotoNaskhArabic',
  'Nunito',
];
