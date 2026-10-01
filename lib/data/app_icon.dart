import 'package:flutter/services.dart';

/// Switches the launcher icon (see the activity aliases in
/// AndroidManifest.xml and MainActivity.kt).
abstract final class AppIcon {
  static const _channel = MethodChannel('sefer/app_icon');

  /// Icon id → (name, letter).
  static const all = {
    'aleph': ('Aleph', 'א'),
    'bet': ('Bet', 'ב'),
    'lamed': ('Lamed', 'ל'),
    'tav': ('Tav', 'ת'),
    'omega': ('Omega', 'Ω'),
    'pe': ('Pe', 'پ'),
    'ko': ('Ko kai', 'ก'),
    'de': ('De', 'Д'),
    'eszett': ('Eszett', 'ß'),
    'eacute': ('É', 'É'),
    'q': ('Q', 'Q'),
    'ani': ('Ani', 'ა'),
    'hiragana': ('A', 'あ'),
    'hangul': ('Han', '한'),
    'devanagari': ('A', 'अ'),
  };

  /// Returns false where icons can't be switched (tests, other platforms).
  static Future<bool> set(String id) async {
    try {
      await _channel.invokeMethod<void>('set', {'name': id});
      return true;
    } catch (_) {
      // No platform side (tests, other platforms) or the switch failed.
      return false;
    }
  }
}
