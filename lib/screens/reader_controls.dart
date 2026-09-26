import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../data/app_state.dart';
import '../data/fonts.dart';
import '../data/io.dart';
import '../data/languages.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/feel.dart';
import '../widgets/notch_toast.dart';
import '../widgets/ui_kit.dart';
import 'reader_screen.dart';

const _groupNames = {
  FontGroup.general: 'General',
  FontGroup.dyslexia: 'Easier to read',
  FontGroup.hebrew: 'Hebrew',
  FontGroup.arabic: 'Arabic',
  FontGroup.custom: 'Your fonts',
};

/// Reader typography and behaviour. Used in the reader's "Aa" sheet and on
/// the Reader settings page. With a [language], fonts can be set for that
/// language alone.
class ReaderControls extends StatefulWidget {
  const ReaderControls({super.key, this.showMarksToggle = true, this.sample, this.language});
  final bool showMarksToggle;

  /// Text shown in the font chips, ideally in the language being read.
  final String? sample;
  final String? language;

  @override
  State<ReaderControls> createState() => _ReaderControlsState();
}

class _ReaderControlsState extends State<ReaderControls> {
  late bool _forLanguage = widget.language != null && context.appRead.settings.fontByLanguage.containsKey(widget.language);

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final s = app.settings;
    final c = context.sc;
    final lang = widget.language;
    void set(void Function() f) => app.updateSettings((_) => f());
    final current = lang != null && s.fontByLanguage.containsKey(lang) ? s.fontByLanguage[lang]! : s.readerFont;

    void pickFont(ReaderFont f) {
      Haptic.selection();
      set(() {
        if (_forLanguage && lang != null) {
          s.fontByLanguage[lang] = f.id;
        } else {
          s.readerFont = f.id;
          if (lang != null) s.fontByLanguage.remove(lang);
        }
      });
    }

