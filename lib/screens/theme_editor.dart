import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../data/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/ui_kit.dart';

const _tokenLabels = {
  'bg': ('Background', 'The floor behind everything'),
  'bgRaised': ('Cards', 'Cards, sheets and dialogs'),
  'bgRaised2': ('Controls', 'Chips, fields and tracks inside cards'),
  'border': ('Lines', 'Hairlines and the background pattern'),
  'text': ('Text', 'Primary text'),
  'textSecondary': ('Secondary text', 'Subtitles and values'),
  'textTertiary': ('Quiet text', 'Labels, captions, inactive icons'),
  'ember': ('Ink', 'Primary buttons and selected states'),
  'onEmber': ('On ink', 'Text on primary buttons'),
  'accent': ('Accent', 'The one warm colour: streaks, charts, cursor'),
  'brass': ('Second accent', 'Transliteration and highlights'),
  'sage': ('Success', 'Known words, goals met'),
  'info': ('New words', 'Highlight for words you haven\'t met'),
  'warn': ('Learning words', 'Highlight for words you\'re learning'),
  'danger': ('Danger', 'Deleting things'),
};

class ThemeEditorScreen extends StatelessWidget {
  const ThemeEditorScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final t = app.customTheme(id);
    if (t == null) {
      return PageScroll(id: 'theme-missing', children: [
        ScreenHeader(title: 'Theme', onBack: app.back),
        const EmptyState(icon: PhosphorIconsRegular.palette, title: 'This theme was deleted'),
      ]);
    }
    final p = t.palette;
    final active = app.settings.themeMode == 'custom' && app.settings.customThemeId == id;
    void save() => app.saveTheme(t);

