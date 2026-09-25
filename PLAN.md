# Sefer: plan

Sefer is a private, offline-first reader for learning languages, in the spirit
of LingQ. You bring the texts, read them in a calm and roomy reader, tap words
to see glosses and transliterations, and track which words you know. It uses
the visual language in [`DESIGN.md`](DESIGN.md), which was written for
"GymMane". Sefer reuses its tokens, type, motion and components. Where
DESIGN.md talks about workouts, Sefer talks about reading sessions.

## Principles

1. **Offline and private.** The Android app declares no `INTERNET`
   permission. There is no analytics, account or cloud. Everything lives in
   the app's private storage and leaves only when you export it.
2. **User-owned content.** Sefer ships no texts. Every story, translation,
   gloss, cover and theme is something you typed, pasted or imported.
3. **Honest stats.** Numbers come only from what you actually did.
4. **Every script.** RTL (Hebrew, Arabic, Persian, Urdu, Yiddish), Hebrew
   nikkud and Arabic harakat, and transliteration for non-Latin scripts.

## Features

| Area | What it does |
|---|---|
| **Reader** | Text is spaced out moderately, with adjustable font, size, line, word and paragraph spacing and page width. Tapping a word opens a sheet with its gloss, transliteration and status (new → 1–4 → known, or ignored) and your own meaning. Long-pressing a word shows the sentence translation. Transliteration can show above words, on tap, or not at all. Nikkud and harakat can be shown or hidden. Direction is automatic per language. Progress is saved per story and reading time is tracked. |
| **Library** | Stories with covers (your image, a stock doodle or a generated pattern), tags and shelves. Filter by language, shelf and tag, and search. Grid or list layout. |
| **Add tab** | Paste or type plain text, paste JSON (one story or an array for multi-text import), or import `.json` / `.txt` files, several at a time. Shows a preview and a report before saving. |
| **Words** | All your vocabulary with status, meaning, transliteration and example sentence. Filter and search. Export to Anki. |
| **Stats** | Time spent, words read, known words and sessions. A GitHub-style activity chart (squares or dots, colour ramp, cell size and gap, metric). A daily streak and a per-language streak. |
| **Settings** | Theme (dark, light, system, or **your own themes** built with a token editor). Reader typography, UI text scale, app layout (tabs shown and their order, labels, centre button, library layout), transition style (blur, fade, slide or none, with strength and duration), background pattern, activity-chart style, data export and import (full JSON backup), Anki export, and wipe data. |

## Import format

This is the JSON structure you gave. `glosses` and `transliterations` are
optional per sentence, and `translation` is optional too. A top-level array
imports several stories at once. Sefer also accepts optional `tags`,
`shelf`, `author` and `cover` (a doodle id).

```json
{
  "title": "Καλημέρα", "language": "el", "translation_language": "en",
  "paragraphs": [{ "sentences": [{
    "text": "Καλημέρα σας!", "translation": "Good morning!",
    "glosses": { "καλημέρα": "good morning" },
    "transliterations": { "καλημέρα": "kaliméra" } }] }]
}
```

Plain text is split into paragraphs on blank lines and into sentences on
terminal punctuation for every script (`. ! ? … 。 ！ ？ ؟ ۔ ।` and so on).

## Anki

- **TSV export**: `word · meaning · transliteration · sentence · translation
  · tags`, with Anki's `#separator` and `#html` headers, so both Anki
  desktop and AnkiDroid import it directly.
- **Share to AnkiDroid**: a single card can be sent through the Android share
  sheet, and AnkiDroid opens it in its note editor.

## Architecture

- **Flutter, Android only** at first. Dependencies are kept small:
  `path_provider`, `file_picker` (import, export and cover images),
  `share_plus` (send to Anki and share backups) and `phosphoricons_flutter`
  (icons). None of them needs network access.
- **State**: one `AppState` (`ChangeNotifier`) exposed through an
  `InheritedNotifier`. No state-management package.
- **Storage**: JSON documents in the app's documents directory, written
  atomically (temporary file, then rename) and debounced. The files are
  `library.json`, `vocab.json`, `activity.json`, `settings.json` and
  `covers/`. A backup is simply those files bundled into one JSON.
- **Text engine** (`lib/text/`), pure Dart and unit tested:
  - a tokenizer that treats combining marks (`\p{M}`) as part of the word,
    so nikkud, harakat and Greek accents never split a word;
  - normalisation for lookups (case fold, strip marks, Arabic tatweel,
    Hebrew final forms kept), so a gloss on `καλημέρα` matches
    `Καλημέρα`;
  - rule-based fallback transliteration for Greek, Cyrillic, Hebrew and
    Arabic when the text doesn't provide one;
  - RTL detection by language code and by script.
- **Fonts** are bundled so rendering is the same on every device: Nunito
  (UI), plus reading faces Literata, Noto Serif, Atkinson Hyperlegible,
  Noto Sans Hebrew, Frank Ruhl Libre (nikkud), Noto Naskh Arabic and Amiri
  (harakat), with a Hebrew and Arabic fallback chain for any face.

```
lib/
  main.dart
  app/        app.dart, app_shell.dart (nav bar, blur transitions), routes
  theme/      app_colors.dart (SeferColors tokens), app_theme.dart, presets
  data/       models, store (JSON files), app_state, importer, exporter, stats
  text/       tokenizer, normalize, transliterate, script/RTL
  widgets/    ui_kit, glass, notch toast, rolling text, rise, heatmap, covers
  screens/    library, reader, add, words, stats, settings
test/         text engine, importer, stats/streaks, Anki export, widget smoke
```

## Milestones

1. Scaffold, fonts, tokens, theme and UI kit.
2. Data models, storage, importer and text engine, with tests.
3. App shell: floating glass nav, customisable tabs, blur transitions.
4. Library (covers, tags, shelves) and the Add tab.
5. Reader (spacing, tap sheets, transliteration, RTL, marks, progress and
   time tracking).
6. Words and Anki export.
7. Stats (heatmap, streaks) and settings (custom themes, layout, backup).
8. Analysis, tests and polish.

## Not in scope yet

Audio, iOS, cloud sync, dictionary lookups (they need the network), and UI
translations. All UI strings live in one file (`lib/l10n/strings.dart`), so
they are ready for translation.
