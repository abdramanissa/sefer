import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../data/ai.dart';
import '../data/app_state.dart';
import '../data/importer.dart';
import '../data/languages.dart';
import '../data/prompt.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/feel.dart';
import '../widgets/knob.dart';
import '../widgets/notch_toast.dart';
import '../widgets/ui_kit.dart';
import 'ai_settings.dart';
import 'import_review.dart';
import 'story_screen.dart';

const _topicIdeas = [
  'a missed train', 'a letter from a grandmother', 'the first day at a new job', 'a market at dawn',
  'a lost cat on a rainy night', 'two neighbours and one parking space', 'a recipe that went wrong',
  'a lighthouse keeper', 'a phone left in a taxi', 'learning to swim at forty', 'a village festival',
  'a night shift in a bakery', 'an old photograph', 'a wrong number', 'the last bus home',
];

/// The story generator on one screen: languages, topic, level and focus,
/// three dials (length, parts, quiz) and a row of switches. The prompt it
/// builds is the backbone plus the chosen level, and can be copied.
class GenerateScreen extends StatefulWidget {
  const GenerateScreen({super.key});

  @override
  State<GenerateScreen> createState() => _GenerateScreenState();
}

class _GenerateScreenState extends State<GenerateScreen> {
  late final AppState _app;
  late final GenOptions _o;
  late final TextEditingController _topic;
  late final TextEditingController _notes;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    final app = _app = context.appRead;
    _o = app.settings.gen;
    if (!app.settings.learning.contains(_o.language) && app.activeLanguage != null) {
      _o.language = app.activeLanguage!;
    }
    if (_o.translation == _o.language) _o.translation = app.settings.nativeLanguage;
    _topic = TextEditingController(text: _o.topic);
    _notes = TextEditingController(text: _o.custom);
    app.generation.addListener(_onGeneration);
    _onGeneration();
  }

  void _onGeneration() {
    final busy = _app.generation.busy;
    if (busy && _clock == null) {
      _clock = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!busy) {
      _clock?.cancel();
      _clock = null;
    }
  }

  @override
  void dispose() {
    _app.generation.removeListener(_onGeneration);
    _clock?.cancel();
    _topic.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _set(void Function(GenOptions o) change) {
    setState(() => change(_o));
    context.appRead.updateSettings((_) {});
  }

  void _generate() {
    final app = context.appRead;
    FocusScope.of(context).unfocus();
    app.generation.start(client: aiClientFor(app), model: app.settings.aiModel, options: _o);
  }

  void _copyPrompt() {
    Clipboard.setData(ClipboardData(text: buildPrompt(_o).full));
    showNotchToast(context, title: 'Prompt copied', subtitle: 'Paste the answer in Add', icon: PhosphorIconsFill.copy);
  }

  Future<void> _review() async {
    final gen = context.appRead.generation;
    final r = gen.result;
    if (r == null) return;
    final save = await showAppSheet<bool>(
      context,
      (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SheetBody(
          children: [ImportReview(result: r, onSave: () => Navigator.pop(ctx, true), onChanged: () => setSheet(() {}))],
        ),
      ),
    );
    if (save == true && mounted) {
      saveImport(context, r);
      gen.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final s = app.settings;
    final c = context.sc;
    final gen = app.generation;
    final bb = PromptBackbone.instance;
    final ready = s.internet && s.aiKey.isNotEmpty;
    final top = MediaQuery.viewPaddingOf(context).top;
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    final gutter = context.feel.gutter;
    final focuses = bb.focusOptions(_o.level);

    Widget body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            RoundBtn(icon: PhosphorIconsBold.caretLeft, label: 'Back', onTap: app.back),
            const SizedBox(width: 6),
            Expanded(
              child: Pressable(
                scale: 0.98,
                onTap: () => pickModel(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Generate', style: AppTheme.f(20, weight: FontWeight.w800, color: c.text)),
                    Text(
                      '${AiProviders.names[s.aiProvider]} · ${s.aiModel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.f(11.5, weight: FontWeight.w600, color: c.textTertiary),
                    ),
                  ],
                ),
              ),
            ),
            RoundBtn(icon: PhosphorIconsBold.textAlignLeft, label: 'See the prompt', onTap: () => _showPrompt(context)),
            const SizedBox(width: 6),
            RoundBtn(icon: PhosphorIconsBold.copy, label: 'Copy the prompt', onTap: _copyPrompt),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _LangBox(label: 'Story in', code: _o.language, onTap: () => _pickLang(story: true))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: RoundBtn(
                icon: PhosphorIconsBold.arrowsLeftRight,
                label: 'Swap languages',
                size: 36,
                onTap: () => _set((o) {
                  final l = o.language;
                  o.language = o.translation;
                  o.translation = l;
                }),
              ),
            ),
            Expanded(child: _LangBox(label: 'Translated into', code: _o.translation, onTap: () => _pickLang(story: false))),
          ],
        ),
        const SizedBox(height: 10),
        AppField(
          controller: _topic,
          hint: 'What is it about? Leave empty to be surprised',
          onChanged: (v) => _set((o) => o.topic = v),
          trailing: _FieldBtn(
            icon: PhosphorIconsBold.diceFive,
            label: 'Suggest a topic',
            onTap: () {
              final t = _topicIdeas[Random().nextInt(_topicIdeas.length)];
              _topic.text = t;
              _set((o) => o.topic = t);
            },
          ),
        ),
        const SizedBox(height: 14),
        _LevelBar(value: _o.level, onChanged: (l) => _set((o) {
          o.level = l;
          if (!bb.focusOptions(l).contains(o.focus)) o.focus = '';
        })),
        const SizedBox(height: 6),
        Text(
          bb.reader(_o.level),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTheme.f(11.5, weight: FontWeight.w500, color: c.textTertiary, height: 1.35),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final f in ['', ...focuses]) ...[
                Pill(
                  dense: true,
                  label: f.isEmpty ? 'Any focus' : f,
                  selected: _o.focus == f,
                  onTap: () => _set((o) => o.focus = f),
                ),
                const SizedBox(width: 6),
              ],
            ],
          ),
        ),
        const Spacer(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Knob<int>(
              stops: GenOptions.lengths,
              value: GenOptions.lengths.contains(_o.words) ? _o.words : 250,
              label: 'Length',
              display: (v) => '$v',
              unit: (_) => 'words',
              onChanged: (v) => _set((o) => o.words = v),
            ),
            Knob<int>(
              stops: const [1, 2, 3, 4, 5, 6],
              value: _o.parts,
              label: 'Parts',
              display: (v) => '$v',
              unit: (v) => v == 1 ? 'story' : 'parts',
              onChanged: (v) => _set((o) => o.parts = v),
            ),
            Knob<int>(
              stops: const [0, 1, 2, 3, 4, 5, 6, 8, 10],
              value: _o.quiz ? _o.quizCount : 0,
              label: 'Quiz',
              display: (v) => v == 0 ? 'Off' : '$v',
              unit: (v) => v == 0 ? '' : 'questions',
              onChanged: (v) => _set((o) {
                o.quiz = v > 0;
                if (v > 0) o.quizCount = v;
              }),
            ),
          ],
        ),
        const Spacer(),
        Row(
          children: [
            _Toggle(icon: PhosphorIconsBold.translate, label: 'Translate', on: _o.translations, onTap: () => _set((o) => o.translations = !o.translations)),
            _Toggle(icon: PhosphorIconsBold.bookOpenText, label: 'Glosses', on: _o.glosses, onTap: () => _set((o) => o.glosses = !o.glosses)),
            if (_o.nonLatin)
              _Toggle(icon: PhosphorIconsBold.textAa, label: 'Translit', on: _o.transliteration, onTap: () => _set((o) => o.transliteration = !o.transliteration)),
            if (_o.hasVowelMarks)
              _Toggle(
                icon: PhosphorIconsBold.dotsThreeOutline,
                label: _o.hebrewScript ? 'Nikkud' : 'Harakat',
                on: _o.vowelMarks,
                onTap: () => _set((o) => o.vowelMarks = !o.vowelMarks),
              ),
            _Toggle(icon: PhosphorIconsBold.userSwitch, label: 'Retell', on: _o.retelling, onTap: () => _set((o) => o.retelling = !o.retelling)),
            _Toggle(icon: PhosphorIconsBold.smiley, label: 'For a child', on: _o.child, onTap: () => _set((o) => o.child = !o.child)),
          ],
        ),
        const SizedBox(height: 12),
        AppField(
          controller: _notes,
          hint: 'Anything else: a place, a name, a twist…',
          onChanged: (v) => _set((o) => o.custom = v),
        ),
        const Spacer(),
        const SizedBox(height: 12),
        _Status(
          ready: ready,
          internet: s.internet,
          busy: gen.busy,
          seconds: gen.elapsed,
          error: gen.error,
          result: gen.result,
          parts: _o.parts,
          onGenerate: _generate,
          onCancel: gen.cancel,
          onReview: _review,
          onDiscard: gen.clear,
          onSettings: () => app.go('settings:ai'),
        ),
      ],
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, top + 12, gutter, bottom + 16),
      child: LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxHeight),
            child: IntrinsicHeight(child: body),
          ),
        ),
      ),
    );
  }

  Future<void> _pickLang({required bool story}) async {
    final l = await pickLanguage(
      context,
      title: story ? 'Story language' : 'Translation language',
      selected: story ? _o.language : _o.translation,
    );
    if (l != null) _set((o) => story ? o.language = l : o.translation = l);
  }

  void _showPrompt(BuildContext context) {
    final p = buildPrompt(_o);
    showAppSheet<void>(
      context,
      (ctx) => SheetBody(
        title: 'Prompt',
        subtitle: 'The backbone, the ${_o.level} level and your choices',
        footer: PrimaryButton(
          label: 'Copy',
          icon: PhosphorIconsBold.copy,
          onTap: () {
            Navigator.pop(ctx);
            _copyPrompt();
          },
        ),
        children: [
          SelectableText(p.full, style: AppTheme.f(12, weight: FontWeight.w500, color: ctx.sc.textSecondary, height: 1.5)),
        ],
      ),
    );
  }
}

