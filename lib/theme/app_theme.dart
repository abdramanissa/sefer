import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Type helpers and [ThemeData] construction. See DESIGN.md §2.
class AppTheme {
  AppTheme._();

  /// The interface face. Set from settings before the theme is built, so a
  /// change re-styles every screen on the next frame.
  static String uiFamily = 'Nunito';
  static String get disp => uiFamily;
  static String get sans => uiFamily;
  static String get round => uiFamily;

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

/// Interface faces you can pick in Appearance.
const uiFonts = <String, (String, String)>{
  'nunito': ('Nunito', 'Nunito'),
  'atkinson': ('Atkinson Hyperlegible', 'Atkinson'),
  'lexend': ('Lexend', 'Lexend'),
  'rubik': ('Rubik', 'Rubik'),
};

String uiFontFamily(String id) => (uiFonts[id] ?? uiFonts['nunito']!).$2;

/// Why a reader face is in the list. Used to group the picker.
enum FontGroup { general, dyslexia, hebrew, arabic, custom }

/// A face the reader can use. [family] must match pubspec.yaml, or be the
/// family a user font was registered under.
class ReaderFont {
  const ReaderFont(this.id, this.label, this.family, this.note, [this.group = FontGroup.general]);
  final String id;
  final String label;
  final String family;
  final String note;
  final FontGroup group;
}

const readerFonts = <ReaderFont>[
  ReaderFont('literata', 'Literata', 'Literata', 'Book serif, Greek and Cyrillic'),
  ReaderFont('notoserif', 'Noto Serif', 'NotoSerif', 'Wide script coverage'),
  ReaderFont('nunito', 'Nunito', 'Nunito', 'Rounded, friendly'),
  ReaderFont('rubik', 'Rubik', 'Rubik', 'Soft corners; Latin, Cyrillic, Hebrew, Arabic'),
  ReaderFont('atkinson', 'Atkinson Hyperlegible', 'Atkinson', 'Letters that can\'t be confused', FontGroup.dyslexia),
  ReaderFont('lexend', 'Lexend', 'Lexend', 'Wide spacing, made for reading fluency', FontGroup.dyslexia),
  ReaderFont('opendyslexic', 'OpenDyslexic', 'OpenDyslexic', 'Weighted bottoms keep letters grounded', FontGroup.dyslexia),
  ReaderFont('andika', 'Andika', 'Andika', 'Clear forms for beginning readers', FontGroup.dyslexia),
  ReaderFont('heebo', 'Heebo', 'Heebo', 'Clean sans, close to SF Hebrew', FontGroup.hebrew),
  ReaderFont('varela', 'Varela Round', 'VarelaRound', 'Rounded, close to SF Hebrew Rounded', FontGroup.hebrew),
  ReaderFont('notohebrew', 'Noto Sans Hebrew', 'NotoSansHebrew', 'Plain sans with nikkud', FontGroup.hebrew),
  ReaderFont('frankruhl', 'Frank Ruhl Libre', 'FrankRuhl', 'Classic book serif', FontGroup.hebrew),
  ReaderFont('vazirmatn', 'Vazirmatn', 'Vazirmatn', 'Clean sans, close to SF Arabic', FontGroup.arabic),
  ReaderFont('balooarabic', 'Baloo Bhaijaan', 'BalooBhaijaan', 'Rounded, close to SF Arabic Rounded', FontGroup.arabic),
  ReaderFont('notoarabic', 'Noto Sans Arabic', 'NotoSansArabic', 'Plain sans with harakat', FontGroup.arabic),
  ReaderFont('naskh', 'Noto Naskh Arabic', 'NotoNaskhArabic', 'Traditional Naskh', FontGroup.arabic),
  ReaderFont('amiri', 'Amiri', 'Amiri', 'Classic, full harakat', FontGroup.arabic),
];

/// Fonts the user imported, registered at startup (see `data/fonts.dart`).
List<ReaderFont> userFonts = [];

List<ReaderFont> get allReaderFonts => [...readerFonts, ...userFonts];

ReaderFont readerFontById(String id) =>
    allReaderFonts.firstWhere((f) => f.id == id, orElse: () => readerFonts.first);

/// The face for a text: the language's own choice if set, else the default.
ReaderFont readerFontFor(Map<String, String> byLanguage, String defaultId, String language) =>
    readerFontById(byLanguage[language.toLowerCase()] ?? defaultId);

/// Fallback chain for the reader. Whatever face is chosen, words in a script it
/// lacks still render in a bundled font that handles their marks.
const readerFallback = <String>[
  'NotoSerif',
  'NotoSansHebrew',
  'NotoNaskhArabic',
  'Nunito',
];
