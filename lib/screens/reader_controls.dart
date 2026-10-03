import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../data/app_state.dart';
import '../data/fonts.dart';
import '../data/io.dart';
import '../data/languages.dart';
import '../data/models.dart';
import '../text/script.dart';
import '../text/tokenizer.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/feel.dart';
import '../widgets/notch_toast.dart';
import '../widgets/ui_kit.dart';
import 'reader_screen.dart';

/// The reader's "Aa": a small popup with what you change most (size,
/// paper, font, mode, layout) and a way into everything else.
Future<void> showReaderSettings(BuildContext context, Story story) {
  final sample = words(story.preview).firstOrNull;
  return showAppSheet<void>(
    context,
    (ctx) => SheetBody(
      children: [
        _Quick(
          language: story.language,
          sample: sample,
          onMore: () {
            Navigator.pop(ctx);
            showReaderMore(context, language: story.language, sample: sample, marks: _hasMarks(story));
          },
        ),
      ],
    ),
  );
}

bool _hasMarks(Story story) {
  final s = dominantScript(story.preview);
  return s == Script.hebrew || s == Script.arabic;
}

/// Every reader option, in tabs.
Future<void> showReaderMore(BuildContext context, {required String language, String? sample, bool marks = true, int tab = 0}) =>
    showAppSheet<void>(
      context,
      (ctx) => SheetBody(
        children: [ReaderSettingsTabs(language: language, sample: sample, marks: marks, initialTab: tab)],
      ),
    );

void _set(BuildContext context, void Function(Settings s) f) => context.appRead.updateSettings(f);

// ------------------------------------------------------------------ quick

class _Quick extends StatelessWidget {
  const _Quick({required this.language, required this.sample, required this.onMore});
  final String language;
  final String? sample;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final s = app.settings;
    final c = context.sc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _SizeButton(small: true, onTap: s.fontSize > 14 ? () => _set(context, (x) => x.fontSize = (x.fontSize - 1).clamp(14, 44)) : null),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Text size', style: AppTheme.f(10.5, weight: FontWeight.w700, color: c.textTertiary)),
                  Text(
                    '${s.fontSize.round()}',
                    textAlign: TextAlign.center,
                    style: AppTheme.f(18, weight: FontWeight.w800, color: c.text, height: 1.15),
                  ),
                ],
              ),
            ),
            _SizeButton(small: false, onTap: s.fontSize < 44 ? () => _set(context, (x) => x.fontSize = (x.fontSize + 1).clamp(14, 44)) : null),
            const SizedBox(width: 14),
            for (final p in ReaderPaper.all) _PaperDot(paper: p, selected: s.readerPaper == p.id),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(height: 62, child: _FontStrip(language: language, sample: sample, compact: true)),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: SegToggle<String>(
                value: s.readerMode,
                expand: true,
                options: const {'learn': 'Learn', 'read': 'Read'},
                onChanged: (v) => _set(context, (x) => x.readerMode = v),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SegToggle<String>(
                value: s.readerLayout,
                expand: true,
                options: const {'scroll': 'Scroll', 'pages': 'Pages'},
                onChanged: (v) => _set(context, (x) => x.readerLayout = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        GhostButton(label: 'More', icon: PhosphorIconsBold.slidersHorizontal, onTap: onMore),
      ],
    );
  }
}

class _SizeButton extends StatelessWidget {
  const _SizeButton({required this.small, required this.onTap});
  final bool small;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    return Semantics(
      button: true,
      label: small ? 'Smaller text' : 'Larger text',
      excludeSemantics: true,
      child: Pressable(
        scale: 0.9,
        onTap: onTap,
        child: Container(
          width: 52,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: c.bgRaised2, borderRadius: BorderRadius.circular(context.feel.r(14))),
          // A small A with a minus, a big A with a plus: smaller and larger
          // text, readable at a glance.
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'A',
                style: TextStyle(fontFamily: 'Literata', fontSize: small ? 14 : 21, fontWeight: FontWeight.w700, color: onTap == null ? c.textTertiary : c.text, height: 1.1),
              ),
              Padding(
                padding: EdgeInsets.only(bottom: small ? 8 : 13),
                child: Icon(small ? PhosphorIconsBold.minus : PhosphorIconsBold.plus, size: small ? 9 : 11, color: onTap == null ? c.textTertiary : c.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaperDot extends StatelessWidget {
  const _PaperDot({required this.paper, required this.selected});
  final ReaderPaper paper;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    return Semantics(
      button: true,
      selected: selected,
      label: '${paper.label} page',
      excludeSemantics: true,
      child: Pressable(
        scale: 0.88,
        onTap: () => _set(context, (x) => x.readerPaper = paper.id),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: paper.bg ?? c.bg,
              border: Border.all(color: selected ? c.accent : c.border, width: selected ? 2.5 : 1),
            ),
          ),
        ),
      ),
    );
  }
}

