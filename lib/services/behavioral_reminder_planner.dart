enum BehavioralReminderKind {
  missedMeal,
  streakRisk,
  comeback,
}

class BehavioralMealSlot {
  const BehavioralMealSlot({
    required this.id,
    required this.name,
    required this.order,
    required this.configuredTime,
  });

  final String id;

  /// Nome já pronto para exibição: localizado para tipos padrão ou definido
  /// pelo usuário para tipos personalizados. O planner é puro e não tem locale.
  final String name;
  final int order;
  final String configuredTime;
}

class BehavioralMealEntry {
  const BehavioralMealEntry({
    required this.recordedAt,
    required this.mealType,
  });

  final DateTime recordedAt;
  final String mealType;
}

class BehavioralReminderContext {
  const BehavioralReminderContext({
    required this.now,
    required this.mealSlots,
    required this.mealEntries,
    required this.daysWithMeals,
    required this.hasMealsToday,
    required this.currentRegistrationStreak,
    required this.isStreakProtected,
    this.registrationLastDate,
    this.horizonDays = BehavioralReminderPlanner.defaultHorizonDays,
  });

  final DateTime now;
  final List<BehavioralMealSlot> mealSlots;
  final List<BehavioralMealEntry> mealEntries;

  /// Datas locais no formato yyyy-MM-dd em que existe ao menos uma refeicao.
  /// Este resumo complementa [mealEntries] quando o servidor carregou apenas
  /// os totais do dia, sem os horarios detalhados.
  final Set<String> daysWithMeals;
  final bool hasMealsToday;
  final int currentRegistrationStreak;
  final DateTime? registrationLastDate;
  final bool isStreakProtected;
  final int horizonDays;

