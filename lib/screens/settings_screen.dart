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
import '../data/stats.dart';
import '../theme/app_theme.dart';
import '../theme/feel.dart';
import '../widgets/covers.dart';
import '../widgets/common.dart';
import '../widgets/notch_toast.dart';
import '../widgets/ui_kit.dart';
import 'reader_controls.dart';
import 'stats_screen.dart';
import 'story_actions.dart';
import 'story_screen.dart';
import 'words_screen.dart';

/// The Profile tab: who you are, what you study, and every setting.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final s = app.settings;
    final c = context.sc;
    final feel = context.feel;
    final isTab = app.visibleTabs.contains('profile');
    final langs = app.knownLanguages;
    final backupDue = s.backupReminderDays > 0 &&
        app.stories.isNotEmpty &&
        (s.lastBackupAt == null || DateTime.now().difference(s.lastBackupAt!).inDays >= s.backupReminderDays);
    final name = s.profileName.trim().isEmpty ? 'Reader' : s.profileName.trim();
    return PageScroll(
      id: 'profile',
      children: [
        if (!isTab) ...[ScreenHeader(title: 'Profile', onBack: app.back), SizedBox(height: feel.gap)],
        // Who you are.
        Row(
          children: [
            Pressable(
              scale: 0.94,
              onTap: () => _editProfile(context),
              child: _Avatar(name: name, emoji: s.profileEmoji, hue: s.profileHue, size: 64),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.f(feel.titleSize - 2, weight: FontWeight.w800, color: c.text)),
                  const SizedBox(height: 4),
                  Text(
                    langs.isEmpty ? 'Add the languages you study' : 'Studying ${langs.map(languageName).join(', ')}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.f(13, weight: FontWeight.w500, color: c.textSecondary),
                  ),
                ],
              ),
            ),
            RoundBtn(icon: PhosphorIconsRegular.pencilSimple, label: 'Edit profile', onTap: () => _editProfile(context)),
          ],
        ),
        SizedBox(height: feel.gap + 4),
        Row(
          children: [
            Expanded(child: _Mini(value: '${app.dailyStreak}', label: 'Day streak', icon: PhosphorIconsFill.flame, color: c.accent, onTap: () => app.go('stats'))),
            SizedBox(width: feel.gap * 0.7),
            Expanded(child: _Mini(value: '${app.knownCount(app.scoped ? app.activeLanguage : null)}', label: 'Known words', icon: PhosphorIconsFill.checkCircle, color: c.sage, onTap: () => app.go('words'))),
            SizedBox(width: feel.gap * 0.7),
            Expanded(child: _Mini(value: '${app.visibleStories.length}', label: 'Stories', icon: PhosphorIconsFill.books, color: c.brass, onTap: () => app.go('library'))),
          ],
        ),
        if (backupDue) ...[
          SizedBox(height: feel.gap),
          SoftCard(
            color: c.warn.withValues(alpha: 0.12),
            borderColor: Colors.transparent,
            onTap: () => _backup(context),
            child: Row(
              children: [
                Icon(PhosphorIconsFill.cloudArrowDown, color: c.warn, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    s.lastBackupAt == null
                        ? 'You haven\'t made a backup yet. Everything lives only on this phone.'
                        : 'Last backup ${DateTime.now().difference(s.lastBackupAt!).inDays} days ago.',
                    style: AppTheme.f(13, weight: FontWeight.w600, color: c.text, height: 1.35),
                  ),
                ),
                const SizedBox(width: 8),
                Text('Back up', style: AppTheme.f(13, weight: FontWeight.w800, color: c.warn)),
              ],
            ),
          ),
        ],
        SizedBox(height: feel.section),
        // Languages.
        const Kicker('Languages'),
        const SizedBox(height: 10),
        ToolGroup(
          children: [
            for (final l in langs)
              ToolRow(
                icon: l == app.activeLanguage ? PhosphorIconsFill.checkCircle : PhosphorIconsRegular.circle,
                label: languageName(l),
                detail: [
                  if (l == app.activeLanguage) 'Studying now',
                  '${app.knownCount(l)} known',
                  if (s.fontByLanguage[l] != null) readerFontById(s.fontByLanguage[l]!).label,
                ].join(' · '),
                onTap: () => _languageSheet(context, l),
              ),
            ToolRow(
              icon: PhosphorIconsRegular.plus,
              label: 'Add a language',
              onTap: () async {
                final l = await pickLanguage(context, title: 'Language you study');
                if (l != null) app.updateSettings((x) => x.learning.contains(l) ? null : x.learning.add(l));
              },
            ),
            ToolRow(
              icon: PhosphorIconsRegular.house,
              label: 'Your own language',
              value: languageName(s.nativeLanguage),
              onTap: () async {
                final l = await pickLanguage(context, title: 'Your language', selected: s.nativeLanguage);
                if (l != null) {
                  app.updateSettings((x) {
                    x.nativeLanguage = l;
                    x.defaultTranslationLang = l;
                  });
                }
              },
            ),
          ],
        ),
        SizedBox(height: feel.gap),
        ToolGroup(
          children: [
            ToolRow(
              icon: PhosphorIconsRegular.eyeSlash,
              label: 'Show only the language I\'m studying now',
              detail: 'Other languages stay out of sight in the library, words and stats. Handy when someone looks over your shoulder.',
              trailing: TinySwitch(
                value: s.languageScope == 'active',
                onChanged: (v) => app.updateSettings((x) => x.languageScope = v ? 'active' : 'all'),
              ),
            ),
          ],
        ),
        SizedBox(height: feel.section),
        const Kicker('Look and feel'),
        const SizedBox(height: 10),
        ToolGroup(
          children: [
            ToolRow(icon: PhosphorIconsRegular.palette, label: 'Appearance', value: '${_themeName(app)} · ${Feel.byId(s.feel).label}', onTap: () => app.go('settings:appearance')),
            ToolRow(
              icon: PhosphorIconsRegular.textAa,
              label: 'Reader',
              value: '${readerFontById(s.readerFont).label} · ${s.fontSize.round()}',
              onTap: () => app.go('settings:reader'),
            ),
            ToolRow(icon: PhosphorIconsRegular.layout, label: 'Navigation', value: '${s.tabs.length} tabs', onTap: () => app.go('settings:layout')),
            ToolRow(icon: PhosphorIconsRegular.sparkle, label: 'Transitions', value: _transitionName(s.transition), onTap: () => app.go('settings:motion')),
            ToolRow(icon: PhosphorIconsRegular.squaresFour, label: 'Activity chart', value: '${s.heatWeeks} weeks', onTap: () => showHeatmapSettings(context)),
          ],
        ),
        SizedBox(height: feel.section),
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
          ],
        ),
        SizedBox(height: feel.section),
        const Kicker('Your data'),
        const SizedBox(height: 10),
        ToolGroup(
          children: [
            ToolRow(
              icon: PhosphorIconsRegular.cloudArrowDown,
              label: 'Back up everything',
              detail: s.lastBackupAt == null ? 'Never backed up' : 'Last: ${_ago(s.lastBackupAt!)}',
              onTap: () => _backup(context),
            ),
            ToolRow(icon: PhosphorIconsRegular.cloudArrowUp, label: 'Restore a backup', onTap: () => _restore(context)),
            ToolRow(
              icon: PhosphorIconsRegular.bellSimple,
              label: 'Remind me to back up',
              value: s.backupReminderDays == 0 ? 'Never' : 'Every ${s.backupReminderDays} days',
              onTap: () async {
                final v = await pickOption<int>(context, title: 'Backup reminder', selected: s.backupReminderDays, items: const [
                  OptionItem(7, 'Every week'),
                  OptionItem(14, 'Every two weeks'),
                  OptionItem(30, 'Every month'),
                  OptionItem(0, 'Never'),
                ]);
                if (v != null) app.updateSettings((x) => x.backupReminderDays = v);
              },
            ),
            ToolRow(
              icon: PhosphorIconsRegular.export,
              label: 'Export all stories',
              detail: 'In the import format',
              onTap: app.stories.isEmpty ? null : () => exportStoriesFlow(context, app.stories),
            ),
            ToolRow(icon: PhosphorIconsRegular.cards, label: 'Export words to Anki', onTap: () => showAnkiExport(context)),
            ToolRow(icon: PhosphorIconsRegular.trash, label: 'Erase everything', danger: true, onTap: () => _wipe(context)),
          ],
        ),
        SizedBox(height: feel.section),
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
            ToolRow(icon: PhosphorIconsRegular.shieldCheck, label: 'Privacy and about', onTap: () => app.go('settings:about')),
          ],
        ),
      ],
    );
  }

  static String _ago(DateTime d) {
    final days = DateTime.now().difference(d).inDays;
    return days == 0 ? 'today' : (days == 1 ? 'yesterday' : '$days days ago');
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

  Future<void> _editProfile(BuildContext context) async {
    final app = context.appRead;
    final s = app.settings;
    final nameCtl = TextEditingController(text: s.profileName);
    const emojis = ['', '📚', '🦉', '🌿', '☕', '🌙', '🦊', '🐢', '✍️', '🎧', '🧭', '🍵'];
    await showAppSheet<void>(
      context,
      (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final c = ctx.sc;
          final st = app.settings;
          return SheetBody(
            title: 'Profile',
            subtitle: 'Only on this device',
            children: [
              Center(child: _Avatar(name: nameCtl.text.isEmpty ? 'Reader' : nameCtl.text, emoji: st.profileEmoji, hue: st.profileHue, size: 84)),
              const SizedBox(height: 18),
              AppField(
                controller: nameCtl,
                label: 'Name',
                hint: 'What should Sefer call you?',
                onChanged: (v) {
                  app.updateSettings((x) => x.profileName = v.trim());
                  setSheet(() {});
                },
              ),
              const SizedBox(height: 18),
              const Kicker('Picture'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in emojis)
                    Pressable(
                      scale: 0.9,
                      onTap: () => app.updateSettings((x) => x.profileEmoji = e),
                      child: Container(
                        width: 46,
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: c.bgRaised2,
                          shape: BoxShape.circle,
                          border: Border.all(color: st.profileEmoji == e ? c.ember : Colors.transparent, width: 2),
                        ),
                        child: e.isEmpty
                            ? Text('Aa', style: AppTheme.f(14, weight: FontWeight.w800, color: c.textSecondary))
                            : Text(e, style: const TextStyle(fontSize: 22)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              const Kicker('Colour'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (var i = 0; i < coverHues.length; i++)
                    Pressable(
                      scale: 0.9,
                      onTap: () => app.updateSettings((x) => x.profileHue = i),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: coverHues[i],
                          shape: BoxShape.circle,
                          border: Border.all(color: st.profileHue == i ? c.ember : Colors.transparent, width: 2.5),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _languageSheet(BuildContext context, String lang) => showAppSheet<void>(
    context,
    (ctx) {
      final app = ctx.app;
      final s = app.settings;
      final c = ctx.sc;
      final t = totals(app.activity);
      return SheetBody(
        title: languageName(lang),
        subtitle: languageByCode(lang)?.native,
        children: [
          Row(
            children: [
              Expanded(child: StatValue(value: '${app.knownCount(lang)}', label: 'Known', roll: false)),
              Expanded(child: StatValue(value: '${app.languageStreak(lang)}', label: 'Streak', roll: false)),
              Expanded(child: StatValue(value: formatDuration(t.langSeconds[lang] ?? 0, short: true), label: 'Read', roll: false)),
            ],
          ),
          const SizedBox(height: 18),
          if (lang != app.activeLanguage) ...[
            PrimaryButton(
              label: 'Study ${languageName(lang)} now',
              onTap: () {
                app.setActiveLanguage(lang);
                Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 12),
          ],
          ToolGroup(
            color: c.bgRaised2,
            radius: 18,
            children: [
              ToolRow(
                icon: PhosphorIconsRegular.textAa,
                label: 'Reader font',
                value: s.fontByLanguage[lang] == null ? 'Default' : readerFontById(s.fontByLanguage[lang]!).label,
                onTap: () async {
                  final v = await pickOption<String>(
                    ctx,
                    title: 'Font for ${languageName(lang)}',
                    selected: s.fontByLanguage[lang] ?? '',
                    items: [
                      OptionItem('', 'Same as everything else', detail: readerFontById(s.readerFont).label),
                      for (final f in allReaderFonts) OptionItem(f.id, f.label, detail: f.note),
                    ],
                  );
                  if (v == null) return;
                  app.updateSettings((x) => v.isEmpty ? x.fontByLanguage.remove(lang) : x.fontByLanguage[lang] = v);
                },
              ),
            ],
          ),
          if (s.learning.contains(lang)) ...[
            const SizedBox(height: 12),
            GhostButton(
              label: 'Stop listing this language',
              color: c.danger,
              onTap: () {
                app.updateSettings((x) {
                  x.learning.remove(lang);
                  if (x.activeLanguage == lang) x.activeLanguage = null;
                });
                Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 6),
            Text(
              'Its stories and words stay; it just leaves your list.',
              textAlign: TextAlign.center,
              style: AppTheme.f(11.5, weight: FontWeight.w500, color: c.textTertiary),
            ),
          ],
        ],
      );
    },
  );

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
      if (ok) app.updateSettings((x) => x.lastBackupAt = DateTime.now());
      if (ok && context.mounted) showNotchToast(context, title: 'Backup saved', subtitle: name, icon: PhosphorIconsFill.cloudCheck);
    } else {
      await Io.shareFile(name, json, mime: 'application/json');
      app.updateSettings((x) => x.lastBackupAt = DateTime.now());
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


class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.emoji, required this.hue, required this.size});
  final String name;
  final String emoji;
  final int hue;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tone = coverTone(hue, context.sc);
    final initials = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(2).map((w) => w.characters.first.toUpperCase()).join();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: tone.paper, shape: BoxShape.circle),
      child: emoji.isNotEmpty
          ? Text(emoji, style: TextStyle(fontSize: size * 0.46))
          : Text(initials.isEmpty ? '·' : initials, style: AppTheme.f(size * 0.36, weight: FontWeight.w800, color: tone.ink)),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini({required this.value, required this.label, required this.icon, required this.color, required this.onTap});
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    return SoftCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text(value, style: AppTheme.f(20, weight: FontWeight.w800, color: c.text)),
          const SizedBox(height: 2),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.f(11.5, weight: FontWeight.w600, color: c.textTertiary)),
        ],
      ),
    );
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
    const accents = [
      null,
      Color(0xFFD9A184), Color(0xFFE0B15A), Color(0xFF8FA377), Color(0xFF7FA8C9),
      Color(0xFFA78BDA), Color(0xFFE6A4B9), Color(0xFFE5674C), Color(0xFF5FB3A8),
    ];
    return PageScroll(
      id: 'settings-appearance',
      children: [
        ScreenHeader(title: 'Appearance', onBack: app.back),
        const SizedBox(height: 22),
        const Kicker('Feel'),
        const SizedBox(height: 6),
        Text(
          'How the app is laid out: spacing, density and how much detail shows.',
          style: AppTheme.f(12.5, weight: FontWeight.w500, color: c.textSecondary),
        ),
        const SizedBox(height: 12),
        GridView.count(
          padding: EdgeInsets.zero,
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.86,
          children: [
            for (final f in Feel.all)
              _FeelTile(
                feel: f,
                selected: s.feel == f.id,
                onTap: () => app.updateSettings((x) {
                  x.feel = f.id;
                  // A feel places the library differently too.
                  x.libraryView = f.libraryView;
                  if (f.id == 'compact') x.gridColumns = 3;
                  if (f.id == 'classic' || f.id == 'airy') x.gridColumns = 2;
                }),
              ),
          ],
        ),
        const SizedBox(height: 28),
        const Kicker('Theme'),
        const SizedBox(height: 10),
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
        const SizedBox(height: 14),
        if (s.customThemes.isNotEmpty) ...[
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final t in s.customThemes)
                SizedBox(
                  width: (MediaQuery.sizeOf(context).width - context.feel.gutter * 2 - 20) / 3,
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
          const SizedBox(height: 8),
          Text('Long-press a theme to edit it.', textAlign: TextAlign.center, style: AppTheme.f(11.5, weight: FontWeight.w500, color: c.textTertiary)),
          const SizedBox(height: 10),
        ],
        GhostButton(
          label: 'Create a theme',
          icon: PhosphorIconsBold.paintBrush,
          onTap: () {
            final t = app.createTheme(name: 'My theme ${s.customThemes.length + 1}', from: c);
            app.go('theme:${t.id}');
          },
        ),
        const SizedBox(height: 28),
        const Kicker('Accent'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final a in accents)
              Semantics(
                button: true,
                selected: (a == null && s.accentHex == null) || (a != null && s.accentHex == colorToHex(a)),
                label: a == null ? 'Theme accent' : 'Accent ${colorToHex(a)}',
                excludeSemantics: true,
                child: Pressable(
                  scale: 0.9,
                  onTap: () => app.updateSettings((x) => x.accentHex = a == null ? null : colorToHex(a)),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: a ?? c.bgRaised2,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: ((a == null && s.accentHex == null) || (a != null && s.accentHex == colorToHex(a))) ? c.ember : c.border,
                        width: 2.5,
                      ),
                    ),
                    child: a == null ? Icon(PhosphorIconsBold.arrowCounterClockwise, size: 14, color: c.textSecondary) : null,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 28),
        const Kicker('Shape and type'),
        const SizedBox(height: 10),
        ToolGroup(
          children: [
            SliderRow(
              label: 'Corner roundness',
              value: s.roundness,
              min: 0.4,
              max: 1.6,
              divisions: 12,
              format: (v) => v < 0.7 ? 'Square' : (v > 1.2 ? 'Round' : 'Soft'),
              onChanged: (v) => app.updateSettings((x) => x.roundness = double.parse(v.toStringAsFixed(1))),
            ),
            SliderRow(
              label: 'Interface text size',
              value: s.uiScale,
              min: 0.85,
              max: 1.3,
              divisions: 9,
              format: (v) => '${(v * 100).round()}%',
              onChanged: (v) => app.updateSettings((x) => x.uiScale = double.parse(v.toStringAsFixed(2))),
            ),
            ToolRow(
              label: 'Interface font',
              value: uiFonts[s.uiFont]?.$1 ?? 'Nunito',
              onTap: () async {
                final v = await pickOption<String>(context, title: 'Interface font', selected: s.uiFont, items: [
                  for (final e in uiFonts.entries) OptionItem(e.key, e.value.$1),
                ]);
                if (v != null) app.updateSettings((x) => x.uiFont = v);
              },
            ),
          ],
        ),
        const SizedBox(height: 28),
        const Kicker('Surfaces'),
        const SizedBox(height: 10),
        ToolGroup(
          children: [
            ToolRow(
              label: 'Frosted glass',
              detail: 'Blur behind the bars. Turn off for extra smoothness on older phones.',
              trailing: TinySwitch(value: s.glass, onChanged: (v) => app.updateSettings((x) => x.glass = v)),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: SegToggle<String>(
                value: s.background,
                expand: true,
                options: const {'none': 'Plain', 'dots': 'Dots', 'grid': 'Grid'},
                onChanged: (v) => app.updateSettings((x) => x.background = v),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A feel, drawn as a tiny wireframe of the library in that layout.
class _FeelTile extends StatelessWidget {
  const _FeelTile({required this.feel, required this.selected, required this.onTap});
  final Feel feel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    Widget bar(double w, double h, Color col) => Container(width: w, height: h, decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(h / 2)));
    Widget card(double w, double h) => Container(width: w, height: h, decoration: BoxDecoration(color: c.bgRaised2, borderRadius: BorderRadius.circular(6 * feel.radius)));
    final preview = switch (feel.id) {
      'minimal' => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            bar(44, 7, c.text),
            const SizedBox(height: 12),
            for (var i = 0; i < 4; i++) ...[bar(70.0 - i * 9, 5, c.textSecondary), const SizedBox(height: 9)],
          ],
        ),
      'compact' => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            bar(34, 6, c.text),
            const SizedBox(height: 6),
            for (var i = 0; i < 5; i++) ...[
              Row(children: [card(10, 13), const SizedBox(width: 5), bar(50, 4, c.textSecondary)]),
              const SizedBox(height: 4),
            ],
          ],
        ),
      'airy' => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            bar(50, 8, c.text),
            const SizedBox(height: 12),
            Row(children: [card(34, 44), const SizedBox(width: 10), card(34, 44)]),
          ],
        ),
      _ => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            bar(22, 3, c.textTertiary),
            const SizedBox(height: 4),
            bar(42, 7, c.text),
            const SizedBox(height: 9),
            Row(children: [card(26, 34), const SizedBox(width: 6), card(26, 34), const SizedBox(width: 6), card(26, 34)]),
            const SizedBox(height: 5),
            bar(56, 4, c.textSecondary),
          ],
        ),
    };
    return Semantics(
      button: true,
      selected: selected,
      label: '${feel.label}. ${feel.blurb}',
      excludeSemantics: true,
      child: Pressable(
        scale: 0.96,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.bgRaised,
            borderRadius: BorderRadius.circular(context.feel.r(20)),
            border: Border.all(color: selected ? c.ember : c.border.withValues(alpha: 0.6), width: selected ? 2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: preview),
              Text(feel.label, style: AppTheme.f(14.5, weight: FontWeight.w800, color: c.text)),
              const SizedBox(height: 2),
              Text(feel.blurb, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTheme.f(11, weight: FontWeight.w500, color: c.textSecondary, height: 1.25)),
            ],
          ),
        ),
      ),
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
        ScreenHeader(title: 'Navigation', onBack: app.back),
        const SizedBox(height: 22),
        const Kicker('Navigation bar'),
        const SizedBox(height: 6),
        Text(
          'Up to $maxTabs tabs; the bar re-spaces itself as you add or remove them. '
          'Anything you hide stays reachable: Profile holds every setting, and '
          'the streak opens Stats.',
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
                  onTap: s.tabs.length >= maxTabs ? null : () => app.updateSettings((x) => x.tabs.add(t)),
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
        const SizedBox(height: 16),
        ToolGroup(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: SegToggle<String>(
                value: s.navStyle,
                expand: true,
                options: const {'floating': 'Floating bar', 'docked': 'Docked to the edge'},
                onChanged: (v) => app.updateSettings((x) => x.navStyle = v),
              ),
            ),
            ToolRow(
              icon: PhosphorIconsRegular.rocketLaunch,
              label: 'Open the app on',
              value: s.startTab == 'last' ? 'Where I left off' : tabMeta[s.startTab]?.label ?? 'Library',
              onTap: () async {
                final v = await pickOption<String>(context, title: 'Open the app on', selected: s.startTab, items: [
                  const OptionItem('last', 'Where I left off'),
                  for (final t in s.tabs) OptionItem(t, tabMeta[t]!.label, icon: tabMeta[t]!.icon),
                ]);
                if (v != null) app.updateSettings((x) => x.startTab = v);
              },
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