/// The faces that suit [language]'s script. Picking one makes it that
/// language's font.
class _FontStrip extends StatelessWidget {
  const _FontStrip({required this.language, required this.sample, this.compact = false});
  final String language;
  final String? sample;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final s = context.app.settings;
    final script = fontScriptOf(language, sample ?? '');
    final current = readerFontFor(s.fontByLanguage, s.readerFont, language, sample ?? '');
    final fonts = fontsFor(script);
    final chip = [
      for (final f in fonts)
        _FontChip(
          font: f,
          selected: current.id == f.id,
          sample: sample ?? _sampleFor(script),
          compact: compact,
          onTap: () {
            Haptic.selection();
            _set(context, (x) => x.fontByLanguage[language.toLowerCase()] = f.id);
          },
        ),
    ];
    if (compact) {
      return ListView.separated(
        key: PageStorageKey('fonts-$language'),
        scrollDirection: Axis.horizontal,
        itemCount: chip.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => chip[i],
      );
    }
    return LayoutBuilder(
      builder: (context, box) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [for (final w in chip) SizedBox(width: (box.maxWidth - 8) / 2, child: w)],
      ),
    );
  }
}

String _sampleFor(FontScript s) => switch (s) {
  FontScript.greek => 'Αα',
  FontScript.cyrillic => 'Дд',
  FontScript.hebrew => 'אָלֶף',
  FontScript.arabic => 'حَرْف',
  FontScript.georgian => 'ანი',
  _ => 'Aa',
};

