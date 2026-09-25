import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../data/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_background.dart';
import '../widgets/covers.dart';
import '../widgets/glass.dart';
import '../widgets/ui_kit.dart';
import 'routes.dart';

const _overlayDark = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  systemNavigationBarColor: Colors.transparent,
  systemNavigationBarContrastEnforced: false,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
  systemNavigationBarIconBrightness: Brightness.light,
);

const _overlayLight = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  systemNavigationBarColor: Colors.transparent,
  systemNavigationBarContrastEnforced: false,
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
  systemNavigationBarIconBrightness: Brightness.dark,
);

/// Height the floating nav takes, so scrolling pages can pad their bottom.
double navClearance(BuildContext context) => 116 + MediaQuery.viewPaddingOf(context).bottom;

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final c = context.sc;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 60;
    final showNav = app.showNav && !keyboard;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: c.isDark ? _overlayDark : _overlayLight,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (!app.back()) SystemNavigator.pop();
        },
        child: Scaffold(
          backgroundColor: c.bg,
          resizeToAvoidBottomInset: false,
          body: Stack(
            children: [
              Positioned.fill(child: AppBackground(pattern: app.settings.background)),
              Positioned.fill(child: _ScreenSwitcher(route: app.route)),
              if (app.showNav)
                Positioned(left: 0, right: 0, bottom: 0, child: _BottomFade(visible: showNav)),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AnimatedSlide(
                  offset: showNav ? Offset.zero : const Offset(0, 1.4),
                  duration: const Duration(milliseconds: 340),
                  curve: showNav ? Curves.easeOutCubic : Curves.easeInCubic,
                  child: const _NavBar(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ transitions

class _ScreenSwitcher extends StatelessWidget {
  const _ScreenSwitcher({required this.route});
  final String route;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final s = app.settings;
    final reduced = Motion.reduced(context) || s.transition == 'none';
    final duration = Duration(milliseconds: reduced ? 0 : s.transitionMs);
    return AnimatedSwitcher(
      duration: duration,
      layoutBuilder: (current, previous) => Stack(
        fit: StackFit.expand,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, animation) {
        final incoming = child.key == ValueKey(route);
        return _RouteTransition(
          animation: animation,
          incoming: incoming,
          style: s.transition,
          blur: s.transitionBlur,
          depth: app.moveDepth,
          side: app.moveSide,
          child: child,
        );
      },
      child: KeyedSubtree(key: ValueKey(route), child: buildScreen(route)),
    );
  }
}

/// The "rack focus" move (DESIGN.md §8.4): the old page drifts back and out of
/// focus while the new one comes into focus. Tabs move sideways, drilling in
/// and out moves vertically. The style and strength come from settings.
class _RouteTransition extends StatelessWidget {
  const _RouteTransition({
    required this.animation,
    required this.incoming,
    required this.style,
    required this.blur,
    required this.depth,
    required this.side,
    required this.child,
  });

  final Animation<double> animation;
  final bool incoming;
  final String style;
  final double blur;
  final int depth;
  final int side;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: animation,
    child: child,
    builder: (context, child) {
      final v = animation.value;
      if (v >= 1 && incoming) return child!;
      // p: 0 → 1 as this page becomes the visible one.
      final double p;
      if (incoming) {
        p = Curves.easeOutCubic.transform(const Interval(0.25, 1).transform(v));
      } else {
        // The outgoing animation runs 1 → 0; it leaves early.
        final q = const Interval(0, 0.7).transform(1 - v);
        p = 1 - Curves.easeInCubic.transform(q);
      }
      final away = 1 - p;
      final rtl = Directionality.of(context) == TextDirection.rtl;
      final dir = (rtl ? -side : side).toDouble();
      Offset offset;
      double scale = 1;
      double sigma = 0;
      switch (style) {
        case 'fade':
          offset = Offset.zero;
        case 'slide':
          final w = MediaQuery.sizeOf(context).width;
          final h = MediaQuery.sizeOf(context).height;
          offset = depth == 0
              ? Offset((incoming ? dir : -dir) * w * 0.3 * away, 0)
              : Offset(0, (incoming ? depth : -depth) * h * 0.08 * away);
        case 'scale':
          offset = Offset.zero;
          scale = incoming ? 1 + 0.06 * away : 1 - 0.06 * away;
        default: // blur
          offset = depth == 0
              ? Offset((incoming ? dir * 26 : -dir * 18) * away, 0)
              : Offset(0, (incoming ? depth * 22.0 : -depth * 8.0) * away);
          scale = incoming ? 1 + 0.03 * away : 1 - 0.04 * away;
          sigma = blur * away;
      }
      Widget out = Opacity(opacity: p.clamp(0.0, 1.0), child: child);
      if (scale != 1) out = Transform.scale(scale: scale, child: out);
      if (offset != Offset.zero) out = Transform.translate(offset: offset, child: out);
      if (sigma > 0.2) {
        out = ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.decal),
          child: out,
        );
      }
      return IgnorePointer(ignoring: !incoming, child: out);
    },
  );
}

// ------------------------------------------------------------------ edge fade

/// Content fades and softens into the bottom edge behind the nav bar
/// (DESIGN.md §5.4, the stacked-strip version).
class _BottomFade extends StatelessWidget {
  const _BottomFade({required this.visible});
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    final h = 128 + MediaQuery.viewPaddingOf(context).bottom;
    const strips = 4;
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 220),
        child: SizedBox(
          height: h,
          child: Stack(
            children: [
              for (var i = 0; i < strips; i++)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: h * (strips - i) / strips,
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 1.5 + i * 1.2, sigmaY: 1.5 + i * 1.2),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      stops: const [0, 0.2, 0.4, 0.6, 0.8, 1],
                      colors: [0.82, 0.62, 0.38, 0.17, 0.05, 0.0]
                          .map((a) => c.bg.withValues(alpha: a))
                          .toList(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ nav bar

class TabMeta {
  const TabMeta(this.label, this.icon, this.iconSelected);
  final String label;
  final IconData icon;
  final IconData iconSelected;
}

const tabMeta = <String, TabMeta>{
  'library': TabMeta('Library', PhosphorIconsRegular.books, PhosphorIconsFill.books),
  'add': TabMeta('Add', PhosphorIconsRegular.plusCircle, PhosphorIconsFill.plusCircle),
  'words': TabMeta('Words', PhosphorIconsRegular.cards, PhosphorIconsFill.cards),
  'stats': TabMeta('Stats', PhosphorIconsRegular.chartBar, PhosphorIconsFill.chartBar),
  'settings': TabMeta('Settings', PhosphorIconsRegular.gearSix, PhosphorIconsFill.gearSix),
};

class _NavBar extends StatefulWidget {
  const _NavBar();

  @override
  State<_NavBar> createState() => _NavBarState();
}

class _NavBarState extends State<_NavBar> with SingleTickerProviderStateMixin {
  static const slot = 58.0;
  static const fab = 64.0;

  late final AnimationController _move = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
    value: 1,
  );
  int _from = 0;
  int _to = 0;
  int? _scrub;
  bool _lifted = false;

  @override
  void dispose() {
    _move.dispose();
    super.dispose();
  }

  List<String> get _tabs => context.appRead.visibleTabs;

  /// Leading edge x of a tab slot, accounting for the centre button gap.
  double _slotX(int i, int count, bool withFab) {
    final half = count ~/ 2;
    var x = i * slot;
    if (withFab && i >= half) x += fab;
    return x;
  }

  void _animateTo(int i) {
    if (i == _to && _move.isCompleted) return;
    _from = _currentIndex();
    _to = i;
    if (Motion.reduced(context)) {
      _move.value = 1;
    } else {
      _move.forward(from: 0);
    }
  }

  int _currentIndex() => _move.value >= 1 ? _to : (_move.value < 0.5 ? _from : _to);

  int? _indexAt(double dx, int count, bool withFab) {
    for (var i = 0; i < count; i++) {
      final x = _slotX(i, count, withFab);
      if (dx >= x && dx < x + slot) return i;
    }
    return null;
  }

  void _openTab(String tab) {
    final app = context.appRead;
    if (app.route == tab) return;
    app.go(tab);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final c = context.sc;
    final s = app.settings;
    final tabs = _tabs;
    final withFab = s.showCenterButton;
    final width = tabs.length * slot + (withFab ? fab : 0);
    final selected = tabs.indexOf(app.lastTab);
    final target = _scrub ?? selected;
    if (target >= 0 && target != _to) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _animateTo(target);
      });
    }
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    const height = 74.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(18, 0, 18, 18 + bottom),
      child: Center(
        heightFactor: 1,
        child: Semantics(
          container: true,
          label: 'Navigation',
          child: GlassSurface(
            radius: 28,
            sigma: 16,
            child: SizedBox(
              height: height,
              width: width + 16,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragStart: (d) {
                  final i = _indexAt(d.localPosition.dx - 8, tabs.length, withFab);
                  if (i == null) return;
                  setState(() {
                    _lifted = true;
                    _scrub = i;
                  });
                },
                onHorizontalDragUpdate: (d) {
                  if (!_lifted) return;
                  final i = _indexAt(d.localPosition.dx - 8, tabs.length, withFab);
                  if (i != null && i != _scrub) {
                    Haptic.selection();
                    setState(() => _scrub = i);
                  }
                },
                onHorizontalDragEnd: (_) {
                  if (!_lifted) return;
                  final i = _scrub;
                  setState(() {
                    _lifted = false;
                    _scrub = null;
                  });
                  if (i != null) _openTab(tabs[i]);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Directionality(
                    // Always LTR so the centre button and muscle memory hold.
                    textDirection: TextDirection.ltr,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        if (selected >= 0 || _scrub != null)
                          AnimatedBuilder(
                            animation: _move,
                            builder: (context, _) => _pill(c, tabs.length, withFab, height),
                          ),
                        for (var i = 0; i < tabs.length; i++)
                          Positioned(
                            left: _slotX(i, tabs.length, withFab),
                            top: 0,
                            bottom: 0,
                            width: slot,
                            child: _NavItem(
                              meta: tabMeta[tabs[i]]!,
                              selected: (_scrub ?? selected) == i,
                              lifted: _lifted && _scrub == i,
                              showLabel: s.showLabels,
                              onTap: () => _openTab(tabs[i]),
                            ),
                          ),
                        if (withFab)
                          Positioned(
                            left: _slotX(tabs.length ~/ 2, tabs.length, false),
                            width: fab,
                            top: 0,
                            bottom: 0,
                            child: const Center(child: _ContinueButton()),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pill(SeferColors c, int count, bool withFab, double height) {
    final t = _move.value;
    final fromX = _slotX(_from.clamp(0, count - 1), count, withFab);
    final toX = _slotX(_to.clamp(0, count - 1), count, withFab);
    final forward = toX >= fromX;
    // The leading edge moves first and the trailing edge catches up, so the
    // pill stretches like a droplet (DESIGN.md §8.5).
    final lead = Curves.easeOutCubic.transform(t);
    final trail = Curves.easeInOutCubic.transform(t);
    final left = lerpDouble(fromX, toX, forward ? trail : lead)!;
    final right = lerpDouble(fromX + slot, toX + slot, forward ? lead : trail)!;
    final squash = 1 - 0.14 * sin(pi * t) * ((toX - fromX).abs() > 0 ? 1 : 0);
    final grow = _lifted ? 6.0 : 0.0;
    final pillH = (height - 18) * squash;
    final alpha = (c.isDark ? 0.10 : 0.07) * (_lifted ? 2.4 : 1);
    return Positioned(
      left: left + 4 - grow,
      width: right - left - 8 + grow * 2,
      top: (height - pillH) / 2,
      height: pillH,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: const Cubic(0.3, 1.25, 0.5, 1),
        decoration: BoxDecoration(
          color: c.text.withValues(alpha: alpha),
          borderRadius: BorderRadius.circular(100),
          border: _lifted ? Border.all(color: Colors.white.withValues(alpha: 0.16)) : null,
          boxShadow: _lifted
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.28), blurRadius: 22, offset: const Offset(0, 8))]
              : null,
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.meta,
    required this.selected,
    required this.lifted,
    required this.showLabel,
    required this.onTap,
  });

  final TabMeta meta;
  final bool selected;
  final bool lifted;
  final bool showLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    final color = selected ? c.text : c.textTertiary;
    return Semantics(
      button: true,
      selected: selected,
      label: meta.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Haptic.selection();
          onTap();
        },
        child: AnimatedScale(
          scale: lifted ? 1.06 : 1,
          duration: const Duration(milliseconds: 200),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TweenAnimationBuilder<Color?>(
                tween: ColorTween(end: color),
                duration: const Duration(milliseconds: 300),
                builder: (_, col, _) => Icon(selected ? meta.iconSelected : meta.icon, size: 22, color: col),
              ),
              if (showLabel) ...[
                const SizedBox(height: 4),
                SizedBox(
                  width: 54,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      style: AppTheme.s(9.5, weight: FontWeight.w600, color: color),
                      child: Text(meta.label, maxLines: 1),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The centre button: one tap continues the story you were reading; a long
/// press lists recent ones. With an empty library it opens the Add tab.
class _ContinueButton extends StatelessWidget {
  const _ContinueButton();

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    final app = context.app;
    final story = app.continueStory;
    return Semantics(
      button: true,
      label: story == null ? 'Add a text' : 'Continue reading ${story.title}',
      excludeSemantics: true,
      child: Pressable(
        scale: 0.9,
        onTap: () {
          Haptic.medium();
          if (story == null) {
            app.go('add');
          } else {
            app.openStory(story);
          }
        },
        onLongPress: () {
          Haptic.medium();
          _recentSheet(context);
        },
        child: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [c.accent, c.brass],
            ),
            boxShadow: [BoxShadow(color: c.accent.withValues(alpha: 0.45), blurRadius: 18, offset: const Offset(0, 6))],
          ),
          child: Icon(
            story == null ? PhosphorIconsBold.plus : PhosphorIconsFill.bookOpenText,
            size: 22,
            color: c.bg,
          ),
        ),
      ),
    );
  }

  void _recentSheet(BuildContext context) {
    final app = context.appRead;
    final recent = app.stories.where((s) => s.lastOpenedAt != null).toList()
      ..sort((a, b) => b.lastOpenedAt!.compareTo(a.lastOpenedAt!));
    showAppSheet<void>(
      context,
      (ctx) => SheetBody(
        title: 'Continue reading',
        subtitle: recent.isEmpty ? 'Nothing opened yet' : null,
        children: [
          if (recent.isEmpty)
            PrimaryButton(
              label: 'Add a text',
              onTap: () {
                Navigator.pop(ctx);
                app.go('add');
              },
            ),
          for (final s in recent.take(6))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Pressable(
                scale: 0.98,
                onTap: () {
                  Navigator.pop(ctx);
                  app.openStory(s);
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: ctx.sc.bgRaised2, borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 44,
                        height: 58,
                        child: StoryCover(
                          cover: s.cover,
                          title: s.title,
                          imagePath: s.cover.imagePath == null ? null : app.coverPath(s.cover.imagePath!),
                          radius: 8,
                          showTitle: false,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.f(14.5, weight: FontWeight.w700, color: ctx.sc.text)),
                            const SizedBox(height: 3),
                            Text('${(s.progress * 100).round()}% read', style: AppTheme.f(12, weight: FontWeight.w500, color: ctx.sc.textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
