import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:nutro_ai/i18n/translations/en_us_translations.dart';
import 'package:nutro_ai/services/ai_service.dart';

class _MockStreamClient extends http.BaseClient {
  _MockStreamClient(this.events);

  final List<Map<String, dynamic>> events;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final requestBody = await request.finalize().transform(utf8.decoder).join();
    print('🟡 Mock client recebeu body: $requestBody');

    final controller = StreamController<List<int>>();

    Future<void>(() async {
      for (final event in events) {
        final payload = 'data: ${jsonEncode(event)}\n\n';
        controller.add(utf8.encode(payload));
        print('🟡 Mock client enviou: $payload');
        await Future.delayed(const Duration(milliseconds: 20));
      }
      await controller.close();
    });

    return http.StreamedResponse(
      controller.stream,
      200,
      headers: {'content-type': 'text/event-stream'},
    );
  }
}

class _MockErrorClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream.value(
        utf8.encode(jsonEncode({'error': 'Falha interna em português'})),
      ),
      500,
      headers: {'content-type': 'application/json'},
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AIService processa stream SSE mockada', () async {
    final mockClient = _MockStreamClient([
      {'status': 'conectado', 'connectionId': 'mock-123'},
      {
        'text':
            '{"date":"2024-01-01","totalNutrition":{"calories":1800,"protein":120,"carbs":180,"fat":60},"meals":['
      },
      {
        'text':
            '{"type":"breakfast","time":"08:00","name":"Café Proteico","foods":[{"name":"Iogurte","emoji":"🥛","amount":200,"unit":"g","calories":150,"protein":15,"carbs":10,"fat":5}],"mealTotals":{"calories":150,"protein":15,"carbs":10,"fat":5}}]}'
      },
      {'done': true},
    ]);

    final service = AIService(httpClient: mockClient);

    final stream = service.getAnswerStream(
      'Teste mock de dieta.',
      languageCode: 'pt_BR',
      quality: 'bom',
      userId: '1',
      agentType: 'diet',
      provider: 'Hyperbolic',
    );

    final buffer = StringBuffer();
    int chunkCount = 0;

    await for (final chunk in stream) {
      chunkCount++;
      print('🟢 Teste recebeu chunk #$chunkCount: "$chunk"');
      buffer.write(chunk);
    }

    final result = buffer.toString();
    print('🟢 Resultado final (${result.length} chars): $result');

    expect(result.contains('"date":"2024-01-01"'), isTrue);
    expect(chunkCount, greaterThanOrEqualTo(3));
  });

  test('AIService localiza erro sem expor mensagem crua do servidor', () async {
    final service = AIService(httpClient: _MockErrorClient());

    final chunks = await service
        .getAnswerStream(
          'Test request',
          languageCode: 'en_US',
          agentType: 'nutrition',
        )
        .toList();

    expect(chunks, [enUSTranslations['process_error']]);
    expect(chunks.single, isNot(contains('Falha interna')));
  });
}
