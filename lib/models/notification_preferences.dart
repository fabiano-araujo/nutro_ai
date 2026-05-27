enum NotificationPreferenceType {
  mealReminders,
  weightReminders,
  personalizedTips,
}

class NotificationPreferences {
  const NotificationPreferences({
    required this.mealReminders,
    required this.weightReminders,
    required this.personalizedTips,
    required this.weightReminderTime,
    required this.weightReminderWeekdays,
    required this.personalizedTipTime,
  });

  final bool mealReminders;
  final bool weightReminders;
  final bool personalizedTips;
  final String weightReminderTime;
  final List<int> weightReminderWeekdays;
  final String personalizedTipTime;

  static const defaults = NotificationPreferences(
    mealReminders: false,
    weightReminders: false,
    personalizedTips: false,
    weightReminderTime: '08:30',
    weightReminderWeekdays: [DateTime.monday],
    personalizedTipTime: '17:30',
  );

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      mealReminders: json['mealReminders'] == true,
      weightReminders: json['weightReminders'] == true,
      personalizedTips: json['personalizedTips'] == true,
      weightReminderTime: normalizeTime(json['weightReminderTime']) ??
          defaults.weightReminderTime,
      weightReminderWeekdays:
          normalizeWeekdays(json['weightReminderWeekdays']) ??
              normalizeWeekdays(json['weightReminderWeekday']) ??
              defaults.weightReminderWeekdays,
      personalizedTipTime: normalizeTime(json['personalizedTipTime']) ??
          defaults.personalizedTipTime,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mealReminders': mealReminders,
      'weightReminders': weightReminders,
      'personalizedTips': personalizedTips,
      'weightReminderTime': weightReminderTime,
      'weightReminderWeekdays': weightReminderWeekdays,
      'personalizedTipTime': personalizedTipTime,
    };
  }

  NotificationPreferences copyWith({
    bool? mealReminders,
    bool? weightReminders,
    bool? personalizedTips,
    String? weightReminderTime,
    List<int>? weightReminderWeekdays,
    String? personalizedTipTime,
  }) {
    return NotificationPreferences(
      mealReminders: mealReminders ?? this.mealReminders,
      weightReminders: weightReminders ?? this.weightReminders,
      personalizedTips: personalizedTips ?? this.personalizedTips,
      weightReminderTime:
          normalizeTime(weightReminderTime) ?? this.weightReminderTime,
      weightReminderWeekdays: normalizeWeekdays(weightReminderWeekdays) ??
          this.weightReminderWeekdays,
      personalizedTipTime:
          normalizeTime(personalizedTipTime) ?? this.personalizedTipTime,
    );
  }

  NotificationPreferences copyWithType(
    NotificationPreferenceType type,
    bool enabled,
  ) {
    switch (type) {
      case NotificationPreferenceType.mealReminders:
        return copyWith(mealReminders: enabled);
      case NotificationPreferenceType.weightReminders:
        return copyWith(weightReminders: enabled);
      case NotificationPreferenceType.personalizedTips:
        return copyWith(personalizedTips: enabled);
    }
  }

  NotificationPreferences copyWithReminderTime(
    NotificationPreferenceType type,
    String reminderTime,
  ) {
    final normalizedTime = normalizeTime(reminderTime);
    if (normalizedTime == null) {
      return this;
    }

    switch (type) {
      case NotificationPreferenceType.mealReminders:
        return this;
      case NotificationPreferenceType.weightReminders:
        return copyWith(weightReminderTime: normalizedTime);
      case NotificationPreferenceType.personalizedTips:
        return copyWith(personalizedTipTime: normalizedTime);
    }
  }

  NotificationPreferences copyWithWeightReminderSettings({
    String? reminderTime,
    List<int>? weekdays,
  }) {
    return copyWith(
      weightReminderTime: reminderTime,
      weightReminderWeekdays: weekdays,
    );
  }

  bool isEnabled(NotificationPreferenceType type) {
    switch (type) {
      case NotificationPreferenceType.mealReminders:
        return mealReminders;
      case NotificationPreferenceType.weightReminders:
        return weightReminders;
      case NotificationPreferenceType.personalizedTips:
        return personalizedTips;
    }
  }

  int get enabledCount {
    return [
      mealReminders,
      weightReminders,
      personalizedTips,
    ].where((enabled) => enabled).length;
  }

  bool get hasAnyEnabled => enabledCount > 0;

  int get weightReminderFrequency => weightReminderWeekdays.length;

  static String? normalizeTime(Object? value) {
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty) return null;

    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(raw);
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

    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  static List<int>? normalizeWeekdays(Object? value) {
    Iterable<dynamic>? values;

    if (value is Iterable) {
      values = value;
    } else if (value != null) {
      values = [value];
    }

    if (values == null) return null;

    final weekdays = <int>{};
    for (final item in values) {
      final weekday = int.tryParse(item.toString());
      if (weekday != null &&
          weekday >= DateTime.monday &&
          weekday <= DateTime.sunday) {
        weekdays.add(weekday);
      }
    }

    if (weekdays.isEmpty) return null;

    final sortedWeekdays = weekdays.toList()..sort();
    return List.unmodifiable(sortedWeekdays);
  }
}
