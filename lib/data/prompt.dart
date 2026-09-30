import 'languages.dart';

/// The story generator's choices. Every option adds, changes or removes a
/// line of the prompt; [buildPrompt] turns them into what is sent.
class GenOptions {
  String language = 'es';
  String translation = 'en';
  String level = 'A2';
  String topic = '';
  String kind = 'story';
  String length = 'medium';
  int parts = 1;
  bool translations = true;
  bool glosses = true;
  bool allGlosses = false;
  bool transliteration = true;
  bool vowelMarks = true;
  bool quiz = true;
  int quizCount = 5;
  Set<String> quizKinds = {'choice', 'yes_no', 'true_false'};
  bool dialogue = false;
  bool simpleGrammar = false;
  bool culture = false;
  String custom = '';

  static const levels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];

  static const kinds = {
    'story': 'Story',
    'dialogue': 'Dialogue',
    'diary': 'Diary entry',
    'news': 'News article',
    'letter': 'Letter',
    'fairy': 'Fairy tale',
    'description': 'Description',
    'essay': 'Short essay',
  };

  static const lengths = {
    'short': ('Short', 120),
    'medium': ('Medium', 250),
    'long': ('Long', 450),
    'xl': ('Very long', 800),
  };

  static const topics = [
    'Daily life', 'Food', 'Travel', 'Family', 'Work', 'School', 'Friendship',
    'Nature', 'City life', 'History', 'Science', 'Mystery', 'Adventure',
    'Humour', 'Sport', 'Music', 'Holidays', 'Health', 'Technology', 'Folklore',
  ];

  static const quizKindLabels = {
    'choice': 'Multiple choice',
    'yes_no': 'Yes / no',
    'true_false': 'True / false',
  };

  /// Whether a transliteration line makes sense for [language].
  bool get nonLatin => !latinLanguages.contains(language.split('-').first);

  /// Hebrew and Arabic-script languages can be written with or without
  /// vowel marks.
  bool get hasVowelMarks => const {'he', 'yi', 'ar', 'fa', 'ur'}.contains(language.split('-').first);

  factory GenOptions.fromJson(Map<String, dynamic> j) {
    final o = GenOptions();
    String s(String k, String d) => j[k] is String ? j[k] as String : d;
    bool b(String k, bool d) => j[k] is bool ? j[k] as bool : d;
    int n(String k, int d) => j[k] is num ? (j[k] as num).toInt() : d;
    o.language = s('language', o.language);
    o.translation = s('translation', o.translation);
    o.level = levels.contains(j['level']) ? j['level'] as String : o.level;
    o.topic = s('topic', o.topic);
    o.kind = kinds.containsKey(j['kind']) ? j['kind'] as String : o.kind;
    o.length = lengths.containsKey(j['length']) ? j['length'] as String : o.length;
    o.parts = n('parts', o.parts).clamp(1, 8);
    o.translations = b('translations', o.translations);
    o.glosses = b('glosses', o.glosses);
    o.allGlosses = b('all_glosses', o.allGlosses);
    o.transliteration = b('transliteration', o.transliteration);
    o.vowelMarks = b('vowel_marks', o.vowelMarks);
    o.quiz = b('quiz', o.quiz);
    o.quizCount = n('quiz_count', o.quizCount).clamp(1, 15);
    if (j['quiz_kinds'] is List) {
      final k = (j['quiz_kinds'] as List).whereType<String>().where(quizKindLabels.containsKey).toSet();
      if (k.isNotEmpty) o.quizKinds = k;
    }
    o.dialogue = b('dialogue', o.dialogue);
    o.simpleGrammar = b('simple_grammar', o.simpleGrammar);
    o.culture = b('culture', o.culture);
    o.custom = s('custom', o.custom);
    return o;
  }

  GenOptions();

  Map<String, dynamic> toJson() => {
    'language': language,
    'translation': translation,
    'level': level,
    'topic': topic,
    'kind': kind,
    'length': length,
    'parts': parts,
    'translations': translations,
    'glosses': glosses,
    'all_glosses': allGlosses,
    'transliteration': transliteration,
    'vowel_marks': vowelMarks,
    'quiz': quiz,
    'quiz_count': quizCount,
    'quiz_kinds': quizKinds.toList(),
    'dialogue': dialogue,
    'simple_grammar': simpleGrammar,
    'culture': culture,
    'custom': custom,
  };
}

/// Languages normally written in the Latin alphabet.
const latinLanguages = {
  'af', 'ca', 'cs', 'cy', 'da', 'de', 'en', 'eo', 'es', 'et', 'eu', 'fi', //
  'fr', 'ga', 'gl', 'hr', 'hu', 'id', 'is', 'it', 'la', 'lt', 'lv', 'ms', //
  'mt', 'nl', 'no', 'nb', 'nn', 'pl', 'pt', 'ro', 'sk', 'sl', 'sq', 'sv', //
  'sw', 'tl', 'tr', 'uz', 'vi', 'yo', 'zu', 'und',
};

