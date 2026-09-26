import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../data/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/feel.dart';
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

const _navHeight = 70.0;

/// Height the nav takes, so scrolling pages can pad their bottom.
double navClearance(BuildContext context) =>
    _navHeight + 40 + MediaQuery.viewPaddingOf(context).bottom;

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final c = context.sc;
    final feel = context.feel;
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
              Positioned.fill(child: AppBackground(pattern: feel.decor ? app.settings.background : 'none')),
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
        return RouteTransition(
          animation: animation,
          incoming: incoming,
          style: s.transition,
          blur: s.transitionBlur,
          depth: app.moveDepth,
          side: app.moveSide,
          child: child,
        );
      },
      // Each page paints into its own layer, so moving or fading it during a
      // transition doesn't repaint its contents every frame.
      child: KeyedSubtree(key: ValueKey(route), child: RepaintBoundary(child: buildScreen(route))),
    );
  }
}

/// The "rack focus" move (DESIGN.md §8.4): the old page drifts back and out of
/// focus while the new one comes into focus. Tabs move sideways, drilling in
/// and out moves vertically. The style and strength come from settings.
///
/// The wrappers stay in place when the move ends (at identity values), so the
/// page underneath is never torn down and rebuilt.
class RouteTransition extends StatelessWidget {
  const RouteTransition({
    super.key,
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
      // p: 0 → 1 as this page becomes the visible one.
      final double p;
      if (incoming) {
        p = v >= 1 ? 1 : Curves.easeOutCubic.transform(const Interval(0.25, 1).transform(v));
      } else {
        // The outgoing animation runs 1 → 0; it leaves early.
        final q = const Interval(0, 0.7).transform(1 - v);
        p = 1 - Curves.easeInCubic.transform(q);
      }
      final away = 1 - p;
      final rtl = Directionality.of(context) == TextDirection.rtl;
      final dir = (rtl ? -side : side).toDouble();
      var offset = Offset.zero;
      double scale = 1;
      double sigma = 0;
      switch (style) {
        case 'fade':
          break;
        case 'slide':
          final size = MediaQuery.sizeOf(context);
          offset = depth == 0
              ? Offset((incoming ? dir : -dir) * size.width * 0.3 * away, 0)
              : Offset(0, (incoming ? depth : -depth) * size.height * 0.08 * away);
        case 'scale':
          scale = incoming ? 1 + 0.06 * away : 1 - 0.06 * away;
        default: // blur
          offset = depth == 0
              ? Offset((incoming ? dir * 26 : -dir * 18) * away, 0)
              : Offset(0, (incoming ? depth * 22.0 : -depth * 8.0) * away);
          scale = incoming ? 1 + 0.03 * away : 1 - 0.04 * away;
          sigma = blur * away;
      }
      return IgnorePointer(
        ignoring: !incoming,
        child: ImageFiltered(
          enabled: sigma > 0.3,
          imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.decal),
          child: Transform(
            transform: Matrix4.translationValues(offset.dx, offset.dy, 0)..scaleByDouble(scale, scale, 1, 1),
            alignment: Alignment.center,
            child: Opacity(opacity: p.clamp(0.0, 1.0), child: child),
          ),
        ),
      );
    },
  );
}

// ------------------------------------------------------------------ edge fade

/// Content fades into the bottom edge behind the nav bar. A gradient only:
/// stacked blur strips looked nice but re-blurred the page on every scroll
/// frame.
class _BottomFade extends StatelessWidget {
  const _BottomFade({required this.visible});
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    final h = 110 + MediaQuery.viewPaddingOf(context).bottom;
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 220),
        child: SizedBox(
          height: h,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                stops: const [0, 0.25, 0.5, 0.75, 1],
                colors: [0.9, 0.7, 0.4, 0.12, 0.0].map((a) => c.bg.withValues(alpha: a)).toList(),
              ),
            ),
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
  'profile': TabMeta('Profile', PhosphorIconsRegular.userCircle, PhosphorIconsFill.userCircle),
};

class _NavBar extends StatefulWidget {
  const _NavBar();

  @override
  State<_NavBar> createState() => _NavBarState();
}

