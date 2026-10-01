import 'languages.dart';
import 'prompt_text.dart';

/// The parsed backbone: the stage every prompt starts with, and a block per
/// level.
class PromptBackbone {
  PromptBackbone._(this.stage, this.levels);

  final String stage;
  final Map<String, String> levels;

  static final PromptBackbone instance = parse(storyPromptSource);

  static PromptBackbone parse(String source) {
    final stage = RegExp(r'<stage>([\s\S]*?)</stage>').firstMatch(source)?.group(1)?.trim() ?? '';
    final levels = <String, String>{
      for (final m in RegExp(r'<level id="([^"]+)">([\s\S]*?)</level>').allMatches(source)) m.group(1)!: m.group(2)!.trim(),
    };
    return PromptBackbone._(stage, levels);
  }

  /// The level's "Focus options" line, split into options.
  List<String> focusOptions(String level) {
    final block = levels[level] ?? '';
    final line = RegExp(r'^Focus options:\s*(.+)$', multiLine: true).firstMatch(block)?.group(1);
    if (line == null) return const [];
    return line.replaceAll(RegExp(r'\.$'), '').split(RegExp(r',\s*')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  }

  /// The level's "Reader:" line, for a one-line description.
  String reader(String level) =>
      RegExp(r'^Reader:\s*(.+)$', multiLine: true).firstMatch(levels[level] ?? '')?.group(1)?.trim() ?? '';
}

/// The story generator's choices. Each one adds, changes or removes a line
/// of the prompt; [buildPrompt] turns them into what is sent.
class GenOptions {
  String language = 'es';
  String translation = 'en';
  String level = 'A2';
  String topic = '';
  String focus = ''; // '' lets the writer pick from the level's options
  int words = 250;
  int parts = 1;
  bool child = false;
  bool translations = true;
  bool glosses = true;
  bool transliteration = true;
  bool vowelMarks = true;
  bool retelling = false;
  bool quiz = true;
  int quizCount = 4;
  String custom = '';

  static const levels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];

  /// Stops on the length dial.
  static const lengths = [80, 150, 250, 400, 600, 900];

  /// Whether a transliteration line makes sense for [language].
  bool get nonLatin => !latinLanguages.contains(language.split('-').first);

  /// Hebrew and Arabic-script languages can be written with or without
  /// vowel marks.
  bool get hasVowelMarks => const {'he', 'yi', 'ar', 'fa', 'ur'}.contains(language.split('-').first);

  bool get hebrewScript => const {'he', 'yi'}.contains(language.split('-').first);

  GenOptions();

  factory GenOptions.fromJson(Map<String, dynamic> j) {
    final o = GenOptions();
    String s(String k, String d) => j[k] is String ? j[k] as String : d;
    bool b(String k, bool d) => j[k] is bool ? j[k] as bool : d;
    int n(String k, int d) => j[k] is num ? (j[k] as num).toInt() : d;
    o.language = s('language', o.language);
    o.translation = s('translation', o.translation);
    o.level = levels.contains(j['level']) ? j['level'] as String : o.level;
    o.topic = s('topic', o.topic);
    o.focus = s('focus', o.focus);
    o.words = n('words', o.words).clamp(lengths.first, lengths.last);
    o.parts = n('parts', o.parts).clamp(1, 6);
    o.child = b('child', o.child);
    o.translations = b('translations', o.translations);
    o.glosses = b('glosses', o.glosses);
    o.transliteration = b('transliteration', o.transliteration);
    o.vowelMarks = b('vowel_marks', o.vowelMarks);
    o.retelling = b('retelling', o.retelling);
    o.quiz = b('quiz', o.quiz);
    o.quizCount = n('quiz_count', o.quizCount).clamp(1, 10);
    o.custom = s('custom', o.custom);
    return o;
  }

