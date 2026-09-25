import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../text/tokenizer.dart';
import '../theme/app_colors.dart';
import 'exporter.dart';
import 'importer.dart';
import 'models.dart';
import 'stats.dart';
import 'store.dart';

/// Per-story word counts, by status, over its distinct words.
class StoryWordStats {
  const StoryWordStats(this.total, this.known, this.learning, this.fresh);
  final int total;
  final int known;
  final int learning;
  final int fresh;

  double get knownRatio => total == 0 ? 0 : known / total;
}

/// The whole app: library, vocabulary, activity, settings and navigation.
///
/// Mutations go through methods here, which notify listeners and schedule a
/// debounced save of the documents they touched.
class AppState extends ChangeNotifier {
  AppState(this.store);

  final Store store;

  static const _library = 'library.json';
  static const _vocab = 'vocab.json';
  static const _activity = 'activity.json';
  static const _settings = 'settings.json';

  List<Story> stories = [];
  List<Shelf> shelves = [];
  final Map<String, VocabEntry> vocab = {};
  Map<String, DayActivity> activity = {};
  Settings settings = Settings();
  bool loaded = false;

  /// Bumped whenever vocabulary changes, so the reader can rebuild cheaply.
  int vocabVersion = 0;

  // ------------------------------------------------------------ persistence

  Future<void> load() async {
    final lib = await store.read(_library);
    if (lib is Map) {
      stories = (lib['stories'] as List? ?? [])
          .whereType<Map>()
          .map((m) => Story.fromJson(m.cast<String, dynamic>()))
          .toList();
      shelves = (lib['shelves'] as List? ?? [])
          .whereType<Map>()
          .map((m) => Shelf.fromJson(m.cast<String, dynamic>()))
          .toList();
    }
    final voc = await store.read(_vocab);
    if (voc is List) {
      for (final m in voc.whereType<Map>()) {
        final e = VocabEntry.fromJson(m.cast<String, dynamic>());
        if (e.word.isNotEmpty) vocab[e.key] = e;
      }
    }
    final act = await store.read(_activity);
    if (act is Map) {
      activity = act.map(
        (k, v) => MapEntry('$k', DayActivity.fromJson((v as Map).cast<String, dynamic>())),
      );
    }
    final set = await store.read(_settings);
    if (set is Map) settings = Settings.fromJson(set.cast<String, dynamic>());
    loaded = true;
    notifyListeners();
  }

  final Set<String> _dirty = {};
  Timer? _saveTimer;

