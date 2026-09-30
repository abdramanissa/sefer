import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sefer/data/ai.dart';
import 'package:sefer/data/importer.dart';
import 'package:sefer/data/prompt.dart';

void main() {
  group('prompt builder', () {
    test('every option adds or removes its line', () {
      final o = GenOptions()
        ..language = 'he'
        ..translation = 'en'
        ..level = 'B1'
        ..topic = 'The market'
        ..parts = 3
        ..custom = 'Name the cat Miso.';
      var p = buildPrompt(o).user;
      expect(p, contains('in Hebrew (he) in 3 parts'));
      expect(p, contains('CEFR level B1'));
      expect(p, contains('Topic: The market.'));
      expect(p, contains('nikkud'));
      expect(p, contains('"translation" into English'));
      expect(p, contains('"transliterations"'));
      expect(p, contains('"quiz" of 5'));
      expect(p, contains('Also: Name the cat Miso.'));
      expect(p, contains('"tags" to ["B1", "the market"]'));

      o
        ..translations = false
        ..transliteration = false
        ..quiz = false
        ..custom = ''
        ..vowelMarks = false;
      p = buildPrompt(o).user;
      expect(p, isNot(contains('"translation" into')));
      expect(p, isNot(contains('"transliterations"')));
      expect(p, isNot(contains('"quiz"')));
      expect(p, isNot(contains('Also:')));
      expect(p, contains('without vowel marks'));
    });

    test('Latin-script languages get no transliteration line', () {
      final p = buildPrompt(GenOptions()..language = 'es').user;
      expect(p, isNot(contains('transliterations')));
      expect(p, isNot(contains('vowel marks')));
    });

    test('options survive storage', () {
      final o = GenOptions()
        ..level = 'C1'
        ..quizKinds = {'yes_no'}
        ..parts = 2;
      final back = GenOptions.fromJson(jsonDecode(jsonEncode(o.toJson())) as Map<String, dynamic>);
      expect(back.level, 'C1');
      expect(back.quizKinds, {'yes_no'});
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
}
