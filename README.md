# Sefer

A private, offline-first reader for learning languages from texts you choose,
in the spirit of LingQ. Paste or import a text, read it in a calm and roomy
reader, and tap any word to see its gloss, its transliteration and how well
you know it. Words you haven't met are tinted blue and words you're learning
are tinted amber. Finishing a story marks the words you never tapped as known.

Sefer ships no content and stays offline unless you turn on the internet
switch to generate stories with your own AI key. Everything you add stays on
the device until you export it.

<p>
<img src="docs/screenshots/library_dark.png" width="200" alt="Library">
<img src="docs/screenshots/reader_word.png" width="200" alt="Reader with the word card">
<img src="docs/screenshots/reader_readmode.png" width="200" alt="Reading mode on sepia paper">
<img src="docs/screenshots/reader_hebrew.png" width="200" alt="Hebrew with nikkud and transliteration">
</p>
<p>
<img src="docs/screenshots/profile.png" width="200" alt="Profile">
<img src="docs/screenshots/settings_appearance.png" width="200" alt="App feel">
<img src="docs/screenshots/feel_compact.png" width="200" alt="Compact feel">
<img src="docs/screenshots/feel_airy.png" width="200" alt="Airy feel">
</p>
<p>
<img src="docs/screenshots/generate.png" width="200" alt="Story generator">
<img src="docs/screenshots/quiz_question.png" width="200" alt="Quiz question">
<img src="docs/screenshots/quiz_result.png" width="200" alt="Quiz score">
<img src="docs/screenshots/reader_pages.png" width="200" alt="Pages layout">
</p>
<p>
<img src="docs/screenshots/theme_gruvbox.png" width="200" alt="Gruvbox theme with the bubble dock">
<img src="docs/screenshots/theme_owl.png" width="200" alt="Owl theme with the line dock">
<img src="docs/screenshots/appearance_themes.png" width="200" alt="Themes">
<img src="docs/screenshots/settings_ai.png" width="200" alt="Internet and AI settings">
</p>
<p><img src="docs/screenshots/app_icons.png" width="420" alt="App icons: aleph and bet, plain and themed"></p>

## Features

- **Reader.** Each paragraph is drawn by a single render object (one text
  layout, highlights painted behind the glyphs, taps resolved by position),
  so long texts scroll smoothly.
  - **Learn mode:** blue and amber highlights, word levels (new, 1–4, known,
    ignored), your own meanings and notes. Double-tap a word to mark it
    known.
  - **Read mode:** plain text for skimming. A tap shows the meaning and the
    sentence translation in a small card.
  - A **compact word card** at the bottom of the screen, or the full sheet
    if you prefer it.
  - Transliteration above words or on tap. Nikkud and harakat can be shown
    or hidden. Right-to-left scripts read right to left, and the reader
    reopens where you stopped.
  - **Scroll or pages:** read one long page, or turn pages by swiping or
    tapping the edges. Paragraphs split between pages at sentence ends.
  - Paper colours (theme, paper, sepia, dusk, black). Text size, line,
    word, letter and paragraph spacing, page width, margins, bold,
    justification and indent. Highlight style (fill, underline or none)
    and strength. Fade paragraphs you've already read, keep the screen on,
    hide the bars while scrolling. "Next story" at the end.
- **Fonts.** 17 bundled reading faces:
  - Dyslexia-friendly: OpenDyslexic, Lexend, Andika, Atkinson
    Hyperlegible.
  - Hebrew: Heebo (close to SF Hebrew), Varela Round (close to SF Hebrew
    Rounded), Noto Sans Hebrew, Frank Ruhl Libre.
  - Arabic: Vazirmatn (close to SF Arabic), Baloo Bhaijaan (rounded), Noto
    Sans Arabic, Noto Naskh, Amiri.
  - You can set a different font per language, and import your own .ttf or
    .otf files.
- **Library.** One options sheet for the view (covers, shelves, list or
  titles), sort, grouping by language or shelf, favourites and filters.
  Covers can be an image, a stock doodle or a pattern. Stories get tags,
  shelves and favourites, and show time left from your own reading speed.
  Deleting a story can be undone.
- **Add.** Paste or type plain text or JSON, or import files, several at a
  time. Several texts can go in one paste, separated by `===`. Every import
  is reviewed before it's saved (tap a title to rename it), with a warning
  for duplicates.
- **Generate.** Build a prompt with chips and switches (languages, CEFR
  level, topic, kind of text, length, number of parts, translations, glosses,
  transliteration, nikkud or harakat, a quiz and its question types) plus a
  box for anything else, and send it to **Google Gemini** or **OpenRouter**
  with your own API key. The answer goes to review like any import. With the
  internet off you can copy the prompt into any AI chat and paste the answer
  back.
- **Quizzes.** Stories can carry a quiz: multiple choice, yes or no, or true
  or false, with no typed answers. Take it from the end of the story or its
  page, see each answer marked and explained, and get a score, a rating and
  your best result.
