import 'package:flutter_test/flutter_test.dart';
import 'package:nutro_ai/services/daily_chat_sync_service.dart';
import 'package:nutro_ai/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final storage = StorageService();
  final service = DailyChatSyncService.instance;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service.clearAuth();
  });

  tearDown(() {
    service.clearAuth();
  });

  test('does not restore stale server chat over local deletion marker',
      () async {
    const key = 'nutrition_chat_user_1_2026-07-08';
    await storage.saveData(key, {
      'messages': <Map<String, dynamic>>[],
      'deleted': true,
      'deletedAt': '2026-07-08T13:00:00.000Z',
      'updatedAt': '2026-07-08T13:00:00.000Z',
    });

    await service.restoreFromServer({
      '2026-07-08': {
        'messages': [
          _msg(true, 'Goiaba', '2026-07-08T12:00:00.000Z'),
          _msg(false, '{"foods":[]}', '2026-07-08T12:00:01.000Z'),
        ],
      },
    }, scope: 'user_1');

    final data = await storage.getData(key);
    expect(data?['deleted'], isTrue);
    expect(data?['messages'], isEmpty);
  });

  test('builds snapshot from newest scope instead of longest conversation',
      () async {
    await storage.saveData('nutrition_chat_guest_2026-07-08', {
      'messages': [
        _msg(true, 'Goiaba', '2026-07-08T10:00:00.000Z'),
        _msg(false, '68 kcal', '2026-07-08T10:00:01.000Z'),
        _msg(true, 'Pao', '2026-07-08T10:01:00.000Z'),
        _msg(false, '80 kcal', '2026-07-08T10:01:01.000Z'),
      ],
    });
    await storage.saveData('nutrition_chat_user_1_2026-07-08', {
      'messages': [
        _msg(true, 'peito de frango com mamao', '2026-07-08T13:00:00.000Z'),
        _msg(false, '304 kcal', '2026-07-08T13:00:01.000Z'),
      ],
    });

    final snapshot = await service.buildSnapshotForDates(['2026-07-08']);
    final messages = (snapshot['2026-07-08'] as Map)['messages'] as List;

    expect(messages, hasLength(2));
    expect(messages.first['message'], 'peito de frango com mamao');
  });

  test('includes local deletion marker in date snapshot', () async {
    await storage.saveData('nutrition_chat_user_1_2026-07-08', {
      'messages': <Map<String, dynamic>>[],
      'deleted': true,
      'deletedAt': '2026-07-08T13:00:00.000Z',
      'updatedAt': '2026-07-08T13:00:00.000Z',
    });

    final snapshot = await service.buildSnapshotForDates(['2026-07-08']);
    final day = snapshot['2026-07-08'] as Map;

    expect(day['deleted'], isTrue);
    expect(day['messages'], isEmpty);
  });
}

Map<String, dynamic> _msg(bool isUser, String message, String timestamp) {
  return {
    'isUser': isUser,
    'message': message,
    'timestamp': timestamp,
  };
}
