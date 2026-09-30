import 'dart:async';

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
import '../widgets/notch_toast.dart';
import '../widgets/ui_kit.dart';
import 'ai_settings.dart';
import 'story_screen.dart';

/// The story generator: a prompt built from chips, switches and a few
/// fields, sent to the chosen model, with the answer going to review.
class GeneratePanel extends StatefulWidget {
  const GeneratePanel({super.key, required this.onResult});
  final ValueChanged<ImportResult> onResult;

  @override
  State<GeneratePanel> createState() => _GeneratePanelState();
}

class _GeneratePanelState extends State<GeneratePanel> {
  late final GenOptions _o;
  late final _topic = TextEditingController(text: _o.topic);
  late final _custom = TextEditingController(text: _o.custom);
  bool _preview = false;
  bool _busy = false;
  String? _error;
  int _run = 0;
  int _elapsed = 0;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    final app = context.appRead;
    _o = app.settings.gen;
    // First time here: start from the language you're studying.
    if (!app.settings.learning.contains(_o.language) && app.activeLanguage != null) {
      _o.language = app.activeLanguage!;
    }
    if (_o.translation == _o.language) _o.translation = app.settings.nativeLanguage;
  }

  @override
  void dispose() {
    _clock?.cancel();
    _topic.dispose();
    _custom.dispose();
    super.dispose();
  }

  void _set(void Function(GenOptions o) change) {
    change(_o);
    context.appRead.updateSettings((_) {});
  }

  Future<void> _generate() async {
    final app = context.appRead;
    FocusScope.of(context).unfocus();
    final run = ++_run;
    setState(() {
      _busy = true;
      _error = null;
      _elapsed = 0;
    });
    _clock?.cancel();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed++);
    });
    try {
      final p = buildPrompt(_o);
      final reply = await aiClientFor(app).complete(model: app.settings.aiModel, system: p.system, user: p.user);
      if (run != _run || !mounted) return;
      final r = importText(extractJson(reply));
      if (r.stories.isEmpty) {
        setState(() => _error = 'The answer could not be read as stories. ${r.problems.join(' ')}');
      } else {
        for (final s in r.stories) {
          if (s.language == 'und') s.language = _o.language;
        }
        Haptic.medium();
        widget.onResult(r);
      }
    } on AiException catch (e) {
      if (run == _run && mounted) setState(() => _error = e.message);
    } catch (e) {
      if (run == _run && mounted) setState(() => _error = 'Something went wrong: $e');
    } finally {
      if (run == _run) {
        _clock?.cancel();
        if (mounted) setState(() => _busy = false);
      }
    }
  }

  void _cancel() {
    _run++;
    _clock?.cancel();
    setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final s = app.settings;
    final c = context.sc;
    final ready = s.internet && s.aiKey.isNotEmpty;
    final prompt = buildPrompt(_o);
    final gap = context.feel.gap;

    Widget section(String title, Widget child, {Widget? trailing}) => Padding(
      padding: EdgeInsets.only(bottom: gap + 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [Expanded(child: Kicker(title)), ?trailing]),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );

    Widget chips<T>(Map<T, String> items, bool Function(T) selected, void Function(T) onTap, {bool dense = false}) => Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final e in items.entries) Pill(label: e.value, dense: dense, selected: selected(e.key), onTap: () => onTap(e.key)),
      ],
    );

    Widget toggle(String label, bool value, void Function(bool) onChanged, {IconData? icon}) =>
        Pill(label: label, icon: value ? PhosphorIconsBold.check : icon ?? PhosphorIconsBold.plus, selected: value, onTap: () => onChanged(!value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!ready) ...[
          _Banner(
            icon: s.internet ? PhosphorIconsFill.key : PhosphorIconsFill.globeX,
            title: s.internet ? 'Add an API key' : 'Internet is off',
            body: s.internet
                ? 'Add a ${AiProviders.names[s.aiProvider]} key to generate here.'
                : 'Turn it on to generate here, or copy the prompt below into any AI chat and paste the answer in "Paste or write".',
            action: 'Open settings',
            onAction: () => app.go('settings:ai'),
          ),
          const SizedBox(height: 18),
        ],
        section(
          'Languages',
          ToolGroup(
            children: [
              ToolRow(
                icon: PhosphorIconsRegular.bookOpenText,
                label: 'Story in',
                value: languageName(_o.language),
                onTap: () async {
                  final l = await pickLanguage(context, title: 'Story language', selected: _o.language);
                  if (l != null) setState(() => _set((o) => o.language = l));
                },
              ),
              ToolRow(
                icon: PhosphorIconsRegular.translate,
                label: 'Translations in',
                value: languageName(_o.translation),
                onTap: () async {
                  final l = await pickLanguage(context, title: 'Translation language', selected: _o.translation);
                  if (l != null) setState(() => _set((o) => o.translation = l));
                },
              ),
            ],
          ),
        ),
        section(
          'Level',
          chips<String>({for (final l in GenOptions.levels) l: l}, (l) => _o.level == l, (l) => setState(() => _set((o) => o.level = l))),
        ),
        section(
          'Topic',
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppField(
                controller: _topic,
                hint: 'Anything: a rainy market day, the history of coffee…',
                onChanged: (v) => setState(() => _set((o) => o.topic = v)),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in GenOptions.topics)
                    Pill(
                      label: t,
                      dense: true,
                      selected: _o.topic.toLowerCase() == t.toLowerCase(),
                      onTap: () => setState(() {
                        final on = _o.topic.toLowerCase() == t.toLowerCase();
                        _set((o) => o.topic = on ? '' : t);
                        _topic.text = _o.topic;
                      }),
                    ),
                ],
              ),
            ],
          ),
        ),
        section('Kind', chips<String>(GenOptions.kinds, (k) => _o.kind == k, (k) => setState(() => _set((o) => o.kind = k)))),
        section(
          'Length',
          chips<String>(
            {for (final e in GenOptions.lengths.entries) e.key: '${e.value.$1} · ~${e.value.$2}'},
            (k) => _o.length == k,
            (k) => setState(() => _set((o) => o.length = k)),
          ),
        ),
        section(
          'Parts',
          Row(
            children: [
              Expanded(
                child: Text(
                  _o.parts == 1 ? 'One text' : '${_o.parts} parts of one story, added as separate texts',
                  style: AppTheme.f(13, weight: FontWeight.w500, color: c.textSecondary),
                ),
              ),
              StepperControl(
                value: _o.parts.toDouble(),
                min: 1,
                max: 8,
                step: 1,
                format: (v) => '${v.round()}',
                onChanged: (v) => setState(() => _set((o) => o.parts = v.round())),
              ),
            ],
          ),
        ),
        section(
          'Include',
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              toggle('Translations', _o.translations, (v) => setState(() => _set((o) => o.translations = v))),
              toggle('Word glosses', _o.glosses, (v) => setState(() => _set((o) => o.glosses = v))),
              if (_o.glosses) toggle('Gloss every word', _o.allGlosses, (v) => setState(() => _set((o) => o.allGlosses = v))),
              if (_o.nonLatin) toggle('Transliteration', _o.transliteration, (v) => setState(() => _set((o) => o.transliteration = v))),
              if (_o.hasVowelMarks)
                toggle(
                  _o.language == 'he' || _o.language == 'yi' ? 'Nikkud' : 'Harakat',
                  _o.vowelMarks,
                  (v) => setState(() => _set((o) => o.vowelMarks = v)),
                ),
              if (_o.kind != 'dialogue') toggle('Some dialogue', _o.dialogue, (v) => setState(() => _set((o) => o.dialogue = v))),
              toggle('Simple grammar', _o.simpleGrammar, (v) => setState(() => _set((o) => o.simpleGrammar = v))),
              toggle('Cultural details', _o.culture, (v) => setState(() => _set((o) => o.culture = v))),
            ],
          ),
        ),
        section(
          'Quiz',
          trailing: TinySwitch(value: _o.quiz, onChanged: (v) => setState(() => _set((o) => o.quiz = v))),
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            alignment: Alignment.topCenter,
            child: !_o.quiz
                ? Text('No quiz.', style: AppTheme.f(13, weight: FontWeight.w500, color: c.textTertiary))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${_o.quizCount} questions${_o.parts > 1 ? ' per part' : ''}',
                              style: AppTheme.f(13, weight: FontWeight.w500, color: c.textSecondary),
                            ),
                          ),
                          StepperControl(
                            value: _o.quizCount.toDouble(),
                            min: 1,
                            max: 15,
                            step: 1,
                            format: (v) => '${v.round()}',
                            onChanged: (v) => setState(() => _set((o) => o.quizCount = v.round())),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      chips<String>(
                        GenOptions.quizKindLabels,
                        _o.quizKinds.contains,
                        (k) => setState(() => _set((o) {
                          if (o.quizKinds.contains(k)) {
                            if (o.quizKinds.length > 1) o.quizKinds.remove(k);
                          } else {
                            o.quizKinds.add(k);
                          }
                        })),
                        dense: true,
                      ),
                    ],
                  ),
          ),
        ),
        section(
          'Anything else',
          AppField(
            controller: _custom,
            hint: 'e.g. set it in a small harbour town, name the cat Miso, end with a twist',
            maxLines: 4,
            minLines: 2,
            onChanged: (v) => setState(() => _set((o) => o.custom = v)),
          ),
        ),
        _PromptPreview(
          open: _preview,
          text: prompt.user,
          onToggle: () => setState(() => _preview = !_preview),
          onCopy: () {
            Clipboard.setData(ClipboardData(text: '${prompt.system}\n\n${prompt.user}'));
            showNotchToast(context, title: 'Prompt copied', subtitle: 'Paste the answer in "Paste or write"', icon: PhosphorIconsFill.copy);
          },
        ),
        const SizedBox(height: 18),
        if (_error != null) ...[
          _Banner(icon: PhosphorIconsFill.warning, title: 'No story this time', body: _error!, color: c.danger),
          const SizedBox(height: 14),
        ],
        if (_busy)
          _Working(seconds: _elapsed, model: s.aiModel, onCancel: _cancel)
        else ...[
          PrimaryButton(
            label: _o.parts > 1 ? 'Generate ${_o.parts} parts' : 'Generate',
            icon: PhosphorIconsBold.sparkle,
            onTap: ready ? _generate : null,
          ),
          const SizedBox(height: 10),
          Center(
            child: Pressable(
              scale: 0.96,
              onTap: () => pickModel(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                child: Text(
                  '${AiProviders.names[s.aiProvider]} · ${s.aiModel}',
                  style: AppTheme.f(12, weight: FontWeight.w600, color: c.textTertiary),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.title, required this.body, this.action, this.onAction, this.color});
  final IconData icon;
  final String title;
  final String body;
  final String? action;
  final VoidCallback? onAction;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    final col = color ?? c.info;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: col.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(context.feel.r(18))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: col),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: AppTheme.f(14.5, weight: FontWeight.w800, color: c.text))),
            ],
          ),
          const SizedBox(height: 6),
          Text(body, style: AppTheme.f(13, weight: FontWeight.w500, color: c.textSecondary, height: 1.4)),
          if (action != null) ...[
            const SizedBox(height: 12),
            Align(alignment: AlignmentDirectional.centerStart, child: GhostButton(label: action!, expand: false, icon: PhosphorIconsBold.gear, onTap: onAction)),
          ],
        ],
      ),
    );
  }
}

