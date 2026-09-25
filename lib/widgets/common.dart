import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../app/app_shell.dart';
import '../data/app_state.dart';
import '../data/languages.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'motion.dart';
import 'ui_kit.dart';

/// A scrolling page with the standard gutters (DESIGN.md §4.3): 20 px sides,
/// the status bar on top and room for the floating nav at the bottom.
class PageScroll extends StatefulWidget {
  const PageScroll({super.key, required this.id, required this.children, this.rise = true, this.nav = true});
  final String id;
  final List<Widget> children;
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
    return RiseScope(
      id: widget.id,
      child: ListView(
        key: PageStorageKey(widget.id),
        padding: EdgeInsets.fromLTRB(
          20,
          top + 14,
          20,
          widget.nav ? navClearance(context) : 32 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        children: widget.rise ? riseAll(widget.children) : widget.children,
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

/// Shown in tab headers when Settings isn't one of the nav tabs.
class SettingsAction extends StatelessWidget {
  const SettingsAction({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    if (app.visibleTabs.contains('settings')) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 4),
      child: RoundBtn(icon: PhosphorIconsRegular.gearSix, label: 'Settings', onTap: () => app.go('settings')),
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