class _FontChip extends StatelessWidget {
  const _FontChip({required this.font, required this.selected, required this.onTap, required this.sample, this.compact = false});
  final ReaderFont font;
  final bool selected;
  final VoidCallback onTap;
  final String sample;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    final fg = selected ? c.onEmber : c.text;
    return Semantics(
      button: true,
      selected: selected,
      label: '${font.label}. ${font.note}',
      excludeSemantics: true,
      child: Pressable(
        scale: 0.95,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: compact ? 104 : null,
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: compact ? 8 : 12),
          decoration: BoxDecoration(
            color: selected ? c.ember : c.bgRaised2,
            borderRadius: BorderRadius.circular(context.feel.r(16)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                sample,
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: TextStyle(fontFamily: font.family, fontFamilyFallback: readerFallback, fontSize: compact ? 18 : 22, height: 1.2, color: fg),
              ),
              const SizedBox(height: 2),
              Text(font.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.f(11, weight: FontWeight.w700, color: selected ? c.onEmber : c.textSecondary)),
              if (!compact)
                Text(
                  font.easyRead ? 'Easier to read · ${font.note}' : font.note,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.f(10.5, weight: FontWeight.w500, color: selected ? c.onEmber.withValues(alpha: 0.75) : c.textTertiary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ tabs

/// All reader settings in four tabs: Font, Spacing, Display and Reading.
/// Used in the reader's "More" sheet and on the Reading settings page.
class ReaderSettingsTabs extends StatefulWidget {
  const ReaderSettingsTabs({super.key, required this.language, this.sample, this.marks = true, this.initialTab = 0, this.pickLanguage = false});
  final String language;
  final String? sample;
  final bool marks;
  final int initialTab;

  /// Lets you switch which language's font you're choosing.
  final bool pickLanguage;

  @override
  State<ReaderSettingsTabs> createState() => _ReaderSettingsTabsState();
}

class _ReaderSettingsTabsState extends State<ReaderSettingsTabs> {
  late int _tab = widget.initialTab;
  late String _lang = widget.language;

  static const _tabs = [
    (PhosphorIconsBold.textAa, 'Font'),
    (PhosphorIconsBold.arrowsOutLineVertical, 'Spacing'),
    (PhosphorIconsBold.highlighter, 'Display'),
    (PhosphorIconsBold.bookOpen, 'Reading'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: c.bgRaised2, borderRadius: BorderRadius.circular(context.feel.r(18))),
          child: Row(
            children: [
              for (final (i, (icon, label)) in _tabs.indexed)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: _tab == i,
                    label: label,
                    excludeSemantics: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        Haptic.selection();
                        setState(() => _tab = i);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _tab == i ? c.bgRaised : Colors.transparent,
                          borderRadius: BorderRadius.circular(context.feel.r(14)),
                        ),
                        child: Column(
                          children: [
                            Icon(icon, size: 17, color: _tab == i ? c.text : c.textTertiary),
                            const SizedBox(height: 3),
                            Text(label, style: AppTheme.f(11, weight: FontWeight.w700, color: _tab == i ? c.text : c.textTertiary)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: KeyedSubtree(
            key: ValueKey(_tab),
            child: switch (_tab) {
              0 => _fontTab(context),
              1 => _spacingTab(context),
              2 => _displayTab(context),
              _ => _readingTab(context),
            },
          ),
        ),
      ],
    );
  }

  Widget _fontTab(BuildContext context) {
    final app = context.app;
    final s = app.settings;
    final c = context.sc;
    final current = readerFontFor(s.fontByLanguage, s.readerFont, _lang, widget.sample ?? '');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'For ${languageName(_lang)}',
                style: AppTheme.f(13, weight: FontWeight.w700, color: c.textSecondary),
              ),
            ),
            if (widget.pickLanguage)
              Pill(
                dense: true,
                label: 'Change',
                icon: PhosphorIconsBold.caretDown,
                onTap: () async {
                  final l = await pickOption<String>(
                    context,
                    title: 'Fonts for',
                    selected: _lang,
                    items: [for (final l in {...s.learning, _lang}) OptionItem(l, languageName(l))],
                  );
                  if (l != null) setState(() => _lang = l);
                },
              ),
          ],
        ),
        const SizedBox(height: 10),
        _FontStrip(language: _lang, sample: widget.language == _lang ? widget.sample : null),
        const SizedBox(height: 14),
        ToolGroup(
          color: c.bgRaised2,
          radius: 18,
          children: [
            ToolRow(label: 'Bold text', trailing: TinySwitch(value: s.boldText, onChanged: (v) => _set(context, (x) => x.boldText = v))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: GhostButton(
                label: 'Import a font',
                icon: PhosphorIconsBold.upload,
                onTap: () async {
                  final f = await Io.pickFont();
                  if (f == null || !context.mounted) return;
                  final font = await UserFonts.add(app, f.name, f.bytes);
                  if (!context.mounted) return;
                  if (font == null) {
                    showNotchToast(context, title: 'Not a font Sefer can read', icon: PhosphorIconsFill.warning, accent: c.warn);
                  } else {
                    _set(context, (x) => x.fontByLanguage[_lang.toLowerCase()] = font.id);
                    showNotchToast(context, title: 'Font added', subtitle: font.name, icon: PhosphorIconsFill.textAa);
                  }
                },
              ),
            ),
            if (userFonts.any((f) => f.id == current.id)) ...[
              const SizedBox(width: 10),
              Expanded(
                child: GhostButton(
                  label: 'Remove it',
                  icon: PhosphorIconsBold.trash,
                  color: c.danger,
                  onTap: () => UserFonts.remove(app, s.customFonts.firstWhere((x) => x.id == current.id)),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _spacingTab(BuildContext context) {
    final s = context.app.settings;
    final c = context.sc;
    return ToolGroup(
      color: c.bgRaised2,
      radius: 18,
      children: [
        SliderRow(label: 'Line height', value: s.lineHeight, min: 1.2, max: 2.8, divisions: 16, format: (v) => v.toStringAsFixed(1), onChanged: (v) => _set(context, (x) => x.lineHeight = v)),
        SliderRow(label: 'Between words', value: s.wordSpacing, min: 0, max: 20, divisions: 20, format: (v) => v.round().toString(), onChanged: (v) => _set(context, (x) => x.wordSpacing = v)),
        SliderRow(label: 'Between letters', value: s.letterSpacing, min: -0.5, max: 3, divisions: 14, format: (v) => v.toStringAsFixed(1), onChanged: (v) => _set(context, (x) => x.letterSpacing = v)),
        SliderRow(label: 'Between paragraphs', value: s.paragraphSpacing, min: 6, max: 60, divisions: 27, format: (v) => v.round().toString(), onChanged: (v) => _set(context, (x) => x.paragraphSpacing = v)),
        SliderRow(label: 'Side margins', value: s.sidePadding, min: 8, max: 48, divisions: 20, format: (v) => v.round().toString(), onChanged: (v) => _set(context, (x) => x.sidePadding = v)),
        ToolRow(label: 'Justify', trailing: TinySwitch(value: s.justify, onChanged: (v) => _set(context, (x) => x.justify = v))),
        ToolRow(label: 'Indent paragraphs', trailing: TinySwitch(value: s.paragraphIndent, onChanged: (v) => _set(context, (x) => x.paragraphIndent = v))),
      ],
    );
  }

  Widget _displayTab(BuildContext context) {
    final s = context.app.settings;
    final c = context.sc;
    return ToolGroup(
      color: c.bgRaised2,
      radius: 18,
      children: [
        _SegRow(
          label: 'Story title',
          value: s.readerTitle,
          options: const {'large': 'Large', 'small': 'Compact', 'bar': 'Top bar'},
          onChanged: (v) => _set(context, (x) {
            x.readerTitle = v;
            x.showReaderHeader = true;
          }),
        ),
        _SegRow(
          label: 'Highlights',
          value: s.highlightStyle,
          options: const {'fill': 'Fill', 'underline': 'Underline', 'none': 'None'},
          onChanged: (v) => _set(context, (x) => x.highlightStyle = v),
        ),
        ToolRow(label: 'New words', trailing: TinySwitch(value: s.highlightNew, onChanged: (v) => _set(context, (x) => x.highlightNew = v))),
        ToolRow(label: 'Words you\'re learning', trailing: TinySwitch(value: s.highlightLearning, onChanged: (v) => _set(context, (x) => x.highlightLearning = v))),
        _SegRow(
          label: 'Transliteration',
          value: s.translit,
          options: const {'off': 'Off', 'above': 'Above', 'tap': 'On tap'},
          onChanged: (v) => _set(context, (x) => x.translit = v),
        ),
        if (widget.marks)
          ToolRow(
            label: 'Vowel marks',
            detail: 'Nikkud and harakat',
            trailing: TinySwitch(value: s.showMarks, onChanged: (v) => _set(context, (x) => x.showMarks = v)),
          ),
        ToolRow(label: 'Fade what you\'ve read', trailing: TinySwitch(value: s.dimRead, onChanged: (v) => _set(context, (x) => x.dimRead = v))),
      ],
    );
  }

  Widget _readingTab(BuildContext context) {
    final s = context.app.settings;
    final c = context.sc;
    return ToolGroup(
      color: c.bgRaised2,
      radius: 18,
      children: [
        _SegRow(
          label: 'Sentence translations',
          value: s.sentenceTranslations,
          options: const {'off': 'Off', 'tap': 'On tap', 'below': 'Always'},
          onChanged: (v) => _set(context, (x) => x.sentenceTranslations = v),
        ),
        _SegRow(
          label: 'Tapping a word opens',
          value: s.wordPopup,
          options: const {'card': 'Small card', 'sheet': 'Full sheet'},
          onChanged: (v) => _set(context, (x) => x.wordPopup = v),
        ),
        ToolRow(label: 'Double-tap marks a word known', trailing: TinySwitch(value: s.doubleTapKnown, onChanged: (v) => _set(context, (x) => x.doubleTapKnown = v))),
        ToolRow(label: 'Hide the top bar while scrolling', trailing: TinySwitch(value: s.hideChromeOnScroll, onChanged: (v) => _set(context, (x) => x.hideChromeOnScroll = v))),
        ToolRow(label: 'Keep the screen on', trailing: TinySwitch(value: s.keepAwake, onChanged: (v) => _set(context, (x) => x.keepAwake = v))),
      ],
    );
  }
}

class _SegRow extends StatelessWidget {
  const _SegRow({required this.label, required this.value, required this.options, required this.onChanged});
  final String label;
  final String value;
  final Map<String, String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: AppTheme.f(14.5, weight: FontWeight.w500, color: c.text)),
          const SizedBox(height: 10),
          SegToggle<String>(value: value, options: options, onChanged: onChanged, expand: true),
        ],
      ),
    );
  }
}
