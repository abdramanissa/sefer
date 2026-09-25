import 'package:flutter/material.dart';

import '../data/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Four-step colour ramps (DESIGN.md §3.5). "More" always means more contrast
/// against the background.
List<Color> heatRamp(String name, SeferColors c) {
  final dark = c.isDark;
  switch (name) {
    case 'green':
      return dark
          ? const [Color(0xFF1B4B2C), Color(0xFF2C7A44), Color(0xFF3FA95C), Color(0xFF63D67F)]
          : const [Color(0xFFBBD9BE), Color(0xFF7FB88A), Color(0xFF488C58), Color(0xFF255E32)];
    case 'blue':
      return dark
          ? const [Color(0xFF1E3A5C), Color(0xFF2C5E96), Color(0xFF3D86C9), Color(0xFF6EB4F0)]
          : const [Color(0xFFBACFE8), Color(0xFF7EA5D2), Color(0xFF3F74AE), Color(0xFF1F4876)];
    case 'mono':
      return dark
          ? const [Color(0xFF3A3A3A), Color(0xFF5E5E5E), Color(0xFF8C8C8C), Color(0xFFD8D8D8)]
          : const [Color(0xFFCFC8BC), Color(0xFF9C958A), Color(0xFF6B655C), Color(0xFF3A352F)];
    case 'ember':
      return dark
          ? const [Color(0xFF7A4028), Color(0xFFB4632C), Color(0xFFE38B3A), Color(0xFFFFC168)]
          : const [Color(0xFFD9B48A), Color(0xFFC07A3C), Color(0xFF9E4A24), Color(0xFF6E2A16)];
    default: // accent: the theme's own accent, so custom themes carry through
      return [
        Color.lerp(c.heatEmpty, c.accent, 0.35)!,
        Color.lerp(c.heatEmpty, c.accent, 0.6)!,
        Color.lerp(c.heatEmpty, c.accent, 0.85)!,
        c.accent,
      ];
  }
}

const heatRampNames = {'accent': 'Accent', 'ember': 'Ember', 'green': 'Green', 'blue': 'Blue', 'mono': 'Mono'};

/// 0 = nothing, 1–4 = ramp step.
int heatLevel(DayActivity? d, {required String metric, required int goalMinutes}) {
  if (d == null) return 0;
  if (metric == 'words') {
    final w = d.words;
    if (w <= 0) return d.seconds > 0 ? 1 : 0;
    if (w < 100) return 1;
    if (w < 300) return 2;
    if (w < 800) return 3;
    return 4;
  }
  final goal = (goalMinutes <= 0 ? 15 : goalMinutes) * 60;
  final s = d.seconds;
  if (s <= 0) return d.isActive ? 1 : 0;
  if (s < goal / 2) return 1;
  if (s < goal) return 2;
  if (s < goal * 2) return 3;
  return 4;
}

class ActivityHeatmap extends StatefulWidget {
  const ActivityHeatmap({
    super.key,
    required this.days,
    required this.weeks,
    required this.cell,
    required this.gap,
    required this.shape,
    required this.ramp,
    required this.metric,
    required this.goalMinutes,
    required this.mondayFirst,
    this.onTapDay,
    this.language,
  });

  final Map<String, DayActivity> days;
  final int weeks;
  final double cell;
  final double gap;
  final String shape; // square | rounded | dot
  final String ramp;
  final String metric;
  final int goalMinutes;
  final bool mondayFirst;
  final ValueChanged<DateTime>? onTapDay;

  /// When set, only activity in this language counts.
  final String? language;

  @override
  State<ActivityHeatmap> createState() => _ActivityHeatmapState();
}

