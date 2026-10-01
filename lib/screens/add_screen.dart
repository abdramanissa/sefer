import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../data/app_state.dart';
import '../data/importer.dart';
import '../data/io.dart';
import '../data/languages.dart';
import '../data/models.dart';
import '../text/script.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../theme/feel.dart';
import '../widgets/notch_toast.dart';
import '../widgets/ui_kit.dart';
import 'import_review.dart';
import 'story_screen.dart';

class AddScreen extends StatefulWidget {
  const AddScreen({super.key});

  @override
  State<AddScreen> createState() => _AddScreenState();
}

/// Draft input survives switching tabs.
class _Draft {
  static final text = TextEditingController();
  static final title = TextEditingController();
  static String? language;
  static String? translation;
  static List<String> tags = [];
}

class _AddScreenState extends State<AddScreen> {
  ImportResult? _review;
  List<String> _files = [];
  bool _guide = false;
  Timer? _clock;

  String get _lang => _Draft.language ?? context.appRead.activeLanguage ?? 'und';
  String get _trans => _Draft.translation ?? context.appRead.settings.defaultTranslationLang;

  PlainTextOptions get _plain => PlainTextOptions(
    title: _Draft.title.text,
    language: _lang,
    translationLanguage: _trans,
    tags: _Draft.tags,
  );

  @override
  void initState() {
    super.initState();
    // The Generate card shows how long a story has been cooking.
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && context.appRead.generation.busy) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  void _reviewPaste() {
    FocusScope.of(context).unfocus();
    setState(() {
      _files = [];
      _review = importText(_Draft.text.text, plain: _plain);
    });
  }

  Future<void> _pickFiles() async {
    final files = await Io.pickTexts();
    if (files.isEmpty) return;
    final stories = <Story>[];
    final problems = <String>[];
    for (final f in files) {
      final text = f.text;
      final r = f.extension == 'json' || looksLikeJson(text)
          ? importText(text)
          : importPlain(
              text,
              PlainTextOptions(
                // One text per file: the file name is the title unless the
                // file uses === separators.
                title: storySeparator.hasMatch(text) ? '' : f.name.replaceAll(RegExp(r'\.[^.]+$'), ''),
                language: _lang,
                translationLanguage: _trans,
                tags: _Draft.tags,
              ),
            );
      stories.addAll(r.stories);
      problems.addAll(r.problems.map((p) => '${f.name}: $p'));
    }
    setState(() {
      _files = files.map((f) => f.name).toList();
      _review = ImportResult(stories, problems);
    });
  }