  BehavioralReminderContext copyWith({DateTime? now}) {
    return BehavioralReminderContext(
      now: now ?? this.now,
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
}

class BehavioralReminder {
  const BehavioralReminder({
    required this.id,
    required this.kind,
    required this.scheduledAt,
    required this.titleKey,
    required this.bodyKey,
    required this.payloadType,
    this.arguments = const <String, String>{},
    this.payload = const <String, String>{},
  });

  final int id;
  final BehavioralReminderKind kind;
  final DateTime scheduledAt;
  final String titleKey;
  final String bodyKey;
  final String payloadType;
  final Map<String, String> arguments;
  final Map<String, String> payload;

  String get fingerprint {
    final sortedArguments = arguments.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final sortedPayload = payload.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return <Object>[
      id,
      kind.name,
      scheduledAt.toIso8601String(),
      titleKey,
      bodyKey,
      payloadType,
      for (final entry in sortedArguments) '${entry.key}=${entry.value}',
      for (final entry in sortedPayload) '${entry.key}=${entry.value}',
    ].join('|');
  }
}

/// Planeja lembretes locais que dependem do estado mais recente do diario.
///
/// O resultado e puro e usa notificacoes one-shot. A camada nativa cancela o
/// plano anterior e agenda este resultado sempre que refeicoes, streak, idioma,
/// horario configurado ou ciclo de vida do app mudam.
class BehavioralReminderPlanner {
  const BehavioralReminderPlanner();

  static const int defaultHorizonDays = 7;
  static const int maxMealSlots = 8;
  static const int maxMealRemindersPerDay = 3;
  static const int maxBehavioralRemindersPerDay = 3;
  static const int habitLookbackDays = 21;
  // Duas ocorrencias em dias diferentes ja permitem personalizar o horario.
  // Antes disso, o lembrete continua usando o horario configurado pelo usuario.
  static const int minimumHabitSamples = 2;
  static const int mealGraceMinutes = 75;
  static const int quietHoursEndMinutes = 22 * 60;
  static const int quietHoursStartMinutes = 8 * 60;

  static const int mealReminderBaseId = 4000;
  static const int comebackReminderId = 4080;
  static const int streakReminderId = 4090;

  List<BehavioralReminder> plan(BehavioralReminderContext context) {
    final now = context.now;
    final today = _dateOnly(now);
    final indexedSlots = _validSlots(context.mealSlots);
    final habits = _buildHabits(
      slots: indexedSlots,
      entries: context.mealEntries,
      today: today,
    );
    final selectedHabits = _selectMealHabits(habits);
    final reminders = <BehavioralReminder>[];
    final shouldUseComeback = _shouldScheduleComeback(context, today);
    final streakAt = DateTime(today.year, today.month, today.day, 23);
    final shouldScheduleStreak =
        _shouldScheduleStreakRisk(context, today) && streakAt.isAfter(now);

    for (var dayOffset = 0;
        dayOffset < context.horizonDays.clamp(1, defaultHorizonDays);
        dayOffset++) {
      final day = DateTime(today.year, today.month, today.day + dayOffset);
      final dayEntries = context.mealEntries
          .where((entry) => _isSameDay(entry.recordedAt, day))
          .toList(growable: false);
      final assignments = _assignEntries(indexedSlots, dayEntries);

      // Quando so existe o resumo remoto do dia, sabemos que houve registro,
      // mas nao qual refeicao foi. Suprimir o restante e mais seguro do que
      // emitir um falso "voce esqueceu".
      final hasOnlySummaryForToday =
          dayOffset == 0 && context.hasMealsToday && dayEntries.isEmpty;
      // Depois de dois dias sem uso, troque a sequencia de lembretes de cada
      // refeicao por um unico convite gentil de retomada. Se a pessoa voltar a
      // registrar, a proxima reconciliacao restaura o plano normal.
      if (shouldUseComeback || hasOnlySummaryForToday) {
        continue;
      }

      final habitsForDay = dayOffset == 0 && shouldScheduleStreak
          ? selectedHabits.take(maxBehavioralRemindersPerDay - 1)
          : selectedHabits;
      for (final habit in habitsForDay) {
        if (assignments[habit.index]?.isNotEmpty == true) {
          continue;
        }

        final reminderMinute = _clampReminderMinute(
          habit.expectedMinute + mealGraceMinutes,
        );
        final scheduledAt = _atMinute(day, reminderMinute);
        if (!scheduledAt.isAfter(now)) {
          continue;
        }

        reminders.add(
          BehavioralReminder(
            id: mealReminderBaseId + (dayOffset * 10) + habit.index,
            kind: BehavioralReminderKind.missedMeal,
            scheduledAt: scheduledAt,
            titleKey: 'notification_smart_meal_title',
            bodyKey: habit.isLearned
                ? 'notification_smart_meal_body_habit'
                : 'notification_smart_meal_body_configured',
            payloadType: 'missed_meal',
            arguments: {
              'meal': habit.slot.name,
              'time': _formatMinute(habit.expectedMinute),
            },
            payload: {
              'mealId': habit.slot.id,
              'mealName': habit.slot.name,
              'date': _dateKey(day),
            },
          ),
        );
      }
    }

    if (shouldUseComeback) {
      final comebackAt = DateTime(today.year, today.month, today.day, 18, 30);
      if (comebackAt.isAfter(now)) {
        reminders.add(
          BehavioralReminder(
            id: comebackReminderId,
            kind: BehavioralReminderKind.comeback,
            scheduledAt: comebackAt,
            titleKey: 'notification_comeback_title',
            bodyKey: 'notification_comeback_body',
            payloadType: 'comeback_reminder',
            payload: {'date': _dateKey(today)},
          ),
        );
      }
    }

    if (shouldScheduleStreak) {
      reminders.add(
        BehavioralReminder(
          id: streakReminderId,
          kind: BehavioralReminderKind.streakRisk,
          scheduledAt: streakAt,
          titleKey: 'notification_streak_risk_title',
          bodyKey: context.currentRegistrationStreak == 1
              ? 'notification_streak_risk_body_one'
              : 'notification_streak_risk_body_other',
          payloadType: 'streak_risk',
          arguments: {
            'count': context.currentRegistrationStreak.toString(),
          },
          payload: {'date': _dateKey(today)},
        ),
      );
    }

    reminders.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return List.unmodifiable(reminders);
  }

  List<_IndexedMealSlot> _validSlots(List<BehavioralMealSlot> slots) {
    final sorted = List<BehavioralMealSlot>.from(slots)
      ..sort((a, b) => a.order.compareTo(b.order));
    final valid = <_IndexedMealSlot>[];

    for (final slot in sorted) {
      if (valid.length >= maxMealSlots) break;
      final configuredMinute = _parseTime(slot.configuredTime);
      if (configuredMinute == null) continue;
      valid.add(
        _IndexedMealSlot(
          index: valid.length,
          slot: slot,
          configuredMinute: configuredMinute,
        ),
      );
    }
    return valid;
  }

  List<_MealHabit> _buildHabits({
    required List<_IndexedMealSlot> slots,
    required List<BehavioralMealEntry> entries,
    required DateTime today,
  }) {
    final oldestDay = today.subtract(const Duration(days: habitLookbackDays));
    final historicalEntries = entries.where((entry) {
      final day = _dateOnly(entry.recordedAt);
      return day.isBefore(today) && !day.isBefore(oldestDay);
    }).toList(growable: false);
    final entriesByDay = <String, List<BehavioralMealEntry>>{};
    for (final entry in historicalEntries) {
      (entriesByDay[_dateKey(entry.recordedAt)] ??= <BehavioralMealEntry>[])
          .add(entry);
    }

    final samplesBySlot = <int, List<int>>{};
    for (final dayEntries in entriesByDay.values) {
      final assignments = _assignEntries(slots, dayEntries);
      for (final slot in slots) {
        final assigned = assignments[slot.index] ?? const [];
        if (assigned.isEmpty) continue;
        final usable = assigned.where((entry) {
          // Versoes antigas normalizavam o horario para 00:00. Esses dados
          // ainda contam como refeicao feita, mas nao como amostra de habito.
          return entry.recordedAt.hour != 0 || entry.recordedAt.minute != 0;
        }).toList(growable: false);
        if (usable.isEmpty) continue;

        usable.sort((a, b) {
          final aDistance =
              (_minuteOfDay(a.recordedAt) - slot.configuredMinute).abs();
          final bDistance =
              (_minuteOfDay(b.recordedAt) - slot.configuredMinute).abs();
          return aDistance.compareTo(bDistance);
        });
        (samplesBySlot[slot.index] ??= <int>[])
            .add(_minuteOfDay(usable.first.recordedAt));
      }
    }

    return slots.map((slot) {
      final samples = samplesBySlot[slot.index] ?? const <int>[];
      var expectedMinute = slot.configuredMinute;
      var isLearned = false;
      if (samples.length >= minimumHabitSamples) {
        final median = _median(samples);
        // Rejeita dados muito distantes do horario configurado. Isso protege
        // contra timestamps antigos normalizados ou refeicoes classificadas no
        // slot errado sem impedir que o habito ajuste algumas horas.
        if ((median - slot.configuredMinute).abs() <= 4 * 60) {
          expectedMinute = median;
          isLearned = true;
        }
      }
      return _MealHabit(
        index: slot.index,
        slot: slot.slot,
        expectedMinute: expectedMinute,
        sampleCount: samples.length,
        isLearned: isLearned,
      );
    }).toList(growable: false);
  }

  List<_MealHabit> _selectMealHabits(List<_MealHabit> habits) {
    final ranked = List<_MealHabit>.from(habits)
      ..sort((a, b) {
        final scoreComparison = _habitScore(b).compareTo(_habitScore(a));
        if (scoreComparison != 0) return scoreComparison;
        return a.slot.order.compareTo(b.slot.order);
      });
    final selected = ranked.take(maxMealRemindersPerDay).toList()
      ..sort((a, b) => a.expectedMinute.compareTo(b.expectedMinute));
    return selected;
  }

  int _habitScore(_MealHabit habit) {
    final primaryBonus = _isPrimarySlot(habit.slot.id) ? 400 : 0;
    return primaryBonus + (habit.sampleCount * 100);
  }

  Map<int, List<BehavioralMealEntry>> _assignEntries(
    List<_IndexedMealSlot> slots,
    List<BehavioralMealEntry> entries,
  ) {
    final result = <int, List<BehavioralMealEntry>>{};
    if (slots.isEmpty) return result;

    for (final entry in entries) {
      final mealType = entry.mealType.trim().toLowerCase();
      var candidates = slots.where((slot) {
        final slotType = _slotType(slot.slot.id);
        switch (mealType) {
          case 'breakfast':
          case 'lunch':
          case 'dinner':
            return slotType == mealType;
          case 'snack':
            return slotType == 'snack' || slotType == 'freeMeal';
          case 'freemeal':
          case 'free_meal':
            return slotType == 'freeMeal' || slotType == 'snack';
          default:
            return false;
        }
      }).toList(growable: false);
      if (candidates.isEmpty) {
        candidates = slots;
      }

      final entryMinute = _minuteOfDay(entry.recordedAt);
      candidates.sort((a, b) {
        final aDistance = (entryMinute - a.configuredMinute).abs();
        final bDistance = (entryMinute - b.configuredMinute).abs();
        return aDistance.compareTo(bDistance);
      });
      (result[candidates.first.index] ??= <BehavioralMealEntry>[]).add(entry);
    }
    return result;
  }

  bool _shouldScheduleStreakRisk(
    BehavioralReminderContext context,
    DateTime today,
  ) {
    if (context.currentRegistrationStreak < 2 ||
        context.hasMealsToday ||
        context.isStreakProtected) {
      return false;
    }

    final lastDate = context.registrationLastDate;
    if (lastDate == null) {
      return false;
    }
    final localLastDate = _dateOnly(lastDate.toLocal());
    final yesterday = today.subtract(const Duration(days: 1));
    return _isSameDay(localLastDate, yesterday);
  }

  bool _shouldScheduleComeback(
    BehavioralReminderContext context,
    DateTime today,
  ) {
    if (context.hasMealsToday) return false;

    final yesterday = today.subtract(const Duration(days: 1));
    final twoDaysAgo = today.subtract(const Duration(days: 2));
    if (context.daysWithMeals.contains(_dateKey(yesterday)) ||
        context.daysWithMeals.contains(_dateKey(twoDaysAgo))) {
      return false;
    }

    var activeDays = 0;
    for (var daysAgo = 3; daysAgo <= 9; daysAgo++) {
      final day = today.subtract(Duration(days: daysAgo));
      if (context.daysWithMeals.contains(_dateKey(day))) {
        activeDays++;
      }
    }
    return activeDays >= 3;
  }

  bool _isPrimarySlot(String id) {
    final normalized = id.trim().toLowerCase();
    return normalized == 'breakfast' ||
        normalized == 'lunch' ||
        normalized == 'dinner';
  }

  String _slotType(String id) {
    final normalized = id.trim().toLowerCase();
    if (normalized == 'breakfast' || normalized.contains('breakfast')) {
      return 'breakfast';
    }
    if (normalized == 'lunch' || normalized.contains('lunch')) {
      return 'lunch';
    }
    if (normalized == 'dinner' || normalized.contains('dinner')) {
      return 'dinner';
    }
    if (normalized.contains('snack')) {
      return 'snack';
    }
    return 'freeMeal';
  }

  int _clampReminderMinute(int minute) {
    return minute.clamp(quietHoursStartMinutes, quietHoursEndMinutes).toInt();
  }

  int? _parseTime(String value) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value.trim());
    if (match == null) return null;
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return null;
    }
    return (hour * 60) + minute;
  }

  int _median(List<int> values) {
    final sorted = List<int>.from(values)..sort();
    final middle = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[middle];
    return ((sorted[middle - 1] + sorted[middle]) / 2).round();
  }

  int _minuteOfDay(DateTime value) => (value.hour * 60) + value.minute;

  DateTime _atMinute(DateTime day, int minute) {
    return DateTime(
      day.year,
      day.month,
      day.day,
      minute ~/ 60,
      minute % 60,
    );
  }

  String _formatMinute(int minute) {
    final hour = (minute ~/ 60).toString().padLeft(2, '0');
    final remainder = (minute % 60).toString().padLeft(2, '0');
    return '$hour:$remainder';
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _dateKey(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}

class _IndexedMealSlot {
  const _IndexedMealSlot({
    required this.index,
    required this.slot,
    required this.configuredMinute,
  });

  final int index;
  final BehavioralMealSlot slot;
  final int configuredMinute;
}

class _MealHabit {
  const _MealHabit({
    required this.index,
    required this.slot,
    required this.expectedMinute,
    required this.sampleCount,
    required this.isLearned,
  });

  final int index;
  final BehavioralMealSlot slot;
  final int expectedMinute;
  final int sampleCount;
  final bool isLearned;
}
