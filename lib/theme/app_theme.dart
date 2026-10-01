import 'package:flutter/material.dart';

import '../text/script.dart';

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

/// Writing systems the bundled reader faces are sorted by.
enum FontScript { latin, greek, cyrillic, hebrew, arabic, georgian, other }

/// The script a language is written in, or failing that, the script of
/// [sample].
FontScript fontScriptOf(String language, [String sample = '']) {
  final l = language.toLowerCase().split(RegExp('[-_]')).first;
  const cyrillic = {'ru', 'uk', 'bg', 'sr', 'mk', 'be', 'kk', 'ky', 'mn', 'tg', 'tt', 'ba', 'cv'};
  if (l == 'el' || l == 'grc') return FontScript.greek;
  if (cyrillic.contains(l)) return FontScript.cyrillic;
  if (l == 'he' || l == 'yi' || l == 'iw' || l == 'lad') return FontScript.hebrew;
  if (const {'ar', 'fa', 'ur', 'ps', 'ckb', 'sd', 'ug'}.contains(l)) return FontScript.arabic;
  if (l == 'ka') return FontScript.georgian;
  return switch (dominantScript(sample)) {
    Script.latin || Script.other => FontScript.latin,
    Script.greek => FontScript.greek,
    Script.cyrillic => FontScript.cyrillic,
    Script.hebrew => FontScript.hebrew,
    Script.arabic => FontScript.arabic,
    Script.georgian => FontScript.georgian,
    _ => FontScript.other,
  };
}

/// A face the reader can use. [family] must match pubspec.yaml, or be the
/// family a user font was registered under. [scripts] are the ones it
/// draws well; an empty set means any (imported fonts).
class ReaderFont {
  const ReaderFont(this.id, this.label, this.family, this.note, this.scripts, {this.easyRead = false});
  final String id;
  final String label;
  final String family;
  final String note;
  final Set<FontScript> scripts;

  /// Designed for dyslexic or beginning readers.
  final bool easyRead;

  bool supports(FontScript s) => scripts.isEmpty || scripts.contains(s);
}

const _l = FontScript.latin, _g = FontScript.greek, _c = FontScript.cyrillic;
const _h = FontScript.hebrew, _a = FontScript.arabic, _ge = FontScript.georgian;

const readerFonts = <ReaderFont>[
  // Latin, Greek and Cyrillic.
  ReaderFont('literata', 'Literata', 'Literata', 'Made for long reading on screens', {_l, _g, _c}),
  ReaderFont('garamond', 'EB Garamond', 'EBGaramond', 'Classic old-style book face', {_l, _g, _c}),
  ReaderFont('ptserif', 'PT Serif', 'PTSerif', 'Sturdy serif from the Cyrillic tradition', {_l, _c}),
  ReaderFont('gfsdidot', 'GFS Didot', 'GFSDidot', 'Elegant Greek book face', {_g}),
  ReaderFont('inter', 'Inter', 'Inter', 'Neutral, crisp sans', {_l, _g, _c}),
  ReaderFont('poppins', 'Poppins', 'Poppins', 'Geometric and round', {_l}),
  ReaderFont('nunito', 'Nunito', 'Nunito', 'Soft rounded sans', {_l, _c}),
  ReaderFont('atkinson', 'Atkinson Hyperlegible', 'Atkinson', 'Letters that can\'t be confused', {_l}, easyRead: true),
  ReaderFont('lexend', 'Lexend', 'Lexend', 'Wide spacing for reading fluency', {_l}, easyRead: true),
  ReaderFont('opendyslexic', 'OpenDyslexic', 'OpenDyslexic', 'Weighted bottoms keep letters grounded', {_l}, easyRead: true),
  ReaderFont('andika', 'Andika', 'Andika', 'Clear forms for beginning readers', {_l, _g, _c}, easyRead: true),
  // Hebrew.
  ReaderFont('frankruhl', 'Frank Ruhl Libre', 'FrankRuhl', 'Classic book serif', {_h}),
  ReaderFont('davidlibre', 'David Libre', 'DavidLibre', 'Traditional, calm and upright', {_h}),
  ReaderFont('heebo', 'Heebo', 'Heebo', 'Clean modern sans', {_h}),
  ReaderFont('rubik', 'Rubik', 'Rubik', 'Soft-cornered sans', {_h, _c}),
  ReaderFont('varela', 'Varela Round', 'VarelaRound', 'Round and friendly', {_h}),
  // Arabic script.
  ReaderFont('amiri', 'Amiri', 'Amiri', 'Classic Naskh, full harakat', {_a}),
  ReaderFont('markazi', 'Markazi Text', 'MarkaziText', 'Gentle Naskh for long reading', {_a}),
  ReaderFont('vazirmatn', 'Vazirmatn', 'Vazirmatn', 'Clean modern sans', {_a}),
  ReaderFont('reemkufi', 'Reem Kufi', 'ReemKufi', 'Geometric Kufi', {_a}),
  ReaderFont('balooarabic', 'Baloo Bhaijaan', 'BalooBhaijaan', 'Round and friendly', {_a}),
  // Georgian.
  ReaderFont('georgianserif', 'Noto Serif Georgian', 'NotoSerifGeorgian', 'Book serif', {_ge}),
  ReaderFont('georgiansans', 'Noto Sans Georgian', 'NotoSansGeorgian', 'Plain sans', {_ge}),
  // Any other script: the phone's own font.
  ReaderFont('system', 'System', 'NotoSerif', 'Your phone\'s font for this script', {FontScript.other}),
];

/// The face a script starts with.
const _scriptDefaults = {
  FontScript.latin: 'literata',
  FontScript.greek: 'literata',
  FontScript.cyrillic: 'literata',
  FontScript.hebrew: 'frankruhl',
  FontScript.arabic: 'amiri',
  FontScript.georgian: 'georgianserif',
  FontScript.other: 'system',
};

/// Fonts the user imported, registered at startup (see `data/fonts.dart`).
List<ReaderFont> userFonts = [];

List<ReaderFont> get allReaderFonts => [...readerFonts, ...userFonts];

ReaderFont? _byId(String? id) {
  if (id == null) return null;
  for (final f in allReaderFonts) {
    if (f.id == id) return f;
  }
  return null;
}

ReaderFont readerFontById(String id) => _byId(id) ?? readerFonts.first;

/// The faces worth offering for [script].
List<ReaderFont> fontsFor(FontScript script) => [for (final f in allReaderFonts) if (f.supports(script)) f];

/// The face for a text in [language]: the one chosen for that language,
/// else the older all-languages choice if it suits the script, else the
/// script's default.
ReaderFont readerFontFor(Map<String, String> byLanguage, String defaultId, String language, [String sample = '']) {
  final script = fontScriptOf(language, sample);
  final chosen = _byId(byLanguage[language.toLowerCase()]);
  if (chosen != null && chosen.supports(script)) return chosen;
  final legacy = _byId(defaultId);
  if (legacy != null && legacy.id != 'literata' && legacy.supports(script)) return legacy;
  return readerFontById(_scriptDefaults[script]!);
}

/// Fallback chain for the reader. Whatever face is chosen, words in a script it
/// lacks still render in a bundled font that handles their marks.
const readerFallback = <String>[
  'NotoSerif',
  'NotoSansHebrew',
  'NotoNaskhArabic',
  'NotoSansGeorgian',
  'Nunito',
];