  Map<String, dynamic> toJson() => {
    'language': language,
    'translation': translation,
    'level': level,
    'topic': topic,
    'focus': focus,
    'words': words,
    'parts': parts,
    'child': child,
    'translations': translations,
    'glosses': glosses,
    'transliteration': transliteration,
    'vowel_marks': vowelMarks,
    'retelling': retelling,
    'quiz': quiz,
    'quiz_count': quizCount,
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

/// How the answer must be shaped so Sefer can import it. Appended after
/// the backbone.
String _outputFormat(GenOptions o) {
  final quiz = o.quiz
      ? '''
  "quiz": [
    { "question": "<statement>. <yes/no question>?", "translation": "<the same in ${languageName(o.translation)}>", "type": "yes_no", "answer": false, "explanation": "<the full-sentence answer>" }
  ]'''
      : '';
  return '''
<output>
This overrides "output only the story": reply with JSON only, with no markdown, code fences or commentary. The JSON is an array with one object per text:
{
  "title": "<a short title in ${languageName(o.language)}>",
  "language": "${o.language}",
  "translation_language": "${o.translation}",
  "tags": ["${o.level}"],
  "paragraphs": [
    { "sentences": [ { "text": "<one sentence, exactly as written>"${o.translations ? ', "translation": "<its translation>"' : ''}${o.glosses ? ', "glosses": { "<word as written>": "<meaning>" }' : ''}${o.nonLatin && o.transliteration ? ', "transliterations": { "<word as written>": "<reading in Latin letters>" }' : ''} } ] }
  ]${o.quiz ? ',' : ''}$quiz
}
Where the level asks for one sentence per line, make each sentence its own paragraph; otherwise group sentences into the paragraphs the story needs.
Leave out any field not shown here.
</output>''';
}

/// The system and user messages for [o], and both joined for copying.
({String system, String user, String full}) buildPrompt(GenOptions o, {PromptBackbone? backbone}) {
  final bb = backbone ?? PromptBackbone.instance;
  final lang = languageName(o.language);
  final trans = languageName(o.translation);

  final system = [
    '<stage>\n${bb.stage}\n</stage>',
    '<level id="${o.level}">\n${bb.levels[o.level] ?? ''}\n</level>',
    'The level descriptions use English as their example. Write in $lang and apply the equivalent vocabulary bands and grammar of $lang.',
    _outputFormat(o),
  ].join('\n\n');

  final lines = <String>[];
  final topic = o.topic.trim();
  lines.add(topic.isEmpty ? 'Write a story in $lang. Choose the subject yourself.' : 'Write a story in $lang about: $topic.');
  if (o.parts > 1) {
    lines.add('Tell it in ${o.parts} parts, each its own object in the array, titled "<title> — Part N", each continuing where the last one stopped.');
  }
  lines.add('Length: about ${o.words} words${o.parts > 1 ? ' per part' : ''}.');
  if (o.focus.trim().isNotEmpty) lines.add('Teaching focus: ${o.focus.trim()}.');
  if (o.child) lines.add('The reader is a child.');
  if (o.hasVowelMarks) {
    lines.add(o.vowelMarks
        ? 'Write with full vowel marks (${o.hebrewScript ? 'nikkud' : 'harakat'}).'
        : 'Write without vowel marks, as adults normally read.');
  }
  if (o.translations) lines.add('Translate every sentence into $trans.');
  if (o.glosses) lines.add('Gloss in $trans the words a ${o.level} reader may not know.');
  if (o.nonLatin && o.transliteration) lines.add('Transliterate every word into Latin letters.');
  if (o.retelling) {
    lines.add('Add a first-person retelling as one more object in the array, titled "<title> — retold" and tagged "retelling".');
  }
  if (o.quiz) {
    lines.add('Add ${o.quizCount} comprehension questions${o.parts > 1 ? ' per part' : ''} as the "quiz", in $lang.');
  }
  if (o.custom.trim().isNotEmpty) lines.add(o.custom.trim());
  final user = lines.join('\n');
  return (system: system, user: user, full: '$system\n\n$user');
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