- **Words.** Your vocabulary with filters and search, and export to
  **Anki** (a TSV file, or a single card shared to AnkiDroid).
- **Stats.** Time, words read, words known, sessions and quiz results. A
  GitHub-style activity chart (shape, colours, range, cell size). A daily
  streak and a streak per language; a day counts once you've read for a
  minute (or reached your goal, if you choose).
- **Profile.** Your name and picture, the languages you study (switch the
  active one from any tab), your own language, and every setting. An
  optional **privacy mode** shows only the language you're studying now
  across the library, words and stats.
- **Make it yours.**
  - **App feel:** Classic, Minimal, Compact or Airy. Each changes spacing,
    density, corners, labels and how the library is laid out.
  - Themes: dark, light, automatic, **Gruvbox** (dark and light),
    **Catppuccin**, **Nord**, **Dracula**, **Owl** and **Owl night** (bright
    and friendly, in the Duolingo spirit), and your own from the theme
    editor. An accent colour over any theme, corner roundness, interface
    font and text size.
  - **App icon:** a black aleph or bet in Noto Serif Hebrew. Both adapt to
    Android's icon shapes and themed icons.
  - Frosted glass on or off. A nav bar with up to five tabs, an optional
    continue-reading button, and five dock styles: floating, island, bubble,
    docked and line. The tab the app opens on.
  - Screen transitions (blur, fade, slide, zoom or none).
- **Your data.** Back up everything to one file, with an optional
  reminder. Restore by merging or replacing. Export stories, export to
  Anki, or erase everything.

## Import format

One story is an object, and several stories are an array of objects. Only
`text` is required in a sentence. The other fields are optional, and
`tags`, `author` and `cover` (a doodle name such as `cup`) are also
accepted. The title comes from `title` and can be changed during review.

```json
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
  ],
  "quiz": [
    {
      "question": "Τι λέμε το πρωί;",
      "translation": "What do we say in the morning?",
      "options": ["Καληνύχτα", "Καλημέρα", "Αντίο"],
      "answer": "Καλημέρα",
      "explanation": "Καλημέρα means good morning."
    },
    { "question": "Is «σας» formal?", "type": "yes_no", "answer": true },
    { "question": "Καλημέρα means good night.", "type": "true_false", "answer": false }
  ]
}
```

`quiz` is optional and goes after the paragraphs. A multiple-choice question
has `options` and an `answer`, given as the option's text or its number
(from 0). A `yes_no` or `true_false` question has `answer` `true` or `false`.
`translation` and `explanation` are optional. Questions without a usable
answer are skipped with a note in the review. `{"questions": [...]}` works
in place of the array too. Libraries saved by older versions are upgraded
when they load.

Glosses and transliterations match words regardless of case, nikkud or
harakat, and fall back to ignoring accents. When a text has no
transliteration, Sefer generates one for Greek, Cyrillic (Russian,
Ukrainian, Bulgarian, Serbian and more), Hebrew, Arabic and Persian,
Georgian and Armenian.

## Privacy

- **Internet is off by default.** The app declares the `INTERNET`
  permission only for the story generator. Every request goes through
  `lib/data/ai.dart`, which refuses to connect while the switch in Profile →
  Internet & AI is off. With it on, Sefer connects only when you press
  Generate or load the list of models, and sends only the prompt: nothing
  from your library, words or stats.
- API keys stay on the device and are left out of backups.
- Android cloud backup is disabled, so your data isn't uploaded to your
  Google account without you knowing.
- There are no accounts, analytics, ads or crash reporting.
- Reading time only counts while the reader is open and you've touched the
  screen in the last two minutes.

## Development

This is a Flutter app for Android. See [`PLAN.md`](PLAN.md) for the
architecture and [`DESIGN.md`](DESIGN.md) for the design language it
follows.

```sh
flutter pub get
flutter analyze
flutter test                     # unit and widget tests
flutter run --release            # judge smoothness on a release build;
                                 # debug builds are much slower
flutter build apk --release

# Re-render the screenshots in tool/shots/ with the real fonts:
flutter test tool/screenshots_test.dart --update-goldens

# Re-render the launcher icons (needs Pillow):
python3 tool/icon/make_icons.py
```

The code is organised like this:

```
lib/
  app/       app root, shell (nav bar, transitions), routes
  data/      models, AppState, JSON storage, importer, exporter, stats, file IO,
             prompt builder, AI client, app icon switch
  text/      tokenizer, normalisation, transliteration, script and direction
  theme/     colour tokens, theme presets, feels and type helpers
  widgets/   UI kit, glass, toast, motion, heatmap, covers
  screens/   library, add, generator, reader, quiz, words, stats, settings,
             theme editor
```

Fonts are bundled under the SIL Open Font License (see `assets/fonts/OFL-*`);
the app icons use Noto Serif Hebrew, under the same licence
(`tool/icon/OFL-notoserifhebrew.txt`).
Icons are [Phosphor](https://phosphoricons.com).
