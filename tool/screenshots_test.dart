// Renders screenshots of the main screens with the real fonts and icons.
//
//   flutter test tool/screenshots_test.dart --update-goldens
//
// PNGs land in tool/shots/. Not part of the regular test suite.
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sefer/app/app.dart';
import 'package:sefer/data/app_state.dart';
import 'package:sefer/data/importer.dart';
import 'package:sefer/data/models.dart';
import 'package:sefer/data/store.dart';

Future<void> _loadFonts() async {
  final families = <String, List<String>>{};
  for (final f in Directory('assets/fonts').listSync().whereType<File>()) {
    final name = f.uri.pathSegments.last;
    if (!name.endsWith('.ttf')) continue;
    families.putIfAbsent(name.split('-').first, () => []).add(f.path);
  }
  for (final e in families.entries) {
    final loader = FontLoader(e.key);
    for (final p in e.value) {
      loader.addFont(Future.value(ByteData.sublistView(File(p).readAsBytesSync())));
    }
    await loader.load();
  }
  final pkg = File('.dart_tool/package_config.json').readAsStringSync();
  final root = RegExp(r'"rootUri":\s*"([^"]*phosphoricons_flutter[^"]*)"').firstMatch(pkg)!.group(1)!;
  final dir = Uri.parse(root).toFilePath();
  for (final (family, file) in [('PhosphorRegular', 'Phosphor.ttf'), ('PhosphorBold', 'Phosphor-Bold.ttf'), ('PhosphorFill', 'Phosphor-Fill.ttf')]) {
    final loader = FontLoader('packages/phosphoricons_flutter/$family')
      ..addFont(Future.value(ByteData.sublistView(File('$dir/lib/fonts/$file').readAsBytesSync())));
    await loader.load();
  }
}

const _greek = '''
{
  "title": "Καλημέρα",
  "language": "el",
  "translation_language": "en",
  "tags": ["A1"],
  "paragraphs": [
    {"sentences": [
      {"text": "Καλημέρα σας!", "translation": "Good morning!",
       "glosses": {"καλημέρα": "good morning", "σας": "to you (formal)"},
       "transliterations": {"καλημέρα": "kaliméra", "σας": "sas"}},
      {"text": "Πώς είστε σήμερα;", "translation": "How are you today?",
       "glosses": {"πώς": "how", "είστε": "you are (formal)", "σήμερα": "today"}}
    ]},
    {"sentences": [
      {"text": "Είμαι πολύ καλά, ευχαριστώ.", "translation": "I am very well, thank you.",
       "glosses": {"είμαι": "I am", "πολύ": "very", "καλά": "well", "ευχαριστώ": "thank you"}},
      {"text": "Ο καφές είναι έτοιμος στην κουζίνα.", "translation": "The coffee is ready in the kitchen."}
    ]}
  ]
}''';

const _spanish = '''
El jardín de mi abuela
Mi abuela tiene un jardín pequeño detrás de su casa. Cada mañana sale con una taza de café y mira las flores.

Dice que las plantas escuchan. Por eso les habla en voz baja, como si fueran viejas amigas.
''';

const _hebrew = '''
בְּרֵאשִׁית
בְּרֵאשִׁית בָּרָא אֱלֹהִים אֵת הַשָּׁמַיִם וְאֵת הָאָרֶץ. וְהָאָרֶץ הָיְתָה תֹהוּ וָבֹהוּ.
''';

const _arabic = '''
في المقهى
ذَهَبْتُ إِلَى الْمَقْهَى صَبَاحًا. طَلَبْتُ فِنْجَانَ قَهْوَةٍ وَكِتَابًا صَغِيرًا.
''';

