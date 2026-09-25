import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../data/app_state.dart';
import '../data/exporter.dart';
import '../data/io.dart';
import '../data/languages.dart';
import '../data/models.dart';
import '../text/script.dart';
import '../text/transliterate.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/notch_toast.dart';
import '../widgets/ui_kit.dart';
import 'word_sheet.dart';

class WordsScreen extends StatefulWidget {
  const WordsScreen({super.key});

  @override
  State<WordsScreen> createState() => _WordsScreenState();
}

class _WordsFilters {
  static String query = '';
  static String? language;
  static String status = 'learning'; // learning | known | ignored | all
  static String sort = 'recent'; // recent | alpha | level
}

class _WordsScreenState extends State<WordsScreen> {
  int _limit = 150;

  List<VocabEntry> _visible(AppState app) {
    final q = _WordsFilters.query.trim().toLowerCase();
    final list = app.vocab.values.where((e) {
      if (_WordsFilters.language != null && e.language != _WordsFilters.language) return false;
      switch (_WordsFilters.status) {
        case 'learning':
          if (!WordStatus.isLearning(e.status)) return false;
        case 'known':
          if (e.status != WordStatus.known) return false;
        case 'ignored':
          if (e.status != WordStatus.ignored) return false;
      }
      if (q.isNotEmpty) {
        final hay = '${e.word} ${e.meaning} ${e.transliteration} ${e.note}'.toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();
    switch (_WordsFilters.sort) {
      case 'alpha':
        list.sort((a, b) => a.word.toLowerCase().compareTo(b.word.toLowerCase()));
      case 'level':
        list.sort((a, b) => a.status.compareTo(b.status));
      default:
        list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final c = context.sc;
    final list = _visible(app);
    final langs = app.vocabLanguages;
    final lang = _WordsFilters.language;
    return PageScroll(
      id: 'words',
      children: [
        TabHeader(
          kicker: '${app.knownCount(lang)} known · ${app.learningCount(lang)} learning',
          title: 'Words',
          actions: [
            RoundBtn(icon: PhosphorIconsRegular.export, label: 'Export to Anki', onTap: () => showAnkiExport(context)),
            const SettingsAction(),
          ],
        ),
        const SizedBox(height: 20),
        if (app.vocab.isEmpty)
          const EmptyState(
            icon: PhosphorIconsRegular.cards,
            title: 'No words yet',
            body: 'Tap a word while reading to give it a meaning and a level. '
                'Finishing a story marks the words you didn\'t tap as known.',
          )
        else ...[
          Row(
            children: [
              Expanded(child: _Count(label: 'Learning', value: app.learningCount(lang), color: c.warn)),
              const SizedBox(width: 10),
              Expanded(child: _Count(label: 'Known', value: app.knownCount(lang), color: c.sage)),
            ],
          ),
          const SizedBox(height: 16),
          SearchField(
            initial: _WordsFilters.query,
            hint: 'Search words, meanings, notes',
            onChanged: (v) => setState(() => _WordsFilters.query = v),
          ),
          const SizedBox(height: 12),
          SegToggle<String>(
            value: _WordsFilters.status,
            expand: true,
            options: const {'learning': 'Learning', 'known': 'Known', 'ignored': 'Ignored', 'all': 'All'},
            onChanged: (v) => setState(() {
              _WordsFilters.status = v;
              _limit = 150;
            }),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                Pill(
                  label: switch (_WordsFilters.sort) { 'alpha' => 'A–Z', 'level' => 'By level', _ => 'Recent' },
                  icon: PhosphorIconsBold.sortAscending,
                  onTap: () async {
                    final v = await pickOption<String>(
                      context,
                      title: 'Sort words',
                      selected: _WordsFilters.sort,
                      items: const [
                        OptionItem('recent', 'Recently changed'),
                        OptionItem('alpha', 'Alphabetical'),
                        OptionItem('level', 'By level'),
                      ],
                    );
                    if (v != null) setState(() => _WordsFilters.sort = v);
                  },
                ),
                if (langs.length > 1)
                  for (final l in langs) ...[
                    const SizedBox(width: 8),
                    Pill(
                      label: languageName(l),
                      selected: lang == l,
                      onTap: () => setState(() => _WordsFilters.language = lang == l ? null : l),
                    ),
                  ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Text(
                'No words here.',
                textAlign: TextAlign.center,
                style: AppTheme.f(13.5, weight: FontWeight.w500, color: c.textSecondary),
              ),
            )
          else
            ToolGroup(
              children: [for (final e in list.take(_limit)) _WordRow(entry: e)],
            ),
          if (list.length > _limit) ...[
            const SizedBox(height: 14),
            GhostButton(label: 'Show more (${list.length - _limit})', onTap: () => setState(() => _limit += 300)),
          ],
        ],
      ],
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.label, required this.value, required this.color});
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: c.bgRaised, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(child: StatValue(value: '$value', label: label)),
        ],
      ),
    );
  }
}

class _WordRow extends StatelessWidget {
  const _WordRow({required this.entry});
  final VocabEntry entry;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    final e = entry;
    final reading = e.transliteration.isNotEmpty ? e.transliteration : transliterate(e.word, language: e.language);
    return Pressable(
      scale: 0.985,
      onTap: () => showWordEditor(context, e),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: statusColor(e.status, c).withValues(alpha: 0.16), shape: BoxShape.circle),
              child: e.status == WordStatus.known
                  ? Icon(PhosphorIconsBold.check, size: 13, color: c.sage)
                  : e.status == WordStatus.ignored
                  ? Icon(PhosphorIconsBold.prohibit, size: 13, color: c.textTertiary)
                  : Text('${e.status}', style: AppTheme.f(13, weight: FontWeight.w800, color: c.warn)),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          e.word,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textDirection: isRtl(e.language, e.word) ? TextDirection.rtl : TextDirection.ltr,
                          style: AppTheme.f(16, weight: FontWeight.w700, color: c.text),
                        ),
                      ),
                      if (reading.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            reading,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.f(12.5, weight: FontWeight.w600, color: c.brass),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (e.meaning.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      e.meaning,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.f(13, weight: FontWeight.w500, color: c.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            LangBadge(e.language),
          ],
        ),
      ),
    );
  }
}

