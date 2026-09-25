import 'package:flutter/material.dart';

/// Every colour in the app, reached through `context.sc`.
///
/// Screens never read `Theme.of(context).colorScheme` directly. The extension
/// implements [lerp], so switching theme animates every token.
@immutable
class SeferColors extends ThemeExtension<SeferColors> {
  const SeferColors({
    required this.brightness,
    required this.pageBg,
    required this.bg,
    required this.bgRaised,
    required this.bgRaised2,
    required this.border,
    required this.navBg,
    required this.text,
    required this.textSecondary,
    required this.textTertiary,
    required this.ember,
    required this.emberDeep,
    required this.onEmber,
    required this.emberSoft,
    required this.emberShadow,
    required this.accent,
    required this.accentSoft,
    required this.brass,
    required this.sage,
    required this.sageSoft,
    required this.mutedFill,
    required this.heatEmpty,
    required this.info,
    required this.warn,
    required this.danger,
  });

  final Brightness brightness;
  final Color pageBg;
  final Color bg;
  final Color bgRaised;
  final Color bgRaised2;
  final Color border;
  final Color navBg;
  final Color text;
  final Color textSecondary;
  final Color textTertiary;
  final Color ember;
  final Color emberDeep;
  final Color onEmber;
  final Color emberSoft;
  final Color emberShadow;
  final Color accent;
  final Color accentSoft;
  final Color brass;
  final Color sage;
  final Color sageSoft;
  final Color mutedFill;
  final Color heatEmpty;
  final Color info;
  final Color warn;
  final Color danger;

  bool get isDark => brightness == Brightness.dark;

