import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// A failure worth showing to the person, in plain words.
class AiException implements Exception {
  AiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class AiModel {
  const AiModel(this.id, this.name, {this.note = ''});
  final String id;
  final String name;
  final String note;
}

/// Sends one HTTP request. Replaced in tests; Sefer makes no other network
/// calls than the ones going through here.
typedef Transport = Future<(int, String)> Function(String method, Uri url, Map<String, String> headers, String? body);

abstract final class AiProviders {
  static const gemini = 'gemini';
  static const openRouter = 'openrouter';

  static const names = {gemini: 'Google Gemini', openRouter: 'OpenRouter'};

  static const defaultModels = {gemini: 'gemini-2.5-flash', openRouter: 'google/gemini-2.5-flash'};

  static const keyPages = {
    gemini: 'aistudio.google.com/apikey',
    openRouter: 'openrouter.ai/settings/keys',
  };
}

/// Talks to Gemini or OpenRouter. Every call checks [internet] first, so
/// nothing leaves the device while the switch in settings is off.
class AiClient {
  AiClient({required this.internet, required this.provider, required this.key, this.transport});

  final bool internet;
  final String provider;
  final String key;
  final Transport? transport;

  static const _timeout = Duration(minutes: 3);

  /// Stands in for the network in tests.
  static Transport? debugTransport;

  void _check() {
    if (!internet) throw AiException('Internet is off. Turn it on in Profile → Internet & AI.');
    if (key.trim().isEmpty) throw AiException('Add your ${AiProviders.names[provider]} API key first.');
  }

  Future<(int, String)> _send(String method, Uri url, Map<String, String> headers, [String? body]) =>
      send(method, url, headers, body, transport: transport);

  /// One request through the test stand-in or the real network, with
  /// failures turned into plain words.
  static Future<(int, String)> send(
    String method,
    Uri url,
    Map<String, String> headers,
    String? body, {
    Transport? transport,
    Duration timeout = _timeout,
  }) async {
    final t = transport ?? debugTransport ?? _httpTransport;
    try {
      return await t(method, url, headers, body).timeout(timeout);
    } on TimeoutException {
      throw AiException('${url.host} took too long to answer.');
    } on SocketException {
      throw AiException('Could not reach ${url.host}. Check your connection.');
    } on HandshakeException {
      throw AiException('A secure connection to ${url.host} failed.');
    }
  }

  static Future<(int, String)> _httpTransport(String method, Uri url, Map<String, String> headers, String? body) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
    try {
      final req = await client.openUrl(method, url);
      headers.forEach(req.headers.set);
      if (body != null) {
        final bytes = utf8.encode(body);
        req.headers.contentType = ContentType.json;
        req.contentLength = bytes.length;
        req.add(bytes);
      }
      final res = await req.close();
      final text = await res.transform(utf8.decoder).join();
      return (res.statusCode, text);
    } finally {
      client.close(force: true);
    }
  }

  static String errorOf(int status, String body) {
    try {
      final j = jsonDecode(body);
      final e = j is Map ? j['error'] : null;
      final m = e is Map ? e['message'] : (e is String ? e : null);
      if (m is String && m.isNotEmpty) return m;
    } catch (_) {}
    return switch (status) {
      401 || 403 => 'The API key was refused.',
      402 => 'Your account has no credit left for this model.',
      404 => 'That model was not found.',
      429 => 'Too many requests. Wait a moment and try again.',
      _ => 'The service answered with an error ($status).',
    };
  }

