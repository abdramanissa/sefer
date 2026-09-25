import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';

/// Reader typography and behaviour controls. Used in the reader's "Aa" sheet
/// and on the Reader settings page.
class ReaderControls extends StatelessWidget {
  const ReaderControls({super.key, this.showMarksToggle = true, this.sample});
  final bool showMarksToggle;

  /// Text shown in the font chips, ideally in the language being read.
  final String? sample;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final s = app.settings;
    final c = context.sc;
    void set(void Function() f) => app.updateSettings((_) => f());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Kicker('Typeface'),
        const SizedBox(height: 10),
        SizedBox(
          height: 78,
          child: ListView(
            key: const PageStorageKey('reader-fonts'),
            scrollDirection: Axis.horizontal,
            children: [
              for (final f in readerFonts)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 10),
                  child: Semantics(
                    button: true,
                    selected: s.readerFont == f.id,
                    label: f.label,
                    child: Pressable(
                      scale: 0.94,
                      onTap: () {
                        Haptic.selection();
                        set(() => s.readerFont = f.id);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 104,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: s.readerFont == f.id ? c.ember : c.bgRaised2,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              sample ?? 'Aa',
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                              style: TextStyle(
                                fontFamily: f.family,
                                fontFamilyFallback: readerFallback,
                                fontSize: 22,
                                height: 1.1,
                                color: s.readerFont == f.id ? c.onEmber : c.text,
                              ),
                            ),
                            Text(
                              f.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.f(
                                11,
                                weight: FontWeight.w600,
                                color: s.readerFont == f.id ? c.onEmber : c.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Kicker('Spacing'),
        const SizedBox(height: 8),
        ToolGroup(
          color: c.bgRaised2,
          radius: 18,
          children: [
            ToolRow(
              label: 'Text size',
              trailing: StepperControl(
                value: s.fontSize,
                min: 14,
                max: 44,
                onChanged: (v) => set(() => s.fontSize = v),
              ),
            ),
            SliderRow(
              label: 'Line height',
              value: s.lineHeight,
              min: 1.2,
              max: 2.8,
              divisions: 16,
              format: (v) => v.toStringAsFixed(1),
              onChanged: (v) => set(() => s.lineHeight = v),
            ),
            SliderRow(
              label: 'Space between words',
              value: s.wordSpacing,
              min: 0,
              max: 20,
              divisions: 20,
              format: (v) => v.round().toString(),
              onChanged: (v) => set(() => s.wordSpacing = v),
            ),
            SliderRow(
              label: 'Space between paragraphs',
              value: s.paragraphSpacing,
              min: 6,
              max: 60,
              divisions: 27,
              format: (v) => v.round().toString(),
              onChanged: (v) => set(() => s.paragraphSpacing = v),
            ),
            SliderRow(
              label: 'Page width',
              value: s.maxWidth,
              min: 360,
              max: 960,
              divisions: 20,
              format: (v) => v.round().toString(),
              onChanged: (v) => set(() => s.maxWidth = v),
            ),
            SliderRow(
              label: 'Side margins',
              value: s.sidePadding,
              min: 8,
              max: 48,
              divisions: 20,
              format: (v) => v.round().toString(),
              onChanged: (v) => set(() => s.sidePadding = v),
            ),
            ToolRow(
              label: 'Justify text',
              trailing: TinySwitch(value: s.justify, onChanged: (v) => set(() => s.justify = v)),
            ),
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
            if (showMarksToggle)
              ToolRow(
                label: 'Vowel marks',
                detail: 'Hebrew nikkud and Arabic harakat',
                trailing: TinySwitch(value: s.showMarks, onChanged: (v) => set(() => s.showMarks = v)),
              ),
            ToolRow(
              label: 'Highlight new words',
              trailing: TinySwitch(value: s.highlightNew, onChanged: (v) => set(() => s.highlightNew = v)),
            ),
            ToolRow(
              label: 'Highlight words you\'re learning',
              trailing: TinySwitch(value: s.highlightLearning, onChanged: (v) => set(() => s.highlightLearning = v)),
            ),
          ],
        ),
      ],
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
