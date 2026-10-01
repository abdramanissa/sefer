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
import 'package:sefer/widgets/word_text.dart';

Future<void> _loadFonts() async {
  final families = <String, List<String>>{};
  for (final f in Directory('assets/fonts').listSync().whereType<File>()) {
    final name = f.uri.pathSegments.last;
    if (!name.endsWith('.ttf') && !name.endsWith('.otf')) continue;
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
  ],
  "quiz": [
    {"question": "Πού είναι ο καφές;", "translation": "Where is the coffee?",
     "options": ["Στην κουζίνα", "Στο σαλόνι", "Στον κήπο"], "answer": "Στην κουζίνα",
     "explanation": "«Ο καφές είναι έτοιμος στην κουζίνα.»"},
    {"question": "Είναι ο καφές έτοιμος;", "translation": "Is the coffee ready?", "type": "yes_no", "answer": true},
    {"question": "Ο ομιλητής είναι άρρωστος.", "translation": "The speaker is ill.", "type": "true_false", "answer": false}
  ]
}''';

const _catalan = '''
{
  "title": "El jardí de l'àvia",
  "language": "ca",
  "translation_language": "en",
  "tags": ["A2"],
  "paragraphs": [
    {"sentences": [
      {"text": "La meva àvia té un jardí petit darrere de casa.", "translation": "My grandmother has a small garden behind the house.",
       "glosses": {"àvia": "grandmother", "jardí": "garden", "darrere": "behind"}},
      {"text": "Cada matí surt amb una tassa de cafè i mira les flors.", "translation": "Every morning she goes out with a cup of coffee and looks at the flowers.",
       "glosses": {"matí": "morning", "tassa": "cup", "flors": "flowers"}}
    ]},
    {"sentences": [
      {"text": "Diu que les plantes escolten.", "translation": "She says the plants listen."},
      {"text": "Per això els parla en veu baixa, com si fossin velles amigues.", "translation": "That's why she talks to them quietly, as if they were old friends."}
    ]}
  ]
}''';

const _market = '''
Al mercat
El dissabte anem al mercat del barri. Hi ha fruita, peix i formatge.

La venedora sempre ens dona una mandarina i ens pregunta pel gos.
''';

const _port = '''
Στο λιμάνι
Το πρωί το λιμάνι είναι ήσυχο. Οι ψαράδες γυρίζουν με τις βάρκες τους.

