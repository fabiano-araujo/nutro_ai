import 'package:flutter_test/flutter_test.dart';
import 'package:nutro_ai/i18n/app_localizations.dart';

void main() {
  const requiredKeys = <String>[
    'notification_smart_meal_title',
    'notification_smart_meal_body_habit',
    'notification_smart_meal_body_configured',
    'notification_streak_risk_title',
    'notification_streak_risk_body',
    'notification_comeback_title',
    'notification_comeback_body',
    'notification_meal_name_morning_snack',
    'notification_meal_name_afternoon_snack',
    'notification_meal_name_supper',
  ];

  for (final locale in AppLocalizations.supportedLocales) {
    test('behavioral notification copy is complete for $locale', () {
      final localizations = AppLocalizations(locale);
      for (final key in requiredKeys) {
        final translation = localizations.translate(key);
        expect(translation, isNot(key), reason: '$key is missing for $locale');
        expect(translation.trim(), isNotEmpty);
      }

      expect(
        localizations.translate('notification_smart_meal_title'),
        contains('{meal}'),
      );
      expect(
        localizations.translate('notification_smart_meal_body_habit'),
        contains('{time}'),
      );
      expect(
        localizations.translate('notification_smart_meal_body_configured'),
        contains('{meal}'),
      );
      expect(
        localizations.translate('notification_streak_risk_body'),
        contains('{count}'),
      );
    });
  }
}
