import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../app/app_shell.dart';
import '../data/app_icon.dart';
import '../data/app_state.dart';
import '../data/exporter.dart';
import '../data/io.dart';
import '../data/languages.dart';
import '../data/models.dart';
import '../theme/app_colors.dart';
import '../data/stats.dart';
import '../theme/app_theme.dart';
import '../theme/feel.dart';
import '../theme/presets.dart';
import '../widgets/covers.dart';
import '../widgets/common.dart';
import '../widgets/notch_toast.dart';
import '../widgets/ui_kit.dart';
import 'reader_controls.dart';
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
        SoftCard(
          radius: 28,
          child: Column(
            children: [
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
                        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.f(22, weight: FontWeight.w800, color: c.text)),
                        const SizedBox(height: 3),
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
              const SizedBox(height: 16),
              Divider(height: 1, color: c.border.withValues(alpha: 0.5)),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _Mini(value: '${app.dailyStreak}', label: 'Day streak', icon: PhosphorIconsFill.flame, color: c.accent, onTap: () => app.go('stats'))),
                  Expanded(child: _Mini(value: '${app.knownCount(app.scoped ? app.activeLanguage : null)}', label: 'Known words', icon: PhosphorIconsFill.checkCircle, color: c.sage, onTap: () => app.go('words'))),
                  Expanded(child: _Mini(value: '${app.visibleStories.length}', label: 'Stories', icon: PhosphorIconsFill.books, color: c.brass, onTap: () => app.go('library'))),
                ],
              ),
            ],
          ),
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
        // Languages, as chips.
        SectionHeading('Languages'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final l in langs)
              _LangChip(
                code: l,
                active: l == app.activeLanguage,
                onTap: () => _languageSheet(context, l),
              ),
            Pill(
              label: 'Add',
              icon: PhosphorIconsBold.plus,
              onTap: () async {
                final l = await pickLanguage(context, title: 'Language you study');
                if (l != null) app.updateSettings((x) => x.learning.contains(l) ? null : x.learning.add(l));
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        ToolGroup(
          children: [
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
            ToolRow(
              icon: PhosphorIconsRegular.eyeSlash,
              label: 'Only show the language I\'m studying',
              detail: 'Hides the others in the library, words and stats',
              trailing: TinySwitch(
                value: s.languageScope == 'active',
                onChanged: (v) => app.updateSettings((x) => x.languageScope = v ? 'active' : 'all'),
              ),
            ),
          ],
        ),
        SizedBox(height: feel.section),
        SectionHeading('Settings'),
        const SizedBox(height: 12),
        GridView.count(
          padding: EdgeInsets.zero,
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.3,
          children: [
            _CategoryTile(
              icon: PhosphorIconsFill.palette,
              color: c.accent,
              title: 'Appearance',
              summary: '${_themeName(app)} · ${Feel.byId(s.feel).label}',
              onTap: () => app.go('settings:appearance'),
            ),
            _CategoryTile(
              icon: PhosphorIconsFill.bookOpenText,
              color: c.sage,
              title: 'Reading',
              summary: 'Goal ${s.dailyGoalMinutes} min · text ${s.fontSize.round()}',
              onTap: () => app.go('settings:reader'),
            ),
            _CategoryTile(
              icon: PhosphorIconsFill.compass,
              color: c.info,
              title: 'Navigation',
              summary: '${s.tabs.length} tabs · ${_transitionName(s.transition).toLowerCase()}',
              onTap: () => app.go('settings:layout'),
            ),
            _CategoryTile(
              icon: s.internet ? PhosphorIconsFill.globe : PhosphorIconsFill.globeX,
              color: c.brass,
              title: 'Internet & AI',
              summary: s.internet ? 'On · ${s.translator == 'off' ? 'stories' : 'stories, translation'}' : 'Off',
              onTap: () => app.go('settings:ai'),
            ),
            _CategoryTile(
              icon: PhosphorIconsFill.hardDrives,
              color: c.warn,
              title: 'Your data',
              summary: s.lastBackupAt == null ? 'Never backed up' : 'Backed up ${_ago(s.lastBackupAt!)}',
              onTap: () => app.go('settings:data'),
            ),
            _CategoryTile(
              icon: PhosphorIconsFill.shieldCheck,
              color: c.textSecondary,
              title: 'Privacy & about',
              summary: s.internet ? 'Online when you ask' : 'Fully offline',
              onTap: () => app.go('settings:about'),
            ),
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
    final m => presetById(m)?.name ?? 'Dark',
  };

  static String _transitionName(String t) => switch (t) {
    'fade' => 'Fade',
    'slide' => 'Slide',
    'scale' => 'Zoom',
    'none' => 'None',
    _ => 'Blur',
  };

  static Future<void> _editProfile(BuildContext context) async {
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

  static Future<void> _languageSheet(BuildContext context, String lang) => showAppSheet<void>(
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
                value: readerFontFor(s.fontByLanguage, s.readerFont, lang).label,
                onTap: () async {
                  final current = readerFontFor(s.fontByLanguage, s.readerFont, lang);
                  final v = await pickOption<String>(
                    ctx,
                    title: 'Font for ${languageName(lang)}',
                    selected: current.id,
                    items: [for (final f in fontsFor(fontScriptOf(lang))) OptionItem(f.id, f.label, detail: f.note)],
                  );
                  if (v != null) app.updateSettings((x) => x.fontByLanguage[lang] = v);
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

  static Future<void> _backup(BuildContext context) async {
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

  static Future<void> _restore(BuildContext context) async {
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

  static Future<void> _wipe(BuildContext context) async {
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


class _LangChip extends StatelessWidget {
  const _LangChip({required this.code, required this.active, required this.onTap});
  final String code;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    return Semantics(
      button: true,
      selected: active,
      label: '${languageName(code)}${active ? ', studying now' : ''}',
      excludeSemantics: true,
      child: Pressable(
        scale: 0.95,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
          decoration: BoxDecoration(
            color: active ? c.accentSoft : c.bgRaised,
            borderRadius: BorderRadius.circular(context.feel.pill(40)),
            border: Border.all(color: active ? c.accent : c.border.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              LangBadge(code),
              const SizedBox(width: 8),
              Text(languageName(code), style: AppTheme.f(13.5, weight: FontWeight.w700, color: c.text)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A settings category on the profile page.
class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.icon, required this.color, required this.title, required this.summary, required this.onTap});
  final IconData icon;
  final Color color;
  final String title;
  final String summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    return Semantics(
      button: true,
      label: '$title. $summary',
      excludeSemantics: true,
      child: Pressable(
        scale: 0.97,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: c.bgRaised, borderRadius: BorderRadius.circular(context.feel.r(22))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(context.feel.r(12))),
                child: Icon(icon, size: 19, color: color),
              ),
              const Spacer(),
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.f(15, weight: FontWeight.w800, color: c.text)),
              const SizedBox(height: 2),
              Text(summary, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.f(12, weight: FontWeight.w500, color: c.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ data

class DataScreen extends StatelessWidget {
  const DataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final s = app.settings;
    final c = context.sc;
    return PageScroll(
      id: 'settings-data',
      children: [
        ScreenHeader(title: 'Your data', onBack: app.back),
        const SizedBox(height: 16),
        Text(
          'Everything lives in this app\'s private storage. Back it up to a file you keep, or take your stories and words elsewhere.',
          style: AppTheme.f(13, weight: FontWeight.w500, color: c.textSecondary, height: 1.45),
        ),
        const SizedBox(height: 18),
        ToolGroup(
          children: [
            ToolRow(
              icon: PhosphorIconsRegular.cloudArrowDown,
              label: 'Back up everything',
              detail: s.lastBackupAt == null ? 'Never backed up' : 'Last: ${ProfileScreen._ago(s.lastBackupAt!)}',
              onTap: () => ProfileScreen._backup(context),
            ),
            ToolRow(icon: PhosphorIconsRegular.cloudArrowUp, label: 'Restore a backup', onTap: () => ProfileScreen._restore(context)),
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
          ],
        ),
        const SizedBox(height: 14),
        ToolGroup(
          children: [
            ToolRow(
              icon: PhosphorIconsRegular.export,
              label: 'Export all stories',
              detail: 'In the import format',
              onTap: app.stories.isEmpty ? null : () => exportStoriesFlow(context, app.stories),
            ),
            ToolRow(icon: PhosphorIconsRegular.cards, label: 'Export words to Anki', onTap: () => showAnkiExport(context)),
          ],
        ),
        const SizedBox(height: 14),
        ToolGroup(
          children: [
            ToolRow(icon: PhosphorIconsRegular.trash, label: 'Erase everything', danger: true, onTap: () => ProfileScreen._wipe(context)),
          ],
        ),
      ],
    );
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
    return Semantics(
      button: true,
      label: '$value $label',
      excludeSemantics: true,
      child: Pressable(
        scale: 0.95,
        onTap: onTap,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Text(value, style: AppTheme.f(20, weight: FontWeight.w800, color: c.text)),
              ],
            ),
            const SizedBox(height: 2),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.f(11.5, weight: FontWeight.w600, color: c.textTertiary)),
          ],
        ),
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
        const SizedBox(height: 18),
        const Kicker('Popular'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 12,
          children: [
            for (final p in themePresets)
              SizedBox(
                width: (MediaQuery.sizeOf(context).width - context.feel.gutter * 2 - 20) / 3,
                child: _ThemeTile(label: p.name, palette: p.palette, selected: s.themeMode == p.id, onTap: () => mode(p.id)),
              ),
          ],
        ),
        const SizedBox(height: 18),
        if (s.customThemes.isNotEmpty) ...[
          const Kicker('Yours'),
          const SizedBox(height: 10),
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
        const Kicker('App icon'),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final e in AppIcon.all.entries) ...[
              if (e.key != AppIcon.all.keys.first) const SizedBox(width: 14),
              Semantics(
                button: true,
                selected: s.appIcon == e.key,
                label: '${e.value.$1} icon',
                excludeSemantics: true,
                child: Pressable(
                  scale: 0.94,
                  onTap: () async {
                    if (s.appIcon == e.key) return;
                    app.updateSettings((x) => x.appIcon = e.key);
                    final ok = await AppIcon.set(e.key);
                    if (!context.mounted) return;
                    showNotchToast(
                      context,
                      title: ok ? '${e.value.$1} icon' : 'Icon saved',
                      subtitle: ok ? 'Your launcher may take a moment to update' : 'Applies on the phone',
                      icon: PhosphorIconsFill.appWindow,
                    );
                  },
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(context.feel.r(24)),
                          border: Border.all(color: s.appIcon == e.key ? c.ember : Colors.transparent, width: 2.5),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(context.feel.r(19)),
                          child: Image.asset('assets/icons/${e.key}.png', width: 64, height: 64, filterQuality: FilterQuality.medium),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        e.value.$1,
                        style: AppTheme.f(12.5, weight: s.appIcon == e.key ? FontWeight.w800 : FontWeight.w600, color: s.appIcon == e.key ? c.text : c.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Both follow your phone\'s themed icons on Android 13 and later.',
          style: AppTheme.f(12, weight: FontWeight.w500, color: c.textTertiary),
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
        const Kicker('Glass'),
        const SizedBox(height: 10),
        ToolGroup(
          children: [
            ToolRow(
              label: 'Frosted glass',
              detail: 'Blur behind the bars. Turn off for extra smoothness on older phones.',
              trailing: TinySwitch(value: s.glass, onChanged: (v) => app.updateSettings((x) => x.glass = v)),
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
    return PageScroll(
      id: 'settings-reader',
      children: [
        ScreenHeader(title: 'Reading', onBack: app.back),
        const SizedBox(height: 20),
        const Kicker('Goal'),
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
              detail: 'Off: a minute of reading keeps it alive',
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
        const SizedBox(height: 26),
        const Kicker('Reader'),
        const SizedBox(height: 10),
        ReaderSettingsTabs(language: app.activeLanguage ?? (s.learning.isNotEmpty ? s.learning.first : 'en'), pickLanguage: true),
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
        const SizedBox(height: 22),
        const Kicker('Dock style'),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, box) => Wrap(
            spacing: 10,
            runSpacing: 12,
            children: [
              for (final st in navStyles)
                SizedBox(
                  width: (box.maxWidth - 20) / 3,
                  child: _DockTile(
                    style: st,
                    selected: s.navStyle == st,
                    onTap: () => app.updateSettings((x) => x.navStyle = st),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ToolGroup(
          children: [
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
        const SizedBox(height: 26),
        const Kicker('Moving between screens'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in const {'blur': 'Blur', 'fade': 'Fade', 'slide': 'Slide', 'scale': 'Zoom', 'none': 'None'}.entries)
              Pill(label: e.value, selected: s.transition == e.key, onTap: () => app.updateSettings((x) => x.transition = e.key)),
          ],
        ),
        const SizedBox(height: 12),
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
          ],
        ),
      ],
    );
  }
}

/// A small drawing of a dock style.
class _DockTile extends StatelessWidget {
  const _DockTile({required this.style, required this.selected, required this.onTap});
  final String style;
  final bool selected;
  final VoidCallback onTap;

  static const _names = {
    'floating': 'Floating',
    'island': 'Island',
    'bubble': 'Bubble',
    'docked': 'Docked',
    'line': 'Line',
  };

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    final docked = style == 'docked' || style == 'line';
    Widget dot(bool on) {
      final col = on
          ? (style == 'bubble' ? c.onEmber : (style == 'line' ? c.accent : c.text))
          : c.textTertiary;
      Widget icon = Container(width: 9, height: 9, decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(3)));
      if (on && style != 'line') {
        icon = Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
          decoration: BoxDecoration(
            color: style == 'bubble' ? c.ember : c.text.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: icon,
        );
      }
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          if (style == 'line') ...[
            const SizedBox(height: 3),
            Container(width: 10, height: 2, color: on ? c.accent : Colors.transparent),
          ],
        ],
      );
    }

    final bar = Container(
      height: 30,
      width: style == 'island' ? 72 : double.infinity,
      margin: docked ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: c.bgRaised2,
        borderRadius: docked ? null : BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [dot(true), dot(false), dot(false)],
      ),
    );
    return Semantics(
      button: true,
      selected: selected,
      label: '${_names[style]} dock',
      excludeSemantics: true,
      child: Pressable(
        scale: 0.96,
        onTap: onTap,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              height: 84,
              decoration: BoxDecoration(
                color: c.bgRaised,
                borderRadius: BorderRadius.circular(context.feel.r(18)),
                border: Border.all(color: selected ? c.ember : c.border, width: selected ? 2.5 : 1),
              ),
              clipBehavior: Clip.antiAlias,
              alignment: Alignment.bottomCenter,
              padding: EdgeInsets.only(bottom: docked ? 0 : 8),
              child: bar,
            ),
            const SizedBox(height: 8),
            Text(
              _names[style]!,
              style: AppTheme.f(12.5, weight: selected ? FontWeight.w800 : FontWeight.w600, color: selected ? c.text : c.textSecondary),
            ),
          ],
        ),
      ),
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

// ------------------------------------------------------------------ about

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final c = context.sc;
    final s = app.settings;
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
          'Offline unless you say so',
          s.internet
              ? 'Internet is on, and used only when you generate a story or load the list of models. Nothing about your library, words or stats is sent. There is no account, analytics or ads.'
              : 'Internet is off, so the app sends nothing anywhere. There is no account, analytics or ads.',
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
