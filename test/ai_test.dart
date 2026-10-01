import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sefer/data/ai.dart';
import 'package:sefer/data/importer.dart';
import 'package:sefer/data/prompt.dart';
import 'package:sefer/data/translate.dart';

void main() {
  group('prompt builder', () {
    test('the backbone parses: stage, six levels, focus options', () {
      final bb = PromptBackbone.instance;
      expect(bb.stage, startsWith('You are an expert writer and educator.'));
      expect(bb.levels.keys, ['A1', 'A2', 'B1', 'B2', 'C1', 'C2']);
      expect(bb.focusOptions('A1'), ['third-person -s', 'be/have', 'can', 'time expressions']);
      expect(bb.reader('C2'), startsWith('understands virtually everything'));
    });

    test('the level picks its block; options add or remove lines', () {
      final o = GenOptions()
        ..language = 'he'
        ..translation = 'en'
        ..level = 'B1'
        ..topic = 'The market'
        ..focus = 'used to'
        ..parts = 3
        ..custom = 'Name the cat Miso.';
      var p = buildPrompt(o);
      expect(p.system, contains('<level id="B1">'));
      expect(p.system, contains('Oxford 3000 A1-B1 words'));
      expect(p.system, isNot(contains('<level id="A2">')));
      expect(p.system, contains('Write in Hebrew'));
      expect(p.system, contains('"transliterations"'));
      expect(p.user, contains('Write a story in Hebrew about: The market.'));
      expect(p.user, contains('3 parts'));
      expect(p.user, contains('Teaching focus: used to.'));
      expect(p.user, contains('nikkud'));
      expect(p.user, contains('Translate every sentence into English.'));
      expect(p.user, contains('4 comprehension questions'));
      expect(p.user, endsWith('Name the cat Miso.'));
      expect(p.full, '${p.system}\n\n${p.user}');

      o
        ..level = 'C2'
        ..translations = false
        ..transliteration = false
        ..quiz = false
        ..custom = ''
        ..retelling = true
        ..child = true
        ..vowelMarks = false;
      p = buildPrompt(o);
      expect(p.system, contains('<level id="C2">'));
      expect(p.system, isNot(contains('"translation": "<its translation>"')));
      expect(p.system, isNot(contains('"quiz"')));
      expect(p.user, isNot(contains('Translate every')));
      expect(p.user, isNot(contains('Transliterate')));
      expect(p.user, contains('first-person retelling'));
      expect(p.user, contains('The reader is a child.'));
      expect(p.user, contains('without vowel marks'));
    });

    test('Latin-script languages get no transliteration', () {
      final p = buildPrompt(GenOptions()..language = 'ca');
      expect(p.system, isNot(contains('transliterations')));
      expect(p.user, isNot(contains('vowel marks')));
      expect(p.user, contains('Write a story in Catalan. Choose the subject yourself.'));
    });

    test('options survive storage', () {
      final o = GenOptions()
        ..level = 'C1'
        ..words = 600
        ..focus = 'inversion'
        ..parts = 2;
      final back = GenOptions.fromJson(jsonDecode(jsonEncode(o.toJson())) as Map<String, dynamic>);
      expect(back.level, 'C1');
      expect(back.words, 600);
      expect(back.focus, 'inversion');
      expect(back.parts, 2);
    });

    test('pulls JSON out of fenced or chatty replies', () {
      expect(extractJson('Here you go:\n```json\n[{"a":1}]\n```\nEnjoy!'), '[{"a":1}]');
      expect(extractJson('Sure! [{"a":1}] Hope it helps.'), '[{"a":1}]');
      expect(extractJson('{"title":"x"}'), '{"title":"x"}');
    });
  });

  group('AI client', () {
    const story = '[{"title":"Hola","language":"es","paragraphs":[{"sentences":[{"text":"Hola."}]}],'
        '"quiz":[{"question":"¿Hola?","type":"yes_no","answer":true}]}]';

    test('refuses to connect while internet is off', () async {
      var called = false;
      final client = AiClient(
        internet: false,
        provider: AiProviders.gemini,
        key: 'k',
        transport: (_, _, _, _) async {
          called = true;
          return (200, '{}');
        },
      );
      await expectLater(client.complete(model: 'm', system: 's', user: 'u'), throwsA(isA<AiException>()));
      await expectLater(client.models(), throwsA(isA<AiException>()));
      expect(called, isFalse);
    });

    test('Gemini request and reply', () async {
      late Uri url;
      late Map<String, String> headers;
      late Map body;
      final client = AiClient(
        internet: true,
        provider: AiProviders.gemini,
        key: ' key123 ',
        transport: (method, u, h, b) async {
          url = u;
          headers = h;
          body = jsonDecode(b!) as Map;
          return (
            200,
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': story},
                    ],
                  },
                  'finishReason': 'STOP',
                },
              ],
            }),
          );
        },
      );
      final reply = await client.complete(model: 'gemini-x', system: 'sys', user: 'usr');
      expect(url.toString(), 'https://generativelanguage.googleapis.com/v1beta/models/gemini-x:generateContent');
      expect(headers['x-goog-api-key'], 'key123');
      expect(body['systemInstruction']['parts'][0]['text'], 'sys');
      expect(body['generationConfig']['responseMimeType'], 'application/json');
      final r = importText(extractJson(reply));
      expect(r.stories.single.quiz.single.answer, 0);
    });

    test('OpenRouter request, reply and errors', () async {
      late Map body;
      var status = 200;
      final client = AiClient(
        internet: true,
        provider: AiProviders.openRouter,
        key: 'sk-or',
        transport: (method, u, h, b) async {
          expect(u.host, 'openrouter.ai');
          expect(h['Authorization'], 'Bearer sk-or');
          body = jsonDecode(b!) as Map;
          if (status != 200) return (status, '{"error":{"message":"Invalid key"}}');
          return (
            200,
            jsonEncode({
              'choices': [
                {
                  'message': {'content': '```json\n$story\n```'},
                  'finish_reason': 'stop',
                },
              ],
            }),
          );
        },
      );
      final reply = await client.complete(model: 'a/b', system: 's', user: 'u');
      expect(body['model'], 'a/b');
      expect(importText(extractJson(reply)).stories, hasLength(1));
      status = 401;
      await expectLater(
        client.complete(model: 'a/b', system: 's', user: 'u'),
        throwsA(isA<AiException>().having((e) => e.message, 'message', 'Invalid key')),
      );
    });

    test('lists models', () async {
      final client = AiClient(
        internet: true,
        provider: AiProviders.gemini,
        key: 'k',
        transport: (_, _, _, _) async => (
          200,
          jsonEncode({
            'models': [
              {'name': 'models/gemini-a', 'displayName': 'Gemini A', 'supportedGenerationMethods': ['generateContent']},
              {'name': 'models/embedding-001', 'supportedGenerationMethods': ['embedContent']},
            ],
          }),
        ),
      );
      final m = await client.models();
      expect(m.map((x) => x.id), ['gemini-a']);
    });
  });

  group('translation', () {
    test('off or offline sends nothing', () async {
      var called = false;
      Future<(int, String)> t(String m, Uri u, Map<String, String> h, String? b) async {
        called = true;
        return (200, '{}');
      }

      final off = Translator(internet: true, service: Translators.off, key: 'k', transport: t);
      final offline = Translator(internet: false, service: Translators.deepl, key: 'k', transport: t);
      await expectLater(off.translate('hola', from: 'es', to: 'en'), throwsA(isA<AiException>()));
      await expectLater(offline.translate('hola', from: 'es', to: 'en'), throwsA(isA<AiException>()));
      expect(called, isFalse);
    });

    test('DeepL: free host, language codes, retry without source', () async {
      final calls = <Map>[];
      final tr = Translator(
        internet: true,
        service: Translators.deepl,
        key: 'abc:fx',
        transport: (m, u, h, b) async {
          expect(u.host, 'api-free.deepl.com');
          expect(h['Authorization'], 'DeepL-Auth-Key abc:fx');
          final body = jsonDecode(b!) as Map;
          calls.add(body);
          if (body.containsKey('source_lang')) return (400, '{"message":"Value for source_lang not supported"}');
          return (200, '{"translations":[{"text":"good morning"}]}');
        },
      );
      expect(await tr.translate('καλημέρα', from: 'el', to: 'en'), 'good morning');
      expect(calls.first['target_lang'], 'EN-US');
      expect(calls.first['source_lang'], 'EL');
      expect(calls.last.containsKey('source_lang'), isFalse);
      // Cached: no second request.
      await tr.translate('καλημέρα', from: 'el', to: 'en');
      expect(calls, hasLength(2));
    });

    test('Google Translate', () async {
      final tr = Translator(
        internet: true,
        service: Translators.google,
        key: 'g',
        transport: (m, u, h, b) async {
          expect(u.queryParameters['key'], 'g');
          expect((jsonDecode(b!) as Map)['target'], 'en');
          return (200, '{"data":{"translations":[{"translatedText":"the cat"}]}}');
        },
      );
      expect(await tr.translate('el gat', from: 'ca', to: 'en'), 'the cat');
    });

    test('AI model gets the sentence for a word, and plain text back', () async {
      late Map body;
      final ai = AiClient(
        internet: true,
        provider: AiProviders.openRouter,
        key: 'k',
        transport: (m, u, h, b) async {
          body = jsonDecode(b!) as Map;
          return (
            200,
            jsonEncode({
              'choices': [
                {
                  'message': {'content': '"bank (of a river)"'},
                },
              ],
            }),
          );
        },
      );
      final tr = Translator(internet: true, service: Translators.ai, key: '', ai: ai, aiModel: 'x/y');
      final out = await tr.translate('riba', from: 'it', to: 'en', context: 'Siamo seduti sulla riba del fiume.');
      expect(out, 'bank (of a river)');
      expect(body.containsKey('response_format'), isFalse);
      expect((body['messages'] as List).last['content'], contains('Sentence: Siamo seduti'));
    });
  });
}
