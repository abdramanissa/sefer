import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../app/app_shell.dart';
import '../data/app_state.dart';
import '../data/exporter.dart';
import '../data/io.dart';
import '../data/languages.dart';
import '../data/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/notch_toast.dart';
import '../widgets/ui_kit.dart';
import 'reader_controls.dart';
import 'stats_screen.dart';
import 'story_actions.dart';
import 'story_screen.dart';
import 'words_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final s = app.settings;
    final isTab = app.visibleTabs.contains('settings');
    return PageScroll(
      id: 'settings',
      children: [
        if (isTab)
          const TabHeader(kicker: 'Make it yours', title: 'Settings')
        else
          ScreenHeader(title: 'Settings', onBack: app.back),
        const SizedBox(height: 24),
        const Kicker('Look and feel'),
        const SizedBox(height: 10),
        ToolGroup(
          children: [
            ToolRow(
              icon: PhosphorIconsRegular.palette,
              label: 'Theme',
              value: _themeName(app),
              onTap: () => app.go('settings:appearance'),
            ),
            ToolRow(
              icon: PhosphorIconsRegular.textAa,
              label: 'Reader',
              value: '${readerFontById(s.readerFont).label} · ${s.fontSize.round()}',
              onTap: () => app.go('settings:reader'),
            ),
            ToolRow(
              icon: PhosphorIconsRegular.layout,
              label: 'Layout',
              value: s.tabs.map((t) => tabMeta[t]!.label).join(', '),
              onTap: () => app.go('settings:layout'),
            ),
            ToolRow(
              icon: PhosphorIconsRegular.sparkle,
              label: 'Transitions',
              value: _transitionName(s.transition),
              onTap: () => app.go('settings:motion'),
            ),
            ToolRow(
              icon: PhosphorIconsRegular.squaresFour,
              label: 'Activity chart',
              value: '${s.heatWeeks} weeks',
              onTap: () => showHeatmapSettings(context),
            ),
          ],
        ),
        const SizedBox(height: 26),
        const Kicker('Learning'),
        const SizedBox(height: 10),
        ToolGroup(
          children: [
            ToolRow(
              icon: PhosphorIconsRegular.target,
              label: 'Daily goal',
              trailing: StepperControl(
                value: s.dailyGoalMinutes.toDouble(),
                min: 5,
                max: 180,
                step: 5,
                format: (v) => '${v.round()}m',
                onChanged: (v) => app.updateSettings((x) => x.dailyGoalMinutes = v.round()),
              ),
            ),
            ToolRow(
              icon: PhosphorIconsRegular.flame,
              label: 'Streak needs the goal',
              detail: 'Off: any reading keeps it alive',
              trailing: TinySwitch(value: s.streakNeedsGoal, onChanged: (v) => app.updateSettings((x) => x.streakNeedsGoal = v)),
            ),
            ToolRow(
              icon: PhosphorIconsRegular.checkCircle,
              label: 'Finishing marks new words known',
              detail: 'Words you never tapped are ones you understood',
              trailing: TinySwitch(value: s.autoKnownOnFinish, onChanged: (v) => app.updateSettings((x) => x.autoKnownOnFinish = v)),
            ),
            ToolRow(
              icon: PhosphorIconsRegular.chatsCircle,
              label: 'Translations usually in',
              value: languageName(s.defaultTranslationLang),
              onTap: () async {
                final l = await pickLanguage(context, title: 'Your language', selected: s.defaultTranslationLang);
                if (l != null) app.updateSettings((x) => x.defaultTranslationLang = l);
              },
            ),
          ],
        ),
        const SizedBox(height: 26),
        const Kicker('Your data'),
        const SizedBox(height: 10),
        ToolGroup(
          children: [
            ToolRow(
              icon: PhosphorIconsRegular.cloudArrowDown,
              label: 'Back up everything',
              detail: 'Stories, words, stats, settings and covers in one file',
              onTap: () => _backup(context),
            ),
            ToolRow(
              icon: PhosphorIconsRegular.cloudArrowUp,
              label: 'Restore a backup',
              onTap: () => _restore(context),
            ),
            ToolRow(
              icon: PhosphorIconsRegular.export,
              label: 'Export all stories',
              detail: 'In the import format',
              onTap: app.stories.isEmpty ? null : () => exportStoriesFlow(context, app.stories),
            ),
            ToolRow(
              icon: PhosphorIconsRegular.cards,
              label: 'Export words to Anki',
              onTap: () => showAnkiExport(context),
            ),
            ToolRow(
              icon: PhosphorIconsRegular.trash,
              label: 'Erase everything',
              danger: true,
              onTap: () => _wipe(context),
            ),
          ],
        ),
        const SizedBox(height: 26),
        const Kicker('App'),
        const SizedBox(height: 10),
        ToolGroup(
          children: [
            ToolRow(
              icon: PhosphorIconsRegular.vibrate,
              label: 'Haptics',
              trailing: TinySwitch(value: s.haptics, onChanged: (v) => app.updateSettings((x) => x.haptics = v)),
            ),
            ToolRow(
              icon: PhosphorIconsRegular.personSimpleWalk,
              label: 'Reduce motion',
              detail: 'Also follows your system setting',
              trailing: TinySwitch(value: s.reduceMotion, onChanged: (v) => app.updateSettings((x) => x.reduceMotion = v)),
            ),
            ToolRow(
              icon: PhosphorIconsRegular.shieldCheck,
              label: 'Privacy and about',
              onTap: () => app.go('settings:about'),
            ),
          ],
        ),
      ],
    );
  }

  static String _themeName(AppState app) => switch (app.settings.themeMode) {
    'light' => 'Light',
    'system' => 'Automatic',
    'custom' => app.customTheme(app.settings.customThemeId)?.name ?? 'Dark',
    _ => 'Dark',
  };

  static String _transitionName(String t) => switch (t) {
    'fade' => 'Fade',
    'slide' => 'Slide',
    'scale' => 'Zoom',
    'none' => 'None',
    _ => 'Blur',
  };

  Future<void> _backup(BuildContext context) async {
    final app = context.appRead;
    final how = await pickOption<String>(
      context,
      title: 'Back up',
      subtitle: 'The file stays wherever you put it',
      items: const [
        OptionItem('save', 'Save to a file', icon: PhosphorIconsRegular.floppyDisk),
        OptionItem('share', 'Share', icon: PhosphorIconsRegular.shareNetwork, detail: 'Send it to another app or device'),
      ],
    );
    if (how == null) return;
    await app.flush();
    final json = jsonEncode(await app.backup());
    final name = 'sefer-backup-${stamp()}.json';
    if (how == 'save') {
      final ok = await Io.saveText(name, json, mime: 'application/json');
      if (ok && context.mounted) showNotchToast(context, title: 'Backup saved', subtitle: name, icon: PhosphorIconsFill.cloudCheck);
    } else {
      await Io.shareFile(name, json, mime: 'application/json');
    }
  }

  Future<void> _restore(BuildContext context) async {
    final app = context.appRead;
    final f = await Io.pickJson();
    if (f == null || !context.mounted) return;
    Object? json;
    try {
      json = jsonDecode(f.text);
    } on FormatException {
      json = null;
    }
    if (!isBackup(json)) {
      if (context.mounted) {
        showNotchToast(
          context,
          title: 'Not a Sefer backup',
          subtitle: 'To add stories from JSON, use the Add tab',
          icon: PhosphorIconsFill.warning,
          accent: context.sc.warn,
        );
      }
      return;
    }
    final backup = parseBackup((json as Map).cast<String, dynamic>());
    if (!context.mounted) return;
    final mode = await pickOption<String>(
      context,
      title: 'Restore backup',
      subtitle: '${backup.stories.length} stories · ${backup.vocab.length} words',
      items: const [
        OptionItem('merge', 'Merge with what\'s here', icon: PhosphorIconsRegular.gitMerge, detail: 'Adds stories and words you don\'t have'),
        OptionItem('replace', 'Replace everything', icon: PhosphorIconsRegular.arrowsClockwise, danger: true, detail: 'Current data is erased'),
      ],
    );
    if (mode == null || !context.mounted) return;
    if (mode == 'replace') {
      final ok = await askConfirm(
        context,
        title: 'Replace everything?',
        body: 'Your current library, words, stats and settings are replaced by the backup.',
        action: 'Replace',
        danger: true,
      );
      if (!ok) return;
    }
    await app.restore(backup, merge: mode == 'merge');
    if (context.mounted) {
      showNotchToast(context, title: 'Backup restored', icon: PhosphorIconsFill.cloudCheck, accent: context.sc.sage);
    }
  }

  Future<void> _wipe(BuildContext context) async {
    final app = context.appRead;
    final ok = await askConfirm(
      context,
      title: 'Erase everything?',
      body: 'All stories, words, stats, themes and settings are deleted from this device. '
          'This can\'t be undone. Make a backup first if you might want them back.',
      action: 'Erase',
      danger: true,
    );
    if (ok) await app.wipe();
  }
}

