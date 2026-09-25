import 'dart:convert';
import 'dart:math';

import '../text/script.dart';
import '../text/tokenizer.dart';
import 'languages.dart';
import 'models.dart';

final _rand = Random();

String newId() =>
    DateTime.now().microsecondsSinceEpoch.toRadixString(36) +
    _rand.nextInt(1 << 30).toRadixString(36);

class ImportResult {
  ImportResult(this.stories, this.problems);
  final List<Story> stories;

  /// Human-readable notes about skipped or repaired input.
  final List<String> problems;

  bool get isEmpty => stories.isEmpty;
}

/// Options for plain text, which carries no metadata of its own.
class PlainTextOptions {
  const PlainTextOptions({
    this.title = '',
    this.language = 'und',
    this.translationLanguage = 'en',
    this.tags = const [],
  });
  final String title;
  final String language;
  final String translationLanguage;
  final List<String> tags;
}

/// A line made of `===` or `---` (three or more) separates stories in pasted
/// plain text, so several texts can be imported in one go.
final storySeparator = RegExp(r'^\s*(={3,}|-{3,})\s*$', multiLine: true);

bool looksLikeJson(String s) {
  final t = s.trimLeft();
  return t.startsWith('{') || t.startsWith('[');
}

/// Imports JSON (one story, an array, or `{"stories": [...]}`) or plain text.
ImportResult importText(String input, {PlainTextOptions plain = const PlainTextOptions()}) {
  final text = input.replaceFirst('﻿', '');
  if (text.trim().isEmpty) return ImportResult([], ['Nothing to import.']);
  if (looksLikeJson(text)) {
    try {
      return importJson(jsonDecode(text));
    } on FormatException catch (e) {
      return ImportResult([], ['This looks like JSON but it does not parse: ${e.message}.']);
    }
  }
  return importPlain(text, plain);
}

ImportResult importJson(Object? data, {String fallbackLanguage = 'und'}) {
  final problems = <String>[];
  final items = switch (data) {
    List l => l,
    Map m when m['stories'] is List => m['stories'] as List,
    Map m => [m],
    _ => const [],
  };
  if (items.isEmpty) {
    return ImportResult([], ['No stories found. Expected an object or an array of objects.']);
  }
  final stories = <Story>[];
  for (var i = 0; i < items.length; i++) {
    final item = items[i];
    final label = items.length > 1 ? 'Item ${i + 1}' : 'The story';
    if (item is! Map) {
      problems.add('$label is not an object, skipped.');
      continue;
    }
    final story = _storyFromMap(item.cast<String, dynamic>(), label, problems, fallbackLanguage);
    if (story != null) stories.add(story);
  }
  return ImportResult(stories, problems);
}

Sentence? _sentence(Object? s) {
  if (s is String) return s.trim().isEmpty ? null : Sentence(text: s.trim());
  if (s is Map) {
    final sentence = Sentence.fromJson(s.cast<String, dynamic>());
    sentence.text = sentence.text.trim();
    return sentence.text.isEmpty ? null : sentence;
  }
  return null;
}

List<Paragraph> _paragraphsFromPlain(String text) => splitParagraphs(text)
    .map((p) => Paragraph(splitSentences(p).map((s) => Sentence(text: s)).toList()))
    .where((p) => p.sentences.isNotEmpty)
    .toList();

