import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../data/app_state.dart';
import '../data/models.dart';
import '../text/normalize.dart';
import '../text/script.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/feel.dart';
import '../widgets/ui_kit.dart';
import 'word_sheet.dart';

/// A small card at the bottom of the reader: the word, its reading and
/// meaning, and (in learning mode) its level. The text stays visible above
/// it; "More" opens the full sheet.
class WordCard extends StatelessWidget {
  const WordCard({
    super.key,
    required this.story,
    required this.word,
    required this.sentence,
    required this.readMode,
    required this.onClose,
    required this.onMore,
    this.sentenceOnly = false,
  });

  final Story story;
  final String word;
  final Sentence sentence;
  final bool readMode;
  final bool sentenceOnly;
  final VoidCallback onClose;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final c = context.sc;
    final feel = context.feel;
    final set = app.settings;
    final lang = story.language;
    final entry = app.entry(lang, word);
    final status = app.statusOf(lang, word);
    final gloss = lookupLoose(sentence.glosses, word);
    final meaning = (entry?.meaning.isNotEmpty ?? false) ? entry!.meaning : gloss;
    final reading = readingFor(word: word, language: lang, sentence: sentence, entry: entry);
    final font = readerFontFor(set.fontByLanguage, set.readerFont, lang);
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    final dir = isRtl(lang, word) ? TextDirection.rtl : TextDirection.ltr;
    final showSentence = sentenceOnly || readMode;

    return GestureDetector(
      // Taps inside the card must not fall through to the page behind.
      onTap: () {},
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 0, 12, bottom + 12),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 14, 10, 14),
              decoration: BoxDecoration(
                color: c.bgRaised,
                borderRadius: BorderRadius.circular(feel.r(24)),
                border: Border.all(color: c.border.withValues(alpha: 0.6)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: c.isDark ? 0.45 : 0.12), blurRadius: 28, offset: const Offset(0, 10))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // The word gets the room it needs; the reading takes
                      // what's left.
                      Expanded(
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 10,
                          children: [
                            Text(
                              sentenceOnly ? 'Sentence' : word,
                              textDirection: sentenceOnly ? null : dir,
                              style: sentenceOnly
                                  ? AppTheme.f(15, weight: FontWeight.w800, color: c.text)
                                  : TextStyle(fontFamily: font.family, fontFamilyFallback: readerFallback, fontSize: 24, fontWeight: FontWeight.w700, color: c.text, height: 1.2),
                            ),
                            if (!sentenceOnly && reading.text.isNotEmpty && set.translit != 'off')
                              Text(reading.text, style: AppTheme.f(14, weight: FontWeight.w600, color: c.brass)),
                          ],
                        ),
                      ),
                      if (!sentenceOnly) _IconBtn(icon: PhosphorIconsBold.arrowsOutSimple, label: 'All details', onTap: onMore),
                      _IconBtn(icon: PhosphorIconsBold.x, label: 'Close', onTap: onClose),
                    ],
                  ),
                  if (!sentenceOnly) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        meaning == null || meaning.isEmpty ? 'No meaning yet. Open details to add one.' : meaning,
                        style: AppTheme.f(15, weight: meaning == null ? FontWeight.w500 : FontWeight.w600, color: meaning == null ? c.textTertiary : c.text, height: 1.3),
                      ),
                    ),
                  ],
                  if (showSentence) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(color: c.bgRaised2, borderRadius: BorderRadius.circular(feel.r(14))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (sentenceOnly) ...[
                            Text(
                              sentence.text,
                              textDirection: isRtl(lang, sentence.text) ? TextDirection.rtl : TextDirection.ltr,
                              style: TextStyle(fontFamily: font.family, fontFamilyFallback: readerFallback, fontSize: 16, height: 1.45, color: c.text),
                            ),
                            const SizedBox(height: 6),
                          ],
                          Text(
                            sentence.translation ?? 'This sentence has no translation yet. Long-press in learning mode to add one.',
                            style: AppTheme.f(13.5, weight: FontWeight.w500, color: sentence.translation == null ? c.textTertiary : c.textSecondary, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (!readMode && !sentenceOnly) ...[
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _Levels(
                        status: status,
                        onSelect: (st) {
                          Haptic.selection();
                          app.setWord(
                            lang,
                            word,
                            status: st,
                            meaning: st == WordStatus.newWord ? null : (entry?.meaning.isNotEmpty ?? false ? null : gloss),
                            example: sentence.text,
                            exampleTranslation: sentence.translation ?? '',
                            storyId: story.id,
                          );
                        },
                      ),
                    ),
                  ],
                  if (readMode && !sentenceOnly && status == WordStatus.newWord) ...[
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GhostButton(
                        label: 'Save to my words',
                        icon: PhosphorIconsBold.bookmarkSimple,
                        onTap: () {
                          app.setWord(lang, word, status: 1, meaning: gloss ?? '', example: sentence.text, exampleTranslation: sentence.translation ?? '', storyId: story.id);
                          onClose();
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(width: 40, height: 40, child: Icon(icon, size: 16, color: context.sc.textSecondary)),
    ),
  );
}

class _Levels extends StatelessWidget {
  const _Levels({required this.status, required this.onSelect});
  final int status;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    final feel = context.feel;
    Widget cell(int s, {String? label, IconData? icon}) {
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
              height: 44,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 34,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: sel ? col : col.withValues(alpha: s == WordStatus.ignored ? 0.10 : 0.16),
                    borderRadius: BorderRadius.circular(feel.r(10)),
                  ),
                  child: icon != null
                      ? Icon(icon, size: 15, color: sel ? c.bg : col)
                      : Text(label!, style: AppTheme.f(14, weight: FontWeight.w800, color: sel ? c.bg : col)),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        cell(WordStatus.newWord, icon: PhosphorIconsBold.sparkle),
        cell(1, label: '1'),
        cell(2, label: '2'),
        cell(3, label: '3'),
        cell(4, label: '4'),
        cell(WordStatus.known, icon: PhosphorIconsBold.check),
        cell(WordStatus.ignored, icon: PhosphorIconsBold.prohibit),
      ],
    );
  }
}