// ------------------------------------------------------------------ appearance

class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final s = app.settings;
    final c = context.sc;
    void mode(String m, [String? id]) => app.updateSettings((x) {
      x.themeMode = m;
      if (id != null) x.customThemeId = id;
    });
    return PageScroll(
      id: 'settings-appearance',
      children: [
        ScreenHeader(title: 'Theme', onBack: app.back),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(child: _ThemeTile(label: 'Dark', palette: SeferColors.dark, selected: s.themeMode == 'dark', onTap: () => mode('dark'))),
            const SizedBox(width: 10),
            Expanded(child: _ThemeTile(label: 'Light', palette: SeferColors.light, selected: s.themeMode == 'light', onTap: () => mode('light'))),
            const SizedBox(width: 10),
            Expanded(
              child: _ThemeTile(
                label: 'Automatic',
                palette: SeferColors.dark,
                split: SeferColors.light,
                selected: s.themeMode == 'system',
                onTap: () => mode('system'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        SectionHeading('Your themes', trailing: '${s.customThemes.length}'),
        const SizedBox(height: 14),
        if (s.customThemes.isNotEmpty)
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final t in s.customThemes)
                SizedBox(
                  width: (MediaQuery.sizeOf(context).width - 40 - 20) / 3,
                  child: _ThemeTile(
                    label: t.name,
                    palette: t.palette,
                    selected: s.themeMode == 'custom' && s.customThemeId == t.id,
                    onTap: () => mode('custom', t.id),
                    onLongPress: () => app.go('theme:${t.id}'),
                  ),
                ),
            ],
          ),
        if (s.customThemes.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Long-press a theme to edit it.',
            textAlign: TextAlign.center,
            style: AppTheme.f(11.5, weight: FontWeight.w500, color: c.textTertiary),
          ),
        ],
        const SizedBox(height: 14),
        PrimaryButton(
          label: 'Create a theme',
          icon: PhosphorIconsBold.paintBrush,
          onTap: () {
            final t = app.createTheme(name: 'My theme ${s.customThemes.length + 1}', from: c);
            app.go('theme:${t.id}');
          },
        ),
        const SizedBox(height: 28),
        const Kicker('Background'),
        const SizedBox(height: 10),
        SegToggle<String>(
          value: s.background,
          expand: true,
          options: const {'none': 'Plain', 'dots': 'Dots', 'grid': 'Grid'},
          onChanged: (v) => app.updateSettings((x) => x.background = v),
        ),
        const SizedBox(height: 22),
        const Kicker('Interface text size'),
        const SizedBox(height: 10),
        ToolGroup(
          children: [
            SliderRow(
              label: 'Scale',
              value: s.uiScale,
              min: 0.85,
              max: 1.3,
              divisions: 9,
              format: (v) => '${(v * 100).round()}%',
              onChanged: (v) => app.updateSettings((x) => x.uiScale = double.parse(v.toStringAsFixed(2))),
            ),
          ],
        ),
      ],
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({required this.label, required this.palette, required this.selected, required this.onTap, this.split, this.onLongPress});
  final String label;
  final SeferColors palette;
  final SeferColors? split;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    Widget mini(SeferColors p) => Container(
      color: p.bg,
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 6, width: 30, decoration: BoxDecoration(color: p.text, borderRadius: BorderRadius.circular(3))),
          const SizedBox(height: 6),
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: p.bgRaised, borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 4, width: 36, decoration: BoxDecoration(color: p.textSecondary, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 4),
                  Container(height: 4, width: 24, decoration: BoxDecoration(color: p.info.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(2))),
                  const Spacer(),
                  Container(height: 10, decoration: BoxDecoration(color: p.ember, borderRadius: BorderRadius.circular(5))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: p.accent, shape: BoxShape.circle)),
              const SizedBox(width: 3),
              Container(width: 10, height: 10, decoration: BoxDecoration(color: p.sage, shape: BoxShape.circle)),
            ],
          ),
        ],
      ),
    );
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Pressable(
        scale: 0.96,
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              height: 124,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: selected ? c.ember : c.border, width: selected ? 2.5 : 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: split == null
                    ? mini(palette)
                    : Row(children: [Expanded(child: mini(palette)), Expanded(child: mini(split!))]),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.f(12.5, weight: selected ? FontWeight.w800 : FontWeight.w600, color: selected ? c.text : c.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ reader

class ReaderSettingsScreen extends StatelessWidget {
  const ReaderSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final s = app.settings;
    final c = context.sc;
    final font = readerFontById(s.readerFont);
    return PageScroll(
      id: 'settings-reader',
      children: [
        ScreenHeader(title: 'Reader', onBack: app.back),
        const SizedBox(height: 20),
        SoftCard(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: 'Καλημέρα ', style: TextStyle(backgroundColor: c.info.withValues(alpha: 0.2))),
                const TextSpan(text: 'σας! '),
                TextSpan(text: 'שָׁלוֹם ', style: TextStyle(backgroundColor: c.warn.withValues(alpha: 0.3))),
                const TextSpan(text: 'עוֹלָם. مَرْحَبًا بِكُمْ. El gato duerme.'),
              ],
            ),
            style: TextStyle(
              fontFamily: font.family,
              fontFamilyFallback: readerFallback,
              fontSize: s.fontSize,
              height: s.lineHeight,
              wordSpacing: s.wordSpacing,
              color: c.text,
            ),
          ),
        ),
        const SizedBox(height: 22),
        const ReaderControls(),
      ],
    );
  }
}

