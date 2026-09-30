import 'dart:math';

import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../data/app_state.dart';
import '../data/languages.dart';
import '../data/models.dart';
import '../text/script.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/feel.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';
import '../widgets/ui_kit.dart';

/// A story's quiz: one question at a time, pick an answer, see whether it
/// was right, and get a score at the end.
class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, required this.id});
  final String id;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final _rand = Random();
  late List<List<int>> _order;
  final Map<int, int> _answers = {};
  int _index = 0;
  bool _done = false;
  bool _newBest = false;
  bool _review = false;
  bool _showTranslation = false;

  @override
  void initState() {
    super.initState();
    _shuffle();
  }

  void _shuffle() {
    final s = context.appRead.story(widget.id);
    _order = [
      for (final q in s?.quiz ?? const <QuizQuestion>[])
        q.kind == QuizKind.choice ? (List.generate(q.options.length, (i) => i)..shuffle(_rand)) : List.generate(q.options.length, (i) => i),
    ];
  }

  void _restart() => setState(() {
    _shuffle();
    _answers.clear();
    _index = 0;
    _done = false;
    _review = false;
    _newBest = false;
  });

  void _pick(Story s, int option) {
    if (_answers.containsKey(_index)) return;
    final right = s.quiz[_index].answer == option;
    right ? Haptic.light() : Haptic.medium();
    setState(() => _answers[_index] = option);
  }

  void _next(Story s) {
    if (_index < s.quiz.length - 1) {
      setState(() {
        _index++;
        _showTranslation = false;
      });
      return;
    }
    final correct = _correct(s);
    final best = context.appRead.recordQuiz(s, correct, s.quiz.length);
    if (correct == s.quiz.length) {
      Haptic.heavy();
    }
    setState(() {
      _done = true;
      _newBest = best && s.quizAttempts > 1;
    });
  }

  int _correct(Story s) {
    var n = 0;
    _answers.forEach((i, a) {
      if (i < s.quiz.length && s.quiz[i].answer == a) n++;
    });
    return n;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final s = app.story(widget.id);
    if (s == null || s.quiz.isEmpty) {
      return Center(
        child: EmptyState(
          icon: PhosphorIconsRegular.question,
          title: s == null ? 'This story no longer exists' : 'This story has no quiz',
          action: GhostButton(label: 'Back', expand: false, onTap: app.back),
        ),
      );
    }
    if (_order.length != s.quiz.length) _shuffle();
    final top = MediaQuery.viewPaddingOf(context).top;
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    final gutter = context.feel.gutter;
    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, top + 12, gutter, 0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: _done
              ? (_review ? _reviewView(s, bottom) : _results(s, bottom))
              : _question(s, bottom),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ question

  Widget _question(Story s, double bottom) {
    final c = context.sc;
    final q = s.quiz[_index];
    final picked = _answers[_index];
    final answered = picked != null;
    final total = s.quiz.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            RoundBtn(icon: PhosphorIconsBold.x, label: 'Leave the quiz', onTap: context.appRead.back),
            const SizedBox(width: 12),
            Expanded(child: ThinProgress(value: (_index + (answered ? 1 : 0)) / total, height: 8)),
            const SizedBox(width: 12),
            Text('${_index + 1} / $total', style: AppTheme.d(13, weight: FontWeight.w700, color: c.textSecondary)),
          ],
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.only(top: 28, bottom: 24),
            children: [
              if (context.feel.kickers) ...[
                Kicker(switch (q.kind) {
                  QuizKind.yesNo => 'Yes or no',
                  QuizKind.trueFalse => 'True or false',
                  _ => 'Question ${_index + 1}',
                }),
                const SizedBox(height: 10),
              ],
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                child: _StoryText(
                  key: ValueKey(_index),
                  story: s,
                  text: q.question,
                  size: 24,
                  weight: FontWeight.w700,
                ),
              ),
              if (q.translation != null) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: _showTranslation
                      ? Text(q.translation!, style: AppTheme.f(14.5, weight: FontWeight.w500, color: c.textSecondary, height: 1.4))
                      : Pill(
                          dense: true,
                          icon: PhosphorIconsBold.translate,
                          label: 'Show in ${languageName(s.translationLanguage)}',
                          onTap: () => setState(() => _showTranslation = true),
                        ),
                ),
              ],
              const SizedBox(height: 26),
              for (final (n, i) in _order[_index].indexed) ...[
                _OptionTile(
                  story: s,
                  letter: q.kind == QuizKind.choice ? String.fromCharCode(65 + n) : null,
                  text: q.options[i],
                  state: !answered
                      ? _OptionState.idle
                      : i == q.answer
                      ? _OptionState.right
                      : i == picked
                      ? _OptionState.wrong
                      : _OptionState.faded,
                  onTap: () => _pick(s, i),
                ),
                const SizedBox(height: 10),
              ],
              if (answered) ...[
                const SizedBox(height: 8),
                Rise(
                  child: _Verdict(right: picked == q.answer, explanation: q.explanation, answer: q.options[q.answer]),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.only(bottom: bottom + 16),
          child: PrimaryButton(
            label: _index < total - 1 ? 'Next question' : 'See my score',
            icon: _index < total - 1 ? PhosphorIconsBold.arrowRight : PhosphorIconsBold.flagCheckered,
            onTap: answered ? () => _next(s) : null,
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------ results

  static (String, int) rating(int score) => switch (score) {
    100 => ('Perfect', 3),
    >= 80 => ('Great work', 3),
    >= 60 => ('Good', 2),
    >= 40 => ('Getting there', 1),
    _ => ('Keep reading', 0),
  };

  Widget _results(Story s, double bottom) {
    final c = context.sc;
    final correct = _correct(s);
    final total = s.quiz.length;
    final score = (correct * 100 / total).round();
    final (label, stars) = rating(score);
    final color = score >= 80 ? c.sage : (score >= 50 ? c.brass : c.accent);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            RoundBtn(icon: PhosphorIconsBold.x, label: 'Close', onTap: context.appRead.back),
            const Spacer(),
          ],
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(top: 24, bottom: 24),
            children: [
              Rise(
                child: Center(
                  child: SizedBox(
                    width: 180,
                    height: 180,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: score / 100),
                          duration: Motion.reduced(context) ? Duration.zero : const Duration(milliseconds: 1100),
                          curve: Curves.easeOutCubic,
                          builder: (_, v, _) => CustomPaint(
                            size: const Size.square(180),
                            painter: _Ring(value: v, color: color, track: c.bgRaised2),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            RollIn(
                              value: score,
                              style: AppTheme.f(46, weight: FontWeight.w800, color: c.text),
                              format: (v) => '${v.round()}%',
                            ),
                            Text('$correct of $total right', style: AppTheme.f(13, weight: FontWeight.w600, color: c.textSecondary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Rise(
                index: 1,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < 3; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          i < stars ? PhosphorIconsFill.star : PhosphorIconsRegular.star,
                          size: 30,
                          color: i < stars ? c.brass : c.textTertiary,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Rise(
                index: 2,
                child: Text(label, textAlign: TextAlign.center, style: AppTheme.f(26, weight: FontWeight.w800, color: c.text)),
              ),
              const SizedBox(height: 6),
              Rise(
                index: 3,
                child: Text(
                  _newBest
                      ? 'A new best for this story.'
                      : (s.quizBest != null && s.quizAttempts > 1 ? 'Your best: ${s.quizBest}%' : s.title),
                  textAlign: TextAlign.center,
                  style: AppTheme.f(14, weight: FontWeight.w600, color: _newBest ? c.sage : c.textSecondary),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.only(bottom: bottom + 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: GhostButton(label: 'Review', icon: PhosphorIconsBold.listChecks, onTap: () => setState(() => _review = true))),
                  const SizedBox(width: 10),
                  Expanded(child: GhostButton(label: 'Try again', icon: PhosphorIconsBold.arrowCounterClockwise, onTap: _restart)),
                ],
              ),
              const SizedBox(height: 10),
              PrimaryButton(label: 'Done', icon: PhosphorIconsBold.check, onTap: context.appRead.back),
            ],
          ),
        ),
      ],
    );
  }

  Widget _reviewView(Story s, double bottom) {
    final c = context.sc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScreenHeader(title: 'Your answers', onBack: () => setState(() => _review = false)),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.only(top: 18, bottom: bottom + 24),
            itemCount: s.quiz.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final q = s.quiz[i];
              final a = _answers[i];
              final right = a == q.answer;
              return SoftCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(right ? PhosphorIconsFill.checkCircle : PhosphorIconsFill.xCircle, size: 18, color: right ? c.sage : c.danger),
                        const SizedBox(width: 8),
                        Text('Question ${i + 1}', style: AppTheme.f(12.5, weight: FontWeight.w700, color: c.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _StoryText(story: s, text: q.question, size: 17, weight: FontWeight.w600),
                    const SizedBox(height: 10),
                    if (!right && a != null) _AnswerLine(story: s, label: 'You said', text: q.options[a], color: c.danger),
                    _AnswerLine(story: s, label: 'Answer', text: q.options[q.answer], color: c.sage),
                    if (q.explanation != null) ...[
                      const SizedBox(height: 6),
                      Text(q.explanation!, style: AppTheme.f(13, weight: FontWeight.w500, color: c.textSecondary, height: 1.4)),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Text in the story's language, font and direction.
class _StoryText extends StatelessWidget {
  const _StoryText({super.key, required this.story, required this.text, required this.size, this.weight = FontWeight.w500, this.color});
  final Story story;
  final String text;
  final double size;
  final FontWeight weight;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final set = context.app.settings;
    final font = readerFontFor(set.fontByLanguage, set.readerFont, story.language);
    final rtl = isRtl(story.language, text);
    return Text(
      text,
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      textAlign: rtl ? TextAlign.right : TextAlign.left,
      style: TextStyle(
        fontFamily: font.family,
        fontFamilyFallback: readerFallback,
        fontSize: size,
        fontWeight: weight,
        height: 1.4,
        color: color ?? context.sc.text,
      ),
    );
  }
}

enum _OptionState { idle, right, wrong, faded }

class _OptionTile extends StatelessWidget {
  const _OptionTile({required this.story, required this.letter, required this.text, required this.state, required this.onTap});
  final Story story;
  final String? letter;
  final String text;
  final _OptionState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    final feel = context.feel;
    final (bg, border, fg) = switch (state) {
      _OptionState.idle => (c.bgRaised, c.border, c.text),
      _OptionState.right => (c.sageSoft, c.sage, c.text),
      _OptionState.wrong => (c.danger.withValues(alpha: 0.14), c.danger, c.text),
      _OptionState.faded => (c.bgRaised, c.border.withValues(alpha: 0.5), c.textTertiary),
    };
    final mark = switch (state) {
      _OptionState.right => Icon(PhosphorIconsFill.checkCircle, size: 20, color: c.sage),
      _OptionState.wrong => Icon(PhosphorIconsFill.xCircle, size: 20, color: c.danger),
      _ => null,
    };
    return Semantics(
      button: true,
      label: text,
      value: switch (state) {
        _OptionState.right => 'Correct answer',
        _OptionState.wrong => 'Wrong',
        _ => null,
      },
      excludeSemantics: true,
      child: Pressable(
        scale: 0.98,
        onTap: state == _OptionState.idle ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(feel.r(18)),
            border: Border.all(color: border, width: state == _OptionState.idle || state == _OptionState.faded ? 1 : 2),
          ),
          child: Row(
            children: [
              if (letter != null) ...[
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: c.bgRaised2, borderRadius: BorderRadius.circular(feel.r(9))),
                  child: Text(letter!, style: AppTheme.f(13, weight: FontWeight.w800, color: c.textSecondary)),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(child: _StoryText(story: story, text: text, size: 17, weight: FontWeight.w600, color: fg)),
              if (mark != null) ...[const SizedBox(width: 10), mark],
            ],
          ),
        ),
      ),
    );
  }
}

class _Verdict extends StatelessWidget {
  const _Verdict({required this.right, required this.explanation, required this.answer});
  final bool right;
  final String? explanation;
  final String answer;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    final color = right ? c.sage : c.danger;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(context.feel.r(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(right ? 'Correct' : 'Not quite', style: AppTheme.f(15, weight: FontWeight.w800, color: color)),
          if (explanation != null) ...[
            const SizedBox(height: 4),
            Text(explanation!, style: AppTheme.f(13.5, weight: FontWeight.w500, color: c.textSecondary, height: 1.4)),
          ],
        ],
      ),
    );
  }
}

class _AnswerLine extends StatelessWidget {
  const _AnswerLine({required this.story, required this.label, required this.text, required this.color});
  final Story story;
  final String label;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(label, style: AppTheme.f(12, weight: FontWeight.w700, color: color)),
          ),
        ),
        Expanded(child: _StoryText(story: story, text: text, size: 15, weight: FontWeight.w600)),
      ],
    ),
  );
}

class _Ring extends CustomPainter {
  _Ring({required this.value, required this.color, required this.track});
  final double value;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 12.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, pi * 2, false, p..color = track);
    if (value > 0) canvas.drawArc(rect, -pi / 2, pi * 2 * value, false, p..color = color);
  }

  @override
  bool shouldRepaint(_Ring old) => old.value != value || old.color != color || old.track != track;
}
