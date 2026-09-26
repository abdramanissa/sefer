import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../app/app_shell.dart';
import '../data/app_state.dart';
import '../data/languages.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/feel.dart';
import 'motion.dart';
import 'ui_kit.dart';

/// A scrolling page with the feel's gutters, the status bar on top and room
/// for the floating nav at the bottom. [children] are laid out in a list;
/// [slivers] follow them and are built lazily (long grids and lists).
class PageScroll extends StatefulWidget {
  const PageScroll({
    super.key,
    required this.id,
    required this.children,
    this.slivers = const [],
    this.rise = true,
    this.nav = true,
  });
  final String id;
  final List<Widget> children;
  final List<Widget> slivers;
  final bool rise;
  final bool nav;

  @override
  State<PageScroll> createState() => _PageScrollState();
}

class _PageScrollState extends State<PageScroll> {
  @override
  void dispose() {
    RiseScope.markPlayed(widget.id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.viewPaddingOf(context).top;
    final g = context.feel.gutter;
    final bottom = widget.nav ? navClearance(context) : 32 + MediaQuery.viewPaddingOf(context).bottom;
    return RiseScope(
      id: widget.id,
      child: CustomScrollView(
        key: PageStorageKey(widget.id),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(g, top + 14, g, widget.slivers.isEmpty ? bottom : 0),
            sliver: SliverList(
              delegate: SliverChildListDelegate(widget.rise ? riseAll(widget.children) : widget.children),
            ),
          ),
          for (final s in widget.slivers) SliverPadding(padding: EdgeInsets.symmetric(horizontal: g), sliver: s),
          if (widget.slivers.isNotEmpty) SliverToBoxAdapter(child: SizedBox(height: bottom)),
        ],
      ),
    );
  }
}

/// Copper flame and the current daily streak.
class StreakPill extends StatelessWidget {
  const StreakPill({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final c = context.sc;
    final n = app.dailyStreak;
    return Semantics(
      label: '$n day streak',
      button: true,
      excludeSemantics: true,
      child: Pressable(
        scale: 0.94,
        onTap: () => app.go('stats'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: c.bgRaised, borderRadius: BorderRadius.circular(100)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(PhosphorIconsFill.flame, size: 16, color: n > 0 ? c.accent : c.textTertiary),
              const SizedBox(width: 5),
              RollingText('$n', style: AppTheme.f(14, weight: FontWeight.w800, color: c.text)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The active language as a pill; tap to switch. Shown in tab headers when
/// you study more than one language.
class LanguagePill extends StatelessWidget {
  const LanguagePill({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final c = context.sc;
    final langs = app.knownLanguages;
    final active = app.activeLanguage;
    if (active == null || langs.length < 2) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: Semantics(
        button: true,
        label: 'Language: ${languageName(active)}. Tap to switch.',
        excludeSemantics: true,
        child: Pressable(
          scale: 0.94,
          onTap: () async {
            final v = await pickOption<String>(
              context,
              title: 'Studying now',
              subtitle: app.scoped ? 'Only this language shows in the app' : null,
              selected: active,
              items: [for (final l in langs) OptionItem(l, languageName(l), detail: languageByCode(l)?.native)],
            );
            if (v != null) app.setActiveLanguage(v);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: c.bgRaised, borderRadius: BorderRadius.circular(context.feel.pill(34))),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(active.toUpperCase(), style: AppTheme.f(13, weight: FontWeight.w800, color: c.text, letterSpacing: 0.6)),
                const SizedBox(width: 4),
                Icon(PhosphorIconsBold.caretDown, size: 11, color: c.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LangBadge extends StatelessWidget {
  const LangBadge(this.code, {super.key, this.full = false});
  final String code;
  final bool full;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: c.emberSoft, borderRadius: BorderRadius.circular(100)),
      child: Text(
        full ? languageName(code) : code.toUpperCase(),
        style: AppTheme.f(10, weight: FontWeight.w800, color: c.textSecondary, letterSpacing: full ? 0 : 0.8),
      ),
    );
  }
}

class ThinProgress extends StatelessWidget {
  const ThinProgress({super.key, required this.value, this.color, this.height = 4});
  final double value;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: ColoredBox(
          color: c.bgRaised2,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: FractionallySizedBox(
              widthFactor: value.clamp(0.0, 1.0),
              heightFactor: 1,
              child: ColoredBox(color: color ?? c.accent),
            ),
          ),
        ),
      ),
    );
  }
}

/// A stat: big number over a tiny uppercase caption.
class StatValue extends StatelessWidget {
  const StatValue({super.key, required this.value, required this.label, this.unit, this.roll = true});
  final String value;
  final String label;
  final String? unit;
  final bool roll;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    final style = AppTheme.f(23, weight: FontWeight.w800, color: c.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          textDirection: TextDirection.ltr,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            roll ? RollingText(value, style: style) : Text(value, style: style),
            if (unit != null) ...[
              const SizedBox(width: 3),
              Text(unit!, style: AppTheme.f(11, weight: FontWeight.w600, color: c.textSecondary)),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Kicker(label, size: 9.5, spacing: 1.2),
      ],
    );
  }
}
