/// Rule-based transliteration to Latin letters, used when a text does not
/// provide its own. It aims to help a learner sound a word out, not to follow
/// one academic standard exactly.
library;

import 'normalize.dart';
import 'script.dart';

String transliterate(String word, {String language = ''}) {
  if (word.isEmpty) return '';
  final lang = baseLanguage(language);
  final out = switch (dominantScript(word)) {
    Script.greek => _greek(word),
    Script.cyrillic => _cyrillic(word, lang),
    Script.hebrew => _hebrew(word),
    Script.arabic => _arabic(word, lang),
    Script.georgian => _table(word, _georgian),
    Script.armenian => _armenian(word),
    _ => '',
  };
  return out;
}

/// Whether [transliterate] has rules for the script of [word].
bool canTransliterate(String word) => switch (dominantScript(word)) {
  Script.greek ||
  Script.cyrillic ||
  Script.hebrew ||
  Script.arabic ||
  Script.georgian ||
  Script.armenian => true,
  _ => false,
};

String _table(String s, Map<String, String> t) =>
    s.split('').map((c) => t[c] ?? t[c.toLowerCase()] ?? c).join();

String _matchCase(String src, String out) {
  if (out.isEmpty || src.isEmpty) return out;
  if (src.toUpperCase() == src && src.toLowerCase() != src && src.length > 1) {
    return out.toUpperCase();
  }
  if (src[0].toUpperCase() == src[0] && src[0].toLowerCase() != src[0]) {
    return out[0].toUpperCase() + out.substring(1);
  }
  return out;
}

// ---------------------------------------------------------------- Greek

const _greekSingle = {
  'α': 'a', 'ά': 'á', 'β': 'v', 'γ': 'g', 'δ': 'd', 'ε': 'e', 'έ': 'é', //
  'ζ': 'z', 'η': 'i', 'ή': 'í', 'θ': 'th', 'ι': 'i', 'ί': 'í', 'ϊ': 'ï',
  'ΐ': 'ḯ', 'κ': 'k', 'λ': 'l', 'μ': 'm', 'ν': 'n', 'ξ': 'x', 'ο': 'o',
  'ό': 'ó', 'π': 'p', 'ρ': 'r', 'σ': 's', 'ς': 's', 'τ': 't', 'υ': 'y',
  'ύ': 'ý', 'ϋ': 'ÿ', 'ΰ': 'ÿ', 'φ': 'f', 'χ': 'ch', 'ψ': 'ps', 'ω': 'o',
  'ώ': 'ó',
};

const _greekPairs = {
  'ου': 'ou', 'ού': 'oú', 'αυ': 'av', 'αύ': 'áv', 'ευ': 'ev', 'εύ': 'év', //
  'ηυ': 'iv', 'γγ': 'ng', 'γκ': 'gk', 'γξ': 'nx', 'γχ': 'nch', 'μπ': 'mp',
  'ντ': 'nt', 'τσ': 'ts', 'τζ': 'tz',
};

String _greek(String word) {
  final s = word.toLowerCase();
  final out = StringBuffer();
  var i = 0;
  while (i < s.length) {
    if (i + 1 < s.length) {
      final pair = s.substring(i, i + 2);
      final p = _greekPairs[pair];
      if (p != null) {
        // Word-initial μπ and ντ sound like b and d.
        if (i == 0 && pair == 'μπ') {
          out.write('b');
        } else if (i == 0 && pair == 'ντ') {
          out.write('d');
        } else if (i == 0 && pair == 'γκ') {
          out.write('g');
        } else {
          out.write(p);
        }
        i += 2;
        continue;
      }
    }
    out.write(_greekSingle[s[i]] ?? s[i]);
    i++;
  }
  return _matchCase(word, out.toString());
}

// ---------------------------------------------------------------- Cyrillic