  /// Sends [system] and [user] to [model] and returns the reply's text.
  Future<String> complete({required String model, required String system, required String user, bool json = true}) async {
    _check();
    if (model.trim().isEmpty) throw AiException('Choose a model first.');
    if (provider == AiProviders.gemini) {
      final id = model.startsWith('models/') ? model.substring(7) : model;
      final (status, body) = await _send(
        'POST',
        Uri.https('generativelanguage.googleapis.com', '/v1beta/models/$id:generateContent'),
        {'x-goog-api-key': key.trim()},
        jsonEncode({
          'systemInstruction': {
            'parts': [
              {'text': system},
            ],
          },
          'contents': [
            {
              'role': 'user',
              'parts': [
                {'text': user},
              ],
            },
          ],
          'generationConfig': {if (json) 'responseMimeType': 'application/json', 'temperature': json ? 0.9 : 0.2},
        }),
      );
      if (status != 200) throw AiException(errorOf(status, body));
      final j = jsonDecode(body) as Map;
      final cands = j['candidates'];
      if (cands is! List || cands.isEmpty) {
        final block = (j['promptFeedback'] as Map?)?['blockReason'];
        throw AiException(block != null ? 'The request was blocked ($block).' : 'The model sent no answer.');
      }
      final first = cands.first as Map;
      final parts = ((first['content'] as Map?)?['parts'] as List?) ?? const [];
      final text = parts.whereType<Map>().where((p) => p['thought'] != true).map((p) => p['text'] ?? '').join();
      if (first['finishReason'] == 'MAX_TOKENS') {
        throw AiException('The answer was cut off. Ask for fewer parts or a shorter length.');
      }
      if (text.trim().isEmpty) throw AiException('The model sent an empty answer.');
      return text;
    }
    final (status, body) = await _send(
      'POST',
      Uri.https('openrouter.ai', '/api/v1/chat/completions'),
      {
        'Authorization': 'Bearer ${key.trim()}',
        'X-Title': 'Sefer',
      },
      jsonEncode({
        'model': model,
        'messages': [
          {'role': 'system', 'content': system},
          {'role': 'user', 'content': user},
        ],
        if (json) 'response_format': {'type': 'json_object'},
        'temperature': json ? 0.9 : 0.2,
      }),
    );
    if (status != 200) throw AiException(errorOf(status, body));
    final j = jsonDecode(body) as Map;
    if (j['error'] != null) throw AiException(errorOf(status, body));
    final choices = j['choices'];
    if (choices is! List || choices.isEmpty) throw AiException('The model sent no answer.');
    final choice = choices.first as Map;
    final content = (choice['message'] as Map?)?['content'];
    if (choice['finish_reason'] == 'length') {
      throw AiException('The answer was cut off. Ask for fewer parts or a shorter length.');
    }
    if (content is! String || content.trim().isEmpty) throw AiException('The model sent an empty answer.');
    return content;
  }

  /// The models this key can use for text, best known first.
  Future<List<AiModel>> models() async {
    _check();
    if (provider == AiProviders.gemini) {
      final (status, body) = await _send(
        'GET',
        Uri.https('generativelanguage.googleapis.com', '/v1beta/models', {'pageSize': '1000'}),
        {'x-goog-api-key': key.trim()},
      );
      if (status != 200) throw AiException(errorOf(status, body));
      final list = (jsonDecode(body) as Map)['models'] as List? ?? const [];
      return [
        for (final m in list.whereType<Map>())
          if ((m['supportedGenerationMethods'] as List? ?? const []).contains('generateContent') &&
              '${m['name']}'.contains('gemini'))
            AiModel('${m['name']}'.replaceFirst('models/', ''), '${m['displayName'] ?? m['name']}'),
      ];
    }
    final (status, body) = await _send('GET', Uri.https('openrouter.ai', '/api/v1/models'), {
      'Authorization': 'Bearer ${key.trim()}',
    });
    if (status != 200) throw AiException(errorOf(status, body));
    final list = (jsonDecode(body) as Map)['data'] as List? ?? const [];
    String price(Map m) {
      final p = m['pricing'];
      if (p is! Map) return '';
      final prompt = double.tryParse('${p['prompt']}') ?? 0;
      final out = double.tryParse('${p['completion']}') ?? 0;
      if (prompt == 0 && out == 0) return 'free';
      return '\$${(prompt * 1e6).toStringAsFixed(2)} / \$${(out * 1e6).toStringAsFixed(2)} per M';
    }

    return [
      for (final m in list.whereType<Map>()) AiModel('${m['id']}', '${m['name'] ?? m['id']}', note: price(m)),
    ];
  }
}
