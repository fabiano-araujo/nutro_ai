import 'package:flutter_test/flutter_test.dart';
import 'package:nutro_ai/services/streak_service.dart';

void main() {
  test('parses a protected comeback check-in event', () {
    final event = StreakCheckInEvent.fromJson({
      'id': 42,
      'checkInDate': '2026-08-13',
      'previousStreak': 8,
      'currentStreak': 9,
      'protectedMissedDate': '2026-08-12',
      'freezesUsed': 1,
      'freezesRecovered': 1,
      'freezesEarned': 0,
      'freezesBefore': 1,
      'freezesAfter': 1,
    });

    expect(event.id, 42);
    expect(event.currentStreak, 9);
    expect(event.checkInDate, DateTime(2026, 8, 13));
    expect(event.protectedMissedDate, DateTime(2026, 8, 12));
    expect(event.freezeRecovered, isTrue);
    expect(event.freezesAfter, 1);
  });

  test('parses a regular increment without a freeze page', () {
    final event = StreakCheckInEvent.fromJson({
      'id': 43,
      'checkInDate': '2026-08-14',
      'previousStreak': 9,
      'currentStreak': 10,
      'protectedMissedDate': null,
      'freezesUsed': 0,
      'freezesRecovered': 0,
      'freezesEarned': 0,
      'freezesBefore': 1,
      'freezesAfter': 1,
    });

    expect(event.currentStreak, 10);
    expect(event.protectedMissedDate, isNull);
    expect(event.freezeRecovered, isFalse);
  });
}