const _cyrBase = {
  'а': 'a', 'б': 'b', 'в': 'v', 'г': 'g', 'д': 'd', 'е': 'e', 'ё': 'yo', //
  'ж': 'zh', 'з': 'z', 'и': 'i', 'й': 'y', 'к': 'k', 'л': 'l', 'м': 'm',
  'н': 'n', 'о': 'o', 'п': 'p', 'р': 'r', 'с': 's', 'т': 't', 'у': 'u',
  'ф': 'f', 'х': 'kh', 'ц': 'ts', 'ч': 'ch', 'ш': 'sh', 'щ': 'shch',
  'ъ': 'ʺ', 'ы': 'y', 'ь': 'ʹ', 'э': 'e', 'ю': 'yu', 'я': 'ya',
  // Other Cyrillic alphabets.
  'і': 'i', 'ї': 'yi', 'є': 'ye', 'ґ': 'g', 'ў': 'ŭ', 'ђ': 'đ', 'ј': 'j',
  'љ': 'lj', 'њ': 'nj', 'ћ': 'ć', 'џ': 'dž', 'ѓ': 'gj', 'ќ': 'kj', 'ѕ': 'dz',
  'ә': 'ä', 'ғ': 'gh', 'қ': 'q', 'ң': 'ng', 'ө': 'ö', 'ұ': 'u', 'ү': 'ü',
  'һ': 'h',
};

const _cyrByLang = {
  'uk': {'и': 'y', 'г': 'h', 'х': 'kh', 'щ': 'shch', 'й': 'i'},
  'bg': {'щ': 'sht', 'ъ': 'a', 'ю': 'yu', 'я': 'ya'},
  'sr': {'х': 'h', 'ц': 'c', 'ч': 'č', 'ш': 'š', 'ж': 'ž'},
  'mk': {'х': 'h', 'ц': 'c', 'ч': 'č', 'ш': 'š', 'ж': 'ž'},
  'be': {'г': 'h', 'і': 'i', 'ў': 'ŭ'},
};

String _cyrillic(String word, String lang) {
  final extra = _cyrByLang[lang] ?? const {};
  final out = StringBuffer();
  for (final ch in word.toLowerCase().split('')) {
    out.write(extra[ch] ?? _cyrBase[ch] ?? ch);
  }
  return _matchCase(word, out.toString());
}

// ---------------------------------------------------------------- Hebrew

const _hebLetters = {
  'א': '', 'ב': 'v', 'ג': 'g', 'ד': 'd', 'ה': 'h', 'ו': 'v', 'ז': 'z', //
  'ח': 'ch', 'ט': 't', 'י': 'y', 'כ': 'kh', 'ך': 'kh', 'ל': 'l', 'מ': 'm',
  'ם': 'm', 'נ': 'n', 'ן': 'n', 'ס': 's', 'ע': '', 'פ': 'f', 'ף': 'f',
  'צ': 'ts', 'ץ': 'ts', 'ק': 'k', 'ר': 'r', 'ש': 'sh', 'ת': 't',
};

const _hebDagesh = {'ב': 'b', 'כ': 'k', 'ך': 'k', 'פ': 'p', 'ף': 'p'};

const _hebVowels = {
  0x05B0: 'e', // shva (often silent; handled below)
  0x05B1: 'e', 0x05B2: 'a', 0x05B3: 'o', 0x05B4: 'i', 0x05B5: 'e',
  0x05B6: 'e', 0x05B7: 'a', 0x05B8: 'a', 0x05B9: 'o', 0x05BA: 'o',
  0x05BB: 'u', 0x05C7: 'o',
};

