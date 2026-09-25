import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

// ------------------------------------------------------------------ helpers

/// Haptics graded by importance (DESIGN.md §9). Turned off in settings.
class Haptic {
  Haptic._();
  static bool enabled = true;
  static void selection() => enabled ? HapticFeedback.selectionClick() : null;
  static void light() => enabled ? HapticFeedback.lightImpact() : null;
  static void medium() => enabled ? HapticFeedback.mediumImpact() : null;
  static void heavy() => enabled ? HapticFeedback.heavyImpact() : null;
}

/// Set from settings; combined with the platform's reduce-motion flag.
class Motion {
  Motion._();
  static bool forceReduce = false;
  static bool reduced(BuildContext context) =>
      forceReduce || (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
}

/// "HELLO WORLD" → "Hello world". Short tokens and anything with digits are
/// left alone (DESIGN.md §2.6).
String titleCase(String s) {
  if (s.isEmpty || s != s.toUpperCase() || s == s.toLowerCase()) return s;
  if ((s.length <= 4 && !s.contains(' ')) || RegExp(r'\d').hasMatch(s)) return s;
  return s[0] + s.substring(1).toLowerCase();
}

EdgeInsets sheetPad(BuildContext context) => EdgeInsets.fromLTRB(
  20,
  12,
  20,
  28 + MediaQuery.viewPaddingOf(context).bottom + MediaQuery.viewInsetsOf(context).bottom,
);

// ------------------------------------------------------------------ Pressable

/// Squish-on-press feedback used instead of ripples (DESIGN.md §8.2).
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.965,
    this.haptic = false,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final bool haptic;
  final HitTestBehavior behavior;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapUp: enabled ? (_) => _set(false) : null,
      onTapCancel: enabled ? () => _set(false) : null,
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptic) Haptic.selection();
              widget.onTap!();
            },
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: Duration(milliseconds: _down ? 90 : 260),
        curve: _down ? Curves.easeOut : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}

// ------------------------------------------------------------------ buttons

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
    this.height = 56,
    this.color,
    this.textColor,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final double height;
  final Color? color;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    final fg = textColor ?? c.onEmber;
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: Opacity(
        opacity: onTap == null ? 0.45 : 1,
        child: Pressable(
          onTap: onTap,
          haptic: true,
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: color ?? c.ember,
              borderRadius: BorderRadius.circular(100),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 22),
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 17, color: fg),
                    const SizedBox(width: 9),
                  ],
                  Text(
                    titleCase(label),
                    style: AppTheme.f(15.5, color: fg, letterSpacing: 0.2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GhostButton extends StatelessWidget {
  const GhostButton({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
    this.color,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? color;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    final fg = color ?? c.text;
    return Semantics(
      button: true,
      child: Opacity(
        opacity: onTap == null ? 0.45 : 1,
        child: Pressable(
          onTap: onTap,
          haptic: true,
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: c.bgRaised2,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: color ?? c.ember),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    titleCase(label),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.f(13.5, color: fg),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.label,
    this.onTap,
    this.onLongPress,
    this.icon,
    this.bg,
    this.fg,
    this.selected = false,
    this.dense = false,
  });

  final String label;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final IconData? icon;
  final Color? bg;
  final Color? fg;
  final bool selected;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    final background = bg ?? (selected ? c.ember : c.bgRaised2);
    final foreground = fg ?? (selected ? c.onEmber : c.textSecondary);
    return Semantics(
      button: onTap != null,
      selected: selected,
      child: Pressable(
        onTap: onTap,
        onLongPress: onLongPress,
        scale: 0.94,
        haptic: true,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(horizontal: dense ? 11 : 14, vertical: dense ? 6 : 8),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: dense ? 11 : 12, color: foreground),
                const SizedBox(width: 5),
              ],
              Text(
                titleCase(label),
                style: AppTheme.f(dense ? 12 : 13, weight: FontWeight.w600, color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RoundBtn extends StatelessWidget {
  const RoundBtn({
    super.key,
    required this.icon,
    this.onTap,
    this.filled = false,
    this.size = 36,
    this.label,
    this.color,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool filled;
  final double size;
  final String? label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    return Semantics(
      button: true,
      label: label,
      child: Pressable(
        onTap: onTap,
        scale: 0.9,
        haptic: true,
        child: SizedBox(
          width: size < 44 ? 44 : size,
          height: size < 44 ? 44 : size,
          child: Center(
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: filled ? c.ember : c.bgRaised,
                shape: BoxShape.circle,
                border: filled ? null : Border.all(color: c.border),
              ),
              child: Icon(
                icon,
                size: size * 0.45,
                color: color ?? (filled ? c.onEmber : c.text),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ surfaces

class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 20,
    this.color,
    this.borderColor,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? c.bgRaised,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? c.border.withValues(alpha: 0.6)),
      ),
      child: child,
    );
    return onTap == null ? box : Pressable(onTap: onTap, scale: 0.975, child: box);
  }
}

/// The small uppercase label above headings and stats (DESIGN.md §2.5).
class Kicker extends StatelessWidget {
  const Kicker(this.text, {super.key, this.color, this.size = 10.5, this.spacing = 1.4});
  final String text;
  final Color? color;
  final double size;
  final double spacing;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: AppTheme.f(
      size,
      weight: FontWeight.w700,
      color: color ?? context.sc.textTertiary,
      letterSpacing: spacing,
    ),
  );
}

class ScreenTitle extends StatelessWidget {
  const ScreenTitle(this.title, {super.key, this.subtitle, this.size = 22});
  final String title;
  final String? subtitle;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          titleCase(title),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTheme.f(size, weight: FontWeight.w800, color: c.text),
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.f(12.5, weight: FontWeight.w500, color: c.textSecondary),
          ),
        ],
      ],
    );
  }
}

/// Back button, title and trailing actions for pages below a tab.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Row(
      children: [
        if (onBack != null) ...[
          RoundBtn(
            icon: rtl ? PhosphorIconsBold.caretRight : PhosphorIconsBold.caretLeft,
            onTap: onBack,
            label: 'Back',
          ),
          const SizedBox(width: 6),
        ],
        Expanded(child: ScreenTitle(title, subtitle: subtitle, size: 20)),
        ...actions,
      ],
    );
  }
}

