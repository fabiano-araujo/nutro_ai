import 'package:flutter_test/flutter_test.dart';
import 'package:nutro_ai/services/behavioral_reminder_planner.dart';

void main() {
  const planner = BehavioralReminderPlanner();

  group('meal reminders', () {
    test('uses configured time plus 75 minutes without enough history', () {
      final reminders = planner.plan(
        _context(
          now: DateTime(2026, 7, 10, 7),
          mealSlots: const [
            BehavioralMealSlot(
              id: 'breakfast',
              name: 'Café da manhã',
              order: 0,
              configuredTime: '08:00',
            ),
          ],
        ),
      );

      final reminder = _singleMealReminder(reminders);
      expect(reminder.scheduledAt, DateTime(2026, 7, 10, 9, 15));
      expect(reminder.bodyKey, 'notification_smart_meal_body_configured');
      expect(reminder.arguments['time'], '08:00');
      expect(reminder.payload['mealId'], 'breakfast');
    });

    test('learns the usual time after two days of historical samples', () {
      final reminders = planner.plan(
        _context(
          now: DateTime(2026, 7, 10, 7),
          mealSlots: const [
            BehavioralMealSlot(
              id: 'breakfast',
              name: 'Café da manhã',
              order: 0,
              configuredTime: '07:30',
            ),
          ],
          mealEntries: [
            _entry(2026, 7, 8, 8, 20, 'breakfast'),
            _entry(2026, 7, 9, 8, 40, 'breakfast'),
          ],
        ),
      );

      final reminder = _singleMealReminder(reminders);
      expect(reminder.scheduledAt, DateTime(2026, 7, 10, 9, 45));
      expect(reminder.bodyKey, 'notification_smart_meal_body_habit');
      expect(reminder.arguments['time'], '08:30');
    });

    test('keeps configured fallback when there is only one sample day', () {
      final reminders = planner.plan(
        _context(
          now: DateTime(2026, 7, 10, 7),
          mealSlots: const [
            BehavioralMealSlot(
              id: 'breakfast',
              name: 'Café da manhã',
              order: 0,
              configuredTime: '07:30',
            ),
          ],
          mealEntries: [
            _entry(2026, 7, 9, 8, 40, 'breakfast'),
          ],
        ),
      );

      final reminder = _singleMealReminder(reminders);
      expect(reminder.scheduledAt, DateTime(2026, 7, 10, 8, 45));
      expect(reminder.bodyKey, 'notification_smart_meal_body_configured');
      expect(reminder.arguments['time'], '07:30');
    });

    test('a meal recorded today suppresses only its matching slot', () {
      final reminders = planner.plan(
        _context(
          now: DateTime(2026, 7, 10, 7),
          mealSlots: const [
            BehavioralMealSlot(
              id: 'breakfast',
              name: 'Café da manhã',
              order: 0,
              configuredTime: '08:00',
            ),
            BehavioralMealSlot(
              id: 'lunch',
              name: 'Almoço',
              order: 1,
              configuredTime: '12:00',
            ),
          ],
          mealEntries: [
            _entry(2026, 7, 10, 6, 30, 'breakfast'),
          ],
          hasMealsToday: true,
          daysWithMeals: const {'2026-07-10'},
        ),
      );

      final mealIds = _mealReminders(reminders)
          .map((reminder) => reminder.payload['mealId'])
          .toList();
      expect(mealIds, ['lunch']);
    });

    test('assigns morning and afternoon snacks by time proximity', () {
      final reminders = planner.plan(
        _context(
          now: DateTime(2026, 7, 10, 8),
          mealSlots: const [
            BehavioralMealSlot(
              id: 'morning_snack',
              name: 'Lanche da manhã',
              order: 0,
              configuredTime: '10:00',
            ),
            BehavioralMealSlot(
              id: 'afternoon_snack',
              name: 'Lanche da tarde',
              order: 1,
              configuredTime: '16:00',
            ),
          ],
          mealEntries: [
            for (final day in [7, 8, 9]) ...[
              _entry(2026, 7, day, 9, 50, 'snack'),
              _entry(2026, 7, day, 16, 10, 'snack'),
            ],
          ],
        ),
      );

      final byMealId = {
        for (final reminder in _mealReminders(reminders))
          reminder.payload['mealId']: reminder,
      };
      expect(byMealId.keys, containsAll(['morning_snack', 'afternoon_snack']));
      expect(byMealId['morning_snack']!.arguments['time'], '09:50');
      expect(
        byMealId['morning_snack']!.scheduledAt,
        DateTime(2026, 7, 10, 11, 5),
      );
      expect(byMealId['afternoon_snack']!.arguments['time'], '16:10');
      expect(
        byMealId['afternoon_snack']!.scheduledAt,
        DateTime(2026, 7, 10, 17, 25),
      );
    });

    test('limits reminders to three and prioritizes primary meals', () {
      final reminders = planner.plan(
        _context(
          now: DateTime(2026, 7, 10, 6),
          mealSlots: const [
            BehavioralMealSlot(
              id: 'morning_snack',
              name: 'Lanche da manhã',
              order: 0,
              configuredTime: '10:00',
            ),
            BehavioralMealSlot(
              id: 'breakfast',
              name: 'Café da manhã',
              order: 1,
              configuredTime: '07:00',
            ),
            BehavioralMealSlot(
              id: 'afternoon_snack',
              name: 'Lanche da tarde',
              order: 2,
              configuredTime: '16:00',
            ),
            BehavioralMealSlot(
              id: 'lunch',
              name: 'Almoço',
              order: 3,
              configuredTime: '12:00',
            ),
            BehavioralMealSlot(
              id: 'dinner',
              name: 'Jantar',
              order: 4,
              configuredTime: '19:00',
            ),
          ],
        ),
      );

      final meals = _mealReminders(reminders);
      expect(
          meals, hasLength(BehavioralReminderPlanner.maxMealRemindersPerDay));
      expect(
        meals.map((reminder) => reminder.payload['mealId']).toSet(),
        {'breakfast', 'lunch', 'dinner'},
      );
    });
  });

  group('streak reminder', () {
    test('schedules at 23:00 when every risk condition is satisfied', () {
      final reminders = planner.plan(
        _context(
          now: DateTime(2026, 7, 10, 20),
          currentRegistrationStreak: 2,
          registrationLastDate: DateTime(2026, 7, 9, 12),
        ),
      );

      final reminder = reminders.singleWhere(
        (item) => item.kind == BehavioralReminderKind.streakRisk,
      );
      expect(reminder.scheduledAt, DateTime(2026, 7, 10, 23));
      expect(reminder.arguments['count'], '2');
      expect(reminder.payloadType, 'streak_risk');
    });

    test('requires streak >= 2 and last registration exactly yesterday', () {
      final invalidContexts = [
        _context(
          now: DateTime(2026, 7, 10, 20),
          currentRegistrationStreak: 1,
          registrationLastDate: DateTime(2026, 7, 9),
        ),
        _context(
          now: DateTime(2026, 7, 10, 20),
          currentRegistrationStreak: 2,
          registrationLastDate: DateTime(2026, 7, 10),
        ),
        _context(
          now: DateTime(2026, 7, 10, 20),
          currentRegistrationStreak: 2,
          registrationLastDate: DateTime(2026, 7, 8),
        ),
        _context(
          now: DateTime(2026, 7, 10, 20),
          currentRegistrationStreak: 2,
        ),
      ];

      for (final context in invalidContexts) {
        expect(
          planner
              .plan(context)
              .where((item) => item.kind == BehavioralReminderKind.streakRisk),
          isEmpty,
        );
      }
    });

    test('does not warn after a meal or while the streak is protected', () {
      final baseNow = DateTime(2026, 7, 10, 20);
      final lastDate = DateTime(2026, 7, 9);

      for (final context in [
        _context(
          now: baseNow,
          hasMealsToday: true,
          currentRegistrationStreak: 8,
          registrationLastDate: lastDate,
        ),
        _context(
          now: baseNow,
          currentRegistrationStreak: 8,
          registrationLastDate: lastDate,
          isStreakProtected: true,
        ),
      ]) {
        expect(
          planner
              .plan(context)
              .where((item) => item.kind == BehavioralReminderKind.streakRisk),
          isEmpty,
        );
      }
    });

    test('keeps the streak alert inside the daily notification cap', () {
      final reminders = planner.plan(
        _context(
          now: DateTime(2026, 7, 10, 6),
          mealSlots: const [
            BehavioralMealSlot(
              id: 'breakfast',
              name: 'Café da manhã',
              order: 0,
              configuredTime: '07:00',
            ),
            BehavioralMealSlot(
              id: 'lunch',
              name: 'Almoço',
              order: 1,
              configuredTime: '12:00',
            ),
            BehavioralMealSlot(
              id: 'dinner',
              name: 'Jantar',
              order: 2,
              configuredTime: '19:00',
            ),
          ],
          currentRegistrationStreak: 8,
          registrationLastDate: DateTime(2026, 7, 9),
        ),
      );

      expect(
        reminders,
        hasLength(BehavioralReminderPlanner.maxBehavioralRemindersPerDay),
      );
      expect(_mealReminders(reminders), hasLength(2));
      expect(
        reminders.where(
          (item) => item.kind == BehavioralReminderKind.streakRisk,
        ),
        hasLength(1),
      );
    });
  });

  group('comeback reminder', () {
    test('schedules after two empty days when recent history was active', () {
      final reminders = planner.plan(
        _context(
          now: DateTime(2026, 7, 10, 10),
          horizonDays: 7,
          daysWithMeals: const {
            '2026-07-07',
            '2026-07-06',
            '2026-07-04',
          },
        ),
      );

      final reminder = reminders.singleWhere(
        (item) => item.kind == BehavioralReminderKind.comeback,
      );
      expect(reminder.scheduledAt, DateTime(2026, 7, 10, 18, 30));
      expect(reminder.payloadType, 'comeback_reminder');
      expect(reminders, hasLength(1));
    });

    test('does not schedule without two empty days or active history', () {
      final invalidContexts = [
        _context(
          now: DateTime(2026, 7, 10, 10),
          daysWithMeals: const {
            '2026-07-09',
            '2026-07-07',
            '2026-07-06',
            '2026-07-05',
          },
        ),
        _context(
          now: DateTime(2026, 7, 10, 10),
          daysWithMeals: const {'2026-07-07', '2026-07-06'},
        ),
      ];

      for (final context in invalidContexts) {
        expect(
          planner
              .plan(context)
              .where((item) => item.kind == BehavioralReminderKind.comeback),
          isEmpty,
        );
      }
    });
  });

  test('remote summary without meal details suppresses false alerts today', () {
    final reminders = planner.plan(
      _context(
        now: DateTime(2026, 7, 10, 7),
        mealSlots: const [
          BehavioralMealSlot(
            id: 'breakfast',
            name: 'Café da manhã',
            order: 0,
            configuredTime: '08:00',
          ),
          BehavioralMealSlot(
            id: 'lunch',
            name: 'Almoço',
            order: 1,
            configuredTime: '12:00',
          ),
        ],
        hasMealsToday: true,
        daysWithMeals: const {'2026-07-10'},
        currentRegistrationStreak: 9,
        registrationLastDate: DateTime(2026, 7, 9),
      ),
    );

    expect(reminders, isEmpty);
  });
}

