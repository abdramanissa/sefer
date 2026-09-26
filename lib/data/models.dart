import 'package:flutter/material.dart';

import '../text/normalize.dart';
import '../text/tokenizer.dart';
import '../theme/app_colors.dart';

Map<String, String> _strMap(Object? v) {
  if (v is! Map) return {};
  return {
    for (final e in v.entries)
      if (e.key != null && e.value != null) '${e.key}': '${e.value}',
  };
}

List<String> _strList(Object? v) =>
    v is List ? v.whereType<Object>().map((e) => '$e').toList() : <String>[];

int _int(Object? v, [int d = 0]) => v is num ? v.toInt() : d;
double _dbl(Object? v, [double d = 0]) => v is num ? v.toDouble() : d;
bool _bool(Object? v, [bool d = false]) => v is bool ? v : d;
String _str(Object? v, [String d = '']) => v is String ? v : d;
DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;

// ------------------------------------------------------------------ Story

class Sentence {
  Sentence({
    required this.text,
    this.translation,
    Map<String, String>? glosses,
    Map<String, String>? transliterations,
  }) : glosses = glosses ?? {},
       transliterations = transliterations ?? {};

  String text;
  String? translation;
  Map<String, String> glosses;
  Map<String, String> transliterations;

  factory Sentence.fromJson(Map<String, dynamic> j) => Sentence(
    text: _str(j['text']),
    translation: (j['translation'] is String &&
            (j['translation'] as String).trim().isNotEmpty)
        ? j['translation'] as String
        : null,
    glosses: _strMap(j['glosses']),
    transliterations: _strMap(j['transliterations']),
  );

  Map<String, dynamic> toJson() => {
    'text': text,
    if (translation != null) 'translation': translation,
    if (glosses.isNotEmpty) 'glosses': glosses,
    if (transliterations.isNotEmpty) 'transliterations': transliterations,
  };
}

class Paragraph {
  Paragraph(this.sentences);
  List<Sentence> sentences;

  factory Paragraph.fromJson(Map<String, dynamic> j) => Paragraph(
    (j['sentences'] as List? ?? [])
        .whereType<Map>()
        .map((s) => Sentence.fromJson(s.cast<String, dynamic>()))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'sentences': sentences.map((s) => s.toJson()).toList(),
  };

  String get text => sentences.map((s) => s.text).join(' ');
}

enum CoverKind { pattern, doodle, image }

class Cover {
  const Cover({
    this.kind = CoverKind.pattern,
    this.seed = 0,
    this.hue = 0,
    this.doodle = 'book',
    this.imagePath,
  });

  final CoverKind kind;
  final int seed;

  /// Index into the cover palette (see `widgets/covers.dart`).
  final int hue;
  final String doodle;

  /// File name inside the app's `covers/` directory.
  final String? imagePath;

  Cover copyWith({
    CoverKind? kind,
    int? seed,
    int? hue,
    String? doodle,
    String? imagePath,
  }) => Cover(
    kind: kind ?? this.kind,
    seed: seed ?? this.seed,
    hue: hue ?? this.hue,
    doodle: doodle ?? this.doodle,
    imagePath: imagePath ?? this.imagePath,
  );