/// Top of a tab: a kicker over a big title, with actions on the right.
class TabHeader extends StatelessWidget {
  const TabHeader({super.key, required this.kicker, required this.title, this.actions = const []});
  final String kicker;
  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Kicker(kicker),
            const SizedBox(height: 4),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.f(28, weight: FontWeight.w800, color: context.sc.text),
            ),
          ],
        ),
      ),
      ...actions,
    ],
  );
}

class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {super.key, this.onTap, this.trailing});
  final String title;
  final VoidCallback? onTap;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final row = Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.f(19, color: c.text),
          ),
        ),
        if (trailing != null)
          Text(trailing!, style: AppTheme.f(12.5, weight: FontWeight.w600, color: c.textTertiary)),
        if (onTap != null) ...[
          const SizedBox(width: 6),
          Icon(
            rtl ? PhosphorIconsBold.caretLeft : PhosphorIconsBold.caretRight,
            size: 14,
            color: c.textTertiary,
          ),
        ],
      ],
    );
    return onTap == null ? row : Pressable(onTap: onTap, scale: 0.98, child: row);
  }
}

// ------------------------------------------------------------------ controls

class TinySwitch extends StatelessWidget {
  const TinySwitch({super.key, required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    return Semantics(
      toggled: value,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Haptic.selection();
          onChanged(!value);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: 44,
            height: 26,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: value ? c.ember : c.bgRaised2,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: value ? c.ember : c.border),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOutCubic,
              alignment: value ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: value ? c.onEmber : c.textTertiary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SegToggle<T> extends StatelessWidget {
  const SegToggle({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.expand = false,
  });

  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    Widget seg(MapEntry<T, String> e) {
      final sel = e.key == value;
      final child = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (sel) return;
          Haptic.selection();
          onChanged(e.key);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: sel ? c.ember : Colors.transparent,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(
            e.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.f(12, weight: FontWeight.w600, color: sel ? c.onEmber : c.textSecondary),
          ),
        ),
      );
      final seg = Semantics(selected: sel, button: true, child: child);
      return expand ? Expanded(child: seg) : seg;
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: c.bgRaised2, borderRadius: BorderRadius.circular(100)),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: options.entries.map(seg).toList(),
      ),
    );
  }
}

