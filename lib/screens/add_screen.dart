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
import '../widgets/covers.dart';
import '../widgets/notch_toast.dart';
import '../widgets/ui_kit.dart';
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
  static String mode = 'paste'; // paste | files
  static String? language;
  static String? translation;
  static List<String> tags = [];
}

class _AddScreenState extends State<AddScreen> {
  ImportResult? _review;
  List<String> _files = [];
  bool _guide = false;

  String get _lang => _Draft.language ?? context.appRead.activeLanguage ?? 'und';
  String get _trans => _Draft.translation ?? context.appRead.settings.defaultTranslationLang;

  PlainTextOptions get _plain => PlainTextOptions(
    title: _Draft.title.text,
    language: _lang,
    translationLanguage: _trans,
    tags: _Draft.tags,
  );

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
    final app = context.appRead;
    final r = _review;
    if (r == null || r.stories.isEmpty) return;
    for (final s in r.stories) {
      for (final t in _Draft.tags) {
        if (!s.tags.contains(t)) s.tags.add(t);
      }
    }
    app.addStories(r.stories);
    Haptic.medium();
    showNotchToast(
      context,
      title: r.stories.length == 1 ? 'Added to your library' : '${r.stories.length} stories added',
      subtitle: r.stories.length == 1 ? r.stories.first.title : null,
      icon: PhosphorIconsFill.books,
      accent: context.sc.sage,
      action: r.stories.length == 1 ? 'Read' : null,
      onAction: r.stories.length == 1 ? () => app.openStory(r.stories.first) : null,
    );
    _Draft.text.clear();
    _Draft.title.clear();
    setState(() {
      _review = null;
      _files = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    final review = _review;
    final isJson = looksLikeJson(_Draft.text.text);
    return PageScroll(
      id: 'add',
      children: [
        const TabHeader(kicker: 'Your texts, your way', title: 'Add', actions: [LanguagePill()]),
        const SizedBox(height: 20),
        SegToggle<String>(
          value: _Draft.mode,
          expand: true,
          options: const {'paste': 'Paste or write', 'files': 'Import files'},
          onChanged: (v) => setState(() {
            _Draft.mode = v;
            _review = null;
          }),
        ),
        const SizedBox(height: 18),
        if (_Draft.mode == 'paste') ...[
          AppField(
            controller: _Draft.text,
            hint: 'Paste a text, or JSON in the Sefer format.\n\n'
                'Put === on its own line between texts to add several at once.',
            maxLines: null,
            minLines: 8,
            textDirection: isRtl('und', _Draft.text.text) ? TextDirection.rtl : null,
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
              if (_Draft.text.text.isNotEmpty)
                Pill(
                  label: 'Clear',
                  icon: PhosphorIconsBold.x,
                  onTap: () {
                    _Draft.text.clear();
                    setState(() => _review = null);
                  },
                ),
              const Spacer(),
              if (_Draft.text.text.isNotEmpty)
                Text(
                  isJson ? 'JSON' : '${_Draft.text.text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length} words',
                  style: AppTheme.f(12, weight: FontWeight.w600, color: c.textTertiary),
                ),
            ],
          ),
        ] else ...[
          SoftCard(
            onTap: _pickFiles,
            child: Column(
              children: [
                Icon(PhosphorIconsRegular.filePlus, size: 34, color: c.accent),
                const SizedBox(height: 12),
                Text('Choose files', style: AppTheme.f(17, color: c.text)),
                const SizedBox(height: 6),
                Text(
                  '.json in the Sefer format (one story or many), or plain .txt. Pick as many as you like.',
                  textAlign: TextAlign.center,
                  style: AppTheme.f(13, weight: FontWeight.w500, color: c.textSecondary, height: 1.4),
                ),
                if (_files.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    _files.join(' · '),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.f(12, weight: FontWeight.w600, color: c.textTertiary),
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 22),
        if (!isJson || _Draft.mode == 'files') ...[
          Kicker(_Draft.mode == 'files' ? 'For plain text files' : 'Details'),
          const SizedBox(height: 10),
          ToolGroup(
            children: [
              if (_Draft.mode == 'paste')
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
        const SizedBox(height: 20),
        if (_Draft.mode == 'paste')
          PrimaryButton(
            label: 'Review',
            icon: PhosphorIconsBold.eye,
            onTap: _Draft.text.text.trim().isEmpty ? null : _reviewPaste,
          ),
        if (review != null) ...[
          const SizedBox(height: 22),
          _Review(result: review, onSave: _save),
        ],
        const SizedBox(height: 26),
        _FormatGuide(
          open: _guide,
          onToggle: () => setState(() => _guide = !_guide),
          onTry: () => setState(() {
            _Draft.mode = 'paste';
            _Draft.text.text = _example;
            _review = null;
          }),
        ),
      ],
    );
  }
}

class _Review extends StatelessWidget {
  const _Review({required this.result, required this.onSave});
  final ImportResult result;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    final n = result.stories.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeading(n == 0 ? 'Nothing to add' : (n == 1 ? 'Ready to add' : '$n stories ready')),
        const SizedBox(height: 12),
        for (final s in result.stories.take(30))
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: c.bgRaised, borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  SizedBox(width: 42, height: 56, child: StoryCover(cover: s.cover, title: s.title, radius: 8, showTitle: false)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textDirection: isRtl(s.language, s.title) ? TextDirection.rtl : TextDirection.ltr,
                          style: AppTheme.f(14.5, weight: FontWeight.w700, color: c.text),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            LangBadge(s.language),
                            Text(
                              '${s.wordCount} words · ${s.sentenceCount} sentences',
                              style: AppTheme.f(12, weight: FontWeight.w500, color: c.textSecondary),
                            ),
                            if (context.app.duplicateOf(s) != null) _Chip('already in library', c.warn),
                            if (s.hasTranslations) _Chip('translated', c.sage),
                            if (s.paragraphs.any((p) => p.sentences.any((x) => x.glosses.isNotEmpty))) _Chip('glosses', c.info),
                            if (s.paragraphs.any((p) => p.sentences.any((x) => x.transliterations.isNotEmpty)))
                              _Chip('transliteration', c.brass),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (n > 30)
          Text('and ${n - 30} more', textAlign: TextAlign.center, style: AppTheme.f(12.5, weight: FontWeight.w600, color: c.textTertiary)),
        if (result.problems.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: c.warn.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(PhosphorIconsFill.warning, size: 16, color: c.warn),
                    const SizedBox(width: 8),
                    Text('Notes', style: AppTheme.f(13.5, color: c.warn)),
                  ],
                ),
                const SizedBox(height: 8),
                for (final p in result.problems.take(12))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('· $p', style: AppTheme.f(12.5, weight: FontWeight.w500, color: c.textSecondary, height: 1.4)),
                  ),
              ],
            ),
          ),
        ],
        if (n > 0) ...[
          const SizedBox(height: 14),
          PrimaryButton(
            label: n == 1 ? 'Add to library' : 'Add $n stories',
            icon: PhosphorIconsBold.plus,
            onTap: onSave,
          ),
        ],
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(100)),
    child: Text(label, style: AppTheme.f(10.5, weight: FontWeight.w700, color: color)),
  );
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
                'case, nikkud or harakat.',
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
