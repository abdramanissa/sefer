import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'app_state.dart';
import 'importer.dart';
import 'models.dart';

/// Fonts you bring yourself (for example SF Hebrew, which can't be bundled):
/// the file is copied into the app's storage and registered with the engine
/// under its own family name.
class UserFonts {
  UserFonts._();

  static final Set<String> _loaded = {};

  static Future<void> _register(CustomFont f, Uint8List bytes) async {
    if (_loaded.contains(f.family)) return;
    final loader = FontLoader(f.family)..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
    _loaded.add(f.family);
  }

  static void _refreshList(AppState app) {
    userFonts = [
      for (final f in app.settings.customFonts)
        ReaderFont(f.id, f.name, f.family, 'Your font', FontGroup.custom),
    ];
  }

  /// Registers every imported font. Call once after the state loads.
  static Future<void> loadAll(AppState app) async {
    for (final f in app.settings.customFonts) {
      final bytes = await app.store.readBytes('fonts/${f.file}');
      if (bytes != null) await _register(f, bytes);
    }
    _refreshList(app);
  }

  /// Adds a font from a .ttf or .otf file. Returns null when the file isn't a
  /// font the engine can read.
  static Future<CustomFont?> add(AppState app, String fileName, Uint8List bytes) async {
    if (!_looksLikeFont(bytes)) return null;
    final id = newId();
    final ext = fileName.toLowerCase().endsWith('.otf') ? 'otf' : 'ttf';
    final name = fileName.replaceAll(RegExp(r'\.(ttf|otf)$', caseSensitive: false), '').replaceAll(RegExp(r'[-_]+'), ' ').trim();
    final font = CustomFont(id: id, name: name.isEmpty ? 'My font' : name, file: '$id.$ext');
    try {
      await _register(font, bytes);
    } catch (_) {
      return null;
    }
    await app.store.writeBytes('fonts/${font.file}', bytes);
    app.updateSettings((s) => s.customFonts.add(font));
    _refreshList(app);
    return font;
  }

  static Future<void> remove(AppState app, CustomFont font) async {
    await app.store.delete('fonts/${font.file}');
    app.updateSettings((s) {
      s.customFonts.removeWhere((f) => f.id == font.id);
      if (s.readerFont == font.id) s.readerFont = 'literata';
      s.fontByLanguage.removeWhere((_, v) => v == font.id);
    });
    _refreshList(app);
  }

  /// TrueType, OpenType (CFF) and TrueType collections.
  static bool _looksLikeFont(Uint8List b) {
    if (b.length < 12) return false;
    final tag = String.fromCharCodes(b.sublist(0, 4));
    return tag == 'OTTO' || tag == 'true' || tag == 'ttcf' || (b[0] == 0 && b[1] == 1 && b[2] == 0 && b[3] == 0);
  }
}
