import 'dart:convert';

import 'models.dart';

const backupFormat = 'sefer-backup';
const backupVersion = 1;

/// Everything the app knows, in one JSON document. Cover images are embedded
/// as base64 so a backup restores on a fresh install.
Map<String, dynamic> buildBackup({
  required Settings settings,
  required List<Story> stories,
  required List<Shelf> shelves,
  required Iterable<VocabEntry> vocab,
  required Map<String, DayActivity> activity,
  Map<String, List<int>> coverImages = const {},
}) => {
  'format': backupFormat,
  'version': backupVersion,
  'exported_at': DateTime.now().toIso8601String(),
  'settings': settings.toJson(),
  'shelves': shelves.map((s) => s.toJson()).toList(),
  'stories': stories.map((s) => s.toJson()).toList(),
  'vocab': vocab.map((v) => v.toJson()).toList(),
  'activity': activity.map((k, v) => MapEntry(k, v.toJson())),
  if (coverImages.isNotEmpty)
    'cover_images': coverImages.map((k, v) => MapEntry(k, base64Encode(v))),
};

class Backup {
  Backup({
    required this.settings,
    required this.stories,
    required this.shelves,
    required this.vocab,
    required this.activity,
    required this.coverImages,
  });
  final Settings settings;
  final List<Story> stories;
  final List<Shelf> shelves;
  final List<VocabEntry> vocab;
  final Map<String, DayActivity> activity;
  final Map<String, List<int>> coverImages;
}

bool isBackup(Object? json) => json is Map && json['format'] == backupFormat;

Backup parseBackup(Map<String, dynamic> j) {
  List<Map<String, dynamic>> list(String k) =>
      (j[k] as List? ?? []).whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
  return Backup(
    settings: j['settings'] is Map
        ? Settings.fromJson((j['settings'] as Map).cast<String, dynamic>())
        : Settings(),
    stories: list('stories').map(Story.fromJson).where((s) => s.id.isNotEmpty).toList(),
    shelves: list('shelves').map(Shelf.fromJson).toList(),
    vocab: list('vocab').map(VocabEntry.fromJson).where((v) => v.word.isNotEmpty).toList(),
    activity: (j['activity'] as Map? ?? {}).map(
      (k, v) => MapEntry('$k', DayActivity.fromJson((v as Map).cast<String, dynamic>())),
    ),
    coverImages: (j['cover_images'] as Map? ?? {}).map(
      (k, v) => MapEntry('$k', base64Decode('$v')),
    ),
  );
}

/// Stories in the import format, so they can be re-imported or shared.
String exportStories(List<Story> stories) {
  final data = stories.map((s) => s.toPortableJson()).toList();
  return const JsonEncoder.withIndent('  ').convert(data.length == 1 ? data.first : data);
}

String _cell(String s) => s
    .replaceAll('\t', ' ')
    .replaceAll('\r\n', '<br>')
    .replaceAll('\n', '<br>')
    .trim();

String _tag(String s) => s.trim().replaceAll(RegExp(r'\s+'), '_');

/// A tab-separated file that Anki (desktop and AnkiDroid) imports directly:
/// File → Import, one note per line, fields in this order:
/// word, meaning, transliteration, sentence, sentence translation, status.
String buildAnkiTsv(
  Iterable<VocabEntry> entries, {
  String deckTag = 'sefer',
  bool includeHeader = true,
}) {
  final buf = StringBuffer();
  if (includeHeader) {
    buf
      ..writeln('#separator:tab')
      ..writeln('#html:true')
      ..writeln('#columns:Word\tMeaning\tTransliteration\tSentence\tTranslation\tStatus\tTags')
      ..writeln('#tags column:7');
  }
  for (final e in entries) {
    final tags = [_tag(deckTag), 'lang::${_tag(e.language)}', 'status::${e.status}'];
    buf.writeln(
      [
        _cell(e.word),
        _cell(e.meaning),
        _cell(e.transliteration),
        _cell(e.example),
        _cell(e.exampleTranslation),
        _cell(WordStatus.label(e.status)),
        tags.join(' '),
      ].join('\t'),
    );
  }
  return buf.toString();
}

/// Plain text for a single card, used when sharing a word to AnkiDroid.
String ankiShareText(VocabEntry e) {
  final lines = <String>[
    e.word,
    if (e.transliteration.isNotEmpty) '[${e.transliteration}]',
    if (e.meaning.isNotEmpty) e.meaning,
    if (e.example.isNotEmpty) '',
    if (e.example.isNotEmpty) e.example,
    if (e.exampleTranslation.isNotEmpty) e.exampleTranslation,
  ];
  return lines.join('\n');
}
