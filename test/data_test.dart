import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sefer/data/app_state.dart';
import 'package:sefer/data/exporter.dart';
import 'package:sefer/data/importer.dart';
import 'package:sefer/data/models.dart';
import 'package:sefer/data/stats.dart';
import 'package:sefer/data/store.dart';

const greek = '''
{
  "title": "Καλημέρα",
  "language": "el",
  "translation_language": "en",
  "paragraphs": [
    {
      "sentences": [
        {
          "text": "Καλημέρα σας!",
          "translation": "Good morning!",
          "glosses": { "καλημέρα": "good morning", "σας": "to you (formal)" },
          "transliterations": { "καλημέρα": "kaliméra", "σας": "sas" }
        }
      ]
    }
  ]
}''';

const spanish = '''
[
  {
    "title": "El gato", "language": "es", "translation_language": "en",
    "paragraphs": [{ "sentences": [
      { "text": "El gato duerme.", "translation": "The cat sleeps.", "transliterations": {} }
    ] }]
  },
  {
    "title": "El perro", "language": "es", "translation_language": "en",
    "paragraphs": [{ "sentences": [
      { "text": "El perro corre.", "translation": "The dog runs.", "transliterations": {} }
    ] }]
  }
]''';

void main() {
  group('import', () {
    test('single story with glosses and transliterations', () {
      final r = importText(greek);
      expect(r.problems, isEmpty);
      expect(r.stories, hasLength(1));
      final s = r.stories.single;
      expect(s.title, 'Καλημέρα');
      expect(s.language, 'el');
      expect(s.translationLanguage, 'en');
      final sentence = s.paragraphs.single.sentences.single;
      expect(sentence.translation, 'Good morning!');
      expect(sentence.glosses['σας'], 'to you (formal)');
      expect(sentence.transliterations['καλημέρα'], 'kaliméra');
      expect(s.wordCount, 2);
    });

    test('multiple stories from an array', () {
      final r = importText(spanish);
      expect(r.stories.map((s) => s.title), ['El gato', 'El perro']);
      expect(r.stories.first.paragraphs.single.sentences.single.transliterations, isEmpty);
      expect(r.stories.map((s) => s.id).toSet(), hasLength(2));
    });

    test('lenient shapes: string sentences, text field, stories wrapper', () {
      final r = importJson({
        'stories': [
          {
            'title': 'A',
            'language': 'fr',
            'paragraphs': [
              {'sentences': ['Bonjour.', 'Ça va ?']},
              'Deuxième paragraphe. Oui.',
            ],
          },
          {'title': 'B', 'language': 'de', 'text': 'Hallo Welt.\n\nZweiter Absatz.'},
        ],
      });
      expect(r.stories, hasLength(2));
      expect(r.stories[0].paragraphs, hasLength(2));
      expect(r.stories[0].paragraphs[1].sentences.map((s) => s.text), [
        'Deuxième paragraphe.',
        'Oui.',
      ]);
      expect(r.stories[1].paragraphs, hasLength(2));
    });

    test('reports and skips bad items', () {
      final r = importJson([
        {'title': 'Empty', 'language': 'es', 'paragraphs': []},
        42,
        {'title': 'Ok', 'paragraphs': [{'sentences': ['שלום עולם.']}]},
      ]);
      expect(r.stories.single.title, 'Ok');
      expect(r.stories.single.language, 'he'); // guessed from the script
      expect(r.problems, hasLength(3));
    });

    test('invalid JSON is reported, not thrown', () {
      final r = importText('{"title": ');
      expect(r.isEmpty, isTrue);
      expect(r.problems.single, contains('does not parse'));
    });

    test('plain text: title line, paragraphs, sentences', () {
      final r = importText(
        'Mi día\nMe levanto temprano. Desayuno café.\n\nLuego trabajo.',
        plain: const PlainTextOptions(language: 'es'),
      );
      final s = r.stories.single;
      expect(s.title, 'Mi día');
      expect(s.language, 'es');
      expect(s.paragraphs, hasLength(2));
      expect(s.paragraphs.first.sentences, hasLength(2));
    });

    test('plain text with separators imports several stories', () {
      final r = importText(
        'Uno\nPrimer texto.\n===\nDos\nSegundo texto.\n---\nTercer texto sin título.',
        plain: const PlainTextOptions(language: 'es', tags: ['A1']),
      );
      expect(r.stories.map((s) => s.title), ['Uno', 'Dos', 'Tercer texto sin título']);
      expect(r.stories.every((s) => s.tags.contains('A1')), isTrue);
    });

    test('round trip through the portable format', () {
      final s = importText(greek).stories.single;
      final again = importText(exportStories([s])).stories.single;
      expect(jsonEncode(again.toPortableJson()), jsonEncode(s.toPortableJson()));
    });
  });

  group('streaks', () {
    final today = DateTime(2026, 9, 25);
    Map<String, DayActivity> days(Map<int, int> secondsByOffset, {String lang = 'es'}) => {
      for (final e in secondsByOffset.entries)
        dayKey(DateTime(2026, 9, 25 - e.key)): DayActivity(
          seconds: e.value,
          langSeconds: {lang: e.value},
        ),
    };

    test('counts back from today', () {
      final d = days({0: 60, 1: 60, 2: 60, 4: 60});
      expect(currentStreak(d, today, (a) => a.isActive), 3);
    });

    test('still alive when today is empty so far', () {
      final d = days({1: 60, 2: 60});
      expect(currentStreak(d, today, (a) => a.isActive), 2);
    });

    test('broken by a missed day', () {
      final d = days({2: 60, 3: 60});
      expect(currentStreak(d, today, (a) => a.isActive), 0);
    });

    test('goal rule and per-language rule', () {
      final d = days({0: 1200, 1: 100, 2: 1200});
      expect(currentStreak(d, today, dailyTest(needsGoal: true, goalMinutes: 15)), 1);
      expect(currentStreak(d, today, dailyTest(needsGoal: false, goalMinutes: 15)), 3);
      expect(currentStreak(d, today, languageTest('es')), 3);
      expect(currentStreak(d, today, languageTest('he')), 0);
    });

    test('best streak across month boundaries', () {
      final d = {
        '2026-08-30': DayActivity(seconds: 1),
        '2026-08-31': DayActivity(seconds: 1),
        '2026-09-01': DayActivity(seconds: 1),
        '2026-09-03': DayActivity(seconds: 1),
      };
      expect(bestStreak(d, (a) => a.isActive), 3);
    });
  });

  group('anki', () {
    test('TSV has Anki headers and one escaped line per word', () {
      final e = VocabEntry(
        language: 'el',
        word: 'καλημέρα',
        meaning: 'good\tmorning\nhello',
        transliteration: 'kaliméra',
        example: 'Καλημέρα σας!',
        exampleTranslation: 'Good morning!',
        status: 2,
      );
      final lines = buildAnkiTsv([e]).trim().split('\n');
      expect(lines.first, '#separator:tab');
      expect(lines.where((l) => l.startsWith('#')), hasLength(4));
      final fields = lines.last.split('\t');
      expect(fields, hasLength(7));
      expect(fields[1], 'good morning<br>hello');
      expect(fields[6], 'sefer lang::el status::2');
    });
  });

  group('app state', () {
    late AppState app;
    setUp(() async {
      app = AppState(MemoryStore());
      await app.load();
    });

    test('word status ignores nikkud and case', () {
      app.setWord('he', 'שָׁלוֹם', status: 2, meaning: 'peace');
      expect(app.statusOf('he', 'שלום'), 2);
      expect(app.entry('he', 'שלום')!.word, 'שלום');
      app.setWord('el', 'Καλημέρα', status: WordStatus.known);
      expect(app.statusOf('el', 'καλημέρα'), WordStatus.known);
      expect(app.today.known, 1);
      expect(app.today.saved, 1);
    });

    test('setting a word back to new removes it', () {
      app.setWord('es', 'gato', status: 1);
      app.setWord('es', 'gato', status: WordStatus.newWord);
      expect(app.vocab, isEmpty);
    });

    test('numbers are never new words', () {
      expect(app.statusOf('es', '2026'), WordStatus.known);
    });

    test('finishing a story marks new words known and counts words read', () {
      final s = importText(spanish).stories.first;
      app.addStories([s]);
      app.setWord('es', 'gato', status: 3);
      final marked = app.finishStory(s);
      expect(marked, 2); // el, duerme
      expect(app.statusOf('es', 'gato'), 3);
      expect(app.statusOf('es', 'duerme'), WordStatus.known);
      expect(app.today.words, 3);
      expect(app.wordStats(s).known, 2);
      expect(app.wordStats(s).learning, 1);
    });

    test('reading time adds to the day and the language', () {
      final s = importText(greek).stories.single;
      app.addStories([s]);
      app.addReadingTime(s, 90);
      expect(app.today.seconds, 90);
      expect(app.today.langSeconds['el'], 90);
      expect(app.dailyStreak, 1);
      expect(app.languageStreak('el'), 1);
      expect(app.languageStreak('es'), 0);
    });

    test('persists and reloads', () async {
      final store = MemoryStore();
      final a = AppState(store);
      await a.load();
      a.addStories(importText(spanish).stories);
      a.setWord('es', 'perro', status: 4, meaning: 'dog');
      a.updateSettings((s) => s.fontSize = 30);
      await a.flush();
      final b = AppState(store);
      await b.load();
      expect(b.stories, hasLength(2));
      expect(b.entry('es', 'perro')!.meaning, 'dog');
      expect(b.settings.fontSize, 30);
    });

    test('backup restores into a fresh app', () async {
      app.addStories(importText(spanish).stories);
      app.setWord('es', 'perro', status: 4);
      app.addShelf('Favourites');
      final json = jsonDecode(jsonEncode(await app.backup())) as Map<String, dynamic>;
      expect(isBackup(json), isTrue);
      final fresh = AppState(MemoryStore());
      await fresh.load();
      await fresh.restore(parseBackup(json), merge: false);
      expect(fresh.stories, hasLength(2));
      expect(fresh.shelves.single.name, 'Favourites');
      expect(fresh.statusOf('es', 'perro'), 4);
    });

    test('navigation: tabs, depth and back', () {
      app.go('words');
      expect(app.moveDepth, 0);
      app.go('reader:x');
      expect(app.moveDepth, 1);
      expect(app.back(), isTrue);
      expect(app.route, 'words');
      expect(app.back(), isTrue);
      expect(app.route, 'library');
      expect(app.back(), isFalse);
    });
  });
}
