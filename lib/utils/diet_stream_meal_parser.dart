import 'dart:convert';

/// Extracts only complete meal values from a still-growing diet JSON response.
///
/// Diet generation currently uses the compact shape below, but older responses
/// used objects. Keeping the stream parser independent from either schema lets
/// the UI reveal a meal as soon as its top-level JSON value is complete.
///
/// ```json
/// {"m":[["breakfast","08:00",[["Eggs",2,"unit",140,12,1,10]]]]}
/// ```
class DietStreamMealParser {
  const DietStreamMealParser._();

  static List<dynamic> extractCompleteMeals(String streamedText) {
    final mealsArrayStart = _findMealsArrayStart(streamedText);
    if (mealsArrayStart == null) {
      return const [];
    }

    final meals = <dynamic>[];
    var cursor = mealsArrayStart + 1;

    while (cursor < streamedText.length) {
      cursor = _skipSeparators(streamedText, cursor);
      if (cursor >= streamedText.length || streamedText[cursor] == ']') {
        break;
      }

      final openingCharacter = streamedText[cursor];
      if (openingCharacter != '[' && openingCharacter != '{') {
        // A top-level meal must be a compact array or a legacy object. If the
        // next value is not one of those, the response is incomplete/invalid.
        break;
      }

      final valueEnd = _findBalancedValueEnd(streamedText, cursor);
      if (valueEnd == null) {
        break;
      }

      try {
        final value = jsonDecode(streamedText.substring(cursor, valueEnd + 1));
        if (_looksLikeMeal(value)) {
          meals.add(value);
        }
      } on FormatException {
        // A balanced-looking fragment can still be invalid JSON. Do not expose
        // it and keep any meals that were completed before this fragment.
        break;
      }

      cursor = valueEnd + 1;
    }

    return meals;
  }

  static int? _findMealsArrayStart(String text) {
    final envelopeMatch = RegExp(
      r'"(?:m|meals)"\s*:\s*\[',
      caseSensitive: false,
    ).firstMatch(text);
    if (envelopeMatch != null) {
      return envelopeMatch.end - 1;
    }

    // Also tolerate a root array for model/provider fallbacks.
    final objectStart = text.indexOf('{');
    final arrayStart = text.indexOf('[');
    if (arrayStart >= 0 && (objectStart < 0 || arrayStart < objectStart)) {
      return arrayStart;
    }
    return null;
  }

  static int _skipSeparators(String text, int start) {
    var cursor = start;
    while (cursor < text.length) {
      final character = text[cursor];
      if (character == ',' || character.trim().isEmpty) {
        cursor++;
        continue;
      }
      break;
    }
    return cursor;
  }

  static int? _findBalancedValueEnd(String text, int start) {
    final closingCharacters = <String>[];
    var inString = false;
    var escaped = false;

    for (var index = start; index < text.length; index++) {
      final character = text[index];

      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (character == r'\') {
          escaped = true;
        } else if (character == '"') {
          inString = false;
        }
        continue;
      }

      if (character == '"') {
        inString = true;
        continue;
      }

      if (character == '[') {
        closingCharacters.add(']');
      } else if (character == '{') {
        closingCharacters.add('}');
      } else if (character == ']' || character == '}') {
        if (closingCharacters.isEmpty || closingCharacters.last != character) {
          return null;
        }
        closingCharacters.removeLast();
        if (closingCharacters.isEmpty) {
          return index;
        }
      }
    }

    return null;
  }

  static bool _looksLikeMeal(dynamic value) {
    if (value is List) {
      return value.length >= 3 && value[0] is String && value[2] is List;
    }

    if (value is Map) {
      final hasLegacyFields =
          value.containsKey('type') && value.containsKey('foods');
      final hasCompactFields = value.containsKey('t') && value.containsKey('f');
      return hasLegacyFields || hasCompactFields;
    }

    return false;
  }
}
