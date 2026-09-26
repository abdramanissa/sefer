import 'dart:math';

import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../data/app_state.dart';
import '../data/io.dart';
import '../data/languages.dart';
import '../data/models.dart';
import '../text/script.dart';
import '../text/tokenizer.dart';
import '../theme/app_colors.dart';
import '../widgets/common.dart';
import '../widgets/covers.dart';
import '../widgets/notch_toast.dart';
import '../widgets/ui_kit.dart';
import 'library_screen.dart';
import 'story_actions.dart';

/// Details of one story: cover, title, languages, tags, shelves and text.
class StoryScreen extends StatefulWidget {
  const StoryScreen({super.key, required this.id});
  final String id;

  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> {
  late final TextEditingController _title;
  late final TextEditingController _author;
  final _tag = TextEditingController();

  @override
  void initState() {
    super.initState();
    final s = context.appRead.story(widget.id);
    _title = TextEditingController(text: s?.title ?? '');
    _author = TextEditingController(text: s?.author ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _author.dispose();
    _tag.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final c = context.sc;
    final s = app.story(widget.id);
    if (s == null) {
      return PageScroll(id: 'story-missing', children: [
        ScreenHeader(title: 'Story', onBack: app.back),
        const EmptyState(icon: PhosphorIconsRegular.question, title: 'This story no longer exists'),
      ]);
    }
    final ws = app.wordStats(s);
    final dir = isRtl(s.language, s.title) ? TextDirection.rtl : TextDirection.ltr;
    return PageScroll(
      id: 'story',
      children: [
        ScreenHeader(
          title: 'Details',
          subtitle: languageName(s.language),
          onBack: app.back,
          actions: [
            RoundBtn(icon: PhosphorIconsBold.dotsThree, label: 'More', onTap: () => showStoryActions(context, s)),
          ],
        ),
        const SizedBox(height: 22),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Pressable(
              scale: 0.97,
              onTap: () => _editCover(s),
              child: SizedBox(
                width: 112,
                height: 150,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    StoryCover(cover: s.cover, title: s.title, imagePath: coverImagePath(app, s)),
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: c.bg.withValues(alpha: 0.75), shape: BoxShape.circle),
                        child: Icon(PhosphorIconsBold.pencilSimple, size: 13, color: c.text),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StatValue(value: '${s.wordCount}', label: 'Words'),
                  const SizedBox(height: 12),
                  StatValue(value: '${(ws.knownRatio * 100).round()}', unit: '%', label: 'Known'),
                  const SizedBox(height: 12),
                  StatValue(value: '${ws.fresh}', label: 'New words'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        PrimaryButton(
          label: s.lastOpenedAt == null ? 'Start reading' : 'Continue',
          icon: PhosphorIconsFill.bookOpenText,
          onTap: () => app.openStory(s),
        ),
        const SizedBox(height: 26),
        AppField(
          controller: _title,
          label: 'Title',
          textDirection: dir,
          onChanged: (v) {
            s.title = v.trim().isEmpty ? 'Untitled' : v.trim();
            app.touchStory(s);
          },
        ),
        const SizedBox(height: 14),
        AppField(
          controller: _author,
          label: 'Author or source',
          hint: 'Optional',
          onChanged: (v) {
            s.author = v.trim();
            app.touchStory(s);
          },
        ),
        const SizedBox(height: 22),
        const Kicker('Languages'),
        const SizedBox(height: 10),
        ToolGroup(
          children: [
            ToolRow(
              icon: PhosphorIconsRegular.translate,
              label: 'Text language',
              value: languageName(s.language),
              onTap: () async {
                final l = await pickLanguage(context, title: 'Text language', selected: s.language);
                if (l != null) {
                  s.language = l;
                  app.touchStory(s);
                }
              },
            ),
            ToolRow(
              icon: PhosphorIconsRegular.chatsCircle,
              label: 'Translations in',
              value: languageName(s.translationLanguage),
              onTap: () async {
                final l = await pickLanguage(context, title: 'Translation language', selected: s.translationLanguage);
                if (l != null) {
                  s.translationLanguage = l;
                  app.touchStory(s);
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 22),
        const Kicker('Tags'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in s.tags)
              Pill(
                label: '#$t',
                icon: PhosphorIconsBold.x,
                onTap: () {
                  s.tags.remove(t);
                  app.touchStory(s);
                },
              ),
            Pill(
              label: 'Add tag',
              icon: PhosphorIconsBold.plus,
              onTap: () async {
                final t = await askText(context, title: 'Add tag', hint: 'e.g. A2, news, poetry', action: 'Add');
                if (t != null && t.isNotEmpty && !s.tags.contains(t)) {
                  s.tags.add(t);
                  app.touchStory(s);
                }
              },
            ),
          ],
        ),
        if (app.allTags.where((t) => !s.tags.contains(t)).isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in app.allTags.where((t) => !s.tags.contains(t)).take(12))
                Pill(
                  label: '+ $t',
                  dense: true,
                  bg: Colors.transparent,
                  fg: c.textTertiary,
                  onTap: () {
                    s.tags.add(t);
                    app.touchStory(s);
                  },
                ),
            ],
          ),
        ],
        const SizedBox(height: 22),
        const Kicker('Shelves'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final sh in app.shelves)
              Pill(
                label: sh.name,
                selected: s.shelves.contains(sh.id),
                onTap: () => app.toggleShelf(s, sh.id),
              ),
            Pill(label: 'New shelf', icon: PhosphorIconsBold.plus, onTap: () => showStoryShelves(context, s)),
          ],
        ),
        const SizedBox(height: 26),
        const Kicker('Text'),
        const SizedBox(height: 10),
        ToolGroup(
          children: [
            ToolRow(
              icon: PhosphorIconsRegular.textAlignLeft,
              label: 'Edit text',
              detail: 'Translations and glosses stay on sentences you don\'t change',
              onTap: () => _editText(s),
            ),
            ToolRow(
              icon: PhosphorIconsRegular.info,
              label: 'Contents',
              value: '${s.paragraphs.length} ¶ · ${s.sentenceCount} sentences',
            ),
            if (s.readSeconds > 0)
              ToolRow(
                icon: PhosphorIconsRegular.timer,
                label: 'Time spent reading',
                value: _dur(s.readSeconds),
              ),
          ],
        ),
      ],
    );
  }

  String _dur(int s) => s >= 3600 ? '${s ~/ 3600} h ${(s % 3600) ~/ 60} min' : '${max(1, s ~/ 60)} min';

  Future<void> _editCover(Story s) async {
    final app = context.appRead;
    await showAppSheet<void>(
      context,
      (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final c = ctx.sc;
          void set(Cover cover) {
            s.cover = cover;
            app.touchStory(s);
            setState(() {});
          }

          return SheetBody(
            title: 'Cover',
            children: [
              Center(
                child: SizedBox(
                  width: 120,
                  height: 160,
                  child: StoryCover(cover: s.cover, title: s.title, imagePath: coverImagePath(app, s)),
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: SegToggle<CoverKind>(
                  value: s.cover.kind,
                  options: const {CoverKind.pattern: 'Pattern', CoverKind.doodle: 'Doodle', CoverKind.image: 'Image'},
                  onChanged: (k) async {
                    if (k == CoverKind.image) {
                      final f = await Io.pickImage();
                      if (f == null) return;
                      final name = await app.saveCoverImage(f.bytes, f.extension.isEmpty ? 'jpg' : f.extension);
                      final old = s.cover.imagePath;
                      set(Cover(kind: CoverKind.image, imagePath: name, hue: s.cover.hue, seed: s.cover.seed, doodle: s.cover.doodle));
                      if (old != null) await app.store.delete('covers/$old');
                    } else {
                      set(s.cover.copyWith(kind: k));
                    }
                  },
                ),
              ),
              const SizedBox(height: 20),
              const Kicker('Colour'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (var i = 0; i < coverHues.length; i++)
                    Semantics(
                      button: true,
                      selected: s.cover.hue == i,
                      label: 'Colour ${i + 1}',
                      child: Pressable(
                        scale: 0.9,
                        onTap: () => set(s.cover.copyWith(hue: i)),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: coverTone(i, c).paper,
                            shape: BoxShape.circle,
                            border: Border.all(color: s.cover.hue == i ? c.ember : c.border, width: s.cover.hue == i ? 2.5 : 1),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if (s.cover.kind == CoverKind.pattern) ...[
                const SizedBox(height: 18),
                GhostButton(
                  label: 'Shuffle pattern',
                  icon: PhosphorIconsBold.shuffle,
                  onTap: () => set(s.cover.copyWith(seed: Random().nextInt(1 << 20))),
                ),
              ],
              if (s.cover.kind == CoverKind.doodle) ...[
                const SizedBox(height: 18),
                const Kicker('Doodle'),
                const SizedBox(height: 10),
                GridView.count(
          padding: EdgeInsets.zero,
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  children: [
                    for (final d in doodles)
                      Semantics(
                        button: true,
                        selected: s.cover.doodle == d,
                        label: d,
                        child: Pressable(
                          scale: 0.92,
                          onTap: () => set(s.cover.copyWith(doodle: d)),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: s.cover.doodle == d ? c.ember : Colors.transparent, width: 2),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CustomPaint(
                                painter: DoodlePainter(d, coverTone(s.cover.hue, c).ink, coverTone(s.cover.hue, c).paper, coverTone(s.cover.hue, c).soft),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              if (s.cover.kind == CoverKind.image) ...[
                const SizedBox(height: 18),
                GhostButton(
                  label: 'Choose another image',
                  icon: PhosphorIconsBold.image,
                  onTap: () async {
                    final f = await Io.pickImage();
                    if (f == null) return;
                    final name = await app.saveCoverImage(f.bytes, f.extension.isEmpty ? 'jpg' : f.extension);
                    final old = s.cover.imagePath;
                    set(s.cover.copyWith(kind: CoverKind.image, imagePath: name));
                    if (old != null && old != name) await app.store.delete('covers/$old');
                  },
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _editText(Story s) async {
    final app = context.appRead;
    final original = s.paragraphs.map((p) => p.sentences.map((x) => x.text).join(' ')).join('\n\n');
    final ctl = TextEditingController(text: original);
    final dir = isRtl(s.language, s.title) ? TextDirection.rtl : TextDirection.ltr;
    final result = await showAppSheet<String>(
      context,
      (ctx) => SheetBody(
        title: 'Edit text',
        subtitle: 'Blank lines separate paragraphs',
        footer: PrimaryButton(label: 'Save text', onTap: () => Navigator.pop(ctx, ctl.text)),
        children: [
          AppField(controller: ctl, maxLines: null, minLines: 10, textDirection: dir),
        ],
      ),
    );
    if (result == null || result.trim().isEmpty || result == original) return;
    final old = <String, Sentence>{
      for (final p in s.paragraphs)
        for (final x in p.sentences) x.text: x,
    };
    s.paragraphs = splitParagraphs(result)
        .map((p) => Paragraph(splitSentences(p).map((t) => old[t] ?? Sentence(text: t)).toList()))
        .where((p) => p.sentences.isNotEmpty)
        .toList();
    s.counted = s.counted.clamp(0, s.paragraphs.length);
    s.position = s.position.clamp(0, s.paragraphs.isEmpty ? 0 : s.paragraphs.length - 1);
    app.touchStory(s);
    if (mounted) showNotchToast(context, title: 'Text updated', subtitle: '${s.wordCount} words', icon: PhosphorIconsFill.checkCircle);
  }
}

/// A language picker sheet with search.
Future<String?> pickLanguage(BuildContext context, {required String title, String? selected}) =>
    showAppSheet<String>(context, (ctx) => _LanguagePicker(title: title, selected: selected));

class _LanguagePicker extends StatefulWidget {
  const _LanguagePicker({required this.title, this.selected});
  final String title;
  final String? selected;

  @override
  State<_LanguagePicker> createState() => _LanguagePickerState();
}

class _LanguagePickerState extends State<_LanguagePicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.toLowerCase().trim();
    final list = languages
        .where((l) => q.isEmpty || l.name.toLowerCase().contains(q) || l.native.toLowerCase().contains(q) || l.code == q)
        .toList();
    final custom = q.length >= 2 && q.length <= 8 && RegExp(r'^[a-z]{2,3}(-[a-z0-9]+)?$').hasMatch(q) && languageByCode(q) == null;
    return SheetBody(
      title: widget.title,
      children: [
        SearchField(hint: 'Search languages or type a code', onChanged: (v) => setState(() => _q = v)),
        const SizedBox(height: 14),
        OptionGroup<String>(
          selected: widget.selected,
          onSelect: (v) => Navigator.pop(context, v),
          items: [
            if (custom) OptionItem(q, 'Use code "$q"', icon: PhosphorIconsRegular.code),
            for (final l in list)
              OptionItem(l.code, l.name, detail: '${l.native} · ${l.code}${l.rtl ? ' · right to left' : ''}'),
          ],
        ),
      ],
    );
  }
}