class StepperControl extends StatelessWidget {
  const StepperControl({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 100,
    this.step = 1,
    this.format,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;
  final double step;
  final String Function(double v)? format;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    Widget btn(IconData icon, double delta) {
      final next = double.parse((value + delta).clamp(min, max).toStringAsFixed(2));
      final enabled = next != value;
      return Pressable(
        onTap: enabled
            ? () {
                Haptic.selection();
                onChanged(next);
              }
            : null,
        scale: 0.9,
        child: SizedBox(
          width: 40,
          height: 44,
          child: Center(
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: c.bgRaised2, borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 14, color: enabled ? c.text : c.textTertiary),
            ),
          ),
        ),
      );
    }

    final text = format?.call(value) ??
        (value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(1));
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        btn(PhosphorIconsBold.minus, -step),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 44),
          child: Text(text, textAlign: TextAlign.center, style: AppTheme.d(16, color: c.text)),
        ),
        btn(PhosphorIconsBold.plus, step),
      ],
    );
  }
}

class SearchField extends StatefulWidget {
  const SearchField({super.key, required this.onChanged, this.hint = 'Search', this.initial = ''});
  final ValueChanged<String> onChanged;
  final String hint;
  final String initial;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  late final _ctl = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    return Container(
      height: 48,
      padding: const EdgeInsetsDirectional.only(start: 16, end: 8),
      decoration: BoxDecoration(color: c.bgRaised, borderRadius: BorderRadius.circular(100)),
      child: Row(
        children: [
          Icon(PhosphorIconsRegular.magnifyingGlass, size: 16, color: c.textTertiary),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _ctl,
              onChanged: (v) {
                setState(() {});
                widget.onChanged(v);
              },
              style: AppTheme.f(14, weight: FontWeight.w500, color: c.text),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: widget.hint,
                hintStyle: AppTheme.f(14, weight: FontWeight.w500, color: c.textTertiary),
              ),
            ),
          ),
          if (_ctl.text.isNotEmpty)
            Semantics(
              button: true,
              label: 'Clear search',
              child: GestureDetector(
                onTap: () {
                  _ctl.clear();
                  setState(() {});
                  widget.onChanged('');
                },
                child: SizedBox(
                  width: 36,
                  height: 44,
                  child: Center(
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(color: c.bgRaised2, shape: BoxShape.circle),
                      child: Icon(PhosphorIconsBold.x, size: 10, color: c.textSecondary),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A text field in the app's style: a filled soft rectangle, no border.
class AppField extends StatelessWidget {
  const AppField({
    super.key,
    required this.controller,
    this.hint,
    this.label,
    this.maxLines = 1,
    this.minLines,
    this.onChanged,
    this.textDirection,
    this.style,
    this.autofocus = false,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String? hint;
  final String? label;
  final int? maxLines;
  final int? minLines;
  final ValueChanged<String>? onChanged;
  final TextDirection? textDirection;
  final TextStyle? style;
  final bool autofocus;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Padding(padding: const EdgeInsetsDirectional.only(start: 4), child: Kicker(label!)),
          const SizedBox(height: 8),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(color: c.bgRaised2, borderRadius: BorderRadius.circular(16)),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            minLines: minLines,
            autofocus: autofocus,
            onChanged: onChanged,
            keyboardType: keyboardType,
            textDirection: textDirection,
            style: style ?? AppTheme.f(14.5, weight: FontWeight.w500, color: c.text, height: 1.4),
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              hintText: hint,
              hintStyle: AppTheme.f(14.5, weight: FontWeight.w500, color: c.textTertiary),
            ),
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ groups

/// A rounded group of rows separated by inset dividers.
class ToolGroup extends StatelessWidget {
  const ToolGroup({super.key, required this.children, this.color, this.radius = 20});
  final List<Widget> children;
  final Color? color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        items.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(height: 1, color: c.border.withValues(alpha: 0.5)),
        ));
      }
      items.add(children[i]);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: ColoredBox(
        color: color ?? c.bgRaised,
        child: Column(mainAxisSize: MainAxisSize.min, children: items),
      ),
    );
  }
}

/// A settings row: icon, label, then a control or value with a caret.
class ToolRow extends StatelessWidget {
  const ToolRow({
    super.key,
    this.icon,
    required this.label,
    this.detail,
    this.value,
    this.trailing,
    this.onTap,
    this.danger = false,
    this.minHeight = 52,
  });

  final IconData? icon;
  final String label;
  final String? detail;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool danger;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final color = danger ? c.danger : c.text;
    final row = ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            if (icon != null) ...[
              SizedBox(width: 22, child: Icon(icon, size: 19, color: danger ? c.danger : c.textSecondary)),
              const SizedBox(width: 13),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: AppTheme.f(14.5, weight: FontWeight.w500, color: color)),
                  if (detail != null) ...[
                    const SizedBox(height: 2),
                    Text(detail!, style: AppTheme.f(12, weight: FontWeight.w500, color: c.textTertiary, height: 1.3)),
                  ],
                ],
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: Text(
                  value!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.f(13, weight: FontWeight.w600, color: c.textSecondary),
                ),
              ),
            ],
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            if (onTap != null && trailing == null) ...[
              const SizedBox(width: 6),
              Icon(rtl ? PhosphorIconsBold.caretLeft : PhosphorIconsBold.caretRight, size: 14, color: c.textTertiary),
            ],
          ],
        ),
      ),
    );
    return onTap == null
        ? row
        : Pressable(onTap: onTap, scale: 0.985, child: row);
  }
}

