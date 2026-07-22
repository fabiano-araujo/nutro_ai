import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutro_ai/services/storage_service.dart';
import 'package:nutro_ai/utils/ai_interaction_helper.dart';
import 'package:nutro_ai/widgets/message_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('stream completion preserves regenerated card identity metadata',
      (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (builderContext) {
            context = builderContext;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final notifier = MessageNotifier();
    final timestamp = DateTime(2026, 7, 8, 9, 30);
    final messages = <Map<String, dynamic>>[
      {
        'isUser': true,
        'id': 'usr-1',
        'turnId': 'turn-1',
        'message': 'pao',
        'timestamp': timestamp.subtract(const Duration(seconds: 1)),
      },
      {
        'isUser': false,
        'id': 'msg-card-1',
        'turnId': 'turn-1',
        'replyToMessageId': 'usr-1',
        'timestamp': timestamp,
        'notifier': notifier,
        'replaceExistingMeals': true,
        'regenerationRevision': 2,
      },
    ];
    final completed = Completer<void>();

    AIInteractionHelper.handleAIStream(
      context: context,
      aiStream: Stream<String>.value('nova resposta'),
      messageNotifier: notifier,
      messages: messages,
      streamingMessageIndex: 1,
      storageService: StorageService(),
      currentConversationId: 'conversation-1',
      studyItemType: 'chat_message',
      toolDataJson: '{"toolName":"Test","sourceType":"test","userInput":"pao"}',
      setLoading: (_) {},
      setConversationId: (_) {},
      setStreamingIndex: (_) {},
      setProcessingMedia: (_) {},
      onStreamComplete: completed.complete,
    );

    await completed.future.timeout(const Duration(seconds: 5));

    expect(messages[1]['message'], 'nova resposta');
    expect(messages[1]['id'], 'msg-card-1');
    expect(messages[1]['turnId'], 'turn-1');
    expect(messages[1]['replyToMessageId'], 'usr-1');
    expect(messages[1]['replaceExistingMeals'], isTrue);
    expect(messages[1]['regenerationRevision'], 2);
    expect(messages[1].containsKey('notifier'), isFalse);
  });
}