    final groups = <FontGroup, List<ReaderFont>>{};
    for (final f in allReaderFonts) {
      groups.putIfAbsent(f.group, () => []).add(f);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Kicker('Mode'),
        const SizedBox(height: 8),
        ToolGroup(
          color: c.bgRaised2,
          radius: 18,
          children: [
            _SegRow(
              label: 'How you read',
              detail: s.readerMode == 'learn'
                  ? 'Highlights, levels and saving words'
                  : 'Plain text; a tap shows the meaning and the sentence translation',
              value: s.readerMode,
              options: const {'learn': 'Learn', 'read': 'Read'},
              onChanged: (v) => set(() => s.readerMode = v),
            ),
            _SegRow(
              label: 'Tapping a word opens',
              value: s.wordPopup,
              options: const {'card': 'Small card', 'sheet': 'Full sheet'},
              onChanged: (v) => set(() => s.wordPopup = v),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const Kicker('Page'),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final p in ReaderPaper.all)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: s.readerPaper == p.id,
                  label: p.label,
                  excludeSemantics: true,
                  child: Pressable(
                    scale: 0.94,
                    onTap: () => set(() => s.readerPaper = p.id),
                    child: Column(
                      children: [
                        Container(
                          height: 46,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: p.bg ?? c.bg,
                            borderRadius: BorderRadius.circular(context.feel.r(14)),
                            border: Border.all(color: s.readerPaper == p.id ? c.ember : c.border, width: s.readerPaper == p.id ? 2 : 1),
                          ),
                          child: Text('Aa', style: TextStyle(fontFamily: 'Literata', fontSize: 17, color: p.ink ?? c.text)),
                        ),
                        const SizedBox(height: 6),
                        Text(p.label, style: AppTheme.f(11, weight: FontWeight.w600, color: c.textSecondary)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            const Expanded(child: Kicker('Typeface')),
            if (lang != null)
              Pressable(
                scale: 0.95,
                onTap: () {
                  setState(() => _forLanguage = !_forLanguage);
                  if (!_forLanguage) set(() => s.fontByLanguage.remove(lang));
                },
                child: Row(
                  children: [
                    Text('Only for ${languageName(lang)}', style: AppTheme.f(12, weight: FontWeight.w600, color: c.textSecondary)),
                    const SizedBox(width: 8),
                    IgnorePointer(child: TinySwitch(value: _forLanguage, onChanged: (_) {})),
                  ],
                ),
              ),
          ],
        ),
        for (final g in FontGroup.values)
          if (groups[g] != null) ...[
            const SizedBox(height: 10),
            Text(_groupNames[g]!, style: AppTheme.f(12, weight: FontWeight.w700, color: c.textTertiary)),
            const SizedBox(height: 8),
            SizedBox(
              height: 78,
              child: ListView(
                key: PageStorageKey('fonts-${g.name}'),
                scrollDirection: Axis.horizontal,
                children: [
                  for (final f in groups[g]!)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 10),
                      child: _FontChip(font: f, selected: current == f.id, sample: widget.sample, onTap: () => pickFont(f)),
                    ),
                ],
              ),
            ),
          ],
        const SizedBox(height: 10),
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
                    showNotchToast(context, title: 'Not a font Sefer can read', subtitle: 'Use a .ttf or .otf file', icon: PhosphorIconsFill.warning, accent: c.warn);
                  } else {
                    showNotchToast(context, title: 'Font added', subtitle: font.name, icon: PhosphorIconsFill.textAa);
                  }
                },
              ),
            ),
            if (userFonts.any((f) => f.id == current)) ...[
              const SizedBox(width: 10),
              Expanded(
                child: GhostButton(
                  label: 'Remove it',
                  icon: PhosphorIconsBold.trash,
                  color: c.danger,
                  onTap: () {
                    final f = s.customFonts.firstWhere((x) => x.id == current);
                    UserFonts.remove(app, f);
                  },
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Bring any .ttf or .otf you have, for example SF Hebrew or SF Arabic from Apple.',
          style: AppTheme.f(11.5, weight: FontWeight.w500, color: c.textTertiary),
        ),
        const SizedBox(height: 18),
        const Kicker('Text'),
        const SizedBox(height: 8),
        ToolGroup(
          color: c.bgRaised2,
          radius: 18,
          children: [
            ToolRow(
              label: 'Text size',
              trailing: StepperControl(value: s.fontSize, min: 14, max: 44, onChanged: (v) => set(() => s.fontSize = v)),
            ),
            SliderRow(label: 'Line height', value: s.lineHeight, min: 1.2, max: 2.8, divisions: 16, format: (v) => v.toStringAsFixed(1), onChanged: (v) => set(() => s.lineHeight = v)),
            SliderRow(label: 'Space between words', value: s.wordSpacing, min: 0, max: 20, divisions: 20, format: (v) => v.round().toString(), onChanged: (v) => set(() => s.wordSpacing = v)),
            SliderRow(label: 'Space between letters', value: s.letterSpacing, min: -0.5, max: 3, divisions: 14, format: (v) => v.toStringAsFixed(1), onChanged: (v) => set(() => s.letterSpacing = v)),
            SliderRow(label: 'Space between paragraphs', value: s.paragraphSpacing, min: 6, max: 60, divisions: 27, format: (v) => v.round().toString(), onChanged: (v) => set(() => s.paragraphSpacing = v)),
            SliderRow(label: 'Page width', value: s.maxWidth, min: 360, max: 960, divisions: 20, format: (v) => v.round().toString(), onChanged: (v) => set(() => s.maxWidth = v)),
            SliderRow(label: 'Side margins', value: s.sidePadding, min: 8, max: 48, divisions: 20, format: (v) => v.round().toString(), onChanged: (v) => set(() => s.sidePadding = v)),
            ToolRow(label: 'Bold text', trailing: TinySwitch(value: s.boldText, onChanged: (v) => set(() => s.boldText = v))),
            ToolRow(label: 'Justify', trailing: TinySwitch(value: s.justify, onChanged: (v) => set(() => s.justify = v))),
            ToolRow(label: 'Indent paragraphs', trailing: TinySwitch(value: s.paragraphIndent, onChanged: (v) => set(() => s.paragraphIndent = v))),
          ],
        ),
        const SizedBox(height: 18),
        const Kicker('Highlights'),
        const SizedBox(height: 8),
        ToolGroup(
          color: c.bgRaised2,
          radius: 18,
          children: [
            _SegRow(
              label: 'Style',
              value: s.highlightStyle,
              options: const {'fill': 'Fill', 'underline': 'Underline', 'none': 'None'},
              onChanged: (v) => set(() => s.highlightStyle = v),
            ),
            if (s.highlightStyle != 'none')
              SliderRow(label: 'Strength', value: s.highlightStrength, min: 0.4, max: 2, divisions: 16, format: (v) => '${(v * 100).round()}%', onChanged: (v) => set(() => s.highlightStrength = v)),
            ToolRow(label: 'New words', trailing: TinySwitch(value: s.highlightNew, onChanged: (v) => set(() => s.highlightNew = v))),
            ToolRow(label: 'Words you\'re learning', trailing: TinySwitch(value: s.highlightLearning, onChanged: (v) => set(() => s.highlightLearning = v))),
            ToolRow(label: 'Double-tap marks a word known', trailing: TinySwitch(value: s.doubleTapKnown, onChanged: (v) => set(() => s.doubleTapKnown = v))),
          ],
        ),
        const SizedBox(height: 18),
        const Kicker('Reading aids'),
        const SizedBox(height: 8),
        ToolGroup(
          color: c.bgRaised2,
          radius: 18,
          children: [
            _SegRow(
              label: 'Transliteration',
              detail: 'For non-Latin scripts',
              value: s.translit,
              options: const {'off': 'Off', 'above': 'Above', 'tap': 'On tap'},
              onChanged: (v) => set(() => s.translit = v),
            ),
            _SegRow(
              label: 'Sentence translations',
              value: s.sentenceTranslations,
              options: const {'off': 'Off', 'tap': 'On tap', 'below': 'Always'},
              onChanged: (v) => set(() => s.sentenceTranslations = v),
            ),
            if (widget.showMarksToggle)
              ToolRow(
                label: 'Vowel marks',
                detail: 'Hebrew nikkud and Arabic harakat',
                trailing: TinySwitch(value: s.showMarks, onChanged: (v) => set(() => s.showMarks = v)),
              ),
            ToolRow(label: 'Fade paragraphs already read', trailing: TinySwitch(value: s.dimRead, onChanged: (v) => set(() => s.dimRead = v))),
          ],
        ),
        const SizedBox(height: 18),
        const Kicker('Screen'),
        const SizedBox(height: 8),
        ToolGroup(
          color: c.bgRaised2,
          radius: 18,
          children: [
            ToolRow(label: 'Keep the screen on', trailing: TinySwitch(value: s.keepAwake, onChanged: (v) => set(() => s.keepAwake = v))),
            ToolRow(label: 'Hide the top bar while scrolling', trailing: TinySwitch(value: s.hideChromeOnScroll, onChanged: (v) => set(() => s.hideChromeOnScroll = v))),
            ToolRow(label: 'Progress bar', trailing: TinySwitch(value: s.showReaderProgress, onChanged: (v) => set(() => s.showReaderProgress = v))),
            ToolRow(label: 'Title and word counts at the top', trailing: TinySwitch(value: s.showReaderHeader, onChanged: (v) => set(() => s.showReaderHeader = v))),
          ],
        ),
      ],
    );
  }
}

