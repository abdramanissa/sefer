import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../data/app_state.dart';
import '../data/models.dart';
import '../text/normalize.dart';
import '../text/script.dart';
import '../text/tokenizer.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/feel.dart';
import '../widgets/common.dart';
import '../widgets/glass.dart';
import '../widgets/notch_toast.dart';
import '../widgets/ui_kit.dart';
import '../widgets/word_text.dart';
import 'reader_controls.dart';
import 'story_actions.dart';
import 'word_card.dart';
import 'word_sheet.dart';

/// Seconds without touching the screen after which reading time stops
/// counting, so an abandoned phone doesn't inflate your stats.
const _idleSeconds = 120;

/// Page colours the reader can use instead of the app theme.
class ReaderPaper {
  const ReaderPaper(this.id, this.label, this.bg, this.ink, this.soft);
  final String id;
  final String label;
  final Color? bg;
  final Color? ink;
  final Color? soft;

  static const all = [
    ReaderPaper('app', 'Theme', null, null, null),
    ReaderPaper('paper', 'Paper', Color(0xFFF6F1E7), Color(0xFF2B2620), Color(0xFF6B6257)),
    ReaderPaper('sepia', 'Sepia', Color(0xFFEADFC8), Color(0xFF43372A), Color(0xFF6F604D)),
    ReaderPaper('dusk', 'Dusk', Color(0xFF1B1F2A), Color(0xFFD5D8E0), Color(0xFF8B91A0)),
    ReaderPaper('black', 'Black', Color(0xFF000000), Color(0xFFC9C9C9), Color(0xFF7A7A7A)),
  ];

  static ReaderPaper byId(String id) => all.firstWhere((p) => p.id == id, orElse: () => all.first);

  /// A full palette built from this paper, so the reader's bars, cards and
  /// sheets sit on it instead of on the app theme.
  SeferColors? palette(SeferColors app) {
    final b = bg, i = ink, s = soft;
    if (b == null || i == null || s == null) return null;
    final dark = ThemeData.estimateBrightnessForColor(b) == Brightness.dark;
    Color mix(double t) => Color.lerp(b, i, t)!;
    return SeferColors.fromBase(dark ? Brightness.dark : Brightness.light, {
      ...app.editable,
      'bg': b,
      'bgRaised': mix(dark ? 0.09 : 0.05),
      'bgRaised2': mix(dark ? 0.16 : 0.11),
      'border': mix(0.2),
      'text': i,
      'textSecondary': s,
      'textTertiary': Color.lerp(s, b, 0.3)!,
      'ember': i,
      'onEmber': b,
    });
  }
}

/// Tokens per sentence, computed once. Sentences are replaced, not mutated,
/// when a text is edited, so the cache can't go stale.
final _tokenCache = Expando<List<Token>>();
List<Token> _tokens(Sentence s) => _tokenCache[s] ??= tokenize(s.text);