String _hebrew(String word) {
  // Group each letter with the marks that follow it.
  final clusters = <(String, List<int>)>[];
  for (final r in word.runes) {
    if (isHebrewMark(r) && clusters.isNotEmpty) {
      clusters.last.$2.add(r);
    } else {
      clusters.add((String.fromCharCode(r), <int>[]));
    }
  }
  final hasNikkud = clusters.any((c) => c.$2.isNotEmpty);
  final out = StringBuffer();
  for (var i = 0; i < clusters.length; i++) {
    final (letter, marks) = clusters[i];
    final dagesh = marks.contains(0x05BC);
    final last = i == clusters.length - 1;
    // Vav as a vowel carrier: holam male (וֹ) and shuruk (וּ).
    if (letter == 'ו' && marks.contains(0x05B9)) {
      out.write('o');
      continue;
    }
    if (letter == 'ו' && dagesh && marks.length == 1 && i > 0) {
      out.write('u');
      continue;
    }
    // Yod after a hiriq or tsere is a long vowel, not a consonant.
    if (letter == 'י' && marks.isEmpty && hasNikkud && i > 0) {
      final prev = clusters[i - 1].$2;
      if (prev.contains(0x05B4) || prev.contains(0x05B5)) continue;
    }
    // Final he without a mark is silent after a vowel.
    if (letter == 'ה' && marks.isEmpty && last && i > 0) continue;
    var cons = _hebLetters[letter];
    if (cons == null) {
      out.write(letter);
      continue;
    }
    if (dagesh && _hebDagesh.containsKey(letter)) cons = _hebDagesh[letter]!;
    if (letter == 'ש' && marks.contains(0x05C2)) cons = 's';
    if (!hasNikkud && letter == 'ו') cons = i == 0 ? 'v' : 'o';
    if (!hasNikkud && letter == 'י' && i > 0 && !last) cons = 'i';
    // Patach under a final chet or ayin is read before the consonant.
    if (last && (letter == 'ח' || letter == 'ע') && marks.contains(0x05B7)) {
      out.write('a$cons');
      continue;
    }
    out.write(cons);
    for (final m in marks) {
      final v = _hebVowels[m];
      if (v == null) continue;
      // Shva is voiced under a word's first letter and silent elsewhere.
      if (m == 0x05B0 && (i != 0 || last)) continue;
      out.write(v);
    }
  }
  return out.toString();
}

// ---------------------------------------------------------------- Arabic

const _arLetters = {
  'ء': 'ʼ', 'آ': 'ā', 'أ': 'ʼ', 'ؤ': 'ʼ', 'إ': 'ʼ', 'ئ': 'ʼ', 'ا': 'ā', //
  'ب': 'b', 'ة': 'a', 'ت': 't', 'ث': 'th', 'ج': 'j', 'ح': 'ḥ', 'خ': 'kh',
  'د': 'd', 'ذ': 'dh', 'ر': 'r', 'ز': 'z', 'س': 's', 'ش': 'sh', 'ص': 'ṣ',
  'ض': 'ḍ', 'ط': 'ṭ', 'ظ': 'ẓ', 'ع': 'ʻ', 'غ': 'gh', 'ف': 'f', 'ق': 'q',
  'ك': 'k', 'ل': 'l', 'م': 'm', 'ن': 'n', 'ه': 'h', 'و': 'w', 'ى': 'ā',
  'ي': 'y', 'ٱ': '',
  // Persian and Urdu.
  'پ': 'p', 'چ': 'ch', 'ژ': 'zh', 'گ': 'g', 'ک': 'k', 'ی': 'y', 'ٹ': 'ṭ',
  'ڈ': 'ḍ', 'ڑ': 'ṛ', 'ں': 'n', 'ہ': 'h', 'ھ': 'h', 'ے': 'e',
};

const _arVowels = {
  0x064E: 'a', 0x064F: 'u', 0x0650: 'i', 0x064B: 'an', 0x064C: 'un', //
  0x064D: 'in', 0x0670: 'ā',
};