class OptionItem<T> {
  const OptionItem(this.value, this.label, {this.icon, this.detail, this.danger = false});
  final T value;
  final String label;
  final IconData? icon;
  final String? detail;
  final bool danger;
}

/// The standard picker inside sheets (DESIGN.md §7.2).
class OptionGroup<T> extends StatelessWidget {
  const OptionGroup({super.key, required this.items, required this.selected, required this.onSelect});
  final List<OptionItem<T>> items;
  final T? selected;
  final ValueChanged<T> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    return ToolGroup(
      color: c.bgRaised2,
      radius: 18,
      children: [
        for (final it in items)
          Semantics(
            selected: it.value == selected,
            button: true,
            child: Pressable(
              scale: 0.985,
              onTap: () {
                Haptic.selection();
                onSelect(it.value);
              },
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 50),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      if (it.icon != null) ...[
                        Icon(it.icon, size: 18, color: it.danger ? c.danger : (it.value == selected ? c.ember : c.textSecondary)),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              it.label,
                              style: AppTheme.f(
                                14.5,
                                weight: it.value == selected ? FontWeight.w800 : FontWeight.w600,
                                color: it.danger ? c.danger : (it.value == selected ? c.ember : c.text),
                              ),
                            ),
                            if (it.detail != null) ...[
                              const SizedBox(height: 2),
                              Text(it.detail!, style: AppTheme.f(12, weight: FontWeight.w500, color: c.textSecondary)),
                            ],
                          ],
                        ),
                      ),
                      if (it.value == selected)
                        Icon(PhosphorIconsFill.checkCircle, size: 20, color: c.ember),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ------------------------------------------------------------------ sheets

const double kSheetBlur = 14;

class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(color: context.sc.bgRaised2, borderRadius: BorderRadius.circular(2)),
    ),
  );
}

class SheetTitle extends StatelessWidget {
  const SheetTitle(this.title, {super.key, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    return Column(
      children: [
        Text(title, textAlign: TextAlign.center, style: AppTheme.f(17, color: c.text)),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: AppTheme.f(12, weight: FontWeight.w500, color: c.textSecondary),
          ),
        ],
      ],
    );
  }
}

class _BlurBarrier extends StatelessWidget {
  const _BlurBarrier({required this.animation, required this.scrim, required this.onTap});
  final Animation<double> animation;
  final double scrim;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: animation,
    builder: (context, _) {
      final t = Curves.easeOut.transform(animation.value);
      final scrimBox = ColoredBox(color: Colors.black.withValues(alpha: scrim * t));
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: t < 0.3 || Motion.reduced(context)
            ? scrimBox
            : BackdropFilter(
                filter: ImageFilter.blur(sigmaX: kSheetBlur * t, sigmaY: kSheetBlur * t),
                child: scrimBox,
              ),
      );
    },
  );
}

class _SheetRoute<T> extends PopupRoute<T> {
  _SheetRoute({required this.builder, required this.capturedThemes, this.scrollable = false});
  final WidgetBuilder builder;
  final CapturedThemes capturedThemes;
  final bool scrollable;