class _FontChip extends StatelessWidget {
  const _FontChip({required this.font, required this.selected, required this.onTap, this.sample});
  final ReaderFont font;
  final bool selected;
  final VoidCallback onTap;
  final String? sample;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    final sampleText = sample ??
        switch (font.group) {
          FontGroup.hebrew => 'אָלֶף',
          FontGroup.arabic => 'حَرْف',
          _ => 'Aa',
        };
    return Semantics(
      button: true,
      selected: selected,
      label: '${font.label}. ${font.note}',
      excludeSemantics: true,
      child: Pressable(
        scale: 0.94,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 112,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: selected ? c.ember : c.bgRaised2,
            borderRadius: BorderRadius.circular(context.feel.r(16)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                sampleText,
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: TextStyle(fontFamily: font.family, fontFamilyFallback: readerFallback, fontSize: 21, height: 1.15, color: selected ? c.onEmber : c.text),
              ),
              Text(
                font.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.f(11, weight: FontWeight.w600, color: selected ? c.onEmber : c.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SegRow extends StatelessWidget {
  const _SegRow({required this.label, this.detail, required this.value, required this.options, required this.onChanged});
  final String label;
  final String? detail;
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
          if (detail != null) ...[
            const SizedBox(height: 2),
            Text(detail!, style: AppTheme.f(12, weight: FontWeight.w500, color: c.textTertiary)),
          ],
          const SizedBox(height: 10),
          SegToggle<String>(value: value, options: options, onChanged: onChanged, expand: true),
        ],
      ),
    );
  }
}