class _LangBox extends StatelessWidget {
  const _LangBox({required this.label, required this.code, required this.onTap});
  final String label;
  final String code;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    return Pressable(
      scale: 0.97,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(color: c.bgRaised2, borderRadius: BorderRadius.circular(context.feel.r(16))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTheme.f(10.5, weight: FontWeight.w600, color: c.textTertiary)),
            Text(languageName(code), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.f(14.5, weight: FontWeight.w700, color: c.text)),
          ],
        ),
      ),
    );
  }
}

class _FieldBtn extends StatelessWidget {
  const _FieldBtn({required this.icon, required this.label, required this.onTap});
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
      onTap: () {
        Haptic.selection();
        onTap();
      },
      child: SizedBox(width: 32, height: 22, child: Icon(icon, size: 18, color: context.sc.textSecondary)),
    ),
  );
}

/// A1 to C2 as one segmented bar.
class _LevelBar extends StatelessWidget {
  const _LevelBar({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    final feel = context.feel;
    return Container(
      height: 42,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: c.bgRaised2, borderRadius: BorderRadius.circular(feel.pill(42))),
      child: Row(
        children: [
          for (final l in GenOptions.levels)
            Expanded(
              child: Semantics(
                button: true,
                selected: l == value,
                label: 'Level $l',
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    Haptic.selection();
                    onChanged(l);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: l == value ? c.ember : Colors.transparent,
                      borderRadius: BorderRadius.circular(feel.pill(36)),
                    ),
                    child: Text(l, style: AppTheme.f(13.5, weight: FontWeight.w800, color: l == value ? c.onEmber : c.textSecondary)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.icon, required this.label, required this.on, required this.onTap});
  final IconData icon;
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    return Expanded(
      child: Semantics(
        button: true,
        toggled: on,
        label: label,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            Haptic.selection();
            onTap();
          },
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: on ? c.ember : c.bgRaised2,
                  borderRadius: BorderRadius.circular(context.feel.r(15)),
                ),
                child: Icon(icon, size: 19, color: on ? c.onEmber : c.textTertiary),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.f(10.5, weight: FontWeight.w600, color: on ? c.text : c.textTertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The bottom of the screen: generate, working, the answer, or what's
/// missing.
class _Status extends StatelessWidget {
  const _Status({
    required this.ready,
    required this.internet,
    required this.busy,
    required this.seconds,
    required this.error,
    required this.result,
    required this.parts,
    required this.onGenerate,
    required this.onCancel,
    required this.onReview,
    required this.onDiscard,
    required this.onSettings,
  });

  final bool ready;
  final bool internet;
  final bool busy;
  final int seconds;
  final String? error;
  final ImportResult? result;
  final int parts;
  final VoidCallback onGenerate;
  final VoidCallback onCancel;
  final VoidCallback onReview;
  final VoidCallback onDiscard;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    final r = result;
    if (busy) {
      return Container(
        height: 56,
        padding: const EdgeInsets.only(left: 18, right: 6),
        decoration: BoxDecoration(color: c.bgRaised2, borderRadius: BorderRadius.circular(context.feel.pill(56))),
        child: Row(
          children: [
            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: c.accent)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                seconds < 25 ? 'Writing… ${seconds}s' : 'Still writing… ${seconds}s. You can leave this screen.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.f(13.5, weight: FontWeight.w700, color: c.text),
              ),
            ),
            GhostButton(label: 'Cancel', expand: false, onTap: onCancel),
          ],
        ),
      );
    }
    if (r != null) {
      final n = r.stories.length;
      return Row(
        children: [
          RoundBtn(icon: PhosphorIconsBold.trash, label: 'Discard', onTap: onDiscard),
          const SizedBox(width: 10),
          Expanded(
            child: PrimaryButton(
              label: n == 1 ? 'Review “${r.stories.first.title}”' : 'Review $n stories',
              icon: PhosphorIconsBold.eye,
              onTap: onReview,
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (error != null || !ready)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Pressable(
              scale: 0.98,
              onTap: error == null ? onSettings : null,
              child: Row(
                children: [
                  Icon(error != null ? PhosphorIconsFill.warning : PhosphorIconsFill.info, size: 15, color: error != null ? c.danger : c.info),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      error ??
                          (internet
                              ? 'Add an API key in Internet & AI to generate here.'
                              : 'Internet is off. Turn it on in Internet & AI, or copy the prompt into any AI chat.'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.f(12, weight: FontWeight.w600, color: error != null ? c.danger : c.textSecondary, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ),
        PrimaryButton(
          label: parts > 1 ? 'Generate $parts parts' : 'Generate',
          icon: PhosphorIconsBold.sparkle,
          onTap: ready ? onGenerate : null,
        ),
      ],
    );
  }
}
