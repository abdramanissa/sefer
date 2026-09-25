import 'models.dart';

typedef DayTest = bool Function(DayActivity d);

/// Days in a row that pass [test], ending today. If today has nothing yet the
/// streak is still alive and counts back from yesterday.
int currentStreak(Map<String, DayActivity> days, DateTime today, DayTest test) {
  bool ok(DateTime d) {
    final a = days[dayKey(d)];
    return a != null && test(a);
  }

  var d = DateTime(today.year, today.month, today.day);
  if (!ok(d)) d = d.subtract(const Duration(days: 1));
  var n = 0;
  while (ok(d)) {
    n++;
    d = DateTime(d.year, d.month, d.day - 1);
  }
  return n;
}

/// The longest run of consecutive days that pass [test].
int bestStreak(Map<String, DayActivity> days, DayTest test) {
  final keys = days.entries.where((e) => test(e.value)).map((e) => e.key).toList()..sort();
  var best = 0;
  var run = 0;
  DateTime? prev;
  for (final k in keys) {
    final d = dayFromKey(k);
    if (prev != null && DateTime(prev.year, prev.month, prev.day + 1) == d) {
      run++;
    } else {
      run = 1;
    }
    if (run > best) best = run;
    prev = d;
  }
  return best;
}

DayTest dailyTest({required bool needsGoal, required int goalMinutes}) =>
    needsGoal ? (d) => d.seconds >= goalMinutes * 60 : (d) => d.isActive;

DayTest languageTest(String lang) => (d) => d.activeIn(lang);

class Totals {
  int seconds = 0;
  int words = 0;
  int known = 0;
  int saved = 0;
  int sessions = 0;
  int activeDays = 0;
  final Map<String, int> langSeconds = {};
  final Map<String, int> langWords = {};
}

Totals totals(Map<String, DayActivity> days, {DateTime? since}) {
  final t = Totals();
  final from = since == null ? null : dayKey(since);
  for (final e in days.entries) {
    if (from != null && e.key.compareTo(from) < 0) continue;
    final d = e.value;
    t.seconds += d.seconds;
    t.words += d.words;
    t.known += d.known;
    t.saved += d.saved;
    t.sessions += d.sessions;
    if (d.isActive) t.activeDays++;
    d.langSeconds.forEach((k, v) => t.langSeconds[k] = (t.langSeconds[k] ?? 0) + v);
    d.langWords.forEach((k, v) => t.langWords[k] = (t.langWords[k] ?? 0) + v);
  }
  return t;
}

String formatDuration(int seconds, {bool short = false}) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  if (h > 0) return short ? '${h}h ${m}m' : '$h h $m min';
  if (m > 0) return short ? '${m}m' : '$m min';
  return short ? '${seconds}s' : '$seconds s';
}