Story? _storyFromMap(
  Map<String, dynamic> m,
  String label,
  List<String> problems,
  String fallbackLanguage,
) {
  var paragraphs = <Paragraph>[];
  final raw = m['paragraphs'];
  if (raw is List) {
    for (final p in raw) {
      final List? sentences = switch (p) {
        Map pm => pm['sentences'] as List?,
        List pl => pl,
        _ => null,
      };
      if (p is String) {
        paragraphs.addAll(_paragraphsFromPlain(p));
        continue;
      }
      final parsed = (sentences ?? const []).map(_sentence).whereType<Sentence>().toList();
      if (parsed.isNotEmpty) paragraphs.add(Paragraph(parsed));
    }
  } else if (m['sentences'] is List) {
    final parsed = (m['sentences'] as List).map(_sentence).whereType<Sentence>().toList();
    if (parsed.isNotEmpty) paragraphs.add(Paragraph(parsed));
  } else if (m['text'] is String) {
    paragraphs = _paragraphsFromPlain(m['text'] as String);
  }
  if (paragraphs.isEmpty) {
    problems.add('$label has no text, skipped.');
    return null;
  }

  var language = (m['language'] as String?)?.trim() ?? '';
  if (language.isEmpty) {
    language = _guessLanguage(paragraphs.first.text) ?? fallbackLanguage;
    problems.add(
      '$label has no "language"; using ${language == 'und' ? 'unknown' : languageName(language)}.',
    );
  }
  var title = (m['title'] as String?)?.trim() ?? '';
  if (title.isEmpty) {
    title = _titleFrom(paragraphs.first.sentences.first.text);
  }
  final tags = m['tags'] is List
      ? (m['tags'] as List).map((t) => '$t'.trim()).where((t) => t.isNotEmpty).toList()
      : <String>[];
  final cover = m['cover'];
  return Story(
    id: newId(),
    title: title,
    language: language.toLowerCase(),
    translationLanguage: ((m['translation_language'] as String?) ?? 'en').toLowerCase(),
    author: (m['author'] as String?)?.trim() ?? '',
    paragraphs: paragraphs,
    tags: tags,
    cover: cover is String
        ? Cover(kind: CoverKind.doodle, doodle: cover, hue: _rand.nextInt(8))
        : Cover(seed: _rand.nextInt(1 << 20), hue: _rand.nextInt(8)),
  );
}

ImportResult importPlain(String text, PlainTextOptions o) {
  final pieces = text
      .split(storySeparator)
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty && !storySeparator.hasMatch(p))
      .toList();
  final stories = <Story>[];
  final problems = <String>[];
  for (var i = 0; i < pieces.length; i++) {
    var body = pieces[i];
    var title = pieces.length == 1 ? o.title.trim() : '';
    // A short first line without end punctuation reads as a title.
    final lines = body.split('\n');
    if (title.isEmpty && lines.length > 1) {
      final first = lines.first.trim();
      if (first.length <= 80 && !RegExp(r'[.!?…。！？؟:]$').hasMatch(first)) {
        title = first;
        body = lines.skip(1).join('\n');
      }
    }
    final paragraphs = _paragraphsFromPlain(body);
    if (paragraphs.isEmpty) continue;
    if (title.isEmpty) title = _titleFrom(paragraphs.first.sentences.first.text);
    if (pieces.length > 1 && o.title.trim().isNotEmpty) {
      title = '${o.title.trim()} · $title';
    }
    var language = o.language;
    if (language == 'und') language = _guessLanguage(body) ?? 'und';
    stories.add(
      Story(
        id: newId(),
        title: title,
        language: language,
        translationLanguage: o.translationLanguage,
        paragraphs: paragraphs,
        tags: [...o.tags],
        cover: Cover(seed: _rand.nextInt(1 << 20), hue: _rand.nextInt(8)),
      ),
    );
  }
  if (stories.isEmpty) problems.add('No readable text found.');
  return ImportResult(stories, problems);
}

String _titleFrom(String sentence) {
  final w = words(sentence);
  final t = w.take(6).join(' ');
  return w.length > 6 ? '$t…' : t;
}

/// A script-level guess, only used when the input says nothing. Latin-script
/// languages can't be told apart this way, so they stay unknown.
String? _guessLanguage(String sample) => switch (dominantScript(sample)) {
  Script.greek => 'el',
  Script.hebrew => 'he',
  Script.arabic => 'ar',
  Script.georgian => 'ka',
  Script.armenian => 'hy',
  Script.devanagari => 'hi',
  Script.thai => 'th',
  Script.hangul => 'ko',
  Script.kana => 'ja',
  Script.han => 'zh',
  Script.cyrillic => 'ru',
  _ => null,
};
