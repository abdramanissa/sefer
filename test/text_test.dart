import 'package:flutter_test/flutter_test.dart';
import 'package:sefer/text/normalize.dart';
import 'package:sefer/text/script.dart';
import 'package:sefer/text/tokenizer.dart';
import 'package:sefer/text/transliterate.dart';

void main() {
  group('tokenize', () {
    test('splits words, spaces and punctuation', () {
      final t = tokenize('El gato duerme.');
      expect(t.map((e) => e.toString()), [
        'word:El',
        'space: ',
        'word:gato',
        'space: ',
        'word:duerme',
        'punct:.',
      ]);
    });

    test('keeps Hebrew nikkud inside the word', () {
      const w = 'שָׁלוֹם';
      expect(words('$w עוֹלָם!'), [w, 'עוֹלָם']);
    });

    test('keeps Arabic harakat and tatweel inside the word', () {
      expect(words('مَرْحَبًا بِكُمْ'), ['مَرْحَبًا', 'بِكُمْ']);
      expect(words('كتـــاب'), ['كتـــاب']);
    });

    test('keeps Hebrew gershayim abbreviations whole', () {
      expect(words('צה"ל ו־צה״ל'), ['צה"ל', 'ו', 'צה״ל']);
    });

    test('keeps apostrophes and hyphens between letters', () {
      expect(words("l'homme well-known 'quoted'"), ["l'homme", 'well-known', 'quoted']);
    });

    test('Persian zero-width non-joiner stays in the word', () {
      expect(words('می‌خواهم'), ['می‌خواهم']);
    });

    test('Han characters are separate words', () {
      expect(words('我爱你。'), ['我', '爱', '你']);
    });

    test('offsets point into the source', () {
      const s = 'Καλημέρα σας!';
      for (final t in tokenize(s)) {
        expect(s.substring(t.start, t.start + t.text.length), t.text);
      }
    });
  });

  group('sentences and paragraphs', () {
    test('splits on terminal punctuation in several scripts', () {
      expect(splitSentences('Hola. ¿Qué tal? Bien!'), ['Hola.', '¿Qué tal?', 'Bien!']);
      expect(splitSentences('مرحبا؟ أنا بخير.'), ['مرحبا؟', 'أنا بخير.']);
      expect(splitSentences('你好。我很好！'), ['你好。', '我很好！']);
    });

    test('closing quotes stay with their sentence', () {
      expect(splitSentences('«Ven.» Y vino.'), ['«Ven.»', 'Y vino.']);
    });

    test('paragraphs split on blank lines, hard-wrapped prose is joined', () {
      const text =
          'This is a long line of prose that was hard wrapped by some editor\n'
          'and continues here without any real paragraph break in it at all\n\n'
          'Second paragraph.';
      expect(splitParagraphs(text), [
        'This is a long line of prose that was hard wrapped by some editor '
            'and continues here without any real paragraph break in it at all',
        'Second paragraph.',
      ]);
    });

    test('short lines (poetry) stay separate', () {
      expect(splitParagraphs('Roses are red\nViolets are blue'), [
        'Roses are red',
        'Violets are blue',
      ]);
    });
  });

  group('normalize', () {
    test('wordKey folds case, nikkud, harakat and final sigma', () {
      expect(wordKey('Καλημέρα'), 'καλημέρα');
      expect(wordKey('ΣΑΣ'), wordKey('σας'));
      expect(wordKey('שָׁלוֹם'), 'שלום');
      expect(wordKey('مَرْحَبًا'), 'مرحبا');
      expect(wordKey('كتـــاب'), 'كتاب');
    });

    test('Devanagari vowel signs are kept', () {
      expect(wordKey('नमस्ते'), 'नमस्ते');
    });

    test('lookupLoose tries exact, then key, then accent-free', () {
      final m = {'καλημέρα': 'good morning', 'σας': 'you', 'cafe': 'coffee'};
      expect(lookupLoose(m, 'Καλημέρα'), 'good morning');
      expect(lookupLoose(m, 'ΣΑΣ'), 'you');
      expect(lookupLoose(m, 'café'), 'coffee');
      expect(lookupLoose(m, 'nope'), isNull);
    });
  });

  group('script', () {
    test('direction by language, then by script', () {
      expect(isRtl('he'), isTrue);
      expect(isRtl('ar-EG'), isTrue);
      expect(isRtl('el'), isFalse);
      expect(isRtl('und', 'שלום'), isTrue);
      expect(isRtl('und', 'hello'), isFalse);
    });

    test('dominant script', () {
      expect(dominantScript('Καλημέρα!'), Script.greek);
      expect(dominantScript('Привет'), Script.cyrillic);
      expect(dominantScript('123 ...'), Script.other);
    });
  });

  group('transliterate', () {
    test('Greek', () {
      expect(transliterate('καλημέρα'), 'kaliméra');
      expect(transliterate('Καλημέρα'), 'Kaliméra');
      expect(transliterate('σας'), 'sas');
      expect(transliterate('μπαμπάς'), 'bampás');
      expect(transliterate('ευχαριστώ'), 'evcharistó');
    });

    test('Cyrillic, with per-language rules', () {
      expect(transliterate('Привет', language: 'ru'), 'Privet');
      expect(transliterate('щука', language: 'ru'), 'shchuka');
      expect(transliterate('щука', language: 'bg'), 'shtuka');
      expect(transliterate('гора', language: 'uk'), 'hora');
    });

    test('Hebrew with nikkud', () {
      expect(transliterate('שָׁלוֹם'), 'shalom');
      expect(transliterate('בְּרֵאשִׁית'), 'bereshit');
      expect(transliterate('תּוֹרָה'), 'tora');
    });

    test('Hebrew without nikkud still gives consonants', () {
      expect(transliterate('שלום'), 'shlom');
    });

    test('Arabic with harakat', () {
      expect(transliterate('كِتَاب'), 'kitāb');
      expect(transliterate('مَرْحَبًا'), 'marḥaban');
      expect(transliterate('كُتُب'), 'kutub');
      expect(transliterate('الكتاب'), 'al-ktāb');
      expect(transliterate('سلام'), 'slām');
    });

    test('Georgian', () {
      expect(transliterate('გამარჯობა'), 'gamarjoba');
    });

    test('Latin has nothing to do', () {
      expect(transliterate('hola'), '');
      expect(canTransliterate('hola'), isFalse);
      expect(canTransliterate('שלום'), isTrue);
    });
  });
}