  @override
  Color? get barrierColor => null;
  @override
  bool get barrierDismissible => true;
  @override
  String? get barrierLabel => 'Close';
  @override
  Duration get transitionDuration => const Duration(milliseconds: 380);
  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 260);

  @override
  Widget buildModalBarrier() => _BlurBarrier(
    animation: animation!,
    scrim: 0.32,
    onTap: () => navigator?.maybePop(),
  );

  @override
  Widget buildPage(BuildContext context, Animation<double> a, Animation<double> b) {
    final c = context.sc;
    final maxH = MediaQuery.sizeOf(context).height * 0.9;
    final content = capturedThemes.wrap(Builder(builder: builder));
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH, maxWidth: 640),
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: c.bgRaised,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: content,
          ),
        ),
      ),
    );
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> a, Animation<double> b, Widget child) {
    if (Motion.reduced(context)) return child;
    final curved = CurvedAnimation(parent: a, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    return SlideTransition(
      position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(curved),
      child: child,
    );
  }
}

/// Opens a bottom sheet with the blurred barrier. [builder] should return the
/// sheet's content; wrap it in [SheetBody] for the standard padding and handle.
Future<T?> showAppSheet<T>(BuildContext context, WidgetBuilder builder) {
  final nav = Navigator.of(context);
  return nav.push(
    _SheetRoute<T>(
      builder: builder,
      capturedThemes: InheritedTheme.capture(from: context, to: nav.context),
    ),
  );
}

/// Standard sheet layout: handle, title, scrolling content.
class SheetBody extends StatelessWidget {
  const SheetBody({super.key, this.title, this.subtitle, required this.children, this.footer});
  final String? title;
  final String? subtitle;
  final List<Widget> children;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final pad = sheetPad(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(pad.left, pad.top, pad.right, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetHandle(),
          const SizedBox(height: 18),
          if (title != null) ...[SheetTitle(title!, subtitle: subtitle), const SizedBox(height: 18)],
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(bottom: footer == null ? pad.bottom : 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
          if (footer != null) Padding(padding: EdgeInsets.only(bottom: pad.bottom), child: footer),
        ],
      ),
    );
  }
}

class _DialogRoute<T> extends PopupRoute<T> {
  _DialogRoute({required this.builder, required this.capturedThemes});
  final WidgetBuilder builder;
  final CapturedThemes capturedThemes;

  @override
  Color? get barrierColor => null;
  @override
  bool get barrierDismissible => true;
  @override
  String? get barrierLabel => 'Close';
  @override
  Duration get transitionDuration => const Duration(milliseconds: 320);
  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 200);

  @override
  Widget buildModalBarrier() => _BlurBarrier(
    animation: animation!,
    scrim: 0.36,
    onTap: () => navigator?.maybePop(),
  );

  @override
  Widget buildPage(BuildContext context, Animation<double> a, Animation<double> b) {
    final c = context.sc;
    return Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(28, 24, 28, 24 + MediaQuery.viewInsetsOf(context).bottom),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: c.bgRaised, borderRadius: BorderRadius.circular(26)),
              child: capturedThemes.wrap(Builder(builder: builder)),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> a, Animation<double> b, Widget child) {
    if (Motion.reduced(context)) return child;
    final curved = CurvedAnimation(parent: a, curve: Curves.easeOutBack, reverseCurve: Curves.easeInCubic);
    return FadeTransition(
      opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
      child: ScaleTransition(scale: Tween(begin: 0.92, end: 1.0).animate(curved), child: child),
    );
  }
}

Future<T?> showAppDialog<T>(BuildContext context, WidgetBuilder builder) {
  final nav = Navigator.of(context);
  return nav.push(
    _DialogRoute<T>(builder: builder, capturedThemes: InheritedTheme.capture(from: context, to: nav.context)),
  );
}

class DialogAction extends StatelessWidget {
  const DialogAction(this.label, {super.key, required this.onTap, this.primary = false, this.danger = false});
  final String label;
  final VoidCallback onTap;
  final bool primary;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    final color = danger ? c.danger : (primary ? c.accent : c.textSecondary);
    return Pressable(
      onTap: onTap,
      scale: 0.94,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Text(
          titleCase(label),
          style: AppTheme.f(14, weight: primary || danger ? FontWeight.w700 : FontWeight.w600, color: color),
        ),
      ),
    );
  }
}

