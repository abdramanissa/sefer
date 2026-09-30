import 'package:flutter/material.dart';

import 'app_colors.dart';

/// A ready-made theme, picked by its id in `Settings.themeMode`.
class ThemePreset {
  const ThemePreset(this.id, this.name, this.brightness, this.colors);
  final String id;
  final String name;
  final Brightness brightness;
  final Map<String, int> colors;

  static final Map<String, SeferColors> _cache = {};

  SeferColors get palette => _cache.putIfAbsent(
    id,
    () => SeferColors.fromBase(brightness, {
      for (final e in colors.entries) e.key: Color(e.value),
    }),
  );
}

/// Popular editor and app palettes, mapped onto Sefer's tokens.
const themePresets = <ThemePreset>[
  ThemePreset('gruvbox', 'Gruvbox', Brightness.dark, {
    'bg': 0xFF282828,
    'bgRaised': 0xFF3C3836,
    'bgRaised2': 0xFF504945,
    'border': 0xFF665C54,
    'text': 0xFFEBDBB2,
    'textSecondary': 0xFFBDAE93,
    'textTertiary': 0xFF928374,
    'ember': 0xFFEBDBB2,
    'onEmber': 0xFF282828,
    'accent': 0xFFFE8019,
    'brass': 0xFFFABD2F,
    'sage': 0xFFB8BB26,
    'info': 0xFF83A598,
    'warn': 0xFFFABD2F,
    'danger': 0xFFFB4934,
  }),
  ThemePreset('gruvbox-light', 'Gruvbox light', Brightness.light, {
    'bg': 0xFFFBF1C7,
    'bgRaised': 0xFFF9F5D7,
    'bgRaised2': 0xFFEBDBB2,
    'border': 0xFFD5C4A1,
    'text': 0xFF3C3836,
    'textSecondary': 0xFF665C54,
    'textTertiary': 0xFF928374,
    'ember': 0xFF3C3836,
    'onEmber': 0xFFFBF1C7,
    'accent': 0xFFAF3A03,
    'brass': 0xFFB57614,
    'sage': 0xFF79740E,
    'info': 0xFF076678,
    'warn': 0xFFB57614,
    'danger': 0xFF9D0006,
  }),
  ThemePreset('catppuccin', 'Catppuccin', Brightness.dark, {
    'bg': 0xFF1E1E2E,
    'bgRaised': 0xFF313244,
    'bgRaised2': 0xFF45475A,
    'border': 0xFF585B70,
    'text': 0xFFCDD6F4,
    'textSecondary': 0xFFA6ADC8,
    'textTertiary': 0xFF7F849C,
    'ember': 0xFFCDD6F4,
    'onEmber': 0xFF1E1E2E,
    'accent': 0xFFCBA6F7,
    'brass': 0xFFF9E2AF,
    'sage': 0xFFA6E3A1,
    'info': 0xFF89B4FA,
    'warn': 0xFFFAB387,
    'danger': 0xFFF38BA8,
  }),
  ThemePreset('nord', 'Nord', Brightness.dark, {
    'bg': 0xFF2E3440,
    'bgRaised': 0xFF3B4252,
    'bgRaised2': 0xFF434C5E,
    'border': 0xFF4C566A,
    'text': 0xFFECEFF4,
    'textSecondary': 0xFFC0C8D6,
    'textTertiary': 0xFF7B88A1,
    'ember': 0xFFECEFF4,
    'onEmber': 0xFF2E3440,
    'accent': 0xFF88C0D0,
    'brass': 0xFFEBCB8B,
    'sage': 0xFFA3BE8C,
    'info': 0xFF81A1C1,
    'warn': 0xFFD08770,
    'danger': 0xFFBF616A,
  }),
  ThemePreset('dracula', 'Dracula', Brightness.dark, {
    'bg': 0xFF282A36,
    'bgRaised': 0xFF343746,
    'bgRaised2': 0xFF44475A,
    'border': 0xFF565A70,
    'text': 0xFFF8F8F2,
    'textSecondary': 0xFFBFBFD0,
    'textTertiary': 0xFF7C86B4,
    'ember': 0xFFF8F8F2,
    'onEmber': 0xFF282A36,
    'accent': 0xFFBD93F9,
    'brass': 0xFFF1FA8C,
    'sage': 0xFF50FA7B,
    'info': 0xFF8BE9FD,
    'warn': 0xFFFFB86C,
    'danger': 0xFFFF5555,
  }),
  // Bright and friendly, in the spirit of Duolingo: green buttons, blue
  // accents, plenty of white.
  ThemePreset('owl', 'Owl', Brightness.light, {
    'bg': 0xFFF7F7F7,
    'bgRaised': 0xFFFFFFFF,
    'bgRaised2': 0xFFE5E5E5,
    'border': 0xFFE5E5E5,
    'text': 0xFF3C3C3C,
    'textSecondary': 0xFF777777,
    'textTertiary': 0xFFAFAFAF,
    'ember': 0xFF58CC02,
    'onEmber': 0xFFFFFFFF,
    'accent': 0xFF1CB0F6,
    'brass': 0xFFFFC800,
    'sage': 0xFF58CC02,
    'info': 0xFF1CB0F6,
    'warn': 0xFFFF9600,
    'danger': 0xFFFF4B4B,
  }),
  ThemePreset('owl-night', 'Owl night', Brightness.dark, {
    'bg': 0xFF131F24,
    'bgRaised': 0xFF1B2B32,
    'bgRaised2': 0xFF2A3B43,
    'border': 0xFF37464F,
    'text': 0xFFF1F7FB,
    'textSecondary': 0xFFA3B4BF,
    'textTertiary': 0xFF6B7F88,
    'ember': 0xFF58CC02,
    'onEmber': 0xFFFFFFFF,
    'accent': 0xFF49C0F8,
    'brass': 0xFFFFC800,
    'sage': 0xFF79D634,
    'info': 0xFF49C0F8,
    'warn': 0xFFFF9600,
    'danger': 0xFFFF4B4B,
  }),
];

ThemePreset? presetById(String id) {
  for (final p in themePresets) {
    if (p.id == id) return p;
  }
  return null;
}