    return PageScroll(
      id: 'theme-editor',
      rise: false,
      children: [
        ScreenHeader(
          title: t.name,
          subtitle: active ? 'In use' : 'Not in use',
          onBack: app.back,
          actions: [
            RoundBtn(
              icon: PhosphorIconsRegular.pencilSimple,
              label: 'Rename',
              onTap: () async {
                final name = await askText(context, title: 'Rename theme', initial: t.name, action: 'Rename');
                if (name != null && name.isNotEmpty) {
                  t.name = name;
                  save();
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 20),
        _Preview(palette: p),
        const SizedBox(height: 16),
        if (!active)
          PrimaryButton(
            label: 'Use this theme',
            icon: PhosphorIconsBold.check,
            onTap: () => app.updateSettings((x) {
              x.themeMode = 'custom';
              x.customThemeId = id;
            }),
          ),
        const SizedBox(height: 22),
        const Kicker('Base'),
        const SizedBox(height: 10),
        SegToggle<Brightness>(
          value: t.brightness,
          expand: true,
          options: const {Brightness.dark: 'Dark', Brightness.light: 'Light'},
          onChanged: (b) {
            t.brightness = b;
            save();
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: GhostButton(
                label: 'Start from dark',
                onTap: () {
                  t.brightness = Brightness.dark;
                  t.colors = SeferColors.dark.editable;
                  save();
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GhostButton(
                label: 'Start from light',
                onTap: () {
                  t.brightness = Brightness.light;
                  t.colors = SeferColors.light.editable;
                  save();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        const Kicker('Colours'),
        const SizedBox(height: 10),
        ToolGroup(
          children: [
            for (final key in SeferColors.editableKeys)
              ToolRow(
                label: _tokenLabels[key]!.$1,
                detail: _tokenLabels[key]!.$2,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(colorToHex(p.byKey(key)).substring(3), style: AppTheme.d(11.5, weight: FontWeight.w600, color: context.sc.textTertiary)),
                    const SizedBox(width: 10),
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: p.byKey(key),
                        shape: BoxShape.circle,
                        border: Border.all(color: context.sc.border),
                      ),
                    ),
                  ],
                ),
                onTap: () async {
                  final col = await pickColor(context, title: _tokenLabels[key]!.$1, initial: p.byKey(key));
                  if (col != null) {
                    t.colors[key] = col;
                    save();
                  }
                },
              ),
          ],
        ),
        const SizedBox(height: 22),
        GhostButton(
          label: 'Duplicate',
          icon: PhosphorIconsBold.copy,
          onTap: () {
            final copy = app.createTheme(name: '${t.name} copy', from: p);
            app.back();
            app.go('theme:${copy.id}');
          },
        ),
        const SizedBox(height: 10),
        GhostButton(
          label: 'Delete theme',
          icon: PhosphorIconsBold.trash,
          color: context.sc.danger,
          onTap: () async {
            final ok = await askConfirm(context, title: 'Delete ${t.name}?', action: 'Delete', danger: true);
            if (ok) {
              app.back();
              app.deleteTheme(id);
            }
          },
        ),
      ],
    );
  }
}

/// A miniature of the app in the theme being edited, so changes are visible
/// without applying the theme.
class _Preview extends StatelessWidget {
  const _Preview({required this.palette});
  final SeferColors palette;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Theme(
      data: AppTheme.build(p),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(24), border: Border.all(color: p.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Kicker('Preview', color: p.textTertiary)),
                Icon(PhosphorIconsFill.flame, size: 16, color: p.accent),
                const SizedBox(width: 4),
                Text('12', style: AppTheme.f(14, weight: FontWeight.w800, color: p.text)),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: p.bgRaised, borderRadius: BorderRadius.circular(18)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: 'El ', style: TextStyle(color: p.text)),
                        TextSpan(text: 'gato', style: TextStyle(color: p.text, backgroundColor: p.info.withValues(alpha: 0.22))),
                        TextSpan(text: ' duerme ', style: TextStyle(color: p.text)),
                        TextSpan(text: 'tranquilo', style: TextStyle(color: p.text, backgroundColor: p.warn.withValues(alpha: 0.35))),
                        TextSpan(text: '.', style: TextStyle(color: p.text)),
                      ],
                    ),
                    style: const TextStyle(fontFamily: 'Literata', fontSize: 19, height: 1.6),
                  ),
                  Text('The cat sleeps peacefully.', style: AppTheme.f(12.5, weight: FontWeight.w500, color: p.textSecondary)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: p.ember, borderRadius: BorderRadius.circular(100)),
                          child: Text('Continue', style: AppTheme.f(13.5, color: p.onEmber)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: p.bgRaised2, borderRadius: BorderRadius.circular(100)),
                        child: Text('Later', style: AppTheme.f(13, color: p.text)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final col in [p.accent, p.brass, p.sage, p.info, p.warn, p.danger])
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 6),
                    child: Container(width: 16, height: 16, decoration: BoxDecoration(color: col, shape: BoxShape.circle)),
                  ),
                const Spacer(),
                Text('Quiet label', style: AppTheme.f(11, weight: FontWeight.w600, color: p.textTertiary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

const _swatches = <Color>[
  Color(0xFF0A0A0A), Color(0xFF1C1C1C), Color(0xFF2B2B2B), Color(0xFF121826), Color(0xFF14201A), //
  Color(0xFFFFFFFF), Color(0xFFF7F4F0), Color(0xFFECE8E3), Color(0xFFF4EFE6), Color(0xFFE9EEF5),
  Color(0xFFD9A184), Color(0xFF9E4E27), Color(0xFFB98F72), Color(0xFFE0B15A), Color(0xFF8FA377),
  Color(0xFF3D7A52), Color(0xFF7FA8C9), Color(0xFF3268A0), Color(0xFFA78BDA), Color(0xFFE5674C),
];

/// HSV sliders, a hex field and swatches.
Future<Color?> pickColor(BuildContext context, {required String title, required Color initial}) =>
    showAppSheet<Color>(context, (ctx) => _ColorPicker(title: title, initial: initial));

class _ColorPicker extends StatefulWidget {
  const _ColorPicker({required this.title, required this.initial});
  final String title;
  final Color initial;

  @override
  State<_ColorPicker> createState() => _ColorPickerState();
}

class _ColorPickerState extends State<_ColorPicker> {
  late HSVColor _hsv = HSVColor.fromColor(widget.initial);
  late final _hex = TextEditingController(text: colorToHex(widget.initial).substring(3));

  Color get _color => _hsv.toColor();

  void _set(HSVColor v, {bool updateHex = true}) {
    setState(() => _hsv = v);
    if (updateHex) _hex.text = colorToHex(_color).substring(3);
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  Widget _track(String label, double value, double max, List<Color> colors, ValueChanged<double> onChanged) {
    final c = context.sc;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Kicker(label),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, box) {
              void at(double dx) => onChanged((dx / box.maxWidth).clamp(0.0, 1.0) * max);
              return GestureDetector(
                onHorizontalDragUpdate: (d) => at(d.localPosition.dx),
                onTapDown: (d) => at(d.localPosition.dx),
                child: SizedBox(
                  height: 32,
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      Container(
                        height: 22,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(100),
                          gradient: LinearGradient(colors: colors),
                          border: Border.all(color: c.border),
                        ),
                      ),
                      Positioned(
                        left: (value / max) * (box.maxWidth - 28),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _color,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 6)],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    final h = _hsv;
    return SheetBody(
      title: widget.title,
      footer: PrimaryButton(label: 'Use colour', onTap: () => Navigator.pop(context, _color)),
      children: [
        Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: _color, borderRadius: BorderRadius.circular(18), border: Border.all(color: c.border)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(color: c.bgRaised2, borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    Text('#', style: AppTheme.d(18, color: c.textTertiary)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: TextField(
                        controller: _hex,
                        style: AppTheme.d(18, color: c.text),
                        decoration: const InputDecoration(isCollapsed: true, border: InputBorder.none),
                        onChanged: (v) {
                          final col = hexToColor(v);
                          if (col != null) _set(HSVColor.fromColor(col), updateHex: false);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _track('Hue', h.hue, 360, [for (var i = 0; i <= 6; i++) HSVColor.fromAHSV(1, i * 60.0, 1, 1).toColor()], (v) => _set(h.withHue(v))),
        _track('Saturation', h.saturation, 1, [h.withSaturation(0).toColor(), h.withSaturation(1).toColor()], (v) => _set(h.withSaturation(v))),
        _track('Brightness', h.value, 1, [h.withValue(0).toColor(), h.withValue(1).toColor()], (v) => _set(h.withValue(v))),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in _swatches)
              Pressable(
                scale: 0.9,
                onTap: () => _set(HSVColor.fromColor(s)),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: s, shape: BoxShape.circle, border: Border.all(color: c.border)),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