class _NavBarState extends State<_NavBar> with SingleTickerProviderStateMixin {
  late final AnimationController _move = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
    value: 1,
  );
  int _from = -1;
  int _to = -1;
  int? _scrub;
  bool _lifted = false;

  @override
  void dispose() {
    _move.dispose();
    super.dispose();
  }

  void _animateTo(int i) {
    if (i == _to) return;
    if (_to < 0 || Motion.reduced(context)) {
      _from = _to = i;
      _move.value = 1;
      return;
    }
    _from = _move.value < 0.5 ? _from : _to;
    _to = i;
    _move.forward(from: 0);
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
    final feel = context.feel;
    final s = app.settings;
    final tabs = app.visibleTabs;
    final withFab = s.showCenterButton;
    final docked = s.navStyle == 'docked';
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    final screen = MediaQuery.sizeOf(context).width;

    // The bar spans the screen (up to a comfortable maximum) and every slot
    // shares the width, so adding or removing tabs or the centre button
    // re-spaces everything instead of crowding it.
    const margin = 14.0;
    final outer = docked ? screen : min(screen - margin * 2, 520.0);
    const pad = 8.0;
    final fabW = withFab ? 76.0 : 0.0;
    final slot = (outer - pad * 2 - fabW) / max(1, tabs.length);
    final half = (tabs.length + 1) ~/ 2;
    double slotX(int i) => i * slot + (withFab && i >= half ? fabW : 0);
    int? indexAt(double dx) {
      for (var i = 0; i < tabs.length; i++) {
        final x = slotX(i);
        if (dx >= x && dx < x + slot) return i;
      }
      return null;
    }

    final selected = tabs.indexOf(app.lastTab);
    final target = _scrub ?? selected;
    if (target >= 0 && target != _to) {
      if (_to < 0) {
        _from = _to = target;
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _animateTo(target);
        });
      }
    }

    final bar = SizedBox(
      height: _navHeight,
      width: outer,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: (d) {
          final i = indexAt(d.localPosition.dx - pad);
          if (i == null) return;
          setState(() {
            _lifted = true;
            _scrub = i;
          });
        },
        onHorizontalDragUpdate: (d) {
          if (!_lifted) return;
          final i = indexAt(d.localPosition.dx - pad);
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
          padding: const EdgeInsets.symmetric(horizontal: pad),
          child: Directionality(
            // Always LTR so the centre button and muscle memory hold.
            textDirection: TextDirection.ltr,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (_to >= 0 && _to < tabs.length)
                  AnimatedBuilder(
                    animation: _move,
                    builder: (context, _) => _pill(c, feel, slotX, slot),
                  ),
                for (var i = 0; i < tabs.length; i++)
                  Positioned(
                    left: slotX(i),
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
                    left: half * slot,
                    width: fabW,
                    top: 0,
                    bottom: 0,
                    child: const Center(child: _ContinueButton()),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    return Semantics(
      container: true,
      label: 'Navigation',
      child: docked
          ? GlassSurface(
              radius: 0,
              sigma: 16,
              shadow: false,
              enabled: s.glass,
              child: Padding(padding: EdgeInsets.only(bottom: bottom), child: Center(heightFactor: 1, child: bar)),
            )
          : Padding(
              padding: EdgeInsets.fromLTRB(margin, 0, margin, 14 + bottom),
              child: Center(
                heightFactor: 1,
                child: GlassSurface(radius: feel.r(28), sigma: 16, enabled: s.glass, child: bar),
              ),
            ),
    );
  }

  Widget _pill(SeferColors c, Feel feel, double Function(int) slotX, double slot) {
    const height = _navHeight;
    final t = _move.value;
    final fromX = slotX(_from.clamp(0, 99));
    final toX = slotX(_to);
    final forward = toX >= fromX;
    // The leading edge moves first and the trailing edge catches up, so the
    // pill stretches like a droplet (DESIGN.md §8.5).
    final lead = Curves.easeOutCubic.transform(t);
    final trail = Curves.easeInOutCubic.transform(t);
    final left = lerpDouble(fromX, toX, forward ? trail : lead)!;
    final right = lerpDouble(fromX + slot, toX + slot, forward ? lead : trail)!;
    final squash = 1 - 0.14 * sin(pi * t) * ((toX - fromX).abs() > 0 ? 1 : 0);
    final grow = _lifted ? 6.0 : 0.0;
    final pillH = (height - 16) * squash;
    final alpha = (c.isDark ? 0.10 : 0.07) * (_lifted ? 2.4 : 1);
    final inset = max(4.0, (slot - 76) / 2);
    return Positioned(
      left: left + inset - grow,
      width: max(0, right - left - inset * 2 + grow * 2),
      top: (height - pillH) / 2,
      height: pillH,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: const Cubic(0.3, 1.25, 0.5, 1),
        decoration: BoxDecoration(
          color: c.text.withValues(alpha: alpha),
          borderRadius: BorderRadius.circular(feel.pill(pillH)),
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
                builder: (_, col, _) => Icon(selected ? meta.iconSelected : meta.icon, size: 23, color: col),
              ),
              if (showLabel) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      style: AppTheme.s(10, weight: FontWeight.w600, color: color),
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