  void _save() {
    final r = _review;
    if (r == null || r.stories.isEmpty) return;
    saveImport(context, r, tags: _Draft.tags);
    if (_files.isEmpty) {
      _Draft.text.clear();
      _Draft.title.clear();
    }
    setState(() {
      _review = null;
      _files = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final c = context.sc;
    final gen = app.generation;
    final review = _review;
    final text = _Draft.text.text;
    final isJson = looksLikeJson(text);
    final genStatus = gen.busy
        ? 'Writing… ${gen.elapsed}s'
        : gen.result != null
        ? 'Ready to review'
        : gen.error != null
        ? 'Didn’t work, tap to see'
        : (app.settings.internet && app.settings.aiKey.isNotEmpty ? 'From a few choices' : 'Or copy the prompt');
    return PageScroll(
      id: 'add',
      children: [
        const TabHeader(kicker: 'Your texts, your way', title: 'Add', actions: [LanguagePill()]),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _ActionCard(
                icon: PhosphorIconsFill.sparkle,
                title: 'Generate',
                subtitle: genStatus,
                busy: gen.busy,
                highlight: gen.result != null,
                onTap: () => app.go('generate'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionCard(
                icon: PhosphorIconsFill.fileArrowUp,
                title: 'Import files',
                subtitle: _files.isEmpty ? '.json or .txt, many at once' : '${_files.length} file${_files.length == 1 ? '' : 's'} read',
                onTap: _pickFiles,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            const Expanded(child: Kicker('Paste or write')),
            if (text.isNotEmpty)
              Text(
                isJson ? 'JSON' : '${text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length} words',
                style: AppTheme.f(12, weight: FontWeight.w600, color: c.textTertiary),
              ),
          ],
        ),
        const SizedBox(height: 10),
        AppField(
          controller: _Draft.text,
          hint: 'A text, or JSON in the Sefer format (for example the answer from an AI chat).\n\n'
              'Put === on its own line between texts to add several at once.',
          maxLines: null,
          minLines: 7,
          textDirection: isRtl('und', text) ? TextDirection.rtl : null,
          style: AppTheme.f(15, weight: FontWeight.w500, color: c.text, height: 1.5),
          onChanged: (_) => setState(() => _review = null),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Pill(
              label: 'Paste',
              icon: PhosphorIconsBold.clipboardText,
              onTap: () async {
                final data = await Clipboard.getData(Clipboard.kTextPlain);
                final t = data?.text;
                if (t == null || t.isEmpty) return;
                _Draft.text.text = t;
                setState(() => _review = null);
              },
            ),
            const SizedBox(width: 8),
            if (text.isNotEmpty)
              Pill(
                label: 'Clear',
                icon: PhosphorIconsBold.x,
                onTap: () {
                  _Draft.text.clear();
                  setState(() => _review = null);
                },
              ),
          ],
        ),
        if (text.trim().isNotEmpty && !isJson) ...[
          const SizedBox(height: 18),
          ToolGroup(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                child: TextField(
                  controller: _Draft.title,
                  style: AppTheme.f(14.5, weight: FontWeight.w500, color: c.text),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Title (optional, or use the first line)',
                    hintStyle: AppTheme.f(14.5, weight: FontWeight.w500, color: c.textTertiary),
                  ),
                ),
              ),
              ToolRow(
                icon: PhosphorIconsRegular.translate,
                label: 'Language',
                value: _lang == 'und' ? 'Detect from script' : languageName(_lang),
                onTap: () async {
                  final l = await pickLanguage(context, title: 'Text language', selected: _lang);
                  if (l != null) setState(() => _Draft.language = l);
                },
              ),
              ToolRow(
                icon: PhosphorIconsRegular.chatsCircle,
                label: 'Translations in',
                value: languageName(_trans),
                onTap: () async {
                  final l = await pickLanguage(context, title: 'Translation language', selected: _trans);
                  if (l != null) setState(() => _Draft.translation = l);
                },
              ),
            ],
          ),
        ],
        if (text.trim().isNotEmpty || _files.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in _Draft.tags)
                Pill(label: '#$t', icon: PhosphorIconsBold.x, onTap: () => setState(() => _Draft.tags.remove(t))),
              Pill(
                label: _Draft.tags.isEmpty ? 'Add tags' : 'Tag',
                icon: PhosphorIconsBold.hash,
                onTap: () async {
                  final t = await askText(context, title: 'Tag these texts', hint: 'e.g. A2, news', action: 'Add');
                  if (t != null && t.isNotEmpty && !_Draft.tags.contains(t)) setState(() => _Draft.tags.add(t));
                },
              ),
            ],
          ),
        ],
        if (text.trim().isNotEmpty && review == null) ...[
          const SizedBox(height: 20),
          PrimaryButton(label: 'Review', icon: PhosphorIconsBold.eye, onTap: _reviewPaste),
        ],
        if (review != null) ...[
          const SizedBox(height: 22),
          ImportReview(result: review, onSave: _save, onChanged: () => setState(() {})),
        ],
        const SizedBox(height: 26),
        _FormatGuide(
          open: _guide,
          onToggle: () => setState(() => _guide = !_guide),
          onTry: () => setState(() {
            _Draft.text.text = _example;
            _review = null;
          }),
        ),
      ],
    );
  }
}