class _ActivityHeatmapState extends State<ActivityHeatmap> {
  // Always opens on today, so there is no offset worth restoring.
  final _scroll = ScrollController(keepScrollOffset: false);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  DayActivity? _day(DateTime d) {
    final a = widget.days[dayKey(d)];
    final lang = widget.language;
    if (a == null || lang == null) return a;
    return DayActivity(seconds: a.langSeconds[lang] ?? 0, words: a.langWords[lang] ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    final ramp = heatRamp(widget.ramp, c);
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final startWeekday = widget.mondayFirst ? DateTime.monday : DateTime.sunday;
    final offset = (todayDate.weekday - startWeekday) % 7;
    final lastColumnStart = todayDate.subtract(Duration(days: offset));
    final first = DateTime(lastColumnStart.year, lastColumnStart.month, lastColumnStart.day - 7 * (widget.weeks - 1));
    final step = widget.cell + widget.gap;
    const labelW = 22.0;
    final monthRow = <Widget>[];
    int? lastMonth;
    for (var w = 0; w < widget.weeks; w++) {
      final d = DateTime(first.year, first.month, first.day + 7 * w);
      final show = d.month != lastMonth && d.day <= 7;
      lastMonth = d.month;
      monthRow.add(SizedBox(
        width: step,
        child: show
            ? OverflowBox(
                maxWidth: 40,
                alignment: AlignmentDirectional.centerStart,
                child: Text(_months[d.month - 1], style: AppTheme.d(10, weight: FontWeight.w600, color: c.textTertiary)),
              )
            : null,
      ));
    }

    final columns = <Widget>[];
    for (var w = 0; w < widget.weeks; w++) {
      final cells = <Widget>[];
      for (var r = 0; r < 7; r++) {
        final d = DateTime(first.year, first.month, first.day + 7 * w + r);
        final future = d.isAfter(todayDate);
        final level = future ? -1 : heatLevel(_day(d), metric: widget.metric, goalMinutes: widget.goalMinutes);
        final color = level < 0 ? Colors.transparent : (level == 0 ? c.heatEmpty : ramp[level - 1]);
        final isToday = d == todayDate;
        cells.add(Padding(
          padding: EdgeInsets.only(bottom: r == 6 ? 0 : widget.gap),
          child: GestureDetector(
            onTap: future || widget.onTapDay == null ? null : () => widget.onTapDay!(d),
            child: _Cell(size: widget.cell, color: color, shape: widget.shape, ring: isToday ? c.text : null),
          ),
        ));
      }
      columns.add(Padding(
        padding: EdgeInsets.only(right: w == widget.weeks - 1 ? 0 : widget.gap),
        child: Column(children: cells),
      ));
    }

    final dayLabels = widget.mondayFirst ? ['M', '', 'W', '', 'F', '', 'S'] : ['S', '', 'T', '', 'T', '', 'S'];
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Column(
              children: [
                for (var r = 0; r < 7; r++)
                  SizedBox(
                    width: labelW,
                    height: step,
                    child: Text(dayLabels[r], style: AppTheme.d(9.5, weight: FontWeight.w600, color: c.textTertiary)),
                  ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 16, child: Row(children: monthRow)),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: columns),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

class _Cell extends StatelessWidget {
  const _Cell({required this.size, required this.color, required this.shape, this.ring});
  final double size;
  final Color color;
  final String shape;
  final Color? ring;

  @override
  Widget build(BuildContext context) {
    final radius = switch (shape) {
      'dot' => size / 2,
      'rounded' => size * 0.3,
      _ => 3.0.clamp(0, size / 4).toDouble(),
    };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: ring == null ? null : Border.all(color: ring!.withValues(alpha: 0.7), width: 1.2),
      ),
    );
  }
}

/// A small legend: "Less ▢▢▢▢▢ More".
class HeatLegend extends StatelessWidget {
  const HeatLegend({super.key, required this.ramp, required this.shape, this.size = 10});
  final String ramp;
  final String shape;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    final colors = [c.heatEmpty, ...heatRamp(ramp, c)];
    final style = AppTheme.s(10, weight: FontWeight.w600, color: c.textTertiary);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Less', style: style),
        const SizedBox(width: 6),
        for (final col in colors)
          Padding(padding: const EdgeInsets.symmetric(horizontal: 1.5), child: _Cell(size: size, color: col, shape: shape)),
        const SizedBox(width: 6),
        Text('More', style: style),
      ],
    );
  }
}