class AppDialogBody extends StatelessWidget {
  const AppDialogBody({super.key, required this.title, this.body, this.content, required this.actions});
  final String title;
  final String? body;
  final Widget? content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: AppTheme.f(19, weight: FontWeight.w800, color: c.text)),
        if (body != null) ...[
          const SizedBox(height: 10),
          Text(body!, style: AppTheme.f(13.5, weight: FontWeight.w500, color: c.textSecondary, height: 1.45)),
        ],
        if (content != null) ...[const SizedBox(height: 16), content!],
        const SizedBox(height: 16),
        Wrap(alignment: WrapAlignment.end, children: actions),
      ],
    );
  }
}

/// The one confirm pattern: a neutral cancel and a named action.
Future<bool> askConfirm(
  BuildContext context, {
  required String title,
  String? body,
  required String action,
  bool danger = false,
}) async {
  final r = await showAppDialog<bool>(
    context,
    (ctx) => AppDialogBody(
      title: title,
      body: body,
      actions: [
        DialogAction('Cancel', onTap: () => Navigator.pop(ctx, false)),
        DialogAction(action, primary: !danger, danger: danger, onTap: () => Navigator.pop(ctx, true)),
      ],
    ),
  );
  return r ?? false;
}

Future<String?> askText(
  BuildContext context, {
  required String title,
  String initial = '',
  String hint = '',
  String action = 'Save',
  int maxLines = 1,
}) {
  final ctl = TextEditingController(text: initial);
  return showAppDialog<String>(
    context,
    (ctx) => AppDialogBody(
      title: title,
      content: AppField(controller: ctl, hint: hint, autofocus: true, maxLines: maxLines),
      actions: [
        DialogAction('Cancel', onTap: () => Navigator.pop(ctx)),
        DialogAction(action, primary: true, onTap: () => Navigator.pop(ctx, ctl.text.trim())),
      ],
    ),
  );
}

/// Picks one option from a list in a sheet.
Future<T?> pickOption<T>(
  BuildContext context, {
  required String title,
  String? subtitle,
  required List<OptionItem<T>> items,
  T? selected,
  String? hint,
}) => showAppSheet<T>(
  context,
  (ctx) => SheetBody(
    title: title,
    subtitle: subtitle,
    children: [
      OptionGroup<T>(items: items, selected: selected, onSelect: (v) => Navigator.pop(ctx, v)),
      if (hint != null) ...[
        const SizedBox(height: 14),
        Text(
          hint,
          textAlign: TextAlign.center,
          style: AppTheme.f(11.5, weight: FontWeight.w500, color: ctx.sc.textTertiary),
        ),
      ],
    ],
  ),
);

/// A labelled slider row for settings.
class SliderRow extends StatelessWidget {
  const SliderRow({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
    this.format,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;
  final String Function(double)? format;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: AppTheme.f(14.5, weight: FontWeight.w500, color: c.text))),
              Text(
                format?.call(value) ?? value.toStringAsFixed(value < 10 ? 1 : 0),
                style: AppTheme.d(13, weight: FontWeight.w600, color: c.textSecondary),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
              overlayShape: SliderComponentShape.noOverlay,
            ),
            child: SizedBox(
              height: 36,
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                divisions: divisions,
                onChanged: (v) {
                  if (divisions != null) Haptic.selection();
                  onChanged(v);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty-state block: a big quiet icon, a title and a hint.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.body, this.action});
  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 12),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: c.bgRaised, shape: BoxShape.circle),
            child: Icon(icon, size: 30, color: c.textTertiary),
          ),
          const SizedBox(height: 18),
          Text(title, textAlign: TextAlign.center, style: AppTheme.f(19, weight: FontWeight.w800, color: c.text)),
          if (body != null) ...[
            const SizedBox(height: 8),
            Text(
              body!,
              textAlign: TextAlign.center,
              style: AppTheme.f(13.5, weight: FontWeight.w500, color: c.textSecondary, height: 1.45),
            ),
          ],
          if (action != null) ...[const SizedBox(height: 22), action!],
        ],
      ),
    );
  }
}