Future<AppState> _seed() async {
  final app = AppState(MemoryStore());
  await app.load();
  app.addStories(importText(_arabic, plain: const PlainTextOptions(language: 'ar', tags: ['cafe'])).stories);
  app.addStories(importText(_hebrew, plain: const PlainTextOptions(language: 'he', tags: ['classic'])).stories);
  app.addStories(importText(_spanish, plain: const PlainTextOptions(language: 'es', tags: ['A2'])).stories);
  app.addStories(importText(_greek).stories);
  final covers = [
    const Cover(kind: CoverKind.doodle, doodle: 'cup', hue: 6),
    const Cover(kind: CoverKind.pattern, seed: 3, hue: 1),
    const Cover(kind: CoverKind.doodle, doodle: 'flower', hue: 2),
    const Cover(kind: CoverKind.doodle, doodle: 'sun', hue: 0),
  ];
  for (var i = 0; i < app.stories.length; i++) {
    app.stories[i].cover = covers[i];
  }
  final greek = app.stories.first;
  greek.lastOpenedAt = DateTime.now();
  greek.progress = 0.4;
  app.stories[1].progress = 0.7;
  app.stories[1].lastOpenedAt = DateTime.now().subtract(const Duration(days: 1));
  app.stories[3].finishedAt = DateTime.now();
  app.stories[3].progress = 1;
  app.setWord('el', 'σήμερα', status: 2, meaning: 'today');
  app.setWord('el', 'πολύ', status: 3, meaning: 'very');
  app.setWord('el', 'Ο', status: WordStatus.known);
  app.setWord('el', 'είναι', status: WordStatus.known);
  app.setWord('es', 'jardín', status: 1, meaning: 'garden', example: 'Mi abuela tiene un jardín pequeño.');
  app.setWord('es', 'abuela', status: 4, meaning: 'grandmother');
  app.setWord('he', 'הָאָרֶץ', status: 2, meaning: 'the earth');
  final r = Random(4);
  final now = DateTime.now();
  for (var d = 0; d < 180; d++) {
    if (r.nextDouble() < 0.28 && d > 6) continue;
    final day = DateTime(now.year, now.month, now.day - d);
    final secs = (r.nextDouble() * 2400).round() + 60;
    final lang = ['el', 'es', 'he'][r.nextInt(3)];
    app.activity[dayKey(day)] = DayActivity(
      seconds: secs,
      words: secs ~/ 4,
      known: r.nextInt(20),
      sessions: 1 + r.nextInt(3),
      langSeconds: {lang: secs},
      langWords: {lang: secs ~/ 4},
    );
  }
  return app;
}

void main() {
  setUpAll(_loadFonts);

  Future<void> shot(WidgetTester tester, AppState app, String name, {Future<void> Function()? then}) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(top: 141, bottom: 102);
    tester.view.viewPadding = const FakeViewPadding(top: 141, bottom: 102);
    await tester.pumpWidget(SeferApp(state: app));
    await tester.pumpAndSettle();
    if (then != null) await then();
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/$name.png'));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    tester.view.reset();
  }

  for (final theme in ['dark', 'light']) {
    testWidgets('library $theme', (t) async {
      final app = await _seed();
      app.settings.themeMode = theme;
      await shot(t, app, 'library_$theme');
    });

    testWidgets('reader $theme', (t) async {
      final app = await _seed();
      app.settings.themeMode = theme;
      await shot(t, app, 'reader_$theme', then: () async {
        app.openStory(app.stories.first);
        await t.pumpAndSettle();
      });
    });
  }

  testWidgets('reader word sheet', (t) async {
    final app = await _seed();
    await shot(t, app, 'reader_word', then: () async {
      app.openStory(app.stories.first);
      await t.pumpAndSettle();
      await t.tap(find.descendant(of: find.byType(CustomScrollView), matching: find.text('Καλημέρα')).last);
      await t.pumpAndSettle();
    });
  });

  testWidgets('reader hebrew above', (t) async {
    final app = await _seed();
    app.settings.translit = 'above';
    app.settings.readerFont = 'frankruhl';
    await shot(t, app, 'reader_hebrew', then: () async {
      app.openStory(app.stories.firstWhere((s) => s.language == 'he'));
      await t.pumpAndSettle();
    });
  });

  testWidgets('reader arabic', (t) async {
    final app = await _seed();
    app.settings.readerFont = 'amiri';
    app.settings.sentenceTranslations = 'below';
    await shot(t, app, 'reader_arabic', then: () async {
      app.openStory(app.stories.firstWhere((s) => s.language == 'ar'));
      await t.pumpAndSettle();
    });
  });

  for (final r in ['add', 'words', 'stats', 'settings', 'settings:appearance', 'settings:layout']) {
    testWidgets('screen $r', (t) async {
      final app = await _seed();
      await shot(t, app, r.replaceAll(':', '_'), then: () async {
        app.go(r);
        await t.pumpAndSettle();
      });
    });
  }

  testWidgets('story details', (t) async {
    final app = await _seed();
    await shot(t, app, 'story', then: () async {
      app.go('story:${app.stories[2].id}');
      await t.pumpAndSettle();
    });
  });

  testWidgets('custom theme', (t) async {
    final app = await _seed();
    final th = app.createTheme(name: 'Night ink', from: app.paletteFor(Brightness.dark));
    th.colors['bg'] = const Color(0xFF0E1320);
    th.colors['bgRaised'] = const Color(0xFF182033);
    th.colors['bgRaised2'] = const Color(0xFF232C44);
    th.colors['accent'] = const Color(0xFF8FB4FF);
    app.saveTheme(th);
    await shot(t, app, 'theme_editor', then: () async {
      app.go('theme:${th.id}');
      await t.pumpAndSettle();
    });
  });
}
