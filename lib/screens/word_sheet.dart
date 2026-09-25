import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../data/app_state.dart';
import '../data/exporter.dart';
import '../data/io.dart';
import '../data/models.dart';
import '../text/normalize.dart';
import '../text/script.dart';
import '../text/transliterate.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/notch_toast.dart';
import '../widgets/ui_kit.dart';

/// Colour for a word status, used in the reader, the sheet and the word list.
Color statusColor(int status, SeferColors c) => switch (status) {
  WordStatus.newWord => c.info,
  WordStatus.known => c.sage,
  WordStatus.ignored => c.textTertiary,
  _ => c.warn,
};

/// Where a word's reading comes from, best first: the text itself, your saved
/// reading, then the built-in rules.
({String text, String source}) readingFor({
  required String word,
  required String language,
  Sentence? sentence,
  VocabEntry? entry,
}) {
  final fromText = sentence == null ? null : lookupLoose(sentence.transliterations, word);
  if (fromText != null && fromText.isNotEmpty) return (text: fromText, source: 'text');
  if (entry != null && entry.transliteration.isNotEmpty) return (text: entry.transliteration, source: 'yours');
  final auto = transliterate(word, language: language);
  return (text: auto, source: auto.isEmpty ? '' : 'auto');
}

/// Edits collected in the sheet, applied when it closes.
class WordDraft {
  String? meaning;
  String? note;
  String? transliteration;
}

class WordSheet extends StatefulWidget {
  const WordSheet({
    super.key,
    required this.story,
    required this.word,
    required this.sentence,
    required this.draft,
  });

  final Story story;
  final String word;
  final Sentence sentence;
  final WordDraft draft;

  @override
  State<WordSheet> createState() => _WordSheetState();
}

class _WordSheetState extends State<WordSheet> {
  late final TextEditingController _meaning;
  late final TextEditingController _note;
  late final TextEditingController _reading;
  bool _editReading = false;

  String get lang => widget.story.language;

  @override
  void initState() {
    super.initState();
    final app = context.appRead;
    final e = app.entry(lang, widget.word);
    final gloss = lookupLoose(widget.sentence.glosses, widget.word) ?? '';
    _meaning = TextEditingController(text: e?.meaning.isNotEmpty == true ? e!.meaning : '');
    _note = TextEditingController(text: e?.note ?? '');
    final r = readingFor(word: widget.word, language: lang, sentence: widget.sentence, entry: e);
    _reading = TextEditingController(text: r.text);
    if (_meaning.text.isEmpty && gloss.isNotEmpty) _meaning.text = gloss;
  }

  @override
  void dispose() {
    _meaning.dispose();
    _note.dispose();
    _reading.dispose();
    super.dispose();
  }

