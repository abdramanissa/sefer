import 'dart:math';

import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../data/app_state.dart';
import '../data/languages.dart';
import '../data/models.dart';
import '../data/stats.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/heatmap.dart';
import '../widgets/motion.dart';
import '../widgets/ui_kit.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsState {
  static String range = '30'; // 7 | 30 | all
  static String? heatLanguage;
}

class _StatsScreenState extends State<StatsScreen> {
  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final c = context.sc;
    final s = app.settings;
    final today = app.today;
    final goal = s.dailyGoalMinutes * 60;
    final since = switch (_StatsState.range) {
      '7' => DateTime.now().subtract(const Duration(days: 6)),
      '30' => DateTime.now().subtract(const Duration(days: 29)),
      _ => null,
    };
    final t = totals(app.activity, since: since);
    final all = totals(app.activity);
    final best = bestStreak(app.activity, app.streakTest);
    final langs = app.activeLanguages;
    final finished = app.stories.where((x) => x.finishedAt != null).length;

    return PageScroll(
      id: 'stats',
      children: [
        const TabHeader(kicker: 'Your reading', title: 'Stats', actions: [StreakPill(), SettingsAction()]),
        const SizedBox(height: 20),
        // Today.
        SoftCard(
          radius: 26,
          child: Row(
            children: [
              GoalRing(value: goal == 0 ? 0 : today.seconds / goal, size: 76, stroke: 7),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Kicker('Today'),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        RollIn(value: today.seconds ~/ 60, style: AppTheme.f(30, weight: FontWeight.w800, color: c.text)),
                        const SizedBox(width: 4),
                        Text('/ ${s.dailyGoalMinutes} min', style: AppTheme.f(13, weight: FontWeight.w600, color: c.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${today.words} words read · ${today.known} new known',
                      style: AppTheme.f(12.5, weight: FontWeight.w500, color: c.textSecondary),
                    ),
                  ],
                ),
              ),
              RoundBtn(
                icon: PhosphorIconsRegular.target,
                label: 'Daily goal',
                onTap: () => _goalSheet(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: SoftCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(PhosphorIconsFill.flame, color: app.dailyStreak > 0 ? c.accent : c.textTertiary, size: 22),
                    const SizedBox(height: 10),
                    StatValue(value: '${app.dailyStreak}', unit: app.dailyStreak == 1 ? 'day' : 'days', label: 'Daily streak'),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: SoftCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(PhosphorIconsFill.trophy, color: c.brass, size: 22),
                    const SizedBox(height: 10),
                    StatValue(value: '$best', unit: best == 1 ? 'day' : 'days', label: 'Best streak'),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (langs.isNotEmpty) ...[
          const SizedBox(height: 30),
          const SectionHeading('Language streaks'),
          const SizedBox(height: 14),
          ToolGroup(
            children: [
              for (final l in langs)
                _LangRow(
                  lang: l,
                  streak: app.languageStreak(l),
                  seconds: all.langSeconds[l] ?? 0,
                  words: all.langWords[l] ?? 0,
                  known: app.knownCount(l),
                ),
            ],
          ),
        ],
        const SizedBox(height: 30),
        SectionHeading('Activity', onTap: () => showHeatmapSettings(context)),
        const SizedBox(height: 14),
        SoftCard(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  SegToggle<String>(
                    value: s.heatMetric,
                    options: const {'time': 'Time', 'words': 'Words'},
                    onChanged: (v) => app.updateSettings((x) => x.heatMetric = v),
                  ),
                  const Spacer(),
                  if (langs.length > 1)
                    Pill(
                      dense: true,
                      label: _StatsState.heatLanguage == null ? 'All languages' : languageName(_StatsState.heatLanguage!),
                      icon: PhosphorIconsBold.caretDown,
                      onTap: () async {
                        final v = await pickOption<String>(
                          context,
                          title: 'Show activity in',
                          selected: _StatsState.heatLanguage ?? '*',
                          items: [const OptionItem('*', 'All languages'), for (final l in langs) OptionItem(l, languageName(l))],
                        );
                        if (v != null) setState(() => _StatsState.heatLanguage = v == '*' ? null : v);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 14),
              ActivityHeatmap(
                days: app.activity,
                weeks: s.heatWeeks,
                cell: s.heatCell,
                gap: s.heatGap,
                shape: s.heatShape,
                ramp: s.heatRamp,
                metric: s.heatMetric,
                goalMinutes: s.dailyGoalMinutes,
                mondayFirst: s.weekStartsMonday,
                language: _StatsState.heatLanguage,
                onTapDay: (d) => _daySheet(context, d),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  Text(
                    '${all.activeDays} active days',
                    style: AppTheme.f(12, weight: FontWeight.w600, color: c.textTertiary),
                  ),
                  HeatLegend(ramp: s.heatRamp, shape: s.heatShape),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),
        Row(
          children: [
            Expanded(child: Text('Totals', style: AppTheme.f(19, color: c.text))),
            SegToggle<String>(
              value: _StatsState.range,
              options: const {'7': '7 days', '30': '30 days', 'all': 'All'},
              onChanged: (v) => setState(() => _StatsState.range = v),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SoftCard(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: StatValue(value: _hours(t.seconds), unit: t.seconds >= 3600 ? 'h' : 'min', label: 'Time reading')),
                  Expanded(child: StatValue(value: _compact(t.words), label: 'Words read')),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(child: StatValue(value: _compact(t.known), label: 'Words learned')),
                  Expanded(child: StatValue(value: _compact(t.saved), label: 'Words saved')),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(child: StatValue(value: '${t.sessions}', label: 'Sessions')),
                  Expanded(child: StatValue(value: '$finished', label: 'Stories finished')),
                ],
              ),
            ],
          ),
        ),
        if (t.langSeconds.length > 1) ...[
          const SizedBox(height: 14),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Kicker('Time by language'),
                const SizedBox(height: 12),
                for (final e in (t.langSeconds.entries.toList()..sort((a, b) => b.value.compareTo(a.value))))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(languageName(e.key), style: AppTheme.f(13.5, weight: FontWeight.w600, color: c.text))),
                            Text(formatDuration(e.value, short: true), style: AppTheme.d(12, weight: FontWeight.w600, color: c.textSecondary)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ThinProgress(value: t.seconds == 0 ? 0 : e.value / t.seconds, height: 6),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _hours(int seconds) =>
      seconds >= 3600 ? (seconds / 3600).toStringAsFixed(seconds >= 36000 ? 0 : 1) : '${seconds ~/ 60}';

  String _compact(int n) => n >= 10000 ? '${(n / 1000).toStringAsFixed(n >= 100000 ? 0 : 1)}k' : '$n';

  Future<void> _goalSheet(BuildContext context) => showAppSheet<void>(
    context,
    (ctx) {
      final app = ctx.app;
      final s = app.settings;
      return SheetBody(
        title: 'Daily goal',
        subtitle: 'Minutes of reading a day',
        children: [
          Center(
            child: StepperControl(
              value: s.dailyGoalMinutes.toDouble(),
              min: 5,
              max: 180,
              step: 5,
              format: (v) => '${v.round()} min',
              onChanged: (v) => app.updateSettings((x) => x.dailyGoalMinutes = v.round()),
            ),
          ),
          const SizedBox(height: 18),
          ToolGroup(
            color: ctx.sc.bgRaised2,
            radius: 18,
            children: [
              ToolRow(
                label: 'Streak needs the goal',
                detail: 'Off: any reading keeps the streak alive',
                trailing: TinySwitch(value: s.streakNeedsGoal, onChanged: (v) => app.updateSettings((x) => x.streakNeedsGoal = v)),
              ),
            ],
          ),
        ],
      );
    },
  );

  Future<void> _daySheet(BuildContext context, DateTime d) {
    final app = context.appRead;
    final a = app.activity[dayKey(d)] ?? DayActivity();
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return showAppSheet<void>(
      context,
      (ctx) => SheetBody(
        title: '${d.day} ${months[d.month - 1]} ${d.year}',
        subtitle: a.isActive ? null : 'No reading this day',
        children: [
          Row(
            children: [
              Expanded(child: StatValue(value: '${a.seconds ~/ 60}', unit: 'min', label: 'Reading', roll: false)),
              Expanded(child: StatValue(value: '${a.words}', label: 'Words read', roll: false)),
              Expanded(child: StatValue(value: '${a.known}', label: 'Learned', roll: false)),
            ],
          ),
          if (a.langSeconds.isNotEmpty || a.langWords.isNotEmpty) ...[
            const SizedBox(height: 18),
            ToolGroup(
              color: ctx.sc.bgRaised2,
              radius: 18,
              children: [
                for (final l in {...a.langSeconds.keys, ...a.langWords.keys})
                  ToolRow(
                    label: languageName(l),
                    value: '${formatDuration(a.langSeconds[l] ?? 0, short: true)} · ${a.langWords[l] ?? 0} words',
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _LangRow extends StatelessWidget {
  const _LangRow({required this.lang, required this.streak, required this.seconds, required this.words, required this.known});
  final String lang;
  final int streak;
  final int seconds;
  final int words;
  final int known;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          LangBadge(lang),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(languageName(lang), style: AppTheme.f(14.5, weight: FontWeight.w600, color: c.text)),
                const SizedBox(height: 2),
                Text(
                  '${formatDuration(seconds, short: true)} · $words words · $known known',
                  style: AppTheme.f(12, weight: FontWeight.w500, color: c.textTertiary),
                ),
              ],
            ),
          ),
          Icon(PhosphorIconsFill.flame, size: 16, color: streak > 0 ? c.accent : c.textTertiary),
          const SizedBox(width: 4),
          Text('$streak', style: AppTheme.f(15, weight: FontWeight.w800, color: c.text)),
        ],
      ),
    );
  }
}

/// A progress ring in copper on a quiet track.
class GoalRing extends StatelessWidget {
  const GoalRing({super.key, required this.value, this.size = 44, this.stroke = 4});
  final double value;
  final double size;
  final double stroke;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    final reduced = Motion.reduced(context);
    return Semantics(
      label: '${(value * 100).clamp(0, 999).round()} percent of daily goal',
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: reduced ? value : 0, end: value),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (_, v, _) => SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _RingPainter(v.clamp(0, 1), c.bgRaised2, v >= 1 ? c.sage : c.accent, stroke),
            child: Center(
              child: v >= 1
                  ? Icon(PhosphorIconsBold.check, size: size * 0.32, color: c.sage)
                  : Text('${(v * 100).round()}%', style: AppTheme.d(size * 0.2, weight: FontWeight.w800, color: c.text)),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value, this.track, this.color, this.stroke);
  final double value;
  final Color track;
  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final r = (min(size.width, size.height) - stroke) / 2;
    final center = size.center(Offset.zero);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, r, p..color = track);
    if (value > 0) {
      canvas.drawArc(Rect.fromCircle(center: center, radius: r), -pi / 2, 2 * pi * value, false, p..color = color);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value || old.color != color || old.track != track;
}

/// Customises the activity chart: shape, colours, range, size and week start.
Future<void> showHeatmapSettings(BuildContext context) => showAppSheet<void>(
  context,
  (ctx) {
    final app = ctx.app;
    final s = app.settings;
    final c = ctx.sc;
    void set(void Function(Settings) f) => app.updateSettings(f);
    return SheetBody(
      title: 'Activity chart',
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: c.bgRaised2, borderRadius: BorderRadius.circular(16)),
          child: ActivityHeatmap(
            days: app.activity,
            weeks: min(s.heatWeeks, 16),
            cell: s.heatCell,
            gap: s.heatGap,
            shape: s.heatShape,
            ramp: s.heatRamp,
            metric: s.heatMetric,
            goalMinutes: s.dailyGoalMinutes,
            mondayFirst: s.weekStartsMonday,
          ),
        ),
        const SizedBox(height: 16),
        const Kicker('Shape'),
        const SizedBox(height: 8),
        SegToggle<String>(
          value: s.heatShape,
          expand: true,
          options: const {'square': 'Squares', 'rounded': 'Rounded', 'dot': 'Dots'},
          onChanged: (v) => set((x) => x.heatShape = v),
        ),
        const SizedBox(height: 16),
        const Kicker('Colour'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in heatRampNames.entries)
              Pill(
                label: e.value,
                selected: s.heatRamp == e.key,
                onTap: () => set((x) => x.heatRamp = e.key),
              ),
          ],
        ),
        const SizedBox(height: 16),
        ToolGroup(
          color: c.bgRaised2,
          radius: 18,
          children: [
            SliderRow(
              label: 'Weeks shown',
              value: s.heatWeeks.toDouble(),
              min: 8,
              max: 53,
              divisions: 45,
              format: (v) => '${v.round()}',
              onChanged: (v) => set((x) => x.heatWeeks = v.round()),
            ),
            SliderRow(
              label: 'Cell size',
              value: s.heatCell,
              min: 8,
              max: 22,
              divisions: 14,
              format: (v) => '${v.round()}',
              onChanged: (v) => set((x) => x.heatCell = v),
            ),
            SliderRow(
              label: 'Gap',
              value: s.heatGap,
              min: 1,
              max: 8,
              divisions: 7,
              format: (v) => '${v.round()}',
              onChanged: (v) => set((x) => x.heatGap = v),
            ),
            ToolRow(
              label: 'Weeks start on Monday',
              trailing: TinySwitch(value: s.weekStartsMonday, onChanged: (v) => set((x) => x.weekStartsMonday = v)),
            ),
          ],
        ),
      ],
    );
  },
);
