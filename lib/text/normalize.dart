/// Keys used to match a word in the text against glosses, transliterations and
/// saved vocabulary.
library;

/// Hebrew points and cantillation (nikkud, te'amim), but not letters.
bool isHebrewMark(int r) =>
    (r >= 0x0591 && r <= 0x05BD) ||
    r == 0x05BF ||
    r == 0x05C1 ||
    r == 0x05C2 ||
    r == 0x05C4 ||
    r == 0x05C5 ||
    r == 0x05C7;

/// Arabic harakat, Quranic annotation marks, superscript alef and tatweel.
bool isArabicMark(int r) =>
    (r >= 0x0610 && r <= 0x061A) ||
    (r >= 0x064B && r <= 0x065F) ||
    r == 0x0670 ||
    (r >= 0x06D6 && r <= 0x06DC) ||
    (r >= 0x06DF && r <= 0x06E8) ||
    (r >= 0x06EA && r <= 0x06ED) ||
    (r >= 0x08D3 && r <= 0x08FF) ||
    r == 0x0640;

bool isVowelMark(int r) => isHebrewMark(r) || isArabicMark(r);

bool _isInvisible(int r) =>
    r == 0x200B || r == 0x200E || r == 0x200F || r == 0xFEFF || r == 0x00AD;

/// Removes Hebrew nikkud and Arabic harakat. Other combining marks (Devanagari
/// vowel signs, for example) are part of the spelling and are kept.
String stripVowelMarks(String s) =>
    String.fromCharCodes(s.runes.where((r) => !isVowelMark(r)));

/// The identity of a word for vocabulary: case folded, without vowel points,
/// invisible characters or Greek final sigma. Two spellings that differ only
/// in nikkud or harakat are the same word, as they are for a reader.
String wordKey(String s) {
  final out = StringBuffer();
  for (final r in s.toLowerCase().runes) {
    if (isVowelMark(r) || _isInvisible(r)) continue;
    out.writeCharCode(r == 0x03C2 ? 0x03C3 : r); // ς → σ
  }
  return out.toString();
}

const _fold = {
  // Greek tonos and dialytika.
  'ά': 'α', 'έ': 'ε', 'ή': 'η', 'ί': 'ι', 'ό': 'ο', 'ύ': 'υ', 'ώ': 'ω', //
  'ϊ': 'ι', 'ϋ': 'υ', 'ΐ': 'ι', 'ΰ': 'υ',
  // Latin.
  'á': 'a', 'à': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a', 'ā': 'a',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', 'ī': 'i',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o', 'ō': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ū': 'u',
  'ñ': 'n', 'ç': 'c', 'ý': 'y', 'ÿ': 'y',
  // Cyrillic.
  'ё': 'е', 'й': 'и',
};

/// A looser key that also ignores accents. Only used as a last resort when
/// matching a gloss the author typed without accents.
String looseKey(String s) {
  final k = wordKey(s);
  final out = StringBuffer();
  for (final ch in k.split('')) {
    out.write(_fold[ch] ?? ch);
  }
  return out.toString();
}

/// Looks [word] up in a map whose keys the author typed by hand: exact
/// first, then case and vowel-mark insensitive, then accent insensitive.
String? lookupLoose(Map<String, String> map, String word) {
  if (map.isEmpty) return null;
  final exact = map[word];
  if (exact != null) return exact;
  final k = wordKey(word);
  final l = looseKey(word);
  String? loose;
  for (final e in map.entries) {
    if (wordKey(e.key) == k) return e.value;
    if (loose == null && looseKey(e.key) == l) loose = e.value;
  }
  return loose;
}