  void _setStatus(int status) {
    final app = context.appRead;
    Haptic.selection();
    app.setWord(
      lang,
      widget.word,
      status: status,
      meaning: status == WordStatus.newWord ? null : _meaning.text.trim(),
      example: widget.sentence.text,
      exampleTranslation: widget.sentence.translation ?? '',
      storyId: widget.story.id,
    );
    // The meaning is now saved with the status; don't apply it twice.
    widget.draft.meaning = null;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final c = context.sc;
    final e = app.entry(lang, widget.word);
    final status = app.statusOf(lang, widget.word);
    final gloss = lookupLoose(widget.sentence.glosses, widget.word);
    final reading = readingFor(word: widget.word, language: lang, sentence: widget.sentence, entry: e);
    final dir = isRtl(lang, widget.word) ? TextDirection.rtl : TextDirection.ltr;
    final font = readerFontById(app.settings.readerFont);
    final showReading = reading.text.isNotEmpty && app.settings.translit != 'off';

    return SheetBody(
      children: [
        Center(
          child: Text(
            widget.word,
            textDirection: dir,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: font.family,
              fontFamilyFallback: readerFallback,
              fontSize: 34,
              height: 1.3,
              fontWeight: FontWeight.w700,
              color: c.text,
            ),
          ),
        ),
        if (showReading || _editReading) ...[
          const SizedBox(height: 4),
          if (_editReading)
            AppField(
              controller: _reading,
              hint: 'How it reads',
              autofocus: true,
              onChanged: (v) => widget.draft.transliteration = v.trim(),
            )
          else
            Pressable(
              scale: 0.97,
              onTap: () => setState(() => _editReading = true),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      reading.text,
                      textAlign: TextAlign.center,
                      style: AppTheme.f(16, weight: FontWeight.w600, color: c.brass),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    reading.source == 'auto' ? 'AUTO' : '',
                    style: AppTheme.f(9, weight: FontWeight.w800, color: c.textTertiary, letterSpacing: 1.2),
                  ),
                  const SizedBox(width: 4),
                  Icon(PhosphorIconsRegular.pencilSimple, size: 13, color: c.textTertiary),
                ],
              ),
            ),
        ],
        if (gloss != null && gloss.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: c.info.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                Icon(PhosphorIconsFill.bookOpenText, size: 16, color: c.info),
                const SizedBox(width: 10),
                Expanded(child: Text(gloss, style: AppTheme.f(15, weight: FontWeight.w600, color: c.text))),
                Text('FROM TEXT', style: AppTheme.f(9, weight: FontWeight.w800, color: c.info, letterSpacing: 1.2)),
              ],
            ),
          ),
        ],
        const SizedBox(height: 18),
        _StatusRow(status: status, onSelect: _setStatus),
        const SizedBox(height: 16),
        AppField(
          controller: _meaning,
          label: 'Your meaning',
          hint: 'What it means to you',
          maxLines: 3,
          minLines: 1,
          onChanged: (v) => widget.draft.meaning = v.trim(),
        ),
        const SizedBox(height: 12),
        AppField(
          controller: _note,
          label: 'Note',
          hint: 'Grammar, a mnemonic, anything',
          maxLines: 3,
          minLines: 1,
          onChanged: (v) => widget.draft.note = v.trim(),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: c.bgRaised2, borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Kicker('In this sentence'),
              const SizedBox(height: 8),
              Text(
                widget.sentence.text,
                textDirection: isRtl(lang, widget.sentence.text) ? TextDirection.rtl : TextDirection.ltr,
                style: TextStyle(
                  fontFamily: font.family,
                  fontFamilyFallback: readerFallback,
                  fontSize: 16,
                  height: 1.5,
                  color: c.text,
                ),
              ),
              if (widget.sentence.translation != null) ...[
                const SizedBox(height: 6),
                Text(
                  widget.sentence.translation!,
                  style: AppTheme.f(13.5, weight: FontWeight.w500, color: c.textSecondary, height: 1.4),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: GhostButton(
                label: 'Copy',
                icon: PhosphorIconsBold.copy,
                onTap: () {
                  Clipboard.setData(ClipboardData(text: stripVowelMarks(widget.word) == widget.word ? widget.word : '${widget.word} (${stripVowelMarks(widget.word)})'));
                  showNotchToast(context, title: 'Copied', subtitle: widget.word, icon: PhosphorIconsFill.copy);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GhostButton(
                label: 'To Anki',
                icon: PhosphorIconsBold.cards,
                onTap: () async {
                  final entry = app.setWord(
                        lang,
                        widget.word,
                        status: status == WordStatus.newWord ? 1 : status,
                        meaning: _meaning.text.trim(),
                        transliteration: _reading.text.trim().isEmpty ? null : _reading.text.trim(),
                        example: widget.sentence.text,
                        exampleTranslation: widget.sentence.translation ?? '',
                        storyId: widget.story.id,
                      ) ??
                      app.entry(lang, widget.word);
                  if (entry == null) return;
                  await Io.shareText(ankiShareText(entry), subject: entry.word);
                  app.markExported([entry]);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.status, required this.onSelect});
  final int status;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    Widget cell(int s, String label, {IconData? icon}) {
      final sel = s == status;
      final col = statusColor(s, c);
      return Expanded(
        child: Semantics(
          button: true,
          selected: sel,
          label: WordStatus.label(s),
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onSelect(s),
            child: SizedBox(
              height: 48,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  height: 40,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: sel ? col : col.withValues(alpha: s == WordStatus.ignored ? 0.10 : 0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: icon != null
                      ? Icon(icon, size: 17, color: sel ? c.bg : col)
                      : Text(label, style: AppTheme.f(15, weight: FontWeight.w800, color: sel ? c.bg : col)),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Kicker('How well you know it'),
            const Spacer(),
            Text(WordStatus.label(status), style: AppTheme.f(12, weight: FontWeight.w700, color: statusColor(status, c))),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            cell(WordStatus.newWord, 'New', icon: PhosphorIconsBold.sparkle),
            cell(1, '1'),
            cell(2, '2'),
            cell(3, '3'),
            cell(4, '4'),
            cell(WordStatus.known, '', icon: PhosphorIconsBold.check),
            cell(WordStatus.ignored, '', icon: PhosphorIconsBold.prohibit),
          ],
        ),
      ],
    );
  }
}

/// Opens the word sheet and saves typed edits when it closes.
Future<void> openWordSheet(BuildContext context, {required Story story, required String word, required Sentence sentence}) async {
  final app = context.appRead;
  final draft = WordDraft();
  await showAppSheet<void>(context, (_) => WordSheet(story: story, word: word, sentence: sentence, draft: draft));
  final changed = draft.meaning != null || draft.note != null || draft.transliteration != null;
  if (!changed) return;
  final current = app.statusOf(story.language, word);
  final hasContent = [draft.meaning, draft.note, draft.transliteration].any((v) => v != null && v.isNotEmpty);
  if (current == WordStatus.newWord && !hasContent) return;
  app.setWord(
    story.language,
    word,
    // Writing a meaning for a new word starts learning it.
    status: current == WordStatus.newWord ? 1 : null,
    meaning: draft.meaning,
    note: draft.note,
    transliteration: draft.transliteration,
    example: sentence.text,
    exampleTranslation: sentence.translation ?? '',
    storyId: story.id,
  );
}
