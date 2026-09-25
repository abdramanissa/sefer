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

// ------------------------------------------------------------------ Settings

/// Every destination that can sit in the nav bar.
const allTabs = ['library', 'add', 'words', 'stats', 'settings'];

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
  List<String> tabs = ['library', 'add', 'words', 'stats'];
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
    final tabs = _strList(j['tabs']).where(allTabs.contains).toList();
    if (j['tabs'] is List && tabs.isNotEmpty) s.tabs = tabs.take(4).toList();
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
  };
}