class _PromptPreview extends StatelessWidget {
  const _PromptPreview({required this.open, required this.text, required this.onToggle, required this.onCopy});
  final bool open;
  final String text;
  final VoidCallback onToggle;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: c.bgRaised, borderRadius: BorderRadius.circular(context.feel.r(18))),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Pressable(
                    scale: 0.98,
                    onTap: onToggle,
                    child: Row(
                      children: [
                        Icon(PhosphorIconsRegular.textAlignLeft, size: 18, color: c.textSecondary),
                        const SizedBox(width: 10),
                        Text('Prompt', style: AppTheme.f(14.5, color: c.text)),
                        const SizedBox(width: 6),
                        Icon(open ? PhosphorIconsBold.caretUp : PhosphorIconsBold.caretDown, size: 12, color: c.textTertiary),
                      ],
                    ),
                  ),
                ),
                Pill(label: 'Copy', dense: true, icon: PhosphorIconsBold.copy, onTap: onCopy),
              ],
            ),
            if (open) ...[
              const SizedBox(height: 12),
              SelectableText(text, style: AppTheme.f(12.5, weight: FontWeight.w500, color: c.textSecondary, height: 1.5)),
              const SizedBox(height: 8),
              Text('Plus the rules for the JSON format.', style: AppTheme.f(11.5, weight: FontWeight.w600, color: c.textTertiary)),
            ],
          ],
        ),
      ),
    );
  }
}

class _Working extends StatelessWidget {
  const _Working({required this.seconds, required this.model, required this.onCancel});
  final int seconds;
  final String model;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: c.bgRaised, borderRadius: BorderRadius.circular(context.feel.r(20))),
      child: Row(
        children: [
          SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: c.accent)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Writing… ${seconds}s', style: AppTheme.f(14.5, weight: FontWeight.w700, color: c.text)),
                const SizedBox(height: 2),
                Text(
                  seconds < 20 ? model : 'Long texts can take a minute or two.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.f(12, weight: FontWeight.w500, color: c.textSecondary),
                ),
              ],
            ),
          ),
          GhostButton(label: 'Cancel', expand: false, onTap: onCancel),
        ],
      ),
    );
  }
}
