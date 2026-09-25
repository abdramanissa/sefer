import 'dart:async';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../data/app_state.dart';
import '../data/models.dart';
import '../text/normalize.dart';
import '../text/script.dart';
import '../text/tokenizer.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/glass.dart';
import '../widgets/notch_toast.dart';
import '../widgets/ui_kit.dart';
import 'reader_controls.dart';
import 'story_actions.dart';
import 'word_sheet.dart';

/// Seconds without touching the screen after which reading time stops
/// counting, so an abandoned phone doesn't inflate your stats.
const _idleSeconds = 120;

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key, required this.id});
  final String id;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> with WidgetsBindingObserver {
  final _scroll = ScrollController();
  final _centerKey = UniqueKey();
  final Map<int, GlobalKey> _keys = {};
  final Set<int> _openTranslations = {};
  late int _anchor;
  Timer? _tick;
  int _pending = 0;
  DateTime _lastTouch = DateTime.now();
  bool _foreground = true;
  bool _chrome = true;
  String? _selected;
  DateTime _lastTrack = DateTime.fromMillisecondsSinceEpoch(0);
  AppState? _app;
  Story? _story;

  static const _barHeight = 64.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _app = context.appRead;
    _story = _app!.story(widget.id);
    final s = _story;
    _anchor = s == null ? 0 : s.position.clamp(0, s.paragraphs.isEmpty ? 0 : s.paragraphs.length - 1);
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialJump());
  }

  void _initialJump() {
    if (!_scroll.hasClients) return;
    final top = MediaQuery.viewPaddingOf(context).top + _barHeight;
    if (_anchor == 0) {
      _scroll.jumpTo(_scroll.position.minScrollExtent);
    } else {
      _scroll.jumpTo((-top).clamp(_scroll.position.minScrollExtent, _scroll.position.maxScrollExtent));
    }
  }

  void _onTick() {
    if (!_foreground) return;
    if (DateTime.now().difference(_lastTouch).inSeconds > _idleSeconds) return;
    _pending++;
    if (_pending >= 20) _commitTime();
  }

  void _commitTime() {
    final s = _story;
    final n = _pending;
    _pending = 0;
    if (s != null && n > 0) _app?.addReadingTime(s, n);
  }

  void _touch() => _lastTouch = DateTime.now();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      _touch();
    } else {
      _commitTime();
      _trackPosition();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tick?.cancel();
    // Saving notifies listeners, which isn't allowed while the tree is being
    // torn down; do it right after.
    final app = _app;
    final s = _story;
    final n = _pending;
    if (app != null && s != null && n > 0) Future(() => app.addReadingTime(s, n));
    _scroll.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification n) {
    _touch();
    if (n is ScrollUpdateNotification && n.dragDetails != null) {
      final d = n.scrollDelta ?? 0;
      if (d > 6 && _chrome) setState(() => _chrome = false);
      if (d < -6 && !_chrome) setState(() => _chrome = true);
    }
    final now = DateTime.now();
    if (n is ScrollEndNotification || now.difference(_lastTrack).inMilliseconds > 400) {
      _lastTrack = now;
      _trackPosition();
    }
    return false;
  }

  /// Finds the first paragraph whose bottom is below the top bar.
  void _trackPosition() {
    final s = _story;
    if (s == null || !mounted || !_scroll.hasClients) return;
    final top = MediaQuery.viewPaddingOf(context).top + _barHeight;
    int? first;
    for (final e in _keys.entries) {
      final box = e.value.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      final y = box.localToGlobal(Offset.zero).dy;
      if (y + box.size.height > top && (first == null || e.key < first)) first = e.key;
    }
    if (first == null) return;
    final atEnd = _scroll.position.pixels >= _scroll.position.maxScrollExtent - 8;
    final progress = atEnd ? 1.0 : first / s.paragraphs.length;
    if (first != s.position || (progress - s.progress).abs() > 0.001) {
      _app!.updatePosition(s, atEnd ? s.paragraphs.length : first, progress);
      setState(() {});
    }
  }

  Future<void> _openWord(Story s, String word, Sentence sentence, String key) async {
    _touch();
    Haptic.selection();
    setState(() => _selected = key);
    await openWordSheet(context, story: s, word: word, sentence: sentence);
    if (mounted) setState(() => _selected = null);
  }

  Future<void> _openSentence(Story s, Sentence sentence) async {
    _touch();
    Haptic.medium();
    await showSentenceSheet(context, s, sentence);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final c = context.sc;
    final s = app.story(widget.id);
    if (s == null) {
      return Center(
        child: EmptyState(
          icon: PhosphorIconsRegular.question,
          title: 'This story no longer exists',
          action: GhostButton(label: 'Back', expand: false, onTap: app.back),
        ),
      );
    }
    _story = s;
    final dir = isRtl(s.language, s.paragraphs.isEmpty ? s.title : s.paragraphs.first.text)
        ? TextDirection.rtl
        : TextDirection.ltr;
    final set = app.settings;
    final top = MediaQuery.viewPaddingOf(context).top;
    final n = s.paragraphs.length;
    _anchor = _anchor.clamp(0, n == 0 ? 0 : n - 1);

    Widget para(int i) {
      final key = _keys.putIfAbsent(i, GlobalKey.new);
      return Center(
        key: key,
        child: ConstrainedBox(
          constraints: BoxConstraints.tightFor(width: min(set.maxWidth, MediaQuery.sizeOf(context).width)),
          child: Padding(
            padding: EdgeInsets.fromLTRB(set.sidePadding, 0, set.sidePadding, set.paragraphSpacing),
            child: _ParagraphView(
              dir: dir,
              story: s,
              index: i,
              selected: _selected,
              showTranslations: set.sentenceTranslations == 'below' || _openTranslations.contains(i),
              onWord: (w, sentence, k) => _openWord(s, w, sentence, k),
              onSentence: (sentence) => _openSentence(s, sentence),
              onToggleTranslations: set.sentenceTranslations == 'tap'
                  ? () => setState(() {
                      if (!_openTranslations.remove(i)) _openTranslations.add(i);
                    })
                  : null,
            ),
          ),
        ),
      );
    }

    return Directionality(
      // The interface stays in the app's direction; only the text itself
      // follows the story's language (see _ParagraphView and _Header).
      textDirection: Directionality.of(context),
      child: ColoredBox(
        color: c.bg,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => setState(() => _chrome = !_chrome),
                child: NotificationListener<ScrollNotification>(
                  onNotification: _onScroll,
                  child: CustomScrollView(
                    controller: _scroll,
                    center: _centerKey,
                    slivers: [
                      SliverToBoxAdapter(child: _Header(story: s, dir: dir, topPad: top + _barHeight + 18)),
                      SliverList(
                        delegate: SliverChildBuilderDelegate((_, i) => para(_anchor - 1 - i), childCount: _anchor),
                      ),
                      SliverList(
                        key: _centerKey,
                        delegate: SliverChildBuilderDelegate((_, i) => para(_anchor + i), childCount: n - _anchor),
                      ),
                      SliverToBoxAdapter(child: _Footer(story: s)),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedSlide(
                offset: _chrome ? Offset.zero : const Offset(0, -1.3),
                duration: const Duration(milliseconds: 280),
                curve: _chrome ? Curves.easeOutCubic : Curves.easeInCubic,
                child: _TopBar(story: s, top: top, onBack: app.back),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ chrome

class _TopBar extends StatelessWidget {
  const _TopBar({required this.story, required this.top, required this.onBack});
  final Story story;
  final double top;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, top + 6, 12, 0),
      child: GlassSurface(
        radius: 24,
        sigma: 18,
        shadow: false,
        child: SizedBox(
          height: 54,
          child: Row(
            children: [
              const SizedBox(width: 4),
              RoundBtn(
                icon: rtl ? PhosphorIconsBold.caretRight : PhosphorIconsBold.caretLeft,
                label: 'Back',
                size: 36,
                onTap: onBack,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      story.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.f(14, weight: FontWeight.w800, color: c.text),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Expanded(child: ThinProgress(value: story.progress, height: 3)),
                        const SizedBox(width: 8),
                        Text(
                          '${(story.progress * 100).round()}%',
                          style: AppTheme.d(11, weight: FontWeight.w700, color: c.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              RoundBtn(
                icon: PhosphorIconsBold.textAa,
                label: 'Text settings',
                size: 36,
                onTap: () => showReaderSettings(context, story),
              ),
              RoundBtn(
                icon: PhosphorIconsBold.dotsThree,
                label: 'More',
                size: 36,
                onTap: () => showStoryActions(context, story),
              ),
              const SizedBox(width: 2),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showReaderSettings(BuildContext context, Story story) {
  final script = dominantScript(story.preview);
  final marks = script == Script.hebrew || script == Script.arabic;
  final sample = words(story.preview).firstOrNull;
  return showAppSheet<void>(
    context,
    (ctx) => SheetBody(
      title: 'Text',
      children: [ReaderControls(showMarksToggle: marks, sample: sample)],
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.story, required this.dir, required this.topPad});
  final Story story;
  final TextDirection dir;
  final double topPad;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final c = context.sc;
    final set = app.settings;
    final ws = app.wordStats(story);
    final font = readerFontById(set.readerFont);
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints.tightFor(width: min(set.maxWidth, MediaQuery.sizeOf(context).width)),
        child: Padding(
          padding: EdgeInsets.fromLTRB(set.sidePadding, topPad, set.sidePadding, set.paragraphSpacing + 10),
          child: Column(
            crossAxisAlignment: dir == TextDirection.rtl ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  LangBadge(story.language, full: true),
                  Text(
                    '${story.wordCount} words · ${ws.fresh} new · ${(ws.knownRatio * 100).round()}% known',
                    style: AppTheme.f(12, weight: FontWeight.w600, color: c.textTertiary),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                set.showMarks ? story.title : stripVowelMarks(story.title),
                textDirection: dir,
                style: TextStyle(
                  fontFamily: font.family,
                  fontFamilyFallback: readerFallback,
                  fontSize: set.fontSize * 1.45,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                  color: c.text,
                ),
              ),
              if (story.author.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(story.author, style: AppTheme.f(14, weight: FontWeight.w600, color: c.textSecondary)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.story});
  final Story story;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final c = context.sc;
    final set = app.settings;
    final ws = app.wordStats(story);
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    final done = story.finishedAt != null;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints.tightFor(width: min(set.maxWidth, MediaQuery.sizeOf(context).width)),
        child: Padding(
          padding: EdgeInsets.fromLTRB(set.sidePadding, 12, set.sidePadding, 40 + bottom),
          child: SoftCard(
            radius: 26,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Kicker(done ? 'Finished' : 'The end'),
                const SizedBox(height: 8),
                Text(
                  done ? 'Nicely done.' : 'You reached the end.',
                  style: AppTheme.f(22, weight: FontWeight.w800, color: c.text),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: StatValue(value: '${(ws.knownRatio * 100).round()}', unit: '%', label: 'Known')),
                    Expanded(child: StatValue(value: '${ws.learning}', label: 'Learning')),
                    Expanded(child: StatValue(value: '${ws.fresh}', label: 'New')),
                  ],
                ),
                const SizedBox(height: 18),
                if (!done)
                  PrimaryButton(
                    label: set.autoKnownOnFinish && ws.fresh > 0 ? 'Finish · ${ws.fresh} new words become known' : 'Finish',
                    icon: PhosphorIconsBold.check,
                    onTap: () {
                      final marked = app.finishStory(story);
                      Haptic.heavy();
                      Future.delayed(const Duration(milliseconds: 110), Haptic.light);
                      Future.delayed(const Duration(milliseconds: 220), Haptic.light);
                      showNotchToast(
                        context,
                        title: 'Story finished',
                        subtitle: marked > 0 ? '$marked words marked known' : '${story.wordCount} words read',
                        icon: PhosphorIconsFill.checkCircle,
                        accent: c.sage,
                      );
                    },
                  )
                else
                  GhostButton(
                    label: 'Read again',
                    icon: PhosphorIconsBold.arrowCounterClockwise,
                    onTap: () => app.resetProgress(story),
                  ),
                const SizedBox(height: 10),
                GhostButton(
                  label: 'Back to library',
                  icon: PhosphorIconsBold.books,
                  onTap: () => app.go('library'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ text

typedef _WordTap = void Function(String word, Sentence sentence, String key);

class _ParagraphView extends StatelessWidget {
  const _ParagraphView({
    required this.dir,
    required this.story,
    required this.index,
    required this.selected,
    required this.showTranslations,
    required this.onWord,
    required this.onSentence,
    this.onToggleTranslations,
  });

  final TextDirection dir;
  final Story story;
  final int index;
  final String? selected;
  final bool showTranslations;
  final _WordTap onWord;
  final ValueChanged<Sentence> onSentence;
  final VoidCallback? onToggleTranslations;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final c = context.sc;
    final set = app.settings;
    final font = readerFontById(set.readerFont);
    final paragraph = story.paragraphs[index];
    final lang = story.language;
    final wordStyle = TextStyle(
      fontFamily: font.family,
      fontFamilyFallback: readerFallback,
      fontSize: set.fontSize,
      height: 1.3,
      color: c.text,
    );
    // Spaces carry the line height and the extra word spacing; words are
    // placeholders so their highlight hugs the glyphs.
    final spaceStyle = wordStyle.copyWith(height: set.lineHeight, wordSpacing: set.wordSpacing);
    final ruby = set.translit == 'above' && needsTransliteration(dominantScript(paragraph.text));
    final rubyStyle = AppTheme.f(set.fontSize * 0.5, weight: FontWeight.w600, color: c.brass, height: 1.1);

    final spans = <InlineSpan>[];
    for (var si = 0; si < paragraph.sentences.length; si++) {
      final sentence = paragraph.sentences[si];
      if (si > 0) spans.add(TextSpan(text: ' ', style: spaceStyle));
      final tokens = tokenize(sentence.text);
      for (var ti = 0; ti < tokens.length; ti++) {
        final t = tokens[ti];
        switch (t.kind) {
          case TokenKind.space:
            spans.add(TextSpan(text: t.text.contains('\n') ? '\n' : ' ', style: spaceStyle));
          case TokenKind.punct:
            final text = set.showMarks ? t.text : stripVowelMarks(t.text);
            if (ruby) {
              spans.add(WidgetSpan(
                alignment: PlaceholderAlignment.bottom,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [Text(' ', style: rubyStyle), Text(text, style: wordStyle)],
                ),
              ));
            } else {
              spans.add(TextSpan(text: text, style: wordStyle.copyWith(height: set.lineHeight)));
            }
          case TokenKind.word:
            final key = '$index:$si:$ti';
            final status = app.statusOf(lang, t.text);
            final entry = status == WordStatus.newWord ? null : app.entry(lang, t.text);
            final reading = ruby
                ? readingFor(word: t.text, language: lang, sentence: sentence, entry: entry).text
                : '';
            spans.add(WidgetSpan(
              alignment: ruby ? PlaceholderAlignment.bottom : PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: _Word(
                text: set.showMarks ? t.text : stripVowelMarks(t.text),
                status: status,
                selected: key == selected,
                style: wordStyle,
                reading: ruby ? reading : null,
                readingStyle: rubyStyle,
                highlightNew: set.highlightNew,
                highlightLearning: set.highlightLearning,
                onTap: () => onWord(t.text, sentence, key),
                onLongPress: () => onSentence(sentence),
              ),
            ));
        }
      }
    }

    final hasTranslations = paragraph.sentences.any((x) => x.translation != null);
    return Directionality(
      textDirection: dir,
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          TextSpan(children: spans),
          textAlign: set.justify ? TextAlign.justify : TextAlign.start,
        ),
        if (hasTranslations && onToggleTranslations != null)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Semantics(
              button: true,
              label: showTranslations ? 'Hide translation' : 'Show translation',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  Haptic.selection();
                  onToggleTranslations!();
                },
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(
                    showTranslations ? PhosphorIconsFill.translate : PhosphorIconsRegular.translate,
                    size: 17,
                    color: showTranslations ? c.accent : c.textTertiary,
                  ),
                ),
              ),
            ),
          ),
        AnimatedSize(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: showTranslations && hasTranslations
              ? Container(
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsetsDirectional.only(start: 12),
                  decoration: BoxDecoration(
                    border: BorderDirectional(start: BorderSide(color: c.accent.withValues(alpha: 0.5), width: 2)),
                  ),
                  child: Text(
                    paragraph.sentences.map((x) => x.translation ?? '').where((t) => t.isNotEmpty).join(' '),
                    textDirection: isRtl(story.translationLanguage) ? TextDirection.rtl : TextDirection.ltr,
                    style: AppTheme.s(set.fontSize * 0.72, weight: FontWeight.w500, color: c.textSecondary, height: 1.5),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
      ),
    );
  }
}

class _Word extends StatelessWidget {
  const _Word({
    required this.text,
    required this.status,
    required this.selected,
    required this.style,
    required this.reading,
    required this.readingStyle,
    required this.highlightNew,
    required this.highlightLearning,
    required this.onTap,
    required this.onLongPress,
  });

  final String text;
  final int status;
  final bool selected;
  final TextStyle style;
  final String? reading;
  final TextStyle readingStyle;
  final bool highlightNew;
  final bool highlightLearning;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  static const _learningAlpha = [0.40, 0.30, 0.20, 0.11];

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    Color? bg;
    if (status == WordStatus.newWord && highlightNew) {
      bg = c.info.withValues(alpha: c.isDark ? 0.22 : 0.16);
    } else if (WordStatus.isLearning(status) && highlightLearning) {
      bg = c.warn.withValues(alpha: _learningAlpha[status - 1]);
    }
    final word = Container(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: selected ? Border.all(color: c.ember, width: 1.5) : null,
      ),
      child: Text(text, style: style),
    );
    return Semantics(
      button: true,
      label: text,
      hint: WordStatus.label(status),
      excludeSemantics: true,
      child: RawGestureDetector(
        behavior: HitTestBehavior.opaque,
        gestures: {
          TapGestureRecognizer: GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
            TapGestureRecognizer.new,
            (r) => r.onTap = onTap,
          ),
          LongPressGestureRecognizer: GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
            LongPressGestureRecognizer.new,
            (r) => r.onLongPress = onLongPress,
          ),
        },
        child: reading == null
            ? word
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(reading!.isEmpty ? ' ' : reading!, style: readingStyle, textDirection: TextDirection.ltr),
                  word,
                ],
              ),
      ),
    );
  }
}

// ------------------------------------------------------------------ sentence

Future<void> showSentenceSheet(BuildContext context, Story story, Sentence sentence) {
  final ctl = TextEditingController(text: sentence.translation ?? '');
  final app = context.appRead;
  return showAppSheet<void>(
    context,
    (ctx) {
      final c = ctx.sc;
      final font = readerFontById(app.settings.readerFont);
      final glossed = [
        for (final w in words(sentence.text))
          if (lookupLoose(sentence.glosses, w) != null) (w, lookupLoose(sentence.glosses, w)!),
      ];
      return SheetBody(
        title: 'Sentence',
        children: [
          Text(
            sentence.text,
            textDirection: isRtl(story.language, sentence.text) ? TextDirection.rtl : TextDirection.ltr,
            style: TextStyle(
              fontFamily: font.family,
              fontFamilyFallback: readerFallback,
              fontSize: 20,
              height: 1.5,
              color: c.text,
            ),
          ),
          const SizedBox(height: 16),
          AppField(
            controller: ctl,
            label: 'Translation',
            hint: 'Add your own translation',
            maxLines: 4,
            minLines: 1,
            onChanged: (v) {
              sentence.translation = v.trim().isEmpty ? null : v.trim();
              app.touchStory(story);
            },
          ),
          if (glossed.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Kicker('Glosses in this text'),
            const SizedBox(height: 8),
            ToolGroup(
              color: c.bgRaised2,
              radius: 18,
              children: [
                for (final (w, g) in glossed) ToolRow(label: w, value: g, minHeight: 44),
              ],
            ),
          ],
          const SizedBox(height: 16),
          GhostButton(
            label: 'Copy sentence',
            icon: PhosphorIconsBold.copy,
            onTap: () {
              Clipboard.setData(ClipboardData(text: sentence.text));
              showNotchToast(ctx, title: 'Sentence copied', icon: PhosphorIconsFill.copy);
            },
          ),
        ],
      );
    },
  );
}