/// One of the two ways in at the top of Add.
class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.icon, required this.title, required this.subtitle, required this.onTap, this.busy = false, this.highlight = false});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool busy;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      excludeSemantics: true,
      child: Pressable(
        scale: 0.97,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          height: 128,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: highlight ? c.accentSoft : c.bgRaised,
            borderRadius: BorderRadius.circular(context.feel.r(22)),
            border: Border.all(color: highlight ? c.accent : Colors.transparent, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: c.accent.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(context.feel.r(13))),
                child: busy
                    ? Padding(padding: const EdgeInsets.all(11), child: CircularProgressIndicator(strokeWidth: 2.2, color: c.accent))
                    : Icon(icon, size: 20, color: c.accent),
              ),
              const Spacer(),
              Text(title, style: AppTheme.f(16, weight: FontWeight.w800, color: c.text)),
              const SizedBox(height: 2),
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.f(12, weight: FontWeight.w500, color: c.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

const _example = '''{
  "title": "Καλημέρα",
  "language": "el",
  "translation_language": "en",
  "tags": ["A1"],
  "paragraphs": [
    {
      "sentences": [
        {
          "text": "Καλημέρα σας!",
          "translation": "Good morning!",
          "glosses": { "καλημέρα": "good morning" },
          "transliterations": { "καλημέρα": "kaliméra" }
        }
      ]
    }
  ],
  "quiz": [
    {
      "question": "Τι λέμε το πρωί;",
      "translation": "What do we say in the morning?",
      "options": ["Καληνύχτα", "Καλημέρα", "Αντίο"],
      "answer": "Καλημέρα"
    },
    {
      "question": "Είναι το «σας» ευγενικό;",
      "translation": "Is «σας» polite?",
      "type": "yes_no",
      "answer": true
    }
  ]
}''';

class _FormatGuide extends StatelessWidget {
  const _FormatGuide({required this.open, required this.onToggle, required this.onTry});
  final bool open;
  final VoidCallback onToggle;
  final VoidCallback onTry;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    final body = AppTheme.f(13, weight: FontWeight.w500, color: c.textSecondary, height: 1.45);
    return SoftCard(
      padding: const EdgeInsets.all(18),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Pressable(
              onTap: onToggle,
              scale: 0.98,
              child: Row(
                children: [
                  Icon(PhosphorIconsRegular.bracketsCurly, size: 19, color: c.textSecondary),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Import format', style: AppTheme.f(15, color: c.text))),
                  Icon(open ? PhosphorIconsBold.caretUp : PhosphorIconsBold.caretDown, size: 14, color: c.textTertiary),
                ],
              ),
            ),
            if (open) ...[
              const SizedBox(height: 14),
              Text(
                'One story is an object; several are an array of objects. '
                'Only "text" is required in a sentence. "translation", "glosses" '
                '(word → meaning) and "transliterations" (word → reading) are optional, '
                'and so are "tags" and "author". Glosses match words regardless of '
                'case, nikkud or harakat.\n\n'
                'An optional "quiz" goes after the paragraphs. Each question has '
                'either "options" with the right one as "answer" (its text or its '
                'number, from 0), or "type": "yes_no" or "true_false" with "answer" '
                'true or false. "translation" and "explanation" are optional.',
                style: body,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: c.bgRaised2, borderRadius: BorderRadius.circular(14)),
                child: SingleChildScrollView(
                  key: const PageStorageKey('add-json-example'),
                  scrollDirection: Axis.horizontal,
                  child: Text(
                    _example,
                    style: TextStyle(fontFamily: 'NotoSerif', fontFamilyFallback: const ['monospace'], fontSize: 12, color: c.text, height: 1.4),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Plain text works too: blank lines split paragraphs, sentences are found '
                'automatically, and a short first line becomes the title. Separate several '
                'texts with a line of === or ---.',
                style: body,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: GhostButton(
                      label: 'Copy example',
                      icon: PhosphorIconsBold.copy,
                      onTap: () {
                        Clipboard.setData(const ClipboardData(text: _example));
                        showNotchToast(context, title: 'Example copied', icon: PhosphorIconsFill.copy);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GhostButton(
                      label: 'Try it',
                      icon: PhosphorIconsBold.play,
                      onTap: onTry,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
