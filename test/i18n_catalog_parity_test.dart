import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nutro_ai/i18n/translations/de_de_translations.dart';
import 'package:nutro_ai/i18n/translations/en_us_translations.dart';
import 'package:nutro_ai/i18n/translations/es_es_translations.dart';
import 'package:nutro_ai/i18n/translations/fr_fr_translations.dart';
import 'package:nutro_ai/i18n/translations/it_it_translations.dart';
import 'package:nutro_ai/i18n/translations/pt_br_translations.dart';
import 'package:nutro_ai/screens/tools/code_enhancer_tool_config.dart';
import 'package:nutro_ai/screens/tools/content_generator_tool_config.dart';
import 'package:nutro_ai/screens/tools/essay_helper_tool_config.dart';
import 'package:nutro_ai/screens/tools/language_tool_config.dart';
import 'package:nutro_ai/screens/tools/learning_assistant_tool_config.dart';
import 'package:nutro_ai/screens/tools/summarizer_tool_config.dart';

void main() {
  final catalogs = <String, Map<String, String>>{
    'pt_BR': ptBRTranslations,
    'en_US': enUSTranslations,
    'es_ES': esESTranslations,
    'fr_FR': frFRTranslations,
    'de_DE': deDETranslations,
    'it_IT': itITTranslations,
  };

  test('all localization catalogs contain the same non-empty keys', () {
    final referenceKeys = ptBRTranslations.keys.toSet();

    for (final entry in catalogs.entries) {
      final keys = entry.value.keys.toSet();
      final missing = referenceKeys.difference(keys).toList()..sort();
      final unexpected = keys.difference(referenceKeys).toList()..sort();
      final empty = entry.value.entries
          .where((translation) => translation.value.trim().isEmpty)
          .map((translation) => translation.key)
          .toList()
        ..sort();

      expect(
        missing,
        isEmpty,
        reason: '${entry.key} is missing localization keys: $missing',
      );
      expect(
        unexpected,
        isEmpty,
        reason: '${entry.key} contains unexpected localization keys: '
            '$unexpected',
      );
      expect(
        empty,
        isEmpty,
        reason: '${entry.key} contains empty translations: $empty',
      );
    }
  });

  test('translated messages preserve interpolation placeholders', () {
    final placeholderPattern = RegExp(r'\{[A-Za-z][A-Za-z0-9_]*\}');

    for (final key in ptBRTranslations.keys) {
      final expected = placeholderPattern
          .allMatches(ptBRTranslations[key]!)
          .map((match) => match.group(0)!)
          .toList()
        ..sort();

      for (final entry in catalogs.entries) {
        final value = entry.value[key];
        if (value == null) {
          continue;
        }
        final actual = placeholderPattern
            .allMatches(value)
            .map((match) => match.group(0)!)
            .toList()
          ..sort();
        expect(
          actual,
          expected,
          reason: '${entry.key} changes placeholders for "$key"',
        );
      }
    }
  });

  test('translated messages preserve line breaks and bullet structure', () {
    for (final key in ptBRTranslations.keys) {
      final reference = ptBRTranslations[key]!;
      final expectedLineBreaks = RegExp(r'\n').allMatches(reference).length;
      final expectedBullets = RegExp('•').allMatches(reference).length;

      for (final entry in catalogs.entries) {
        final value = entry.value[key];
        if (value == null) continue;

        expect(
          RegExp(r'\n').allMatches(value).length,
          expectedLineBreaks,
          reason: '${entry.key} changes line-break structure for "$key"',
        );
        expect(
          RegExp('•').allMatches(value).length,
          expectedBullets,
          reason: '${entry.key} changes bullet structure for "$key"',
        );
      }
    }
  });

  test('localization source files do not declare duplicate keys', () {
    const paths = <String, String>{
      'pt_BR': 'lib/i18n/translations/pt_br_translations.dart',
      'en_US': 'lib/i18n/translations/en_us_translations.dart',
      'es_ES': 'lib/i18n/translations/es_es_translations.dart',
      'fr_FR': 'lib/i18n/translations/fr_fr_translations.dart',
      'de_DE': 'lib/i18n/translations/de_de_translations.dart',
      'it_IT': 'lib/i18n/translations/it_it_translations.dart',
    };
    final keyPattern = RegExp(r"^\s*'([^']+)'\s*:", multiLine: true);

    for (final entry in paths.entries) {
      final source = File(entry.value).readAsStringSync();
      final counts = <String, int>{};
      for (final match in keyPattern.allMatches(source)) {
        final key = match.group(1)!;
        counts[key] = (counts[key] ?? 0) + 1;
      }
      final duplicates = counts.entries
          .where((count) => count.value > 1)
          .map((count) => count.key)
          .toList()
        ..sort();

      expect(
        duplicates,
        isEmpty,
        reason: '${entry.key} declares duplicate keys: $duplicates',
      );
    }
  });

  test('literal translation keys used by the app exist in the catalog', () {
    final usedKeys = <String>{};
    final translationCalls = <RegExp>[
      RegExp(
        r'''(?:translate|_translate|_translateWith|_translateWithValues)\(\s*['"]([A-Za-z0-9_.-]+)['"]''',
      ),
      RegExp(
        r'''(?:_translate|_translateWith|_translateWithValues)\(\s*context\s*,\s*['"]([A-Za-z0-9_.-]+)['"]''',
      ),
      RegExp(
        r'''_localizedMessage\(\s*[^,]+,\s*['"]([A-Za-z0-9_.-]+)['"]''',
      ),
    ];
    final declaredTranslationKey = RegExp(
      r'''(?:['"])?\b(?:bodyKey|descriptionKey|labelKey|nameKey|textKey|titleKey|titleTranslationKey|translationKey)(?:['"])?\s*:\s*['"]([A-Za-z0-9_.-]+)['"]''',
    );

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.contains(
          '${Platform.pathSeparator}translations${Platform.pathSeparator}')) {
        continue;
      }
      final source = entity.readAsStringSync();
      for (final translationCall in translationCalls) {
        usedKeys.addAll(
          translationCall.allMatches(source).map((match) => match.group(1)!),
        );
      }
      usedKeys.addAll(
        declaredTranslationKey
            .allMatches(source)
            .map((match) => match.group(1)!),
      );
    }

    final missing = usedKeys.difference(ptBRTranslations.keys.toSet()).toList()
      ..sort();
    expect(missing, isEmpty, reason: 'Unknown localization keys: $missing');
  });

  test('tool configurations reference valid localization keys', () {
    final configs = [
      CodeEnhancerToolConfig.getConfig(),
      ContentGeneratorToolConfig.getConfig(),
      EssayHelperToolConfig.getConfig(),
      LanguageToolConfig.getConfig(),
      LearningAssistantToolConfig.getConfig(),
      SummarizerToolConfig.getConfig(),
    ];
    final knownKeys = ptBRTranslations.keys.toSet();
    final promptToken = RegExp(r'\{([A-Za-z0-9_.-]+)\}');
    final missing = <String>{};

    for (final config in configs) {
      if (!knownKeys.contains(config.titleTranslationKey)) {
        missing.add(config.titleTranslationKey);
      }
      for (final tab in config.tabs) {
        if (!knownKeys.contains(tab.translationKey)) {
          missing.add(tab.translationKey);
        }

        final parameterIds = tab.parameters.map((parameter) => parameter.id);
        for (final parameter in tab.parameters) {
          if (!knownKeys.contains(parameter.translationKey)) {
            missing.add(parameter.translationKey);
          }
          for (final option in parameter.options ?? const []) {
            if (!knownKeys.contains(option.translationKey)) {
              missing.add(option.translationKey);
            }
          }
        }

        for (final match in promptToken.allMatches(tab.promptTemplate)) {
          final token = match.group(1)!;
          if (token != 'input_text' &&
              !parameterIds.contains(token) &&
              !knownKeys.contains(token)) {
            missing.add(token);
          }
        }
      }
    }

    expect(
      missing.toList()..sort(),
      isEmpty,
      reason: 'Tool configurations reference unknown localization keys',
    );
  });

  test('Android native string resources have locale parity', () {
    const paths = <String, String>{
      'default': 'android/app/src/main/res/values/strings.xml',
      'pt_BR': 'android/app/src/main/res/values-pt-rBR/strings.xml',
      'en_US': 'android/app/src/main/res/values-en/strings.xml',
      'es_ES': 'android/app/src/main/res/values-es/strings.xml',
      'fr_FR': 'android/app/src/main/res/values-fr/strings.xml',
      'de_DE': 'android/app/src/main/res/values-de/strings.xml',
      'it_IT': 'android/app/src/main/res/values-it/strings.xml',
    };
    final resourcePattern = RegExp(
      r'<string\s+name="([^"]+)"[^>]*>([\s\S]*?)</string>',
    );
    final nativeCatalogs = <String, Map<String, String>>{};

    for (final entry in paths.entries) {
      final source = File(entry.value).readAsStringSync();
      nativeCatalogs[entry.key] = {
        for (final match in resourcePattern.allMatches(source))
          match.group(1)!: match.group(2)!.trim(),
      };
    }

    final referenceKeys = nativeCatalogs['pt_BR']!.keys.toSet();
    for (final entry in nativeCatalogs.entries) {
      expect(
        entry.value.keys.toSet(),
        referenceKeys,
        reason: '${entry.key} has different Android native string keys',
      );
      expect(
        entry.value.values.where((value) => value.isEmpty),
        isEmpty,
        reason: '${entry.key} contains an empty Android native string',
      );
    }
  });

  test('iOS permission descriptions have locale parity', () {
    const paths = <String, String>{
      'pt_BR': 'ios/Runner/pt-BR.lproj/InfoPlist.strings',
      'en_US': 'ios/Runner/en.lproj/InfoPlist.strings',
      'es_ES': 'ios/Runner/es.lproj/InfoPlist.strings',
      'fr_FR': 'ios/Runner/fr.lproj/InfoPlist.strings',
      'de_DE': 'ios/Runner/de.lproj/InfoPlist.strings',
      'it_IT': 'ios/Runner/it.lproj/InfoPlist.strings',
    };
    final entryPattern =
        RegExp(r'^\s*"([^"]+)"\s*=\s*"([^"]+)";', multiLine: true);
    final nativeCatalogs = <String, Map<String, String>>{};

    for (final entry in paths.entries) {
      final source = File(entry.value).readAsStringSync();
      nativeCatalogs[entry.key] = {
        for (final match in entryPattern.allMatches(source))
          match.group(1)!: match.group(2)!.trim(),
      };
    }

    final referenceKeys = nativeCatalogs['pt_BR']!.keys.toSet();
    for (final entry in nativeCatalogs.entries) {
      expect(
        entry.value.keys.toSet(),
        referenceKeys,
        reason: '${entry.key} has different iOS permission-description keys',
      );
      expect(
        entry.value.values.where((value) => value.isEmpty),
        isEmpty,
        reason: '${entry.key} contains an empty iOS permission description',
      );
    }
  });
}