  factory Cover.fromJson(Object? v) {
    if (v is! Map) return const Cover();
    return Cover(
      kind: CoverKind.values.firstWhere(
        (k) => k.name == v['kind'],
        orElse: () => CoverKind.pattern,
      ),
      seed: _int(v['seed']),
      hue: _int(v['hue']),
      doodle: _str(v['doodle'], 'book'),
      imagePath: v['image'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'seed': seed,
    'hue': hue,
    'doodle': doodle,
    if (imagePath != null) 'image': imagePath,
  };
}

class Story {
  Story({
    required this.id,
    required this.title,
    required this.language,
    this.translationLanguage = 'en',
    this.author = '',
    required this.paragraphs,
    List<String>? tags,
    List<String>? shelves,
    this.cover = const Cover(),
    DateTime? createdAt,
    DateTime? updatedAt,
    this.lastOpenedAt,
    this.finishedAt,
    this.position = 0,
    this.progress = 0,
    this.readSeconds = 0,
    this.counted = 0,
    this.favorite = false,
  }) : tags = tags ?? [],
       shelves = shelves ?? [],
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  final String id;
  String title;
  String language;
  String translationLanguage;
  String author;
  List<Paragraph> paragraphs;
  List<String> tags;
  List<String> shelves;
  Cover cover;
  DateTime createdAt;
  DateTime updatedAt;
  DateTime? lastOpenedAt;
  DateTime? finishedAt;

  /// Index of the paragraph at the top of the reader.
  int position;

  /// 0–1, how far through the text the reader has scrolled.
  double progress;
  int readSeconds;

  /// Paragraphs already added to "words read" in this read-through.
  int counted;
  bool favorite;

  int? _wordCount;
  int get wordCount => _wordCount ??= paragraphs.fold<int>(
    0,
    (n, p) => n + p.sentences.fold<int>(0, (m, s) => m + words(s.text).length),
  );

  Set<String>? _uniqueKeys;

  /// Distinct vocabulary keys in the text.
  Set<String> get uniqueKeys => _uniqueKeys ??= {
    for (final p in paragraphs)
      for (final s in p.sentences)
        for (final w in words(s.text)) wordKey(w),
  };

  void invalidate() {
    _wordCount = null;
    _uniqueKeys = null;
  }

  int get sentenceCount =>
      paragraphs.fold(0, (n, p) => n + p.sentences.length);

  bool get hasTranslations =>
      paragraphs.any((p) => p.sentences.any((s) => s.translation != null));

  String get preview {
    final buf = StringBuffer();
    for (final p in paragraphs) {
      for (final s in p.sentences) {
        buf.write('${s.text} ');
        if (buf.length > 160) return buf.toString().trim();
      }
    }
    return buf.toString().trim();
  }

  factory Story.fromJson(Map<String, dynamic> j) => Story(
    id: _str(j['id']),
    title: _str(j['title'], 'Untitled'),
    language: _str(j['language'], 'und'),
    translationLanguage: _str(j['translation_language'], 'en'),
    author: _str(j['author']),
    paragraphs: (j['paragraphs'] as List? ?? [])
        .whereType<Map>()
        .map((p) => Paragraph.fromJson(p.cast<String, dynamic>()))
        .toList(),
    tags: _strList(j['tags']),
    shelves: _strList(j['shelves']),
    cover: Cover.fromJson(j['cover']),
    createdAt: _date(j['created_at']),
    updatedAt: _date(j['updated_at']),
    lastOpenedAt: _date(j['last_opened_at']),
    finishedAt: _date(j['finished_at']),
    position: _int(j['position']),
    progress: _dbl(j['progress']),
    readSeconds: _int(j['read_seconds']),
    counted: _int(j['counted']),
    favorite: _bool(j['favorite']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'language': language,
    'translation_language': translationLanguage,
    if (author.isNotEmpty) 'author': author,
    'paragraphs': paragraphs.map((p) => p.toJson()).toList(),
    'tags': tags,
    'shelves': shelves,
    'cover': cover.toJson(),
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    if (lastOpenedAt != null)
      'last_opened_at': lastOpenedAt!.toIso8601String(),
    if (finishedAt != null) 'finished_at': finishedAt!.toIso8601String(),
    'position': position,
    'progress': progress,
    'read_seconds': readSeconds,
    'counted': counted,
    if (favorite) 'favorite': true,
  };

  /// The portable form used by import and export: the same shape as the
  /// import format, without reading state.
  Map<String, dynamic> toPortableJson() => {
    'title': title,
    'language': language,
    'translation_language': translationLanguage,
    if (author.isNotEmpty) 'author': author,
    if (tags.isNotEmpty) 'tags': tags,
    'paragraphs': paragraphs.map((p) => p.toJson()).toList(),
  };
}

class Shelf {
  Shelf({required this.id, required this.name, DateTime? createdAt})
    : createdAt = createdAt ?? DateTime.now();

  final String id;
  String name;
  final DateTime createdAt;

  factory Shelf.fromJson(Map<String, dynamic> j) => Shelf(
    id: _str(j['id']),
    name: _str(j['name'], 'Shelf'),
    createdAt: _date(j['created_at']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'created_at': createdAt.toIso8601String(),
  };
}

// ------------------------------------------------------------------ Words

/// How well you know a word. New words have no entry at all.
class WordStatus {
  WordStatus._();
  static const ignored = -1;
  static const newWord = 0;
  static const known = 5;

  /// 1 = just met, 4 = almost known.
  static bool isLearning(int s) => s >= 1 && s <= 4;

  static String label(int s) => switch (s) {
    ignored => 'Ignored',
    newWord => 'New',
    known => 'Known',
    _ => 'Level $s',
  };
}

class VocabEntry {
  VocabEntry({
    required this.language,
    required this.word,
    this.status = 1,
    this.meaning = '',
    this.transliteration = '',
    this.note = '',
    this.example = '',
    this.exampleTranslation = '',
    this.storyId,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.exportedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  final String language;

  /// The spelling first saved, with its marks.
  String word;
  int status;
  String meaning;
  String transliteration;
  String note;
  String example;
  String exampleTranslation;
  String? storyId;
  DateTime createdAt;
  DateTime updatedAt;
  DateTime? exportedAt;

  String get key => vocabId(language, word);

  factory VocabEntry.fromJson(Map<String, dynamic> j) => VocabEntry(
    language: _str(j['language'], 'und'),
    word: _str(j['word']),
    status: _int(j['status'], 1),
    meaning: _str(j['meaning']),
    transliteration: _str(j['transliteration']),
    note: _str(j['note']),
    example: _str(j['example']),
    exampleTranslation: _str(j['example_translation']),
    storyId: j['story_id'] as String?,
    createdAt: _date(j['created_at']),
    updatedAt: _date(j['updated_at']),
    exportedAt: _date(j['exported_at']),
  );

  Map<String, dynamic> toJson() => {
    'language': language,
    'word': word,
    'status': status,
    if (meaning.isNotEmpty) 'meaning': meaning,
    if (transliteration.isNotEmpty) 'transliteration': transliteration,
    if (note.isNotEmpty) 'note': note,
    if (example.isNotEmpty) 'example': example,
    if (exampleTranslation.isNotEmpty)
      'example_translation': exampleTranslation,
    if (storyId != null) 'story_id': storyId,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    if (exportedAt != null) 'exported_at': exportedAt!.toIso8601String(),
  };
}

String vocabId(String language, String word) =>
    '${language.toLowerCase()}|${wordKey(word)}';

// ------------------------------------------------------------------ Activity

String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

DateTime dayFromKey(String k) {
  final p = k.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

class DayActivity {
  DayActivity({
    this.seconds = 0,
    this.words = 0,
    this.known = 0,
    this.saved = 0,
    this.sessions = 0,
    Map<String, int>? langSeconds,
    Map<String, int>? langWords,
  }) : langSeconds = langSeconds ?? {},
       langWords = langWords ?? {};

  int seconds;

  /// Words read (counted when you move past a paragraph or finish a story).
  int words;

  /// Words newly marked known.
  int known;

  /// Words saved to vocabulary with a meaning or a level.
  int saved;
  int sessions;
  Map<String, int> langSeconds;
  Map<String, int> langWords;

  bool get isActive => seconds > 0 || words > 0 || known > 0 || saved > 0;

  bool activeIn(String lang) =>
      (langSeconds[lang] ?? 0) > 0 || (langWords[lang] ?? 0) > 0;

  factory DayActivity.fromJson(Map<String, dynamic> j) => DayActivity(
    seconds: _int(j['seconds']),
    words: _int(j['words']),
    known: _int(j['known']),
    saved: _int(j['saved']),
    sessions: _int(j['sessions']),
    langSeconds: (j['lang_seconds'] as Map? ?? {}).map(
      (k, v) => MapEntry('$k', _int(v)),
    ),
    langWords: (j['lang_words'] as Map? ?? {}).map(
      (k, v) => MapEntry('$k', _int(v)),
    ),
  );

  Map<String, dynamic> toJson() => {
    'seconds': seconds,
    'words': words,
    'known': known,
    'saved': saved,
    'sessions': sessions,
    if (langSeconds.isNotEmpty) 'lang_seconds': langSeconds,
    if (langWords.isNotEmpty) 'lang_words': langWords,
  };
}

// ------------------------------------------------------------------ Themes

class CustomTheme {
  CustomTheme({
    required this.id,
    required this.name,
    required this.brightness,
    required this.colors,
  });

  final String id;
  String name;
  Brightness brightness;
  Map<String, Color> colors;

  SeferColors get palette => SeferColors.fromBase(brightness, colors);

  factory CustomTheme.fromJson(Map<String, dynamic> j) => CustomTheme(
    id: _str(j['id']),
    name: _str(j['name'], 'My theme'),
    brightness: j['brightness'] == 'light' ? Brightness.light : Brightness.dark,
    colors: {
      for (final e in (j['colors'] as Map? ?? {}).entries)
        if (hexToColor('${e.value}') != null)
          '${e.key}': hexToColor('${e.value}')!,
    },
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'brightness': brightness == Brightness.light ? 'light' : 'dark',
    'colors': colors.map((k, v) => MapEntry(k, colorToHex(v))),
  };
}

/// A font file the user imported. [file] lives in the app's `fonts/` folder.
class CustomFont {
  CustomFont({required this.id, required this.name, required this.file});
  final String id;
  String name;
  final String file;

  /// The family name it's registered under with the engine.
  String get family => 'user-$id';

  factory CustomFont.fromJson(Map<String, dynamic> j) =>
      CustomFont(id: _str(j['id']), name: _str(j['name'], 'Font'), file: _str(j['file']));

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'file': file};
}

// ------------------------------------------------------------------ Settings

/// Every destination that can sit in the nav bar.
const allTabs = ['library', 'add', 'words', 'stats', 'profile'];

/// Most tabs the nav bar holds.
const maxTabs = 5;

class Settings {
  Settings();

  // Appearance.
  String themeMode = 'dark'; // dark | light | system | custom
  String? customThemeId;
  List<CustomTheme> customThemes = [];
  double uiScale = 1.0;
  String background = 'dots'; // none | dots | grid

  // Reader.
  String readerFont = 'literata';
  double fontSize = 21;
  double lineHeight = 1.9;
  double wordSpacing = 5;
  double paragraphSpacing = 26;
  double maxWidth = 640;
  double sidePadding = 24;
  bool justify = false;
  String translit = 'tap'; // off | above | tap
  bool showMarks = true;
  bool highlightNew = true;
  bool highlightLearning = true;
  String sentenceTranslations = 'tap'; // off | tap | below
  bool autoKnownOnFinish = true;

  // Layout.
  List<String> tabs = ['library', 'add', 'words', 'profile'];
  bool showLabels = true;
  bool showCenterButton = true;
  String libraryView = 'grid'; // grid | list
  int gridColumns = 2;

  // Transitions.
  String transition = 'blur'; // blur | fade | slide | scale | none
  double transitionBlur = 10;
  int transitionMs = 380;

  // Activity chart.
  String heatShape = 'square'; // square | rounded | dot
  String heatRamp = 'accent'; // accent | green | blue | mono
  String heatMetric = 'time'; // time | words
  int heatWeeks = 26;
  double heatCell = 12;
  double heatGap = 3;
  bool weekStartsMonday = true;

  // Goals and behaviour.
  int dailyGoalMinutes = 15;
  bool streakNeedsGoal = false;
  String defaultTranslationLang = 'en';
  bool haptics = true;
  bool reduceMotion = false;
  bool onboarded = false;

  // Added in 0.2: feel, profile, more reader and library options.
  String feel = 'classic'; // classic | minimal | compact | airy
  bool glass = true; // frosted nav and bars
  String? accentHex; // overrides the theme's accent
  double roundness = 1.0; // 0.5 square .. 1.5 very round
  String uiFont = 'nunito'; // nunito | atkinson | lexend | rubik
  String startTab = 'last'; // last or a tab id
  String lastTab = 'library';
  String navStyle = 'floating'; // floating | docked
  String languageScope = 'all'; // all | active: only the active language shows
  bool showContinueCard = false;
  String libraryGroup = 'none'; // none | language | shelf
  String librarySort = 'recent';
  bool libraryHideFinished = false;
  bool libraryFavoritesFirst = true;
  bool libraryShowStats = true; // known % and new words on cards
  String readerMode = 'learn'; // learn | read
  String wordPopup = 'card'; // card | sheet
  String readerPaper = 'app'; // app | paper | sepia | dusk | black
  double letterSpacing = 0;
  bool boldText = false;
  bool paragraphIndent = false;
  String highlightStyle = 'fill'; // fill | underline | none
  double highlightStrength = 1.0;
  bool keepAwake = true;
  bool showReaderProgress = true;
  bool hideChromeOnScroll = true;
  bool doubleTapKnown = true; // double-tap a word to mark it known
  bool showReaderHeader = true;
  bool dimRead = false; // fade paragraphs above the one you're on
  Map<String, String> fontByLanguage = {}; // language → reader font id
  List<CustomFont> customFonts = [];
  String profileName = '';
  String profileEmoji = '';
  int profileHue = 6;
  String nativeLanguage = 'en';
  List<String> learning = []; // languages you study, in your order
  String? activeLanguage;
  DateTime? lastBackupAt;
  int backupReminderDays = 14; // 0 = never

  factory Settings.fromJson(Map<String, dynamic> j) {
    final s = Settings();
    s.themeMode = _str(j['theme_mode'], s.themeMode);
    s.customThemeId = j['custom_theme_id'] as String?;
    s.customThemes = (j['custom_themes'] as List? ?? [])
        .whereType<Map>()
        .map((t) => CustomTheme.fromJson(t.cast<String, dynamic>()))
        .toList();
    s.uiScale = _dbl(j['ui_scale'], s.uiScale).clamp(0.85, 1.3);
    s.background = _str(j['background'], s.background);
    s.readerFont = _str(j['reader_font'], s.readerFont);
    s.fontSize = _dbl(j['font_size'], s.fontSize);
    s.lineHeight = _dbl(j['line_height'], s.lineHeight);
    s.wordSpacing = _dbl(j['word_spacing'], s.wordSpacing);
    s.paragraphSpacing = _dbl(j['paragraph_spacing'], s.paragraphSpacing);
    s.maxWidth = _dbl(j['max_width'], s.maxWidth);
    s.sidePadding = _dbl(j['side_padding'], s.sidePadding);
    s.justify = _bool(j['justify'], s.justify);
    s.translit = _str(j['translit'], s.translit);
    s.showMarks = _bool(j['show_marks'], s.showMarks);
    s.highlightNew = _bool(j['highlight_new'], s.highlightNew);
    s.highlightLearning = _bool(j['highlight_learning'], s.highlightLearning);
    s.sentenceTranslations = _str(
      j['sentence_translations'],
      s.sentenceTranslations,
    );
    s.autoKnownOnFinish = _bool(j['auto_known'], s.autoKnownOnFinish);
    // Settings used to be a tab; it now lives in Profile.
    final tabs = _strList(j['tabs']).map((t) => t == 'settings' ? 'profile' : t).where(allTabs.contains).toSet().toList();
    if (j['tabs'] is List && tabs.isNotEmpty) s.tabs = tabs.take(maxTabs).toList();
    s.showLabels = _bool(j['show_labels'], s.showLabels);
    s.showCenterButton = _bool(j['center_button'], s.showCenterButton);
    s.libraryView = _str(j['library_view'], s.libraryView);
    s.gridColumns = _int(j['grid_columns'], s.gridColumns).clamp(2, 3);
    s.transition = _str(j['transition'], s.transition);
    s.transitionBlur = _dbl(j['transition_blur'], s.transitionBlur);
    s.transitionMs = _int(j['transition_ms'], s.transitionMs);
    s.heatShape = _str(j['heat_shape'], s.heatShape);
    s.heatRamp = _str(j['heat_ramp'], s.heatRamp);
    s.heatMetric = _str(j['heat_metric'], s.heatMetric);
    s.heatWeeks = _int(j['heat_weeks'], s.heatWeeks);
    s.heatCell = _dbl(j['heat_cell'], s.heatCell);
    s.heatGap = _dbl(j['heat_gap'], s.heatGap);
    s.weekStartsMonday = _bool(j['week_monday'], s.weekStartsMonday);
    s.dailyGoalMinutes = _int(j['daily_goal'], s.dailyGoalMinutes);
    s.streakNeedsGoal = _bool(j['streak_needs_goal'], s.streakNeedsGoal);
    s.defaultTranslationLang = _str(
      j['default_translation_lang'],
      s.defaultTranslationLang,
    );
    s.haptics = _bool(j['haptics'], s.haptics);
    s.reduceMotion = _bool(j['reduce_motion'], s.reduceMotion);
    s.onboarded = _bool(j['onboarded'], s.onboarded);
    s.feel = _str(j['feel'], s.feel);
    s.glass = _bool(j['glass'], s.glass);
    s.accentHex = j['accent_hex'] as String?;
    s.roundness = _dbl(j['roundness'], s.roundness).clamp(0.4, 1.6);
    s.uiFont = _str(j['ui_font'], s.uiFont);
    s.startTab = _str(j['start_tab'], s.startTab);
    s.lastTab = _str(j['last_tab'], s.lastTab);
    s.navStyle = _str(j['nav_style'], s.navStyle);
    s.languageScope = _str(j['language_scope'], s.languageScope);
    s.showContinueCard = _bool(j['continue_card'], s.showContinueCard);
    s.libraryGroup = _str(j['library_group'], s.libraryGroup);
    s.librarySort = _str(j['library_sort'], s.librarySort);
    s.libraryHideFinished = _bool(j['library_hide_finished'], s.libraryHideFinished);
    s.libraryFavoritesFirst = _bool(j['library_favorites_first'], s.libraryFavoritesFirst);
    s.libraryShowStats = _bool(j['library_show_stats'], s.libraryShowStats);
    s.readerMode = _str(j['reader_mode'], s.readerMode);
    s.wordPopup = _str(j['word_popup'], s.wordPopup);
    s.readerPaper = _str(j['reader_paper'], s.readerPaper);
    s.letterSpacing = _dbl(j['letter_spacing'], s.letterSpacing);
    s.boldText = _bool(j['bold_text'], s.boldText);
    s.paragraphIndent = _bool(j['paragraph_indent'], s.paragraphIndent);
    s.highlightStyle = _str(j['highlight_style'], s.highlightStyle);
    s.highlightStrength = _dbl(j['highlight_strength'], s.highlightStrength);
    s.keepAwake = _bool(j['keep_awake'], s.keepAwake);
    s.showReaderProgress = _bool(j['reader_progress'], s.showReaderProgress);
    s.hideChromeOnScroll = _bool(j['hide_chrome'], s.hideChromeOnScroll);
    s.doubleTapKnown = _bool(j['double_tap_known'], s.doubleTapKnown);
    s.showReaderHeader = _bool(j['reader_header'], s.showReaderHeader);
    s.dimRead = _bool(j['dim_read'], s.dimRead);
    s.fontByLanguage = _strMap(j['font_by_language']);
    s.profileName = _str(j['profile_name']);
    s.profileEmoji = _str(j['profile_emoji']);
    s.profileHue = _int(j['profile_hue'], s.profileHue);
    s.nativeLanguage = _str(j['native_language'], s.nativeLanguage);
    s.learning = _strList(j['learning']);
    s.activeLanguage = j['active_language'] as String?;
    s.backupReminderDays = _int(j['backup_reminder_days'], s.backupReminderDays);
    s.customFonts = (j['custom_fonts'] as List? ?? []).whereType<Map>().map((m) => CustomFont.fromJson(m.cast<String, dynamic>())).toList();
    s.lastBackupAt = _date(j['last_backup_at']);
    return s;
  }

  Map<String, dynamic> toJson() => {
    'theme_mode': themeMode,
    'custom_theme_id': customThemeId,
    'custom_themes': customThemes.map((t) => t.toJson()).toList(),
    'ui_scale': uiScale,
    'background': background,
    'reader_font': readerFont,
    'font_size': fontSize,
    'line_height': lineHeight,
    'word_spacing': wordSpacing,
    'paragraph_spacing': paragraphSpacing,
    'max_width': maxWidth,
    'side_padding': sidePadding,
    'justify': justify,
    'translit': translit,
    'show_marks': showMarks,
    'highlight_new': highlightNew,
    'highlight_learning': highlightLearning,
    'sentence_translations': sentenceTranslations,
    'auto_known': autoKnownOnFinish,
    'tabs': tabs,
    'show_labels': showLabels,
    'center_button': showCenterButton,
    'library_view': libraryView,
    'grid_columns': gridColumns,
    'transition': transition,
    'transition_blur': transitionBlur,
    'transition_ms': transitionMs,
    'heat_shape': heatShape,
    'heat_ramp': heatRamp,
    'heat_metric': heatMetric,
    'heat_weeks': heatWeeks,
    'heat_cell': heatCell,
    'heat_gap': heatGap,
    'week_monday': weekStartsMonday,
    'daily_goal': dailyGoalMinutes,
    'streak_needs_goal': streakNeedsGoal,
    'default_translation_lang': defaultTranslationLang,
    'haptics': haptics,
    'reduce_motion': reduceMotion,
    'onboarded': onboarded,
    'feel': feel,
    'glass': glass,
    'accent_hex': accentHex,
    'roundness': roundness,
    'ui_font': uiFont,
    'start_tab': startTab,
    'last_tab': lastTab,
    'nav_style': navStyle,
    'language_scope': languageScope,
    'continue_card': showContinueCard,
    'library_group': libraryGroup,
    'library_sort': librarySort,
    'library_hide_finished': libraryHideFinished,
    'library_favorites_first': libraryFavoritesFirst,
    'library_show_stats': libraryShowStats,
    'reader_mode': readerMode,
    'word_popup': wordPopup,
    'reader_paper': readerPaper,
    'letter_spacing': letterSpacing,
    'bold_text': boldText,
    'paragraph_indent': paragraphIndent,
    'highlight_style': highlightStyle,
    'highlight_strength': highlightStrength,
    'keep_awake': keepAwake,
    'reader_progress': showReaderProgress,
    'hide_chrome': hideChromeOnScroll,
    'double_tap_known': doubleTapKnown,
    'reader_header': showReaderHeader,
    'dim_read': dimRead,
    'font_by_language': fontByLanguage,
    'custom_fonts': customFonts.map((f) => f.toJson()).toList(),
    'profile_name': profileName,
    'profile_emoji': profileEmoji,
    'profile_hue': profileHue,
    'native_language': nativeLanguage,
    'learning': learning,
    'active_language': activeLanguage,
    'last_backup_at': lastBackupAt?.toIso8601String(),
    'backup_reminder_days': backupReminderDays,
  };
}
