/// Script detection and text direction.
library;

enum Script {
  latin,
  greek,
  cyrillic,
  hebrew,
  arabic,
  georgian,
  armenian,
  devanagari,
  thai,
  han,
  kana,
  hangul,
  other,
}

/// Languages written right to left (ISO 639-1 and a few 639-3 codes).
const rtlLanguages = {
  'ar', 'arc', 'ckb', 'dv', 'fa', 'he', 'iw', 'ku', 'ps', 'sd', 'syr', //
  'ug', 'ur', 'yi', 'ji', 'lad',
};

Script scriptOfRune(int r) {
  if (r < 0x0250) {
    final isLetter =
        (r >= 0x41 && r <= 0x5A) ||
        (r >= 0x61 && r <= 0x7A) ||
        (r >= 0xC0 && r != 0xD7 && r != 0xF7);
    return isLetter ? Script.latin : Script.other;
  }
  if (r >= 0x1E00 && r <= 0x1EFF) return Script.latin;
  if (r >= 0x0370 && r <= 0x03FF) return Script.greek;
  if (r >= 0x1F00 && r <= 0x1FFF) return Script.greek;
  if (r >= 0x0400 && r <= 0x052F) return Script.cyrillic;
  if (r >= 0x0530 && r <= 0x058F) return Script.armenian;
  if (r >= 0x0590 && r <= 0x05FF) return Script.hebrew;
  if (r >= 0xFB1D && r <= 0xFB4F) return Script.hebrew;
  if (r >= 0x0600 && r <= 0x08FF) return Script.arabic;
  if (r >= 0xFB50 && r <= 0xFEFF) return Script.arabic;
  if (r >= 0x0700 && r <= 0x074F) return Script.arabic;
  if (r >= 0x0900 && r <= 0x097F) return Script.devanagari;
  if (r >= 0x0E00 && r <= 0x0E7F) return Script.thai;
  if (r >= 0x10A0 && r <= 0x10FF) return Script.georgian;
  if (r >= 0x1C90 && r <= 0x1CBF) return Script.georgian;
  if (r >= 0x3040 && r <= 0x30FF) return Script.kana;
  if (r >= 0xAC00 && r <= 0xD7AF) return Script.hangul;
  if (r >= 0x1100 && r <= 0x11FF) return Script.hangul;
  if (r >= 0x4E00 && r <= 0x9FFF) return Script.han;
  if (r >= 0x3400 && r <= 0x4DBF) return Script.han;
  return Script.other;
}

/// The dominant script of [s], ignoring punctuation, digits and marks.
Script dominantScript(String s) {
  final counts = <Script, int>{};
  for (final r in s.runes) {
    final sc = scriptOfRune(r);
    if (sc == Script.other) continue;
    counts[sc] = (counts[sc] ?? 0) + 1;
  }
  if (counts.isEmpty) return Script.other;
  return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
}

bool isRtlScript(Script s) => s == Script.hebrew || s == Script.arabic;

String baseLanguage(String code) =>
    code.toLowerCase().split(RegExp('[-_]')).first;

/// Direction for a text: the language code decides when it is known,
/// otherwise the script of the sample text.
bool isRtl(String languageCode, [String sample = '']) {
  final lang = baseLanguage(languageCode);
  if (rtlLanguages.contains(lang)) return true;
  if (lang.isNotEmpty && lang != 'und' && lang != 'xx') return false;
  return isRtlScript(dominantScript(sample));
}

/// Scripts that are not Latin, where a transliteration line helps.
bool needsTransliteration(Script s) =>
    s != Script.latin && s != Script.other;

/// Scripts written without spaces between words.
bool isUnspacedScript(Script s) =>
    s == Script.han || s == Script.kana || s == Script.thai;