String _arabic(String word, String lang) {
  final persian = lang == 'fa' || lang == 'ur' || lang == 'ps';
  final clusters = <(String, List<int>)>[];
  for (final r in word.runes) {
    if (r == 0x0640) continue; // tatweel
    if (isArabicMark(r) && clusters.isNotEmpty) {
      clusters.last.$2.add(r);
    } else {
      clusters.add((String.fromCharCode(r), <int>[]));
    }
  }
  final hasHarakat = clusters.any((c) => c.$2.isNotEmpty);
  bool bare(int i, Set<String> letters) =>
      i < clusters.length &&
      letters.contains(clusters[i].$1) &&
      clusters[i].$2.every((m) => m == 0x0651);
  const alif = {'ا', 'ى'};
  const waw = {'و'};
  const ya = {'ي', 'ی'};

  final out = StringBuffer();
  var i = 0;
  // Definite article: ال at the start reads "al-".
  if (clusters.length > 2 && clusters[0].$1 == 'ا' && clusters[1].$1 == 'ل') {
    out.write('al-');
    i = 2;
  }
  for (; i < clusters.length; i++) {
    final (letter, marks) = clusters[i];
    final first = i == 0;
    final cons = _arLetters[letter];
    if (cons == null) {
      out.write(letter);
      continue;
    }
    final seat = letter == 'ا' || letter == 'أ' || letter == 'إ' || letter == 'ء';
    if (!hasHarakat) {
      // Without vowel marks, long-vowel letters are all there is to read.
      if (alif.contains(letter) && !first) {
        out.write('ā');
      } else if (waw.contains(letter) && !first) {
        out.write(persian ? 'u' : 'ū');
      } else if (ya.contains(letter) && !first && i < clusters.length - 1) {
        out.write(persian ? 'i' : 'ī');
      } else if (first && seat) {
        out.write(letter == 'إ' ? 'i' : 'a');
      } else {
        out.write(cons);
      }
      continue;
    }
    // A bare alif the previous letter's vowel didn't absorb is a long a.
    if (alif.contains(letter) && marks.isEmpty && !first) {
      out.write('ā');
      continue;
    }
    out.write(first && seat ? '' : cons);
    if (marks.contains(0x0651)) out.write(cons); // shadda doubles
    var vowel = '';
    for (final m in marks) {
      vowel = _arVowels[m] ?? vowel;
    }
    if (vowel == 'a' && bare(i + 1, alif)) {
      out.write('ā');
      i++;
    } else if (vowel == 'u' && bare(i + 1, waw)) {
      out.write(persian ? 'u' : 'ū');
      i++;
    } else if (vowel == 'i' && bare(i + 1, ya)) {
      out.write(persian ? 'i' : 'ī');
      i++;
    } else if (vowel == 'an' && bare(i + 1, alif)) {
      out.write('an');
      i++;
    } else if (vowel.isNotEmpty) {
      out.write(vowel);
    } else if (first && seat) {
      out.write(letter == 'إ' ? 'i' : 'a');
    }
  }
  return out.toString();
}

// ---------------------------------------------------------------- Georgian

const _georgian = {
  'ა': 'a', 'ბ': 'b', 'გ': 'g', 'დ': 'd', 'ე': 'e', 'ვ': 'v', 'ზ': 'z', //
  'თ': 't', 'ი': 'i', 'კ': 'kʼ', 'ლ': 'l', 'მ': 'm', 'ნ': 'n', 'ო': 'o',
  'პ': 'pʼ', 'ჟ': 'zh', 'რ': 'r', 'ს': 's', 'ტ': 'tʼ', 'უ': 'u', 'ფ': 'p',
  'ქ': 'k', 'ღ': 'gh', 'ყ': 'qʼ', 'შ': 'sh', 'ჩ': 'ch', 'ც': 'ts',
  'ძ': 'dz', 'წ': 'tsʼ', 'ჭ': 'chʼ', 'ხ': 'kh', 'ჯ': 'j', 'ჰ': 'h',
};

// ---------------------------------------------------------------- Armenian

const _armenianMap = {
  'ա': 'a', 'բ': 'b', 'գ': 'g', 'դ': 'd', 'ե': 'e', 'զ': 'z', 'է': 'ē', //
  'ը': 'ə', 'թ': 'tʻ', 'ժ': 'zh', 'ի': 'i', 'լ': 'l', 'խ': 'kh', 'ծ': 'ts',
  'կ': 'k', 'հ': 'h', 'ձ': 'dz', 'ղ': 'gh', 'ճ': 'ch', 'մ': 'm', 'յ': 'y',
  'ն': 'n', 'շ': 'sh', 'ո': 'o', 'չ': 'chʻ', 'պ': 'p', 'ջ': 'j', 'ռ': 'ṙ',
  'ս': 's', 'վ': 'v', 'տ': 't', 'ր': 'r', 'ց': 'tsʻ', 'ւ': 'w', 'փ': 'pʻ',
  'ք': 'kʻ', 'օ': 'ō', 'ֆ': 'f', 'և': 'ev',
};

String _armenian(String word) {
  final s = word.toLowerCase().replaceAll('ու', 'u');
  return _matchCase(word, _table(s, _armenianMap));
}