BehavioralReminderContext _context({
  required DateTime now,
  List<BehavioralMealSlot> mealSlots = const [],
  List<BehavioralMealEntry> mealEntries = const [],
  Set<String> daysWithMeals = const {},
  bool hasMealsToday = false,
  int currentRegistrationStreak = 0,
  DateTime? registrationLastDate,
  bool isStreakProtected = false,
  int horizonDays = 1,
}) {
  return BehavioralReminderContext(
    now: now,
    mealSlots: mealSlots,
    mealEntries: mealEntries,
    daysWithMeals: daysWithMeals,
    hasMealsToday: hasMealsToday,
    currentRegistrationStreak: currentRegistrationStreak,
    registrationLastDate: registrationLastDate,
    isStreakProtected: isStreakProtected,
    horizonDays: horizonDays,
  );
}

BehavioralMealEntry _entry(
  int year,
  int month,
  int day,
  int hour,
  int minute,
  String mealType,
) {
  return BehavioralMealEntry(
    recordedAt: DateTime(year, month, day, hour, minute),
    mealType: mealType,
  );
}

List<BehavioralReminder> _mealReminders(
  List<BehavioralReminder> reminders,
) {
  return reminders
      .where((item) => item.kind == BehavioralReminderKind.missedMeal)
      .toList(growable: false);
}

BehavioralReminder _singleMealReminder(
  List<BehavioralReminder> reminders,
) {
  return _mealReminders(reminders).single;
}