// ------------------------------------------------------------------ layout

class LayoutScreen extends StatelessWidget {
  const LayoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final s = app.settings;
    final c = context.sc;
    final hidden = allTabs.where((t) => !s.tabs.contains(t)).toList();
    return PageScroll(
      id: 'settings-layout',
      children: [
        ScreenHeader(title: 'Layout', onBack: app.back),
        const SizedBox(height: 22),
        const Kicker('Navigation bar'),
        const SizedBox(height: 6),
        Text(
          'Up to four tabs. Anything you hide stays reachable: Settings from the '
          'gear on each tab, the rest from Settings and the Library.',
          style: AppTheme.f(12.5, weight: FontWeight.w500, color: c.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 12),
        ToolGroup(
          children: [
            for (var i = 0; i < s.tabs.length; i++)
              ToolRow(
                icon: tabMeta[s.tabs[i]]!.iconSelected,
                label: tabMeta[s.tabs[i]]!.label,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _MiniBtn(
                      icon: PhosphorIconsBold.arrowUp,
                      label: 'Move up',
                      onTap: i == 0
                          ? null
                          : () => app.updateSettings((x) {
                              final t = x.tabs.removeAt(i);
                              x.tabs.insert(i - 1, t);
                            }),
                    ),
                    _MiniBtn(
                      icon: PhosphorIconsBold.arrowDown,
                      label: 'Move down',
                      onTap: i == s.tabs.length - 1
                          ? null
                          : () => app.updateSettings((x) {
                              final t = x.tabs.removeAt(i);
                              x.tabs.insert(i + 1, t);
                            }),
                    ),
                    _MiniBtn(
                      icon: PhosphorIconsBold.minus,
                      label: 'Hide',
                      onTap: s.tabs.length <= 1
                          ? null
                          : () => app.updateSettings((x) {
                              x.tabs.removeAt(i);
                              if (!x.tabs.contains(app.lastTab)) app.lastTab = x.tabs.first;
                            }),
                    ),
                  ],
                ),
              ),
          ],
        ),
        if (hidden.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in hidden)
                Pill(
                  label: 'Add ${tabMeta[t]!.label}',
                  icon: PhosphorIconsBold.plus,
                  onTap: s.tabs.length >= 4 ? null : () => app.updateSettings((x) => x.tabs.add(t)),
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        ToolGroup(
          children: [
            ToolRow(
              icon: PhosphorIconsRegular.textT,
              label: 'Show labels',
              trailing: TinySwitch(value: s.showLabels, onChanged: (v) => app.updateSettings((x) => x.showLabels = v)),
            ),
            ToolRow(
              icon: PhosphorIconsRegular.bookOpenText,
              label: 'Continue-reading button',
              detail: 'Centre of the bar; hold it for recent stories',
              trailing: TinySwitch(value: s.showCenterButton, onChanged: (v) => app.updateSettings((x) => x.showCenterButton = v)),
            ),
          ],
        ),
        const SizedBox(height: 26),
        const Kicker('Library'),
        const SizedBox(height: 10),
        ToolGroup(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: SegToggle<String>(
                value: s.libraryView,
                expand: true,
                options: const {'grid': 'Covers', 'list': 'List'},
                onChanged: (v) => app.updateSettings((x) => x.libraryView = v),
              ),
            ),
            if (s.libraryView == 'grid')
              ToolRow(
                label: 'Covers per row',
                trailing: SegToggle<int>(
                  value: s.gridColumns,
                  options: const {2: '2', 3: '3'},
                  onChanged: (v) => app.updateSettings((x) => x.gridColumns = v),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _MiniBtn extends StatelessWidget {
  const _MiniBtn({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    return Semantics(
      button: true,
      label: label,
      enabled: onTap != null,
      child: Pressable(
        scale: 0.88,
        onTap: onTap == null
            ? null
            : () {
                Haptic.selection();
                onTap!();
              },
        child: SizedBox(
          width: 36,
          height: 44,
          child: Center(
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: c.bgRaised2, borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 14, color: onTap == null ? c.textTertiary.withValues(alpha: 0.4) : c.text),
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ motion

class MotionScreen extends StatefulWidget {
  const MotionScreen({super.key});

  @override
  State<MotionScreen> createState() => _MotionScreenState();
}

class _MotionScreenState extends State<MotionScreen> {
  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final s = app.settings;
    final c = context.sc;
    return PageScroll(
      id: 'settings-motion',
      children: [
        ScreenHeader(title: 'Transitions', onBack: app.back),
        const SizedBox(height: 22),
        Text(
          'How screens hand over when you switch tabs or open a page. '
          'Switch tabs to see the result.',
          style: AppTheme.f(13, weight: FontWeight.w500, color: c.textSecondary, height: 1.45),
        ),
        const SizedBox(height: 16),
        OptionGroup<String>(
          selected: s.transition,
          onSelect: (v) => app.updateSettings((x) => x.transition = v),
          items: const [
            OptionItem('blur', 'Blur', icon: PhosphorIconsRegular.drop, detail: 'The old page drifts out of focus as the new one sharpens'),
            OptionItem('fade', 'Fade', icon: PhosphorIconsRegular.circleHalf, detail: 'A plain cross-fade'),
            OptionItem('slide', 'Slide', icon: PhosphorIconsRegular.arrowsLeftRight, detail: 'Pages slide sideways and up'),
            OptionItem('scale', 'Zoom', icon: PhosphorIconsRegular.arrowsOut, detail: 'The new page settles in from slightly larger'),
            OptionItem('none', 'None', icon: PhosphorIconsRegular.prohibit, detail: 'Instant'),
          ],
        ),
        const SizedBox(height: 16),
        ToolGroup(
          children: [
            if (s.transition == 'blur')
              SliderRow(
                label: 'Blur strength',
                value: s.transitionBlur,
                min: 2,
                max: 24,
                divisions: 22,
                format: (v) => v.round().toString(),
                onChanged: (v) => app.updateSettings((x) => x.transitionBlur = v),
              ),
            if (s.transition != 'none')
              SliderRow(
                label: 'Duration',
                value: s.transitionMs.toDouble(),
                min: 180,
                max: 800,
                divisions: 31,
                format: (v) => '${v.round()} ms',
                onChanged: (v) => app.updateSettings((x) => x.transitionMs = v.round()),
              ),
          ],
        ),
        const SizedBox(height: 16),
        GhostButton(
          label: 'Try it: open the Library',
          icon: PhosphorIconsBold.play,
          onTap: () => app.go(app.visibleTabs.first),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ about

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final c = context.sc;
    final body = AppTheme.f(13.5, weight: FontWeight.w500, color: c.textSecondary, height: 1.5);
    Widget point(IconData icon, String title, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: c.accentSoft, shape: BoxShape.circle),
            child: Icon(icon, size: 18, color: c.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTheme.f(15, color: c.text)),
                const SizedBox(height: 3),
                Text(text, style: body),
              ],
            ),
          ),
        ],
      ),
    );
    return PageScroll(
      id: 'settings-about',
      children: [
        ScreenHeader(title: 'Privacy and about', onBack: app.back),
        const SizedBox(height: 24),
        Text('Sefer', style: AppTheme.f(44, weight: FontWeight.w800, color: c.text)),
        const SizedBox(height: 6),
        Text('A quiet reader for learning languages from texts you choose.', style: body),
        const SizedBox(height: 26),
        point(
          PhosphorIconsRegular.wifiSlash,
          'Fully offline',
          'The app has no internet permission. It cannot send anything anywhere, and there is no account, analytics or ads.',
        ),
        point(
          PhosphorIconsRegular.hardDrives,
          'Stored on this device',
          'Stories, words, stats and settings are JSON files in the app\'s private storage. Uninstalling the app removes them.',
        ),
        point(
          PhosphorIconsRegular.export,
          'Yours to take',
          'Back up everything to one file, export stories in the import format, or export words to Anki, whenever you like.',
        ),
        point(
          PhosphorIconsRegular.handHeart,
          'Honest numbers',
          'Reading time only counts while the reader is open and you\'ve touched it in the last two minutes.',
        ),
        const SizedBox(height: 10),
        ToolGroup(
          children: [
            ToolRow(icon: PhosphorIconsRegular.info, label: 'Version', value: '0.1.0'),
            ToolRow(
              icon: PhosphorIconsRegular.scroll,
              label: 'Licences',
              detail: 'Fonts are under the SIL Open Font License',
              onTap: () => showLicensePage(context: context, applicationName: 'Sefer', applicationVersion: '0.1.0'),
            ),
          ],
        ),
      ],
    );
  }
}
