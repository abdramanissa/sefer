import 'package:flutter/foundation.dart';

import 'ai.dart';
import 'importer.dart';
import 'prompt.dart';

/// A story being generated. It lives with the app state rather than a
/// screen, so leaving the generator doesn't lose the answer.
class Generation extends ChangeNotifier {
  bool busy = false;
  DateTime? startedAt;
  String? error;
  ImportResult? result;
  int _run = 0;

  int get elapsed => startedAt == null ? 0 : DateTime.now().difference(startedAt!).inSeconds;

  Future<void> start({required AiClient client, required String model, required GenOptions options}) async {
    final run = ++_run;
    busy = true;
    error = null;
    result = null;
    startedAt = DateTime.now();
    notifyListeners();
    try {
      final p = buildPrompt(options);
      final reply = await client.complete(model: model, system: p.system, user: p.user);
      if (run != _run) return;
      final r = importText(extractJson(reply));
      if (r.stories.isEmpty) {
        error = 'The answer could not be read as stories. ${r.problems.join(' ')}';
      } else {
        for (final s in r.stories) {
          if (s.language == 'und') s.language = options.language;
          if (!s.tags.contains(options.level)) s.tags.add(options.level);
        }
        result = r;
      }
    } on AiException catch (e) {
      if (run == _run) error = e.message;
    } catch (e) {
      if (run == _run) error = 'Something went wrong: $e';
    } finally {
      if (run == _run) {
        busy = false;
        notifyListeners();
      }
    }
  }

  void cancel() {
    _run++;
    busy = false;
    notifyListeners();
  }

  /// Forgets the last answer or error.
  void clear() {
    result = null;
    error = null;
    notifyListeners();
  }
}