  void _markDirty(String doc) {
    _dirty.add(doc);
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), flush);
  }

  Future<void> flush() async {
    _saveTimer?.cancel();
    final docs = {..._dirty};
    _dirty.clear();
    for (final d in docs) {
      switch (d) {
        case _library:
          await store.write(_library, {
            'stories': stories.map((s) => s.toJson()).toList(),
            'shelves': shelves.map((s) => s.toJson()).toList(),
          });
        case _vocab:
          await store.write(_vocab, vocab.values.map((v) => v.toJson()).toList());
        case _activity:
          await store.write(_activity, activity.map((k, v) => MapEntry(k, v.toJson())));
        case _settings:
          await store.write(_settings, settings.toJson());
      }
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }

  // ------------------------------------------------------------ settings

  void updateSettings(void Function(Settings s) change) {
    change(settings);
    _markDirty(_settings);
    notifyListeners();
  }

  SeferColors paletteFor(Brightness platform) {
    switch (settings.themeMode) {
      case 'light':
        return SeferColors.light;
      case 'system':
        return platform == Brightness.light ? SeferColors.light : SeferColors.dark;
      case 'custom':
        final t = customTheme(settings.customThemeId);
        return t?.palette ?? SeferColors.dark;
      default:
        return SeferColors.dark;
    }
  }

  CustomTheme? customTheme(String? id) {
    for (final t in settings.customThemes) {
      if (t.id == id) return t;
    }
    return null;
  }

  CustomTheme createTheme({required String name, required SeferColors from}) {
    final t = CustomTheme(
      id: newId(),
      name: name,
      brightness: from.brightness,
      colors: from.editable,
    );
    updateSettings((s) => s.customThemes.add(t));
    return t;
  }

  void saveTheme(CustomTheme t) {
    updateSettings((s) {
      final i = s.customThemes.indexWhere((x) => x.id == t.id);
      if (i >= 0) {
        s.customThemes[i] = t;
      } else {
        s.customThemes.add(t);
      }
    });
  }

  void deleteTheme(String id) {
    updateSettings((s) {
      s.customThemes.removeWhere((t) => t.id == id);
      if (s.customThemeId == id) {
        s.customThemeId = null;
        if (s.themeMode == 'custom') s.themeMode = 'dark';
      }
    });
  }

  // ------------------------------------------------------------ navigation

  /// The current screen. Tabs are plain names; deeper screens are
  /// `name:argument`, for example `reader:abc123` or `settings:reader`.
  String route = 'library';
  final List<String> _stack = [];
  String lastTab = 'library';

  /// Direction of the last move, for the shell's transition:
  /// 0 = tab to tab, 1 = deeper, -1 = back out.
  int moveDepth = 0;
  int moveSide = 1;

  static bool isTab(String r) => allTabs.contains(r);

  List<String> get visibleTabs => settings.tabs;

  void go(String r) {
    if (r == route) return;
    if (isTab(r)) {
      final order = [...visibleTabs, ...allTabs.where((t) => !visibleTabs.contains(t))];
      moveSide = order.indexOf(r) >= order.indexOf(lastTab) ? 1 : -1;
      moveDepth = isTab(route) ? 0 : -1;
      _stack.clear();
      lastTab = r;
    } else {
      moveDepth = 1;
      _stack.add(route);
    }
    route = r;
    notifyListeners();
  }

  bool get canGoBack => _stack.isNotEmpty || route != lastTab;

  /// Returns false when there is nowhere to go back to.
  bool back() {
    if (_stack.isNotEmpty) {
      moveDepth = -1;
      route = _stack.removeLast();
      notifyListeners();
      return true;
    }
    if (route != lastTab) {
      moveDepth = -1;
      route = lastTab;
      notifyListeners();
      return true;
    }
    if (route != visibleTabs.first) {
      go(visibleTabs.first);
      return true;
    }
    return false;
  }

  String? get routeArg {
    final i = route.indexOf(':');
    return i < 0 ? null : route.substring(i + 1);
  }

  String get routeName {
    final i = route.indexOf(':');
    return i < 0 ? route : route.substring(0, i);
  }

  bool get showNav => routeName != 'reader';

  // ------------------------------------------------------------ library

  Story? story(String? id) {
    for (final s in stories) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// The story to continue: the most recently opened unfinished one.
  Story? get continueStory {
    final open = stories.where((s) => s.lastOpenedAt != null && s.finishedAt == null).toList()
      ..sort((a, b) => b.lastOpenedAt!.compareTo(a.lastOpenedAt!));
    if (open.isNotEmpty) return open.first;
    final unread = stories.where((s) => s.finishedAt == null).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return unread.isEmpty ? null : unread.first;
  }

  List<String> get libraryLanguages {
    final counts = <String, int>{};
    for (final s in stories) {
      counts[s.language] = (counts[s.language] ?? 0) + 1;
    }
    return counts.keys.toList()..sort((a, b) => counts[b]!.compareTo(counts[a]!));
  }

  List<String> get allTags {
    final set = <String>{for (final s in stories) ...s.tags};
    return set.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  void addStories(List<Story> list) {
    stories.insertAll(0, list);
    _markDirty(_library);
    notifyListeners();
  }

  void touchStory(Story s) {
    s.updatedAt = DateTime.now();
    s.invalidate();
    _markDirty(_library);
    notifyListeners();
  }

  Future<void> deleteStory(String id) async {
    final s = story(id);
    if (s == null) return;
    stories.remove(s);
    if (s.cover.imagePath != null) await store.delete('covers/${s.cover.imagePath}');
    _markDirty(_library);
    notifyListeners();
  }

  Future<String> saveCoverImage(Uint8List bytes, String ext) async {
    final name = '${newId()}.${ext.toLowerCase()}';
    await store.writeBytes('covers/$name', bytes);
    return name;
  }

  String? coverPath(String name) => store.pathOf('covers/$name');

  Shelf addShelf(String name) {
    final s = Shelf(id: newId(), name: name.trim());
    shelves.add(s);
    _markDirty(_library);
    notifyListeners();
    return s;
  }

  void renameShelf(String id, String name) {
    for (final s in shelves) {
      if (s.id == id) s.name = name.trim();
    }
    _markDirty(_library);
    notifyListeners();
  }

  void deleteShelf(String id) {
    shelves.removeWhere((s) => s.id == id);
    for (final st in stories) {
      st.shelves.remove(id);
    }
    _markDirty(_library);
    notifyListeners();
  }

  void toggleShelf(Story story, String shelfId) {
    if (!story.shelves.remove(shelfId)) story.shelves.add(shelfId);
    _markDirty(_library);
    notifyListeners();
  }

  void renameTag(String from, String to) {
    final t = to.trim();
    for (final s in stories) {
      final i = s.tags.indexOf(from);
      if (i < 0) continue;
      if (t.isEmpty || s.tags.contains(t)) {
        s.tags.removeAt(i);
      } else {
        s.tags[i] = t;
      }
    }
    _markDirty(_library);
    notifyListeners();
  }

  // ------------------------------------------------------------ reading

  void openStory(Story s) {
    s.lastOpenedAt = DateTime.now();
    if (s.finishedAt != null && s.progress >= 0.999) {
      // Starting again: count words afresh.
      s.position = 0;
      s.progress = 0;
      s.counted = 0;
    }
    _day().sessions++;
    _markDirty(_library);
    _markDirty(_activity);
    go('reader:${s.id}');
  }

  /// Saves the reading position and counts paragraphs passed as read.
  void updatePosition(Story s, int paragraph, double progress) {
    s.position = paragraph;
    s.progress = progress.clamp(0, 1);
    if (paragraph > s.counted) {
      var n = 0;
      for (var i = s.counted; i < paragraph && i < s.paragraphs.length; i++) {
        n += s.paragraphs[i].sentences.fold(0, (m, x) => m + words(x.text).length);
      }
      s.counted = paragraph;
      _addWords(s.language, n);
    }
    _markDirty(_library);
  }

  /// Adds active reading time. Called by the reader once per tick.
  void addReadingTime(Story s, int seconds) {
    if (seconds <= 0) return;
    s.readSeconds += seconds;
    final d = _day();
    d.seconds += seconds;
    d.langSeconds[s.language] = (d.langSeconds[s.language] ?? 0) + seconds;
    _markDirty(_library);
    _markDirty(_activity);
    notifyListeners();
  }

  /// Marks a story finished. Remaining new words become known when the
  /// setting asks for it. Returns how many words were marked known.
  int finishStory(Story s) {
    updatePosition(s, s.paragraphs.length, 1);
    s.finishedAt = DateTime.now();
    var marked = 0;
    if (settings.autoKnownOnFinish) {
      final seen = <String>{};
      for (final p in s.paragraphs) {
        for (final sentence in p.sentences) {
          for (final w in words(sentence.text)) {
            final id = vocabId(s.language, w);
            if (!seen.add(id) || vocab.containsKey(id)) continue;
            if (!_isWordish(w)) continue;
            vocab[id] = VocabEntry(
              language: s.language,
              word: w,
              status: WordStatus.known,
              storyId: s.id,
            );
            marked++;
          }
        }
      }
      if (marked > 0) {
        _day().known += marked;
        vocabVersion++;
        _markDirty(_vocab);
      }
    }
    _markDirty(_library);
    _markDirty(_activity);
    notifyListeners();
    return marked;
  }

  void resetProgress(Story s) {
    s.position = 0;
    s.progress = 0;
    s.counted = 0;
    s.finishedAt = null;
    _markDirty(_library);
    notifyListeners();
  }

  bool _isWordish(String w) => !RegExp(r'^[\p{N}]+$', unicode: true).hasMatch(w);

  DayActivity _day([DateTime? d]) =>
      activity.putIfAbsent(dayKey(d ?? DateTime.now()), DayActivity.new);

  void _addWords(String lang, int n) {
    if (n <= 0) return;
    final d = _day();
    d.words += n;
    d.langWords[lang] = (d.langWords[lang] ?? 0) + n;
    _markDirty(_activity);
  }

  // ------------------------------------------------------------ vocabulary

  VocabEntry? entry(String language, String word) => vocab[vocabId(language, word)];

  int statusOf(String language, String word) {
    if (!_isWordish(word)) return WordStatus.known;
    return vocab[vocabId(language, word)]?.status ?? WordStatus.newWord;
  }

  /// Creates or updates the entry for [word]. Returns the entry, or null when
  /// the word was reset to new.
  VocabEntry? setWord(
    String language,
    String word, {
    int? status,
    String? meaning,
    String? transliteration,
    String? note,
    String? example,
    String? exampleTranslation,
    String? storyId,
  }) {
    final id = vocabId(language, word);
    var e = vocab[id];
    final before = e?.status ?? WordStatus.newWord;
    if (status == WordStatus.newWord) {
      vocab.remove(id);
      vocabVersion++;
      _markDirty(_vocab);
      notifyListeners();
      return null;
    }
    final isNew = e == null;
    e ??= VocabEntry(language: language, word: word, storyId: storyId);
    if (status != null) e.status = status;
    if (meaning != null) e.meaning = meaning;
    if (transliteration != null) e.transliteration = transliteration;
    if (note != null) e.note = note;
    if (example != null && (e.example.isEmpty || isNew)) e.example = example;
    if (exampleTranslation != null && (e.exampleTranslation.isEmpty || isNew)) {
      e.exampleTranslation = exampleTranslation;
    }
    e.updatedAt = DateTime.now();
    vocab[id] = e;
    final d = _day();
    if (isNew && WordStatus.isLearning(e.status)) d.saved++;
    if (before != WordStatus.known && e.status == WordStatus.known) d.known++;
    vocabVersion++;
    _markDirty(_vocab);
    _markDirty(_activity);
    notifyListeners();
    return e;
  }

  void deleteWord(VocabEntry e) {
    vocab.remove(e.key);
    vocabVersion++;
    _markDirty(_vocab);
    notifyListeners();
  }

  void markExported(Iterable<VocabEntry> list) {
    final now = DateTime.now();
    for (final e in list) {
      e.exportedAt = now;
    }
    _markDirty(_vocab);
    notifyListeners();
  }

  StoryWordStats wordStats(Story s) {
    var known = 0, learning = 0, fresh = 0;
    for (final k in s.uniqueKeys) {
      final e = vocab['${s.language.toLowerCase()}|$k'];
      final st = e?.status ?? WordStatus.newWord;
      if (st == WordStatus.known || st == WordStatus.ignored) {
        known++;
      } else if (WordStatus.isLearning(st)) {
        learning++;
      } else {
        fresh++;
      }
    }
    return StoryWordStats(s.uniqueKeys.length, known, learning, fresh);
  }

  int knownCount([String? language]) => vocab.values
      .where((e) => e.status == WordStatus.known && (language == null || e.language == language))
      .length;

  int learningCount([String? language]) => vocab.values
      .where((e) => WordStatus.isLearning(e.status) && (language == null || e.language == language))
      .length;

  List<String> get vocabLanguages {
    final set = <String>{for (final e in vocab.values) e.language};
    return set.toList()..sort();
  }

  // ------------------------------------------------------------ stats

  DayTest get streakTest => dailyTest(
    needsGoal: settings.streakNeedsGoal,
    goalMinutes: settings.dailyGoalMinutes,
  );

  int get dailyStreak => currentStreak(activity, DateTime.now(), streakTest);

  int languageStreak(String lang) =>
      currentStreak(activity, DateTime.now(), languageTest(lang));

  /// Languages you have read in, most recent first.
  List<String> get activeLanguages {
    final last = <String, String>{};
    for (final e in activity.entries) {
      for (final l in e.value.langSeconds.keys) {
        if ((last[l] ?? '').compareTo(e.key) < 0) last[l] = e.key;
      }
      for (final l in e.value.langWords.keys) {
        if ((last[l] ?? '').compareTo(e.key) < 0) last[l] = e.key;
      }
    }
    return last.keys.toList()..sort((a, b) => last[b]!.compareTo(last[a]!));
  }

  DayActivity get today => activity[dayKey(DateTime.now())] ?? DayActivity();

  // ------------------------------------------------------------ backup

  Future<Map<String, dynamic>> backup() async {
    final images = <String, List<int>>{};
    for (final s in stories) {
      final name = s.cover.imagePath;
      if (name == null) continue;
      final bytes = await store.readBytes('covers/$name');
      if (bytes != null) images[name] = bytes;
    }
    return buildBackup(
      settings: settings,
      stories: stories,
      shelves: shelves,
      vocab: vocab.values,
      activity: activity,
      coverImages: images,
    );
  }

  /// Restores a backup. With [merge], stories and words are added to what is
  /// here (existing ids and words win); otherwise everything is replaced.
  Future<void> restore(Backup b, {required bool merge}) async {
    for (final e in b.coverImages.entries) {
      await store.writeBytes('covers/${e.key}', Uint8List.fromList(e.value));
    }
    if (merge) {
      final ids = stories.map((s) => s.id).toSet();
      stories.addAll(b.stories.where((s) => !ids.contains(s.id)));
      final shelfIds = shelves.map((s) => s.id).toSet();
      shelves.addAll(b.shelves.where((s) => !shelfIds.contains(s.id)));
      for (final v in b.vocab) {
        vocab.putIfAbsent(v.key, () => v);
      }
      for (final e in b.activity.entries) {
        activity.putIfAbsent(e.key, () => e.value);
      }
      final themeIds = settings.customThemes.map((t) => t.id).toSet();
      settings.customThemes.addAll(
        b.settings.customThemes.where((t) => !themeIds.contains(t.id)),
      );
    } else {
      stories = b.stories;
      shelves = b.shelves;
      vocab
        ..clear()
        ..addEntries(b.vocab.map((v) => MapEntry(v.key, v)));
      activity = b.activity;
      settings = b.settings..onboarded = true;
    }
    vocabVersion++;
    _dirty.addAll([_library, _vocab, _activity, _settings]);
    await flush();
    notifyListeners();
  }

  Future<void> wipe() async {
    await store.wipe();
    stories = [];
    shelves = [];
    vocab.clear();
    activity = {};
    settings = Settings();
    vocabVersion++;
    route = 'library';
    lastTab = 'library';
    _stack.clear();
    notifyListeners();
  }
}

/// Gives the widget tree access to [AppState] and rebuilds dependents when it
/// notifies.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Reads the state without subscribing to changes.
  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

extension AppStateContext on BuildContext {
  AppState get app => AppScope.of(this);
  AppState get appRead => AppScope.read(this);
}
