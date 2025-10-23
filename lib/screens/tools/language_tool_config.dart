import 'package:flutter/material.dart';
import '../generic_ai_screen.dart';

class LanguageToolConfig {
  static ToolConfig getConfig() {
    return ToolConfig(
      titleTranslationKey: 'language_tools',
      tabs: [
        // Aba de tradução
        ToolTab(
          id: 'translate',
          translationKey: 'translation',
          icon: Icons.translate,
          promptTemplate:
              '{translate_following_text_to} {target_language} ({auto_detect_source}):\n\n{input_text}',
          parameters: [
            ToolParameter(
              id: 'target_language',
              translationKey: 'target_language',
              type: ParameterType.dropdown,
              options: [
                ParameterOption(id: 'portuguese', translationKey: 'portuguese'),
                ParameterOption(id: 'english', translationKey: 'english'),
                ParameterOption(id: 'spanish', translationKey: 'spanish'),
                ParameterOption(id: 'french', translationKey: 'french'),
                ParameterOption(id: 'german', translationKey: 'german'),
                ParameterOption(id: 'italian', translationKey: 'italian'),
                ParameterOption(id: 'japanese', translationKey: 'japanese'),
                ParameterOption(id: 'chinese', translationKey: 'chinese'),
                ParameterOption(id: 'russian', translationKey: 'russian'),
                ParameterOption(id: 'arabic', translationKey: 'arabic'),
              ],
              defaultDropdown: 'english',
            ),
          ],
        ),

        // Aba de verificação gramatical
        ToolTab(
          id: 'grammar',
          translationKey: 'grammar_check',
          icon: Icons.spellcheck,
          promptTemplate:
              '{check_grammar_spelling}. {use_language_for_explanations}. {list_errors_suggest_corrections}:\n\n{input_text}',
          parameters: [],
        ),
      ],
    );
  }
}