const _levelGuide = {
  'A1': 'Use very short sentences, the present tense, and only the most common words. Repeat key words.',
  'A2': 'Use short, simple sentences, common everyday words, and mostly present and past tenses.',
  'B1': 'Use clear sentences of moderate length and everyday vocabulary with some less common words.',
  'B2': 'Use natural sentences of varied length, a broad vocabulary and a range of tenses.',
  'C1': 'Write naturally, with complex sentences, idioms and precise vocabulary.',
  'C2': 'Write as for an educated native reader, with rich style and nuance.',
};

/// What the model is told about the output format.
const formatSpec = '''
Reply with JSON only: no markdown, no code fences, no commentary.
The JSON is an array with one object per text, each shaped like this:
{
  "title": "Title in the text's language",
  "language": "<ISO 639-1 code>",
  "translation_language": "<ISO 639-1 code>",
  "tags": ["<level>", "<topic>"],
  "paragraphs": [
    {
      "sentences": [
        {
          "text": "One sentence exactly as it appears in the text.",
          "translation": "Its translation.",
          "glosses": { "word": "meaning" },
          "transliterations": { "word": "reading in Latin letters" }
        }
      ]
    }
  ],
  "quiz": [
    { "question": "…", "translation": "…", "options": ["…", "…", "…"], "answer": "the correct option, copied exactly" },
    { "question": "…", "translation": "…", "type": "yes_no", "answer": true },
    { "question": "…", "translation": "…", "type": "true_false", "answer": false }
  ]
}
Keys in "glosses" and "transliterations" are words exactly as written in that sentence.
Leave out any field the instructions don't ask for.''';

/// The system and user messages for [o].
({String system, String user}) buildPrompt(GenOptions o) {
  final lang = languageName(o.language);
  final trans = languageName(o.translation);
  final (_, words) = GenOptions.lengths[o.length] ?? ('Medium', 250);
  final kind = (GenOptions.kinds[o.kind] ?? 'Story').toLowerCase();
  final lines = <String>[];

  if (o.parts > 1) {
    lines.add(
      'Write a $kind in $lang (${o.language}) in ${o.parts} parts. Each part is its '
      'own object in the array, continues where the last one stopped, and is titled '
      '"<title> — Part N".',
    );
  } else {
    lines.add('Write one $kind in $lang (${o.language}).');
  }
  lines.add('The reader is learning $lang at CEFR level ${o.level}. ${_levelGuide[o.level]}');
  if (o.topic.trim().isNotEmpty) lines.add('Topic: ${o.topic.trim()}.');
  lines.add('Length: about $words words${o.parts > 1 ? ' per part' : ''}, in several short paragraphs.');
  if (o.dialogue && o.kind != 'dialogue') lines.add('Include some dialogue between characters.');
  if (o.simpleGrammar) lines.add('Avoid rare grammar; prefer the forms a learner meets first.');
  if (o.culture) lines.add('Weave in real cultural details from places where $lang is spoken.');
  if (o.hasVowelMarks) {
    lines.add(o.vowelMarks
        ? 'Write the text with full vowel marks (${o.language == 'he' || o.language == 'yi' ? 'nikkud' : 'harakat'}).'
        : 'Write the text without vowel marks, as adults normally read it.');
  }

  if (o.translations) {
    lines.add('Give every sentence a "translation" into $trans.');
  }
  if (o.glosses) {
    lines.add(o.allGlosses
        ? 'Give "glosses" in $trans for every word of every sentence.'
        : 'Give "glosses" in $trans for the words a ${o.level} learner may not know.');
  }
  if (o.nonLatin && o.transliteration) {
    lines.add('Give "transliterations" in Latin letters for every word.');
  }
  if (o.quiz && o.quizKinds.isNotEmpty) {
    final kinds = o.quizKinds.map((k) => GenOptions.quizKindLabels[k]!.toLowerCase()).join(', ');
    lines.add(
      'After the paragraphs${o.parts > 1 ? ' of each part' : ''}, add a "quiz" of ${o.quizCount} '
      'questions about the text ($kinds). Questions and options are in $lang, each with a '
      '"translation" of the question into $trans. Every question has exactly one right answer '
      'and no written answers.',
    );
  }
  lines.add('Set "language" to "${o.language}", "translation_language" to "${o.translation}", '
      'and "tags" to ["${o.level}"${o.topic.trim().isEmpty ? '' : ', "${o.topic.trim().toLowerCase()}"'}].');
  if (o.custom.trim().isNotEmpty) lines.add('Also: ${o.custom.trim()}');

  return (
    system: 'You write graded reading texts for language learners.\n$formatSpec',
    user: lines.join('\n'),
  );
}

/// Pulls the JSON out of a model's reply, which may be wrapped in code
/// fences or prose despite the instructions.
String extractJson(String reply) {
  var t = reply.trim();
  final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(t);
  if (fence != null) t = fence.group(1)!.trim();
  final start = t.indexOf(RegExp(r'[\[{]'));
  if (start > 0) t = t.substring(start);
  final end = t.lastIndexOf(RegExp(r'[\]}]'));
  if (end >= 0 && end < t.length - 1) t = t.substring(0, end + 1);
  return t;
}
