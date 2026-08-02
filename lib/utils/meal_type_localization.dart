import 'package:flutter/material.dart';

import '../i18n/app_localizations.dart';
import '../providers/meal_types_provider.dart';

/// Formats a persisted 24-hour meal time according to the device's locale and
/// 12/24-hour preference. Invalid or non-clock values are preserved verbatim.
String localizedMealTime(BuildContext context, String rawTime) {
  final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(rawTime.trim());
  final hour = match == null ? null : int.tryParse(match.group(1)!);
  final minute = match == null ? null : int.tryParse(match.group(2)!);
  if (hour == null ||
      minute == null ||
      hour < 0 ||
      hour > 23 ||
      minute < 0 ||
      minute > 59) {
    return rawTime;
  }

  return MaterialLocalizations.of(context).formatTimeOfDay(
    TimeOfDay(hour: hour, minute: minute),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
}

/// Returns a localized label for built-in meal types while preserving names
/// created by the user.
String localizedMealTypeName(
  AppLocalizations localizations,
  MealTypeConfig mealType,
) {
  final generatedExtraNumber =
      MealTypeConfig.generatedExtraNumberFromName(mealType.name) ??
          _legacyGeneratedExtraNumber(mealType);
  if (generatedExtraNumber != null) {
    return localizations
        .translate('extra_meal_number')
        .replaceAll('{number}', generatedExtraNumber.toString());
  }

  if (!_hasDefaultBuiltInName(mealType)) {
    return mealType.name;
  }

  switch (mealType.id) {
    case 'breakfast':
      return localizations.translate('breakfast');
    case 'morning_snack':
      return localizations.translate('notification_meal_name_morning_snack');
    case 'lunch':
      return localizations.translate('lunch');
    case 'afternoon_snack':
      return localizations.translate('notification_meal_name_afternoon_snack');
    case 'snack':
      return localizations.translate('snack');
    case 'dinner':
      return localizations.translate('dinner');
    case 'supper':
      return localizations.translate('notification_meal_name_supper');
    case 'free_meal':
      return localizations.translate('free_meal');
    default:
      return mealType.name;
  }
}

bool _hasDefaultBuiltInName(MealTypeConfig mealType) {
  const legacyDefaultNames = <String, String>{
    'breakfast': 'Café da Manhã',
    'morning_snack': 'Lanche da Manhã',
    'lunch': 'Almoço',
    'afternoon_snack': 'Lanche da Tarde',
    'snack': 'Lanche',
    'dinner': 'Jantar',
    'supper': 'Ceia',
    'free_meal': 'Refeição Livre',
  };
  final defaultName = legacyDefaultNames[mealType.id];
  return defaultName != null && mealType.name.trim() == defaultName;
}

int? _legacyGeneratedExtraNumber(MealTypeConfig mealType) {
  if (!mealType.id.startsWith('extra_')) {
    return null;
  }
  final match = RegExp(r'^Refeição extra (\d+)$').firstMatch(
    mealType.name.trim(),
  );
  return match == null ? null : int.tryParse(match.group(1)!);
}
