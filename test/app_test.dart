import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sefer/app/app.dart';
import 'package:sefer/data/ai.dart';
import 'package:sefer/data/app_state.dart';
import 'package:sefer/data/importer.dart';
import 'package:sefer/data/models.dart';
import 'package:sefer/data/store.dart';
import 'package:sefer/screens/word_card.dart';
import 'package:sefer/widgets/ui_kit.dart';
import 'package:sefer/screens/word_sheet.dart';
import 'package:sefer/widgets/word_text.dart';

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

const multi = '''
[
  {"title": "El gato", "language": "es", "translation_language": "en",
   "paragraphs": [{"sentences": [{"text": "El gato duerme.", "translation": "The cat sleeps.", "transliterations": {}}]}]},
  {"title": "El perro", "language": "es", "translation_language": "en",
   "paragraphs": [{"sentences": [{"text": "El perro corre.", "translation": "The dog runs.", "transliterations": {}}]}]}
]''';

const hebrew = 'שָׁלוֹם עוֹלָם. זֶה סֵפֶר טוֹב.';

Future<AppState> _state({bool withStories = true}) async {
  final app = AppState(MemoryStore());
  await app.load();
  if (withStories) {
    app.addStories(importText(multi).stories);
    app.addStories(importText(hebrew, plain: const PlainTextOptions(title: 'ספר', language: 'he')).stories);
    app.addStories(importText(greek).stories);
  }
  return app;
}

Future<void> _pump(WidgetTester tester, AppState app) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(SeferApp(state: app));
  await tester.pumpAndSettle();
}

Future<void> _go(WidgetTester tester, AppState app, String route) async {
  app.go(route);
  await tester.pumpAndSettle();
}

RenderWordText _paragraph(WidgetTester tester) =>
    tester.renderObject<RenderWordText>(find.byType(WordText).first);

/// Scrolls [finder] to the middle of the screen, clear of the nav bar.
Future<void> _centre(WidgetTester tester, Finder finder) async {
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pumpAndSettle();
}

