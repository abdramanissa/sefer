import 'dart:convert';

import 'ai.dart';
import 'languages.dart';

abstract final class Translators {
  static const off = 'off';
  static const deepl = 'deepl';
  static const google = 'google';
  static const ai = 'ai';

  static const names = {off: 'Off', deepl: 'DeepL', google: 'Google Translate', ai: 'Your AI model'};
}

/// Translates words and sentences with DeepL, Google Translate or the AI
/// model. Like the generator, it refuses to connect while the internet
/// switch is off, and only the text being translated is sent.
class Translator {
  Translator({required this.internet, required this.service, required this.key, this.ai, this.aiModel = '', this.transport});

  final bool internet;
  final String service;
  final String key;

  /// Used when [service] is [Translators.ai].
  final AiClient? ai;
  final String aiModel;
  final Transport? transport;

  static final Map<String, String> _cache = {};

  bool get enabled => service != Translators.off;

  /// Translates [text] from [from] into [to]. For a single word, [context]
  /// (its sentence) helps the AI model pick the right sense.
  Future<String> translate(String text, {required String from, required String to, String? context}) async {
    if (!enabled) throw AiException('Choose a translation service in Profile → Internet & AI.');
    if (!internet) throw AiException('Internet is off. Turn it on in Profile → Internet & AI.');
    final t = text.trim();
    if (t.isEmpty) return '';
    final cacheKey = '$service|$from|$to|$t|${context ?? ''}';
    final hit = _cache[cacheKey];
    if (hit != null) return hit;
    final out = switch (service) {
      Translators.deepl => await _deepl(t, from, to),
      Translators.google => await _google(t, from, to),
      _ => await _ai(t, from, to, context),
    };
    return _cache[cacheKey] = out.trim();
  }

  void _needKey(String name) {
    if (key.trim().isEmpty) throw AiException('Add your $name key in Profile → Internet & AI.');
  }

  static String _deeplTarget(String code) => switch (code) {
    'en' => 'EN-US',
    'pt' => 'PT-PT',
    'zh' => 'ZH-HANS',
    _ => code.toUpperCase(),
  };

  Future<String> _deepl(String text, String from, String to) async {
    _needKey('DeepL');
    // Free keys end in ":fx" and use their own host.
    final host = key.trim().endsWith(':fx') ? 'api-free.deepl.com' : 'api.deepl.com';
    Future<(int, String)> call(bool withSource) => AiClient.send(
      'POST',
      Uri.https(host, '/v2/translate'),
      {'Authorization': 'DeepL-Auth-Key ${key.trim()}'},
      jsonEncode({
        'text': [text],
        'target_lang': _deeplTarget(to),
        if (withSource && from != 'und') 'source_lang': from.split('-').first.toUpperCase(),
      }),
      transport: transport,
      timeout: const Duration(seconds: 30),
    );
    var (status, body) = await call(true);
    // DeepL doesn't take every source language; let it detect instead.
    if (status == 400) (status, body) = await call(false);
    if (status != 200) throw AiException(AiClient.errorOf(status, body));
    final list = (jsonDecode(body) as Map)['translations'] as List? ?? const [];
    if (list.isEmpty) throw AiException('DeepL sent no translation.');
    return '${(list.first as Map)['text']}';
  }

  Future<String> _google(String text, String from, String to) async {
    _needKey('Google Translate');
    final (status, body) = await AiClient.send(
      'POST',
      Uri.https('translation.googleapis.com', '/language/translate/v2', {'key': key.trim()}),
      const {},
      jsonEncode({'q': text, 'target': to, if (from != 'und') 'source': from, 'format': 'text'}),
      transport: transport,
      timeout: const Duration(seconds: 30),
    );
    if (status != 200) throw AiException(AiClient.errorOf(status, body));
    final list = ((jsonDecode(body) as Map)['data'] as Map?)?['translations'] as List? ?? const [];
    if (list.isEmpty) throw AiException('Google sent no translation.');
    return '${(list.first as Map)['translatedText']}';
  }

  Future<String> _ai(String text, String from, String to, String? context) async {
    final client = ai;
    if (client == null) throw AiException('Set up an AI model in Profile → Internet & AI.');
    final single = !text.contains(RegExp(r'\s'));
    final user = single && context != null
        ? 'Word: $text\nSentence: $context\nGive its meaning here in ${languageName(to)}, in one to four words.'
        : 'Translate from ${languageName(from)} into ${languageName(to)}:\n$text';
    final reply = await client.complete(
      model: aiModel,
      system: 'You are a translator for language learners. Reply with the translation only: no quotes, notes or alternatives.',
      user: user,
      json: false,
    );
    return reply.trim().replaceAll(RegExp(r'^["“«]|["”»]$'), '');
  }
}
