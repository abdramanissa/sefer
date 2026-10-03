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

    test('a word saved or a few seconds of reading keep no streak', () {
      final d = {
        dayKey(today): DayActivity(seconds: 20),
        dayKey(today.subtract(const Duration(days: 1))): DayActivity(saved: 3, words: 40, langWords: {'es': 40}),
        dayKey(today.subtract(const Duration(days: 2))): DayActivity(seconds: 300, langSeconds: {'es': 300}),
      };
      expect(currentStreak(d, today, dailyTest(needsGoal: false, goalMinutes: 15)), 0);
      expect(currentStreak(d, today, languageTest('es')), 0);
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
      expect(app.entry('he', 'שלום')!.word, 'שָׁלוֹם'); // spelling kept, lookup ignores marks
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

  group('shelves and settings', () {
    test('a shelf holds stories by hand or by tag, and follows renamed tags', () async {
      final app = AppState(MemoryStore());
      await app.load();
      app.addStories(importText('A\nUn text.', plain: const PlainTextOptions(language: 'ca')).stories);
      app.addStories(importText('B\nUn altre.', plain: const PlainTextOptions(language: 'ca')).stories);
      final a = app.stories.firstWhere((s) => s.title == 'A');
      final b = app.stories.firstWhere((s) => s.title == 'B');
      a.tags.add('grammar');
      final sh = app.addShelf('Study', tags: ['grammar']);
      expect(app.stories.where(sh.holds), [a]);
      app.toggleShelf(b, sh.id);
      expect(app.stories.where(sh.holds).toSet(), {a, b});
      app.renameTag('grammar', 'gramàtica');
      expect(sh.tags, ['gramàtica']);
      expect(sh.holds(a), isTrue);
      final back = Shelf.fromJson(sh.toJson());
      expect(back.tags, ['gramàtica']);
    });

    test('older settings move to the matte look once', () {
      final old = Settings.fromJson({'transition': 'blur', 'glass': true, 'nav_style': 'floating'});
      expect(old.transition, 'zoom');
      expect(old.glass, isFalse);
      expect(old.navStyle, 'pill');
      final chosen = Settings.fromJson({...old.toJson(), 'transition': 'blur', 'nav_style': 'island'});
      expect(chosen.transition, 'blur');
      expect(chosen.navStyle, 'island');
    });
  });

  group('quiz', () {
    const json = '''
{
  "title": "Michael",
  "language": "en",
  "paragraphs": ["Michael went to the market."],
  "quiz": [
    {"question": "Michael went to the ...", "options": ["school", "market", "beach"], "answer": "market"},
    {"question": "Where did he go?", "options": ["home", "work"], "answer": 1, "explanation": "He went to work."},
    {"question": "Did Michael go out?", "type": "yes_no", "answer": "yes"},
    {"question": "Michael stayed home.", "type": "true_false", "answer": false},
    {"question": "Pick the letter", "options": ["a", "b", "c"], "answer": "C"},
    {"question": "No answer here", "options": ["x", "y"]},
    {"question": "Write your answer"}
  ]
}''';

    test('reads every kind of question and skips unanswerable ones', () {
      final r = importText(json);
      final q = r.stories.single.quiz;
      expect(q, hasLength(5));
      expect(q[0].answer, 1);
      expect(q[1].answer, 1);
      expect(q[1].explanation, 'He went to work.');
      expect(q[2].kind, QuizKind.yesNo);
      expect(q[2].options, ['Yes', 'No']);
      expect(q[2].answer, 0);
      expect(q[3].kind, QuizKind.trueFalse);
      expect(q[3].answer, 1);
      expect(q[4].answer, 2);
      expect(r.problems.single, contains('2 quiz questions'));
    });

    test('survives storage and export', () {
      final s = importText(json).stories.single;
      final back = Story.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>);
      expect(back.quiz.map((q) => '${q.kind} ${q.options} ${q.answer}').toList(), s.quiz.map((q) => '${q.kind} ${q.options} ${q.answer}').toList());
      final again = importText(jsonEncode(s.toPortableJson())).stories.single;
      expect(again.quiz, hasLength(5));
      expect(again.quiz[2].answer, 0);
    });

    test('accepts {"questions": [...]} too', () {
      final q = parseQuiz({
        'questions': [
          {'question': 'Is it?', 'answer': true},
        ],
      });
      expect(q.single.kind, QuizKind.trueFalse);
    });

    test('records scores, best and daily totals', () async {
      final app = AppState(MemoryStore());
      await app.load();
      app.addStories(importText(json).stories);
      final s = app.stories.single;
      expect(app.recordQuiz(s, 3, 5), isTrue);
      expect(app.recordQuiz(s, 2, 5), isFalse);
      expect(s.quizBest, 60);
      expect(s.quizLast, 40);
      expect(s.quizAttempts, 2);
      expect(app.today.quizzes, 2);
      expect(app.today.quizCorrect, 5);
      expect(app.today.quizQuestions, 10);
    });
  });
}