Future<void> showWordEditor(BuildContext context, VocabEntry e) {
  final app = context.appRead;
  final meaning = TextEditingController(text: e.meaning);
  final reading = TextEditingController(text: e.transliteration);
  final note = TextEditingController(text: e.note);
  return showAppSheet<void>(
    context,
    (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final c = ctx.sc;
        void save({int? status}) {
          app.setWord(
            e.language,
            e.word,
            status: status,
            meaning: meaning.text.trim(),
            transliteration: reading.text.trim(),
            note: note.text.trim(),
          );
          setState(() {});
        }

        final dir = isRtl(e.language, e.word) ? TextDirection.rtl : TextDirection.ltr;
        return SheetBody(
          title: e.word,
          subtitle: '${languageName(e.language)} · ${WordStatus.label(e.status)}',
          footer: Row(
            children: [
              Expanded(
                child: GhostButton(
                  label: 'Delete',
                  icon: PhosphorIconsBold.trash,
                  color: c.danger,
                  onTap: () {
                    app.deleteWord(e);
                    Navigator.pop(ctx);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GhostButton(
                  label: 'To Anki',
                  icon: PhosphorIconsBold.cards,
                  onTap: () async {
                    save();
                    await Io.shareText(ankiShareText(e), subject: e.word);
                    app.markExported([e]);
                  },
                ),
              ),
            ],
          ),
          children: [
            SegToggle<int>(
              value: e.status,
              expand: true,
              options: const {1: '1', 2: '2', 3: '3', 4: '4', WordStatus.known: 'Known', WordStatus.ignored: 'Ignore'},
              onChanged: (v) => save(status: v),
            ),
            const SizedBox(height: 16),
            AppField(controller: meaning, label: 'Meaning', maxLines: 3, minLines: 1, onChanged: (_) => save()),
            const SizedBox(height: 12),
            AppField(controller: reading, label: 'Reading', hint: transliterate(e.word, language: e.language), onChanged: (_) => save()),
            const SizedBox(height: 12),
            AppField(controller: note, label: 'Note', maxLines: 4, minLines: 1, onChanged: (_) => save()),
            if (e.example.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: c.bgRaised2, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Kicker('Seen in'),
                    const SizedBox(height: 8),
                    Text(e.example, textDirection: dir, style: AppTheme.s(15, color: c.text, height: 1.5)),
                    if (e.exampleTranslation.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(e.exampleTranslation, style: AppTheme.f(13, weight: FontWeight.w500, color: c.textSecondary)),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    ),
  );
}

/// Anki export: choose which words, then save or share a TSV that Anki and
/// AnkiDroid import directly (File → Import).
Future<void> showAnkiExport(BuildContext context) async {
  final app = context.appRead;
  var which = 'learning';
  String? lang = _WordsFilters.language;
  var onlyNew = false;
  await showAppSheet<void>(
    context,
    (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final c = ctx.sc;
        final entries = app.vocab.values.where((e) {
          if (lang != null && e.language != lang) return false;
          if (onlyNew && e.exportedAt != null) return false;
          return switch (which) {
            'learning' => WordStatus.isLearning(e.status),
            'known' => e.status == WordStatus.known,
            _ => e.status != WordStatus.ignored,
          };
        }).toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        final name = 'sefer-${lang ?? 'all'}-$which-${stamp()}.tsv';

        Future<void> run(bool share) async {
          final tsv = buildAnkiTsv(entries, deckTag: 'sefer${lang == null ? '' : '_$lang'}');
          if (share) {
            await Io.shareFile(name, tsv, mime: 'text/tab-separated-values');
            app.markExported(entries);
          } else {
            final ok = await Io.saveText(name, tsv, mime: 'text/tab-separated-values');
            if (ok) {
              app.markExported(entries);
              if (ctx.mounted) showNotchToast(ctx, title: '${entries.length} cards saved', subtitle: name, icon: PhosphorIconsFill.cards);
            }
          }
        }

        return SheetBody(
          title: 'Export to Anki',
          subtitle: 'Tab-separated, ready for Anki and AnkiDroid',
          children: [
            SegToggle<String>(
              value: which,
              expand: true,
              options: const {'learning': 'Learning', 'known': 'Known', 'all': 'All'},
              onChanged: (v) => setState(() => which = v),
            ),
            const SizedBox(height: 14),
            ToolGroup(
              color: c.bgRaised2,
              radius: 18,
              children: [
                ToolRow(
                  icon: PhosphorIconsRegular.translate,
                  label: 'Language',
                  value: lang == null ? 'All' : languageName(lang!),
                  onTap: () async {
                    final v = await pickOption<String>(
                      ctx,
                      title: 'Language',
                      selected: lang ?? '*',
                      items: [
                        const OptionItem('*', 'All languages'),
                        for (final l in app.vocabLanguages) OptionItem(l, languageName(l)),
                      ],
                    );
                    if (v != null) setState(() => lang = v == '*' ? null : v);
                  },
                ),
                ToolRow(
                  icon: PhosphorIconsRegular.clockCounterClockwise,
                  label: 'Only words not exported yet',
                  trailing: TinySwitch(value: onlyNew, onChanged: (v) => setState(() => onlyNew = v)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Fields: word, meaning, reading, sentence, translation, level. '
              'Tags carry the language and level. In Anki choose File → Import and '
              'map the fields to your note type.',
              textAlign: TextAlign.center,
              style: AppTheme.f(12, weight: FontWeight.w500, color: c.textTertiary, height: 1.4),
            ),
            const SizedBox(height: 18),
            PrimaryButton(
              label: entries.isEmpty ? 'No words to export' : 'Save ${entries.length} cards',
              icon: PhosphorIconsBold.floppyDisk,
              onTap: entries.isEmpty ? null : () => run(false),
            ),
            const SizedBox(height: 10),
            GhostButton(
              label: 'Share to AnkiDroid or another app',
              icon: PhosphorIconsBold.shareNetwork,
              onTap: entries.isEmpty ? null : () => run(true),
            ),
          ],
        );
      },
    ),
  );
}