/// A word the reader is showing a card for.
class _Picked {
  const _Picked(this.key, this.word, this.sentence, {this.sentenceOnly = false});
  final String key;
  final String word;
  final Sentence sentence;
  final bool sentenceOnly;
}

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

  // Scrolling touches only these, never the whole page.
  final _chrome = ValueNotifier(true);
  final _progress = ValueNotifier(0.0);
  final _position = ValueNotifier(0);
  final _picked = ValueNotifier<_Picked?>(null);

  late int _anchor;
  Timer? _tick;
  int _pending = 0;
  DateTime _lastTouch = DateTime.now();
  bool _foreground = true;
  DateTime _lastTrack = DateTime.fromMillisecondsSinceEpoch(0);
  (String, DateTime)? _lastTap;
  AppState? _app;
  Story? _story;
  bool _awake = false;

  static const _barHeight = 64.0;

  // Pages layout.
  PageController? _pager;
  List<_Page> _pages = const [];
  Object? _pagesKey;
  final _page = ValueNotifier(0);
  // Pages are counted during layout; the indicator learns the count after.
  final _pageCount = ValueNotifier(0);
  String _layout = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _app = context.appRead;
    _story = _app!.story(widget.id);
    final s = _story;
    _anchor = s == null ? 0 : s.position.clamp(0, s.paragraphs.isEmpty ? 0 : s.paragraphs.length - 1);
    _progress.value = s?.progress ?? 0;
    _position.value = _anchor;
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    _setAwake(_app!.settings.keepAwake);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialJump());
  }

  void _setAwake(bool on) {
    if (on == _awake) return;
    _awake = on;
    // Not available in tests or on every platform; staying awake is a nicety.
    (on ? WakelockPlus.enable() : WakelockPlus.disable()).catchError((_) {});
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
    if (_pending >= 30) _commitTime();
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
    _setAwake(false);
    // Saving notifies listeners, which isn't allowed while the tree is being
    // torn down; do it right after.
    final app = _app;
    final s = _story;
    final n = _pending;
    if (app != null && s != null && n > 0) Future(() => app.addReadingTime(s, n));
    _scroll.dispose();
    _chrome.dispose();
    _progress.dispose();
    _position.dispose();
    _picked.dispose();
    _pager?.dispose();
    _page.dispose();
    _pageCount.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification n) {
    _touch();
    if (n is ScrollUpdateNotification && n.dragDetails != null && _app!.settings.hideChromeOnScroll) {
      final d = n.scrollDelta ?? 0;
      if (d > 6) _chrome.value = false;
      if (d < -6) _chrome.value = true;
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
    final progress = atEnd ? 1.0 : first / max(1, s.paragraphs.length);
    _position.value = first;
    if (first != s.position || (progress - s.progress).abs() > 0.001) {
      _app!.updatePosition(s, atEnd ? s.paragraphs.length : first, progress);
      _progress.value = progress;
    }
  }

  Future<void> _onWord(Story s, String word, Sentence sentence, String key) async {
    _touch();
    final app = _app!;
    final set = app.settings;
    final learn = set.readerMode == 'learn';
    // Double-tap: mark known and move on.
    final last = _lastTap;
    _lastTap = (key, DateTime.now());
    if (learn && set.doubleTapKnown && last != null && last.$1 == key && DateTime.now().difference(last.$2).inMilliseconds < 350) {
      _lastTap = null;
      Haptic.medium();
      app.setWord(s.language, word, status: WordStatus.known, example: sentence.text, storyId: s.id);
      _picked.value = null;
      return;
    }
    Haptic.selection();
    if (learn && set.wordPopup == 'sheet') {
      _picked.value = _Picked(key, word, sentence);
      await openWordSheet(context, story: s, word: word, sentence: sentence);
      if (mounted) _picked.value = null;
      return;
    }
    _picked.value = _picked.value?.key == key ? null : _Picked(key, word, sentence);
  }

  Future<void> _onSentence(Story s, String word, Sentence sentence, String key) async {
    _touch();
    Haptic.medium();
    if (_app!.settings.readerMode == 'read') {
      _picked.value = _Picked(key, word, sentence, sentenceOnly: true);
      return;
    }
    _picked.value = null;
    await showSentenceSheet(context, s, sentence);
  }

  // ------------------------------------------------------------ pages

  void _turn(bool forward) {
    final p = _pager;
    if (p == null || !p.hasClients) return;
    _touch();
    Haptic.selection();
    final target = (p.page?.round() ?? 0) + (forward ? 1 : -1);
    if (target < 0 || target >= _pages.length) return;
    if (Motion.reduced(context)) {
      p.jumpToPage(target);
    } else {
      p.animateToPage(target, duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
    }
  }

  int _pageOf(int paragraph) {
    for (var i = 0; i < _pages.length; i++) {
      if (_pages[i].chunks.any((c) => c.p >= paragraph)) return i;
    }
    return max(0, _pages.length - 1);
  }

  void _onPage(Story s, int i) {
    _touch();
    _picked.value = null;
    _page.value = i;
    if (i >= _pages.length) return;
    final n = s.paragraphs.length;
    final page = _pages[i];
    final contentPages = _pages.where((p) => !p.footer).length;
    final atEnd = page.footer || i >= contentPages - 1;
    final first = page.chunks.isEmpty ? n : page.chunks.first.p;
    final progress = atEnd ? 1.0 : first / max(1, n);
    _position.value = min(first, max(0, n - 1));
    _progress.value = progress;
    _app!.updatePosition(s, atEnd ? n : first, progress);
  }

  Widget _pagedBody(Story s, Settings set, TextDirection dir, double width, double top, Widget Function(int, {int from, int? to, bool tracked}) para) {
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    final scaler = MediaQuery.textScalerOf(context);
    final topPad = top + _barHeight + 18;
    final bottomPad = bottom + 44;
    return LayoutBuilder(
      builder: (context, box) {
        final avail = box.maxHeight - topPad - bottomPad;
        final key = Object.hashAll([
          width, avail, scaler.scale(100), s.updatedAt, set.fontSize, set.lineHeight, set.wordSpacing, //
          set.letterSpacing, set.paragraphSpacing, set.sidePadding, set.readerFont, set.fontByLanguage[s.language],
          set.translit, set.showMarks, set.boldText, set.paragraphIndent, set.sentenceTranslations,
          set.showReaderHeader, _openTranslations.join(','),
        ]);
        if (key != _pagesKey) {
          final keep = _pages.isEmpty ? _anchor : _position.value;
          _pages = _paginate(s, set, dir, width - set.sidePadding * 2, avail, scaler);
          _pagesKey = key;
          final target = _pageOf(keep);
          final count = _pages.where((p) => !p.footer).length;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _pageCount.value = count;
          });
          if (_pager == null) {
            _pager = PageController(initialPage: target);
            _page.value = target;
          } else if (_pager!.hasClients) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_pager?.hasClients ?? false) _pager!.jumpToPage(target);
            });
          }
        }
        return NotificationListener<ScrollNotification>(
          onNotification: (_) {
            _touch();
            return false;
          },
          child: PageView.builder(
            controller: _pager,
            reverse: dir == TextDirection.rtl,
            itemCount: _pages.length,
            onPageChanged: (i) => _onPage(s, i),
            itemBuilder: (context, i) {
              final page = _pages[i];
              if (page.footer) {
                return SingleChildScrollView(
                  padding: EdgeInsets.only(top: topPad),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: avail),
                    child: Center(child: _Footer(story: s, width: width)),
                  ),
                );
              }
              return RepaintBoundary(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: EdgeInsets.only(top: page.header ? 0 : topPad, bottom: bottomPad),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (page.header) _Header(story: s, dir: dir, paper: ReaderPaper.byId(set.readerPaper), width: width, topPad: topPad),
                      for (final c in page.chunks) para(c.p, from: c.from, to: c.to, tracked: false),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
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
    final set = app.settings;
    _setAwake(set.keepAwake);
    final paper = ReaderPaper.byId(set.readerPaper);
    final bg = paper.bg ?? c.bg;
    final dir = isRtl(s.language, s.paragraphs.isEmpty ? s.title : s.paragraphs.first.text)
        ? TextDirection.rtl
        : TextDirection.ltr;
    final top = MediaQuery.viewPaddingOf(context).top;
    final width = min(set.maxWidth, MediaQuery.sizeOf(context).width);
    final n = s.paragraphs.length;
    _anchor = _anchor.clamp(0, n == 0 ? 0 : n - 1);

    Widget para(int i, {int from = 0, int? to, bool tracked = true}) {
      final key = tracked ? _keys.putIfAbsent(i, GlobalKey.new) : null;
      Widget child = _ParagraphView(
        dir: dir,
        story: s,
        index: i,
        from: from,
        to: to,
        paper: paper,
        picked: _picked,
        showTranslations: set.sentenceTranslations == 'below' || _openTranslations.contains(i),
        onWord: (w, sentence, k) => _onWord(s, w, sentence, k),
        onSentence: (w, sentence, k) => _onSentence(s, w, sentence, k),
        onToggleTranslations: set.sentenceTranslations == 'tap'
            ? () => setState(() {
                if (!_openTranslations.remove(i)) _openTranslations.add(i);
              })
            : null,
      );
      if (set.dimRead) {
        child = ValueListenableBuilder<int>(
          valueListenable: _position,
          child: child,
          builder: (_, pos, child) => AnimatedOpacity(
            opacity: i < pos ? 0.4 : 1,
            duration: const Duration(milliseconds: 240),
            child: child,
          ),
        );
      }
      return Center(
        key: key,
        child: SizedBox(
          width: width,
          child: Padding(
            padding: EdgeInsets.fromLTRB(set.sidePadding, 0, set.sidePadding, set.paragraphSpacing),
            child: child,
          ),
        ),
      );
    }

    final paged = set.readerLayout == 'pages';
    if (_layout != set.readerLayout) {
      // Switching layout keeps your place.
      if (_layout.isNotEmpty) {
        _anchor = _position.value.clamp(0, n == 0 ? 0 : n - 1);
        _pager?.dispose();
        _pager = null;
        _pagesKey = null;
        if (!paged) WidgetsBinding.instance.addPostFrameCallback((_) => _initialJump());
      }
      _layout = set.readerLayout;
    }

    final paperColors = paper.palette(c);
    final page = AnnotatedRegion<SystemUiOverlayStyle>(
      value: ThemeData.estimateBrightnessForColor(bg) == Brightness.dark
          ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent)
          : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
      child: ColoredBox(
        color: bg,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapUp: (d) {
                  if (_picked.value != null) {
                    _picked.value = null;
                    return;
                  }
                  // In pages, the outer fifths of the screen turn the page.
                  final w = MediaQuery.sizeOf(context).width;
                  final x = d.globalPosition.dx;
                  if (paged && (x < w * 0.2 || x > w * 0.8)) {
                    final left = x < w * 0.2;
                    _turn(dir == TextDirection.rtl ? left : !left);
                    return;
                  }
                  _chrome.value = !_chrome.value;
                },
                child: paged
                    ? _pagedBody(s, set, dir, width, top, para)
                    : NotificationListener<ScrollNotification>(
                  onNotification: _onScroll,
                  child: CustomScrollView(
                    controller: _scroll,
                    center: _centerKey,
                    slivers: [
                      SliverToBoxAdapter(
                        child: _Header(story: s, dir: dir, paper: paper, width: width, topPad: top + _barHeight + 18),
                      ),
                      SliverList(
                        delegate: SliverChildBuilderDelegate((_, i) => para(_anchor - 1 - i), childCount: _anchor),
                      ),
                      SliverList(
                        key: _centerKey,
                        delegate: SliverChildBuilderDelegate((_, i) => para(_anchor + i), childCount: n - _anchor),
                      ),
                      SliverToBoxAdapter(child: _Footer(story: s, width: width)),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ValueListenableBuilder<bool>(
                valueListenable: _chrome,
                builder: (_, shown, child) => AnimatedSlide(
                  offset: shown ? Offset.zero : const Offset(0, -1.3),
                  duration: const Duration(milliseconds: 280),
                  curve: shown ? Curves.easeOutCubic : Curves.easeInCubic,
                  child: child,
                ),
                child: _TopBar(story: s, top: top, progress: _progress, onBack: app.back),
              ),
            ),
            if (paged)
              Positioned(
                left: 0,
                right: 0,
                bottom: MediaQuery.viewPaddingOf(context).bottom + 14,
                child: IgnorePointer(
                  child: ListenableBuilder(
                    listenable: Listenable.merge([_page, _pageCount]),
                    builder: (_, _) => Text(
                      _pageCount.value == 0 || _page.value >= _pageCount.value ? '' : '${_page.value + 1} / ${_pageCount.value}',
                      textAlign: TextAlign.center,
                      style: AppTheme.d(12, weight: FontWeight.w700, color: paper.soft ?? c.textTertiary),
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ValueListenableBuilder<_Picked?>(
                valueListenable: _picked,
                builder: (context, p, _) => AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, a) => SlideTransition(
                    position: Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(a),
                    child: FadeTransition(opacity: a, child: child),
                  ),
                  child: p == null || (set.readerMode == 'learn' && set.wordPopup == 'sheet' && !p.sentenceOnly)
                      ? const SizedBox(key: ValueKey('none'), width: double.infinity)
                      : WordCard(
                          key: ValueKey(p.key + (p.sentenceOnly ? 's' : '')),
                          story: s,
                          word: p.word,
                          sentence: p.sentence,
                          readMode: set.readerMode == 'read',
                          sentenceOnly: p.sentenceOnly,
                          onClose: () => _picked.value = null,
                          onMore: () async {
                            _picked.value = null;
                            await openWordSheet(context, story: s, word: p.word, sentence: p.sentence);
                          },
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    // On a paper page the whole reader (bars, cards, sheets) takes its colours.
    return paperColors == null ? page : Theme(data: AppTheme.build(paperColors), child: page);
  }
}

// ------------------------------------------------------------------ pages

class _Chunk {
  const _Chunk(this.p, this.from, this.to);
  final int p;
  final int from;
  final int to;
}

class _Page {
  _Page(this.chunks, {this.header = false, this.footer = false});
  final List<_Chunk> chunks;
  final bool header;
  final bool footer;
}

/// Splits a story into pages that fit [height]. Paragraphs are split at
/// sentence boundaries when they don't fit; a single sentence taller than a
/// page gets a page of its own, which scrolls.
List<_Page> _paginate(Story s, Settings set, TextDirection dir, double width, double height, TextScaler scaler) {
  final font = readerFontFor(set.fontByLanguage, set.readerFont, s.language);
  final painter = TextPainter(textDirection: dir, textScaler: scaler);
  double measure(String text, TextStyle style) {
    painter.text = TextSpan(text: text, style: style);
    painter.layout(maxWidth: max(40, width));
    return painter.height;
  }

  final translationStyle = AppTheme.s(set.fontSize * 0.72, weight: FontWeight.w500, height: 1.5);
  final styles = <bool, TextStyle>{};
  TextStyle styleFor(bool ruby) => styles[ruby] ??= _readerStyle(set, font, const Color(0xFF000000)).copyWith(
    height: ruby ? max(set.lineHeight, 2.3) : set.lineHeight,
    wordSpacing: set.wordSpacing,
    leadingDistribution: ruby ? TextLeadingDistribution.proportional : TextLeadingDistribution.even,
  );

  double chunkHeight(int p, int from, int to) {
    final para = s.paragraphs[p];
    final sentences = para.sentences.sublist(from, to);
    final ruby = set.translit == 'above' && needsTransliteration(dominantScript(para.text));
    var text = sentences.map((x) => x.text).join(' ');
    if (!set.showMarks) text = stripVowelMarks(text);
    if (set.paragraphIndent && from == 0) text = '\u2003\u2003$text';
    // A little slack for rounding and the reading line above the first row.
    var h = measure(text, styleFor(ruby)) * 1.03 + (ruby ? set.fontSize * 0.5 : 0);
    final translations = sentences.map((x) => x.translation ?? '').where((t) => t.isNotEmpty).join(' ');
    if (translations.isNotEmpty) {
      if (set.sentenceTranslations == 'tap') h += 37;
      if (set.sentenceTranslations == 'below') h += measure(translations, translationStyle) + 6;
    }
    return h + set.paragraphSpacing;
  }

  var header = 0.0;
  if (set.showReaderHeader) {
    header = 17 + 12 + measure(s.title, styleFor(false).copyWith(fontSize: set.fontSize * 1.45, height: 1.25)) + set.paragraphSpacing + 10;
    if (s.author.isNotEmpty) header += 26;
  }

  final pages = <_Page>[];
  var chunks = <_Chunk>[];
  var used = header;
  void flush() {
    pages.add(_Page(chunks, header: pages.isEmpty && set.showReaderHeader));
    chunks = [];
    used = 0;
  }

  for (var p = 0; p < s.paragraphs.length; p++) {
    final n = s.paragraphs[p].sentences.length;
    var from = 0;
    while (from < n) {
      final room = height - used;
      final whole = chunkHeight(p, from, n);
      if (whole <= room) {
        chunks.add(_Chunk(p, from, n));
        used += whole;
        break;
      }
      // The most sentences that still fit.
      var to = from;
      while (to < n && chunkHeight(p, from, to + 1) <= room) {
        to++;
      }
      if (to > from) {
        chunks.add(_Chunk(p, from, to));
        from = to;
        flush();
      } else if (chunks.isEmpty && !(pages.isEmpty && header > 0 && used > 0)) {
        chunks.add(_Chunk(p, from, from + 1));
        from++;
        flush();
      } else {
        flush();
      }
    }
  }
  if (chunks.isNotEmpty || pages.isEmpty) flush();
  painter.dispose();
  pages.add(_Page(const [], footer: true));
  return pages;
}

// ------------------------------------------------------------------ chrome

class _TopBar extends StatelessWidget {
  const _TopBar({required this.story, required this.top, required this.progress, required this.onBack});
  final Story story;
  final double top;
  final ValueListenable<double> progress;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final c = context.sc;
    final set = app.settings;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final learn = set.readerMode == 'learn';
    return Padding(
      padding: EdgeInsets.fromLTRB(12, top + 6, 12, 0),
      child: GlassSurface(
        radius: context.feel.r(24),
        sigma: 18,
        shadow: false,
        enabled: set.glass,
        child: SizedBox(
          height: 54,
          child: Row(
            children: [
              const SizedBox(width: 4),
              RoundBtn(icon: rtl ? PhosphorIconsBold.caretRight : PhosphorIconsBold.caretLeft, label: 'Back', size: 36, onTap: onBack),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(story.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.f(14, weight: FontWeight.w800, color: c.text)),
                    if (set.showReaderProgress) ...[
                      const SizedBox(height: 5),
                      ValueListenableBuilder<double>(
                        valueListenable: progress,
                        builder: (_, p, _) => Row(
                          children: [
                            Expanded(child: ThinProgress(value: p, height: 3)),
                            const SizedBox(width: 8),
                            Text('${(p * 100).round()}%', style: AppTheme.d(11, weight: FontWeight.w700, color: c.textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Semantics(
                label: learn ? 'Learning mode. Switch to reading mode' : 'Reading mode. Switch to learning mode',
                child: RoundBtn(
                  icon: learn ? PhosphorIconsBold.graduationCap : PhosphorIconsBold.bookOpen,
                  size: 36,
                  onTap: () {
                    app.updateSettings((x) => x.readerMode = learn ? 'read' : 'learn');
                    showNotchToast(
                      context,
                      title: learn ? 'Reading mode' : 'Learning mode',
                      subtitle: learn ? 'No highlights. Tap for a quick meaning.' : 'Highlights and word levels are back.',
                      icon: learn ? PhosphorIconsFill.bookOpen : PhosphorIconsFill.graduationCap,
                      accent: c.accent,
                    );
                  },
                ),
              ),
              RoundBtn(icon: PhosphorIconsBold.textAa, label: 'Text settings', size: 36, onTap: () => showReaderSettings(context, story)),
              RoundBtn(icon: PhosphorIconsBold.dotsThree, label: 'More', size: 36, onTap: () => showStoryActions(context, story)),
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
      children: [ReaderControls(showMarksToggle: marks, sample: sample, language: story.language)],
    ),
  );
}

TextStyle _readerStyle(Settings set, ReaderFont font, Color ink) => TextStyle(
  fontFamily: font.family,
  fontFamilyFallback: readerFallback,
  fontSize: set.fontSize,
  fontWeight: set.boldText ? FontWeight.w700 : FontWeight.w400,
  letterSpacing: set.letterSpacing,
  color: ink,
);

class _Header extends StatelessWidget {
  const _Header({required this.story, required this.dir, required this.paper, required this.width, required this.topPad});
  final Story story;
  final TextDirection dir;
  final ReaderPaper paper;
  final double width;
  final double topPad;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final c = context.sc;
    final set = app.settings;
    final font = readerFontFor(set.fontByLanguage, set.readerFont, story.language);
    final ink = paper.ink ?? c.text;
    final soft = paper.soft ?? c.textTertiary;
    if (!set.showReaderHeader) return SizedBox(height: topPad);
    final ws = app.wordStats(story);
    return Center(
      child: SizedBox(
        width: width,
        child: Padding(
          padding: EdgeInsets.fromLTRB(set.sidePadding, topPad, set.sidePadding, set.paragraphSpacing + 10),
          child: Column(
            crossAxisAlignment: dir == TextDirection.rtl ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(
                [
                  '${story.wordCount} words',
                  '~${app.minutesLeft(story)} min',
                  if (set.readerMode == 'learn') '${ws.fresh} new',
                  if (set.readerMode == 'learn') '${(ws.knownRatio * 100).round()}% known',
                ].join(' · '),
                style: AppTheme.f(12, weight: FontWeight.w600, color: soft),
              ),
              const SizedBox(height: 12),
              Text(
                set.showMarks ? story.title : stripVowelMarks(story.title),
                textDirection: dir,
                style: _readerStyle(set, font, ink).copyWith(fontSize: set.fontSize * 1.45, fontWeight: FontWeight.w700, height: 1.25),
              ),
              if (story.author.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(story.author, style: AppTheme.f(14, weight: FontWeight.w600, color: soft)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.story, required this.width});
  final Story story;
  final double width;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final c = context.sc;
    final set = app.settings;
    final ws = app.wordStats(story);
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    final done = story.finishedAt != null;
    final next = app.nextAfter(story);
    return Center(
      child: SizedBox(
        width: width,
        child: Padding(
          padding: EdgeInsets.fromLTRB(set.sidePadding, 12, set.sidePadding, 40 + bottom),
          child: SoftCard(
            radius: 26,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (context.feel.kickers) ...[Kicker(done ? 'Finished' : 'The end'), const SizedBox(height: 8)],
                Text(done ? 'Nicely done.' : 'You reached the end.', style: AppTheme.f(22, weight: FontWeight.w800, color: c.text)),
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
                  GhostButton(label: 'Read again', icon: PhosphorIconsBold.arrowCounterClockwise, onTap: () => app.resetProgress(story)),
                if (story.quiz.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _QuizCta(story: story, primary: done),
                ],
                if (next != null) ...[
                  const SizedBox(height: 10),
                  GhostButton(
                    label: 'Next: ${next.title}',
                    icon: PhosphorIconsBold.arrowRight,
                    onTap: () {
                      app.back();
                      app.openStory(next);
                    },
                  ),
                ],
                const SizedBox(height: 10),
                GhostButton(label: 'Back to library', icon: PhosphorIconsBold.books, onTap: () => app.go('library')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens the story's quiz; shows the best score once taken.
class _QuizCta extends StatelessWidget {
  const _QuizCta({required this.story, required this.primary});
  final Story story;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final n = story.quiz.length;
    final best = story.quizBest;
    final label = best == null
        ? 'Take the quiz · $n question${n == 1 ? '' : 's'}'
        : 'Quiz again · best $best%';
    void open() => context.appRead.go('quiz:${story.id}');
    return primary
        ? PrimaryButton(label: label, icon: PhosphorIconsBold.exam, onTap: open)
        : GhostButton(label: label, icon: PhosphorIconsBold.exam, onTap: open);
  }
}

// ------------------------------------------------------------------ text

typedef _WordTap = void Function(String word, Sentence sentence, String key);

class _ParagraphView extends StatelessWidget {
  const _ParagraphView({
    required this.dir,
    required this.story,
    required this.index,
    required this.paper,
    required this.picked,
    required this.showTranslations,
    required this.onWord,
    required this.onSentence,
    this.onToggleTranslations,
    this.from = 0,
    this.to,
  });

  final TextDirection dir;
  final Story story;
  final int index;

  /// The sentences shown, when a page holds only part of the paragraph.
  final int from;
  final int? to;
  final ReaderPaper paper;
  final ValueListenable<_Picked?> picked;
  final bool showTranslations;
  final _WordTap onWord;
  final _WordTap onSentence;
  final VoidCallback? onToggleTranslations;

  static const _learningAlpha = [0.40, 0.30, 0.20, 0.11];

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final c = context.sc;
    final set = app.settings;
    final font = readerFontFor(set.fontByLanguage, set.readerFont, story.language);
    final paragraph = story.paragraphs[index];
    final lang = story.language;
    final learn = set.readerMode == 'learn';
    final ink = paper.ink ?? c.text;
    final ruby = set.translit == 'above' && needsTransliteration(dominantScript(paragraph.text));
    // Room above each line for the reading when it's shown.
    final lineHeight = ruby ? max(set.lineHeight, 2.3) : set.lineHeight;
    final style = _readerStyle(set, font, ink).copyWith(
      height: lineHeight,
      wordSpacing: set.wordSpacing,
      leadingDistribution: ruby ? TextLeadingDistribution.proportional : TextLeadingDistribution.even,
    );
    final strength = set.highlightStrength;

    // One string for the whole paragraph; words are ranges into it.
    final buf = StringBuffer(set.paragraphIndent && from == 0 ? '  ' : '');
    final ranges = <TextRange>[];
    final refs = <(String, Sentence, String)>[];
    final marks = <int, WordMark>{};
    final end = min(to ?? paragraph.sentences.length, paragraph.sentences.length);
    final shownSentences = paragraph.sentences.sublist(min(from, end), end);
    for (var si = from; si < end; si++) {
      final sentence = paragraph.sentences[si];
      if (si > from) buf.write(' ');
      final tokens = _tokens(sentence);
      for (var ti = 0; ti < tokens.length; ti++) {
        final t = tokens[ti];
        if (t.kind == TokenKind.space) {
          buf.write(t.text.contains('\n') ? '\n' : ' ');
          continue;
        }
        final shown = set.showMarks ? t.text : stripVowelMarks(t.text);
        if (t.kind == TokenKind.punct) {
          buf.write(shown);
          continue;
        }
        final start = buf.length;
        buf.write(shown);
        final i = ranges.length;
        ranges.add(TextRange(start: start, end: buf.length));
        refs.add((t.text, sentence, '$index:$si:$ti'));

        Color? fill;
        Color? underline;
        String? reading;
        if (learn && set.highlightStyle != 'none') {
          final status = app.statusOf(lang, t.text);
          Color? tone;
          if (status == WordStatus.newWord && set.highlightNew) {
            tone = c.info.withValues(alpha: ((c.isDark ? 0.22 : 0.16) * strength).clamp(0.0, 1.0));
          } else if (WordStatus.isLearning(status) && set.highlightLearning) {
            tone = c.warn.withValues(alpha: (_learningAlpha[status - 1] * strength).clamp(0.0, 1.0));
          }
          if (tone != null) {
            if (set.highlightStyle == 'underline') {
              underline = tone.withValues(alpha: (tone.a * 2.4).clamp(0.0, 1.0));
            } else {
              fill = tone;
            }
          }
        }
        if (ruby) {
          final entry = app.entry(lang, t.text);
          reading = readingFor(word: t.text, language: lang, sentence: sentence, entry: entry).text;
        }
        if (fill != null || underline != null || (reading != null && reading.isNotEmpty)) {
          marks[i] = WordMark(fill: fill, underline: underline, reading: reading);
        }
      }
    }
    final text = TextSpan(text: buf.toString(), style: style);

    final hasTranslations = shownSentences.any((x) => x.translation != null);
    return Directionality(
      textDirection: dir,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ValueListenableBuilder<_Picked?>(
            valueListenable: picked,
            builder: (context, p, _) {
              var shownMarks = marks;
              if (p != null) {
                final i = refs.indexWhere((r) => r.$3 == p.key);
                if (i >= 0) {
                  shownMarks = {...marks, i: WordMark(fill: marks[i]?.fill, underline: marks[i]?.underline, reading: marks[i]?.reading, selected: true)};
                }
              }
              return WordText(
                text: text,
                words: ranges,
                marks: shownMarks,
                textDirection: dir,
                textAlign: set.justify ? TextAlign.justify : TextAlign.start,
                readingStyle: ruby ? AppTheme.f(set.fontSize * 0.46, weight: FontWeight.w600, color: c.brass, height: 1.1) : null,
                selectedColor: ink,
                onTap: (i, _) => onWord(refs[i].$1, refs[i].$2, refs[i].$3),
                onLongPress: (i, _) => onSentence(refs[i].$1, refs[i].$2, refs[i].$3),
              );
            },
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
                      color: showTranslations ? c.accent : (paper.soft ?? c.textTertiary),
                    ),
                  ),
                ),
              ),
            ),
          if (showTranslations && hasTranslations)
            Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsetsDirectional.only(start: 12),
              decoration: BoxDecoration(
                border: BorderDirectional(start: BorderSide(color: c.accent.withValues(alpha: 0.5), width: 2)),
              ),
              child: Text(
                shownSentences.map((x) => x.translation ?? '').where((t) => t.isNotEmpty).join(' '),
                textDirection: isRtl(story.translationLanguage) ? TextDirection.rtl : TextDirection.ltr,
                style: AppTheme.s(set.fontSize * 0.72, weight: FontWeight.w500, color: paper.soft ?? c.textSecondary, height: 1.5),
              ),
            ),
        ],
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
      final set = app.settings;
      final font = readerFontFor(set.fontByLanguage, set.readerFont, story.language);
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
            style: TextStyle(fontFamily: font.family, fontFamilyFallback: readerFallback, fontSize: 20, height: 1.5, color: c.text),
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
              children: [for (final (w, g) in glossed) ToolRow(label: w, value: g, minHeight: 44)],
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
