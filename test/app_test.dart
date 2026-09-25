import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sefer/app/app.dart';
import 'package:sefer/data/app_state.dart';
import 'package:sefer/data/importer.dart';
import 'package:sefer/data/models.dart';
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
      'settings:motion',
      'settings:about',
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

  testWidgets('reader: tap a word, see gloss and reading, set a level', (tester) async {
    final app = await _state();
    await _pump(tester, app);
    final story = app.stories.firstWhere((s) => s.language == 'el');
    app.openStory(story);
    await tester.pumpAndSettle();
    expect(app.routeName, 'reader');

    await tester.tap(find.descendant(of: find.byType(CustomScrollView), matching: find.text('Καλημέρα')).last);
    await tester.pumpAndSettle();
    expect(find.text('good morning'), findsWidgets);
    expect(find.text('kaliméra'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Level 2'));
    await tester.pumpAndSettle();
    expect(app.statusOf('el', 'καλημέρα'), 2);
    expect(app.entry('el', 'καλημέρα')!.meaning, 'good morning');

    // Close the sheet, finish the story.
    await tester.tapAt(const Offset(20, 60));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.textContaining('Finish'), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.textContaining('Finish'));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(story.finishedAt, isNotNull);
    expect(app.statusOf('el', 'σας'), WordStatus.known);
    expect(app.statusOf('el', 'καλημέρα'), 2);
    await _unmount(tester);
  });

  testWidgets('reader: Hebrew is right to left and can hide nikkud', (tester) async {
    final app = await _state();
    await _pump(tester, app);
    final story = app.stories.firstWhere((s) => s.language == 'he');
    app.openStory(story);
    await tester.pumpAndSettle();
    expect(find.text('שָׁלוֹם'), findsOneWidget);
    final dir = tester.widget<Directionality>(
      find.ancestor(of: find.text('שָׁלוֹם'), matching: find.byType(Directionality)).first,
    );
    expect(dir.textDirection, TextDirection.rtl);

    app.updateSettings((s) => s.showMarks = false);
    await tester.pumpAndSettle();
    expect(find.text('שָׁלוֹם'), findsNothing);
    expect(find.text('שלום'), findsOneWidget);

    app.updateSettings((s) => s.translit = 'above');
    await tester.pumpAndSettle();
    expect(find.text('shalom'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('custom theme can be created and applied', (tester) async {
    final app = await _state();
    await _pump(tester, app);
    await _go(tester, app, 'settings:appearance');
    await tester.ensureVisible(find.text('Create a theme'));
    await tester.tap(find.text('Create a theme'));
    await tester.pumpAndSettle();
    expect(app.routeName, 'theme');
    await tester.tap(find.text('Use this theme'));
    await tester.pumpAndSettle();
    expect(app.settings.themeMode, 'custom');
    expect(app.settings.customThemes, hasLength(1));
    await _unmount(tester);
  });
}