/// Removes the app so periodic timers (the reader's clock) are cancelled.
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('empty library points to the Add tab', (tester) async {
    final app = await _state(withStories: false);
    await _pump(tester, app);
    expect(find.text('Your library is empty'), findsOneWidget);
    await tester.tap(find.text('Add a text'));
    await tester.pumpAndSettle();
    expect(app.route, 'add');
    await _unmount(tester);
  });

  testWidgets('every screen builds without errors', (tester) async {
    final app = await _state();
    app.setWord('es', 'gato', status: 2, meaning: 'cat', example: 'El gato duerme.');
    app.setWord('he', 'שָׁלוֹם', status: WordStatus.known);
    await _pump(tester, app);
    final story = app.stories.first;
    for (final r in [
      'library',
      'add',
      'words',
      'stats',
      'settings',
      'settings:appearance',
      'settings:reader',
      'settings:layout',
      'profile',
      'settings:motion',
      'settings:about',
      'settings:ai',
      'story:${story.id}',
    ]) {
      await _go(tester, app, r);
      expect(tester.takeException(), isNull, reason: r);
    }
    app.updateSettings((s) => s.libraryView = 'list');
    await _go(tester, app, 'library');
    app.updateSettings((s) {
      s.themeMode = 'light';
      s.transition = 'slide';
    });
    await _go(tester, app, 'stats');
    await _unmount(tester);
  });

  testWidgets('import several stories from pasted JSON', (tester) async {
    final app = await _state(withStories: false);
    await _pump(tester, app);
    await _go(tester, app, 'add');
    await tester.enterText(find.byType(TextField).first, multi);
    await tester.pumpAndSettle();
    final page = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('Review'), 300, scrollable: page);
    await tester.drag(page, const Offset(0, -250));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    expect(find.text('2 stories ready'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Add 2 stories'), 300, scrollable: page);
    // Lift it clear of the floating nav bar.
    await tester.drag(page, const Offset(0, -250));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add 2 stories'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(app.stories.map((s) => s.title), containsAll(['El gato', 'El perro']));
    await _unmount(tester);
  });

  testWidgets('reader: tap a word for the card, set a level, double-tap to know', (tester) async {
    final app = await _state();
    await _pump(tester, app);
    final story = app.stories.firstWhere((s) => s.language == 'el');
    app.openStory(story);
    await tester.pumpAndSettle();
    expect(app.routeName, 'reader');

    final text = _paragraph(tester);
    expect(text.plainText, contains('Καλημέρα σας!'));
    await tester.tapAt(text.globalRectOf(0).center);
    await tester.pumpAndSettle();
    expect(find.byType(WordCard), findsOneWidget);
    expect(find.text('good morning'), findsWidgets);
    expect(find.text('kaliméra'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Level 2'));
    await tester.pumpAndSettle();
    expect(app.statusOf('el', 'καλημέρα'), 2);
    expect(app.entry('el', 'καλημέρα')!.meaning, 'good morning');

    // Double-tap σας: known in one move.
    final sas = _paragraph(tester).globalRectOf(1).center;
    await tester.tapAt(sas);
    await tester.pump(const Duration(milliseconds: 120));
    await tester.tapAt(sas);
    await tester.pumpAndSettle();
    expect(app.statusOf('el', 'σας'), WordStatus.known);

    await tester.scrollUntilVisible(find.bySemanticsLabel(RegExp('^Finish')), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.bySemanticsLabel(RegExp('^Finish')));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(story.finishedAt, isNotNull);
    expect(app.statusOf('el', 'καλημέρα'), 2);
    await _unmount(tester);
  });

  testWidgets('reader: full sheet option and reading mode', (tester) async {
    final app = await _state();
    app.settings.wordPopup = 'sheet';
    await _pump(tester, app);
    app.openStory(app.stories.firstWhere((s) => s.language == 'el'));
    await tester.pumpAndSettle();
    await tester.tapAt(_paragraph(tester).globalRectOf(0).center);
    await tester.pumpAndSettle();
    expect(find.byType(WordSheet), findsOneWidget);
    await tester.tapAt(const Offset(20, 60));
    await tester.pumpAndSettle();

    app.updateSettings((s) => s.readerMode = 'read');
    await tester.pumpAndSettle();
    expect(tester.widget<WordText>(find.byType(WordText).first).marks, isEmpty);
    await tester.tapAt(_paragraph(tester).globalRectOf(0).center);
    await tester.pumpAndSettle();
    expect(find.byType(WordCard), findsOneWidget);
    expect(find.text('Good morning!'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('reader: Hebrew is right to left and can hide nikkud', (tester) async {
    final app = await _state();
    await _pump(tester, app);
    final story = app.stories.firstWhere((s) => s.language == 'he');
    app.openStory(story);
    await tester.pumpAndSettle();
    expect(_paragraph(tester).plainText, contains('שָׁלוֹם'));
    expect(tester.widget<WordText>(find.byType(WordText).first).textDirection, TextDirection.rtl);

    app.updateSettings((s) => s.showMarks = false);
    await tester.pumpAndSettle();
    expect(_paragraph(tester).plainText, isNot(contains('שָׁלוֹם')));
    expect(_paragraph(tester).plainText, contains('שלום'));

    app.updateSettings((s) => s.translit = 'above');
    await tester.pumpAndSettle();
    final readings = tester.widget<WordText>(find.byType(WordText).first).marks.values.map((m) => m.reading);
    expect(readings, contains('shalom'));
    await _unmount(tester);
  });

  testWidgets('active-language mode hides other languages', (tester) async {
    final app = await _state();
    app.settings.learning = ['es', 'he'];
    app.settings.activeLanguage = 'he';
    app.settings.languageScope = 'active';
    app.settings.libraryView = 'titles';
    await _pump(tester, app);
    expect(find.text('ספר'), findsOneWidget);
    expect(find.text('El gato'), findsNothing);
    app.setActiveLanguage('es');
    await tester.pumpAndSettle();
    expect(find.text('El gato'), findsOneWidget);
    expect(find.text('ספר'), findsNothing);
    await _unmount(tester);
  });

  testWidgets('each feel lays out the main screens', (tester) async {
    final app = await _state();
    await _pump(tester, app);
    for (final f in ['minimal', 'compact', 'airy', 'classic']) {
      app.updateSettings((s) {
        s.feel = f;
        s.libraryView = {'minimal': 'titles', 'compact': 'list', 'airy': 'shelf', 'classic': 'grid'}[f]!;
        s.navStyle = f == 'compact' ? 'docked' : 'floating';
        s.showCenterButton = f != 'minimal';
        s.glass = f != 'compact';
      });
      for (final r in ['library', 'profile', 'settings:appearance', 'stats']) {
        await _go(tester, app, r);
        expect(tester.takeException(), isNull, reason: '$f $r');
      }
    }
    await _unmount(tester);
  });

  testWidgets('custom theme can be created and applied', (tester) async {
    final app = await _state();
    await _pump(tester, app);
    await _go(tester, app, 'settings:appearance');
    final page = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('Create a theme'), 300, scrollable: page);
    await _centre(tester, find.text('Create a theme'));
    await tester.tap(find.text('Create a theme'));
    await tester.pumpAndSettle();
    expect(app.routeName, 'theme');
    await tester.tap(find.text('Use this theme'));
    await tester.pumpAndSettle();
    expect(app.settings.themeMode, 'custom');
    expect(app.settings.customThemes, hasLength(1));
    await _unmount(tester);
  });

  testWidgets('pages layout turns pages and keeps your place', (tester) async {
    final app = await _state(withStories: false);
    final long = List.generate(30, (i) => 'Mi abuela tiene un jardín pequeño detrás de su casa número $i. Cada mañana sale con una taza de café y mira las flores.').join('\n\n');
    app.addStories(importText(long, plain: const PlainTextOptions(title: 'Largo', language: 'es')).stories);
    app.settings.readerLayout = 'pages';
    await _pump(tester, app);
    final s = app.stories.single;
    app.openStory(s);
    await tester.pumpAndSettle();
    expect(find.byType(PageView), findsOneWidget);
    expect(find.textContaining('1 / '), findsOneWidget);
    expect(tester.takeException(), isNull);
    // Tap the right edge: next page.
    await tester.tapAt(const Offset(380, 420));
    await tester.pumpAndSettle();
    expect(find.textContaining('2 / '), findsOneWidget);
    expect(s.position, greaterThan(0));
    // Swipe on to the next.
    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1500);
    await tester.pumpAndSettle();
    expect(find.textContaining('3 / '), findsOneWidget);
    final kept = s.position;
    // Switching back to scrolling keeps the place.
    app.updateSettings((x) => x.readerLayout = 'scroll');
    await tester.pumpAndSettle();
    expect(find.byType(PageView), findsNothing);
    expect(s.position, kept);
    await _unmount(tester);
  });

  testWidgets('quiz: answer, see the score, best is saved', (tester) async {
    final app = await _state(withStories: false);
    app.addStories(importText(jsonEncode({
      'title': 'Quiz',
      'language': 'es',
      'paragraphs': ['El gato duerme.'],
      'quiz': [
        {'question': '¿Duerme el gato?', 'type': 'yes_no', 'answer': true},
        {'question': '¿Corre el gato?', 'type': 'yes_no', 'answer': false, 'explanation': 'Duerme.'},
      ],
    })).stories);
    await _pump(tester, app);
    final s = app.stories.single;
    await _go(tester, app, 'quiz:${s.id}');
    expect(app.showNav, isFalse);
    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();
    expect(find.text('Correct'), findsOneWidget);
    await tester.tap(find.text('Next question'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();
    expect(find.text('Not quite'), findsOneWidget);
    expect(find.text('Duerme.'), findsOneWidget);
    await tester.tap(find.text('See my score'));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('1 of 2 right'), findsOneWidget);
    expect(find.text('Getting there'), findsOneWidget);
    expect(s.quizBest, 50);
    expect(app.today.quizzes, 1);
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    expect(find.text('You said'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('generator: builds a prompt, calls the model, reviews the answer', (tester) async {
    final app = await _state(withStories: false);
    app.settings
      ..internet = true
      ..geminiKey = 'test-key';
    String? sent;
    AiClient.debugTransport = (method, url, headers, body) async {
      sent = body;
      await Future<void>.delayed(const Duration(milliseconds: 300));
      return (
        200,
        jsonEncode({
          'candidates': [
            {
              'content': {
                'parts': [
                  {
                    'text': jsonEncode([
                      {
                        'title': 'El mercado',
                        'language': 'es',
                        'paragraphs': [
                          {'sentences': [{'text': 'Voy al mercado.', 'translation': 'I go to the market.'}]},
                        ],
                        'quiz': [
                          {'question': '¿Adónde voy?', 'options': ['Al mercado', 'A casa'], 'answer': 'Al mercado'},
                        ],
                      },
                    ]),
                  },
                ],
              },
            },
          ],
        }),
      );
    };
    addTearDown(() => AiClient.debugTransport = null);
    await _pump(tester, app);
    await _go(tester, app, 'add');
    await tester.tap(find.text('Generate'));
    await tester.pumpAndSettle();
    expect(app.routeName, 'generate');
    expect(app.showNav, isFalse);
    await tester.tap(find.text('B1'));
    await tester.pumpAndSettle();
    expect(app.settings.gen.level, 'B1');
    await tester.tap(find.widgetWithText(PrimaryButton, 'Generate'));
    // Leave while it's writing: the answer must still arrive.
    await _go(tester, app, 'library');
    await tester.pumpAndSettle();
    expect(sent, contains('Oxford 3000 A1-B1 words'));
    expect(app.generation.result?.stories.single.title, 'El mercado');
    expect(find.text('Your story is ready'), findsOneWidget);
    await _go(tester, app, 'generate');
    await tester.tap(find.textContaining('Review “El mercado”'));
    await tester.pumpAndSettle();
    expect(find.text('Ready to add'), findsOneWidget);
    expect(find.text('1-question quiz'), findsOneWidget);
    await tester.tap(find.text('Add to library'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(app.stories.single.title, 'El mercado');
    expect(app.generation.result, isNull);
    await _unmount(tester);
  });

  testWidgets('generator is blocked while internet is off', (tester) async {
    final app = await _state(withStories: false);
    var called = false;
    AiClient.debugTransport = (_, _, _, _) async {
      called = true;
      return (200, '{}');
    };
    addTearDown(() => AiClient.debugTransport = null);
    await _pump(tester, app);
    await _go(tester, app, 'generate');
    expect(find.textContaining('Internet is off'), findsOneWidget);
    await tester.tap(find.widgetWithText(PrimaryButton, 'Generate'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(called, isFalse);
    await _unmount(tester);
  });
}