  static const dark = SeferColors(
    brightness: Brightness.dark,
    pageBg: Color(0xFF0A0908),
    bg: Color(0xFF0A0A0A),
    bgRaised: Color(0xFF1C1C1C),
    bgRaised2: Color(0xFF2B2B2B),
    border: Color(0xFF3E3E3E),
    navBg: Color(0xD90A0A0A),
    text: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF9A9A9A),
    textTertiary: Color(0xFF666666),
    ember: Color(0xFFFFFFFF),
    emberDeep: Color(0xFFD0D0D0),
    onEmber: Color(0xFF0A0A0A),
    emberSoft: Color(0x1AFFFFFF),
    emberShadow: Color(0x80000000),
    accent: Color(0xFFD9A184),
    accentSoft: Color(0x29D9A184),
    brass: Color(0xFFB98F72),
    sage: Color(0xFF8FA377),
    sageSoft: Color(0x298FA377),
    mutedFill: Color(0xFF2A2A2A),
    heatEmpty: Color(0xFF242424),
    info: Color(0xFF7FA8C9),
    warn: Color(0xFFE0B15A),
    danger: Color(0xFFE5674C),
  );

  static const light = SeferColors(
    brightness: Brightness.light,
    pageBg: Color(0xFFFFFEFD),
    bg: Color(0xFFF7F4F0),
    bgRaised: Color(0xFFFFFFFF),
    bgRaised2: Color(0xFFECE8E3),
    border: Color(0xFFE0DBD5),
    navBg: Color(0xF2FFFEFD),
    text: Color(0xFF1A1713),
    textSecondary: Color(0xFF5F574F),
    textTertiary: Color(0xFF8A8179),
    ember: Color(0xFF1A1713),
    emberDeep: Color(0xFF000000),
    onEmber: Color(0xFFFFFFFF),
    emberSoft: Color(0x121A1713),
    emberShadow: Color(0x1F1A1713),
    accent: Color(0xFF9E4E27),
    accentSoft: Color(0x1F9E4E27),
    brass: Color(0xFF8A6B41),
    sage: Color(0xFF3D7A52),
    sageSoft: Color(0x1F3D7A52),
    mutedFill: Color(0xFFE9E4DE),
    heatEmpty: Color(0xFFE7E2DC),
    info: Color(0xFF3268A0),
    warn: Color(0xFF9A6A12),
    danger: Color(0xFFC0392B),
  );

  /// The tokens a user edits in the theme builder. Everything else is derived
  /// from them (see [fromBase]).
  static const editableKeys = <String>[
    'bg',
    'bgRaised',
    'bgRaised2',
    'border',
    'text',
    'textSecondary',
    'textTertiary',
    'ember',
    'onEmber',
    'accent',
    'brass',
    'sage',
    'info',
    'warn',
    'danger',
  ];

  Color byKey(String key) => switch (key) {
    'bg' => bg,
    'bgRaised' => bgRaised,
    'bgRaised2' => bgRaised2,
    'border' => border,
    'text' => text,
    'textSecondary' => textSecondary,
    'textTertiary' => textTertiary,
    'ember' => ember,
    'onEmber' => onEmber,
    'accent' => accent,
    'brass' => brass,
    'sage' => sage,
    'info' => info,
    'warn' => warn,
    'danger' => danger,
    _ => text,
  };

  /// Builds a full palette from the editable tokens, deriving the soft,
  /// shadow and fill variants the same way the built-in palettes do.
  factory SeferColors.fromBase(Brightness b, Map<String, Color> c) {
    final dark = b == Brightness.dark;
    final base = dark ? SeferColors.dark : SeferColors.light;
    Color k(String key) => c[key] ?? base.byKey(key);
    final bg = k('bg');
    final text = k('text');
    final ember = k('ember');
    final accent = k('accent');
    final sage = k('sage');
    return SeferColors(
      brightness: b,
      pageBg: Color.lerp(bg, text, dark ? 0.0 : 0.01)!,
      bg: bg,
      bgRaised: k('bgRaised'),
      bgRaised2: k('bgRaised2'),
      border: k('border'),
      navBg: bg.withValues(alpha: dark ? 0.85 : 0.95),
      text: text,
      textSecondary: k('textSecondary'),
      textTertiary: k('textTertiary'),
      ember: ember,
      emberDeep: Color.lerp(ember, Colors.black, 0.18)!,
      onEmber: k('onEmber'),
      emberSoft: ember.withValues(alpha: dark ? 0.10 : 0.07),
      emberShadow: dark
          ? Colors.black.withValues(alpha: 0.5)
          : text.withValues(alpha: 0.12),
      accent: accent,
      accentSoft: accent.withValues(alpha: dark ? 0.16 : 0.12),
      brass: k('brass'),
      sage: sage,
      sageSoft: sage.withValues(alpha: dark ? 0.16 : 0.12),
      mutedFill: Color.lerp(k('bgRaised2'), bg, 0.1)!,
      heatEmpty: Color.lerp(k('bgRaised2'), bg, 0.3)!,
      info: k('info'),
      warn: k('warn'),
      danger: k('danger'),
    );
  }

  Map<String, Color> get editable => {
    for (final key in editableKeys) key: byKey(key),
  };

  @override
  SeferColors copyWith({Brightness? brightness}) =>
      SeferColors.fromBase(brightness ?? this.brightness, editable);

  @override
  SeferColors lerp(covariant SeferColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return SeferColors(
      brightness: t < 0.5 ? brightness : other.brightness,
      pageBg: l(pageBg, other.pageBg),
      bg: l(bg, other.bg),
      bgRaised: l(bgRaised, other.bgRaised),
      bgRaised2: l(bgRaised2, other.bgRaised2),
      border: l(border, other.border),
      navBg: l(navBg, other.navBg),
      text: l(text, other.text),
      textSecondary: l(textSecondary, other.textSecondary),
      textTertiary: l(textTertiary, other.textTertiary),
      ember: l(ember, other.ember),
      emberDeep: l(emberDeep, other.emberDeep),
      onEmber: l(onEmber, other.onEmber),
      emberSoft: l(emberSoft, other.emberSoft),
      emberShadow: l(emberShadow, other.emberShadow),
      accent: l(accent, other.accent),
      accentSoft: l(accentSoft, other.accentSoft),
      brass: l(brass, other.brass),
      sage: l(sage, other.sage),
      sageSoft: l(sageSoft, other.sageSoft),
      mutedFill: l(mutedFill, other.mutedFill),
      heatEmpty: l(heatEmpty, other.heatEmpty),
      info: l(info, other.info),
      warn: l(warn, other.warn),
      danger: l(danger, other.danger),
    );
  }
}

extension SeferColorsContext on BuildContext {
  SeferColors get sc =>
      Theme.of(this).extension<SeferColors>() ?? SeferColors.dark;
}

String colorToHex(Color c) {
  final v = c.toARGB32();
  return '#${v.toRadixString(16).padLeft(8, '0').toUpperCase()}';
}

Color? hexToColor(String? s) {
  if (s == null) return null;
  var h = s.trim().replaceFirst('#', '');
  if (h.length == 3) h = h.split('').map((c) => '$c$c').join();
  if (h.length == 6) h = 'FF$h';
  if (h.length != 8) return null;
  final v = int.tryParse(h, radix: 16);
  return v == null ? null : Color(v);
}