Μια γάτα περιμένει στην άκρη του μώλου.
''';

Future<AppState> _seed() async {
  final app = AppState(MemoryStore());
  await app.load();
  app.addStories(importText(_port, plain: const PlainTextOptions(language: 'el', tags: ['A2'])).stories);
  app.addStories(importText(_market, plain: const PlainTextOptions(language: 'ca', tags: ['A1'])).stories);
  app.addStories(importText(_catalan).stories);
  app.addStories(importText(_greek).stories);
  final covers = [
    const Cover(kind: CoverKind.doodle, doodle: 'lake', hue: 6),
    const Cover(kind: CoverKind.doodle, doodle: 'field', hue: 2),
    const Cover(kind: CoverKind.doodle, doodle: 'city', hue: 3),
    const Cover(kind: CoverKind.doodle, doodle: 'coast', hue: 1),
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
  app.setWord('ca', 'jardí', status: 1, meaning: 'garden', example: 'La meva àvia té un jardí petit darrere de casa.');
  app.setWord('ca', 'àvia', status: 4, meaning: 'grandmother');
  app.setWord('ca', 'cafè', status: WordStatus.known);
  app.settings.learning = ['el', 'ca'];
  app.settings.profileName = 'Issa';
  final r = Random(4);
  final now = DateTime.now();
  for (var d = 0; d < 180; d++) {
    if (r.nextDouble() < 0.28 && d > 6) continue;
    final day = DateTime(now.year, now.month, now.day - d);
    final secs = (r.nextDouble() * 2400).round() + 60;
    final lang = ['el', 'ca'][r.nextInt(2)];
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
      final r = t.renderObject<RenderWordText>(find.byType(WordText).first);
      await t.tapAt(r.globalRectOf(0).center);
      await t.pumpAndSettle();
    });
  });

  for (final r in ['add', 'words', 'stats', 'profile', 'settings:appearance', 'settings:layout', 'settings:reader']) {
    testWidgets('screen $r', (t) async {
      final app = await _seed();
      await shot(t, app, r.replaceAll(':', '_'), then: () async {
        app.go(r);
        await t.pumpAndSettle();
      });
    });
  }


  testWidgets('reader read mode', (t) async {
    final app = await _seed();
    app.settings.readerMode = 'read';
    app.settings.readerPaper = 'sepia';
    await shot(t, app, 'reader_readmode', then: () async {
      app.openStory(app.stories.first);
      await t.pumpAndSettle();
      final r = t.renderObject<RenderWordText>(find.byType(WordText).first);
      await t.tapAt(r.globalRectOf(2).center);
      await t.pumpAndSettle();
    });
  });

  for (final f in ['minimal', 'compact', 'airy']) {
    testWidgets('feel $f', (t) async {
      final app = await _seed();
      app.settings.feel = f;
      app.settings.libraryView = {'minimal': 'titles', 'compact': 'list', 'airy': 'shelf'}[f]!;
      if (f == 'compact') {
        app.settings.navStyle = 'docked';
        app.settings.gridColumns = 3;
      }
      if (f == 'minimal') app.settings.showCenterButton = false;
      await shot(t, app, 'feel_$f');
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

  testWidgets('reader pages', (t) async {
    final app = await _seed();
    app.settings.readerLayout = 'pages';
    final long = List.generate(12, (i) => 'La meva àvia té un jardí petit darrere de casa. Cada matí surt amb una tassa de cafè i mira les flors. Diu que les plantes escolten, per això els parla en veu baixa.').join('\n\n');
    app.addStories(importText('El jardí\n$long', plain: const PlainTextOptions(language: 'ca')).stories);
    await shot(t, app, 'reader_pages', then: () async {
      app.openStory(app.stories.firstWhere((s) => s.title == 'El jardí'));
      await t.pumpAndSettle();
      await t.tapAt(const Offset(380, 420));
      await t.pumpAndSettle();
    });
  });

  testWidgets('quiz question', (t) async {
    final app = await _seed();
    await shot(t, app, 'quiz_question', then: () async {
      app.go('quiz:${app.stories.firstWhere((s) => s.quiz.isNotEmpty).id}');
      await t.pumpAndSettle();
      await t.tap(find.text('Στο σαλόνι'));
      await t.pumpAndSettle();
    });
  });

  testWidgets('quiz result', (t) async {
    final app = await _seed();
    await shot(t, app, 'quiz_result', then: () async {
      app.go('quiz:${app.stories.firstWhere((s) => s.quiz.isNotEmpty).id}');
      await t.pumpAndSettle();
      await t.tap(find.text('Στην κουζίνα'));
      await t.pumpAndSettle();
      await t.tap(find.text('Next question'));
      await t.pumpAndSettle();
      await t.tap(find.text('Yes'));
      await t.pumpAndSettle();
      await t.tap(find.text('Next question'));
      await t.pumpAndSettle();
      await t.tap(find.text('True'));
      await t.pumpAndSettle();
      await t.tap(find.text('See my score'));
      await t.pumpAndSettle(const Duration(seconds: 2));
    });
  });

  testWidgets('generate', (t) async {
    final app = await _seed();
    app.settings
      ..internet = true
      ..geminiKey = 'x'
      ..gen.language = 'el'
      ..gen.topic = 'Food';
    await shot(t, app, 'generate', then: () async {
      app.go('generate');
      await t.pumpAndSettle();
    });
  });

  testWidgets('settings ai', (t) async {
    final app = await _seed();
    app.settings.internet = true;
    await shot(t, app, 'settings_ai', then: () async {
      app.go('settings:ai');
      await t.pumpAndSettle();
    });
  });

  testWidgets('appearance themes', (t) async {
    final app = await _seed();
    await shot(t, app, 'appearance_themes', then: () async {
      app.go('settings:appearance');
      await t.pumpAndSettle();
      await t.scrollUntilVisible(find.text('Gruvbox'), 300, scrollable: find.byType(Scrollable).first);
      await Scrollable.ensureVisible(t.element(find.text('Gruvbox')), alignment: 0.3);
      await t.pumpAndSettle();
    });
  });

  for (final th in ['gruvbox', 'owl', 'catppuccin', 'owl-night']) {
    testWidgets('theme $th', (t) async {
      final app = await _seed();
      app.settings.themeMode = th;
      app.settings.navStyle = {'gruvbox': 'bubble', 'owl': 'line', 'catppuccin': 'island', 'owl-night': 'bubble'}[th]!;
      await shot(t, app, 'theme_$th');
    });
  }

  testWidgets('dock styles', (t) async {
    final app = await _seed();
    app.settings.navStyle = 'bubble';
    await shot(t, app, 'dock_styles', then: () async {
      app.go('settings:layout');
      await t.pumpAndSettle();
      await t.scrollUntilVisible(find.text('Island'), 300, scrollable: find.byType(Scrollable).first);
      await Scrollable.ensureVisible(t.element(find.text('Island')), alignment: 0.4);
      await t.pumpAndSettle();
    });
  });

  testWidgets('reader quick', (t) async {
    final app = await _seed();
    await shot(t, app, 'reader_quick', then: () async {
      app.openStory(app.stories.first);
      await t.pumpAndSettle();
      await t.tap(find.bySemanticsLabel('Text settings'));
      await t.pumpAndSettle();
    });
  });

  testWidgets('reader more', (t) async {
    final app = await _seed();
    await shot(t, app, 'reader_more', then: () async {
      app.openStory(app.stories.first);
      await t.pumpAndSettle();
      await t.tap(find.bySemanticsLabel('Text settings'));
      await t.pumpAndSettle();
      await t.tap(find.text('More'));
      await t.pumpAndSettle();
      await t.tap(find.text('Spacing'));
      await t.pumpAndSettle();
    });
  });

  testWidgets('profile settings grid', (t) async {
    final app = await _seed();
    app.settings.lastBackupAt = DateTime.now();
    await shot(t, app, 'profile_grid', then: () async {
      app.go('profile');
      await t.pumpAndSettle();
      await t.scrollUntilVisible(find.text('Privacy & about'), 300, scrollable: find.byType(Scrollable).first);
      await Scrollable.ensureVisible(t.element(find.text('Privacy & about')), alignment: 0.7);
      await t.pumpAndSettle();
    });
  });
}
