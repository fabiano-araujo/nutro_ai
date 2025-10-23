import 'package:flutter/material.dart';
import '../generic_ai_screen.dart';

class EssayHelperToolConfig {
  static ToolConfig getConfig() {
    return ToolConfig(
      titleTranslationKey: 'essay_helper',
      tabs: [
        // Aba de Aprimorar texto
        ToolTab(
          id: 'enhance',
          translationKey: 'enhance',
          icon: Icons.auto_awesome,
          promptTemplate:
              '{enhance_following_text}: {input_text}. {use_style} {style} {with_tone} {tone} {appropriate_for} {target_audience}.',
          parameters: [
            ToolParameter(
              id: 'style',
              translationKey: 'writing_style',
              type: ParameterType.dropdown,
              options: [
                ParameterOption(
                    id: 'academic', translationKey: 'academic_style'),
                ParameterOption(
                    id: 'creative', translationKey: 'creative_style'),
                ParameterOption(
                    id: 'technical', translationKey: 'technical_style'),
                ParameterOption(
                    id: 'journalistic', translationKey: 'journalistic_style'),
                ParameterOption(
                    id: 'persuasive', translationKey: 'persuasive_style'),
              ],
              defaultDropdown: 'academic',
            ),
            ToolParameter(
              id: 'tone',
              translationKey: 'writing_tone',
              type: ParameterType.dropdown,
              options: [
                ParameterOption(id: 'formal', translationKey: 'formal_tone'),
                ParameterOption(id: 'neutral', translationKey: 'neutral_tone'),
                ParameterOption(
                    id: 'friendly', translationKey: 'friendly_tone'),
                ParameterOption(
                    id: 'enthusiastic', translationKey: 'enthusiastic_tone'),
                ParameterOption(
                    id: 'professional', translationKey: 'professional_tone'),
              ],
              defaultDropdown: 'neutral',
            ),
            ToolParameter(
              id: 'target_audience',
              translationKey: 'target_audience',
              type: ParameterType.dropdown,
              options: [
                ParameterOption(
                    id: 'general', translationKey: 'general_audience'),
                ParameterOption(
                    id: 'academic', translationKey: 'academic_audience'),
                ParameterOption(
                    id: 'children', translationKey: 'children_audience'),
                ParameterOption(id: 'youth', translationKey: 'youth_audience'),
                ParameterOption(
                    id: 'professional',
                    translationKey: 'professional_audience'),
              ],
              defaultDropdown: 'general',
            ),
          ],
        ),

        // Aba de Parafrasear
        ToolTab(
          id: 'paraphrase',
          translationKey: 'paraphrase',
          icon: Icons.repeat,
          promptTemplate:
              '{paraphrase_following_text}: {input_text}. {use_level} {paraphrase_level} {of_change}, {keeping_original_meaning}.',
          parameters: [
            ToolParameter(
              id: 'paraphrase_level',
              translationKey: 'paraphrase_level',
              type: ParameterType.dropdown,
              options: [
                ParameterOption(
                    id: 'light', translationKey: 'light_paraphrase'),
                ParameterOption(
                    id: 'moderate', translationKey: 'moderate_paraphrase'),
                ParameterOption(
                    id: 'substantial',
                    translationKey: 'substantial_paraphrase'),
              ],
              defaultDropdown: 'moderate',
            ),
          ],
        ),

        // Aba de Simplificar
        ToolTab(
          id: 'simplify',
          translationKey: 'simplify',
          icon: Icons.tune,
          promptTemplate:
              '{simplify_following_text}: {input_text}. {reduce_to_reading_level} {reading_level}, {keeping_main_ideas}.',
          parameters: [
            ToolParameter(
              id: 'reading_level',
              translationKey: 'reading_level',
              type: ParameterType.dropdown,
              options: [
                ParameterOption(
                    id: 'elementary', translationKey: 'elementary_level'),
                ParameterOption(
                    id: 'middle_school', translationKey: 'middle_school_level'),
                ParameterOption(
                    id: 'high_school', translationKey: 'high_school_level'),
                ParameterOption(id: 'college', translationKey: 'college_level'),
              ],
              defaultDropdown: 'middle_school',
            ),
          ],
        ),

        // Aba de Continuar escrevendo
        ToolTab(
          id: 'continue',
          translationKey: 'continue_writing',
          icon: Icons.arrow_forward,
          promptTemplate:
              '{continue_writing_from_text}: {input_text}. {add_approximately} {additional_paragraphs} {maintaining_style_tone}.',
          parameters: [
            ToolParameter(
              id: 'additional_paragraphs',
              translationKey: 'additional_paragraphs',
              type: ParameterType.dropdown,
              options: [
                ParameterOption(id: '1', translationKey: 'one_paragraph'),
                ParameterOption(id: '2', translationKey: 'two_paragraphs'),
                ParameterOption(id: '3', translationKey: 'three_paragraphs'),
                ParameterOption(id: '5', translationKey: 'five_paragraphs'),
              ],
              defaultDropdown: '2',
            ),
          ],
        ),

        // Aba de Encurtar
        ToolTab(
          id: 'shorten',
          translationKey: 'shorten',
          icon: Icons.compress,
          promptTemplate:
              '{shorten_following_text}: {input_text}. {reduce_to_approximately} {target_length} {of_original_text}, {preserving_important_information}.',
          parameters: [
            ToolParameter(
              id: 'target_length',
              translationKey: 'target_length',
              type: ParameterType.dropdown,
              options: [
                ParameterOption(id: '25', translationKey: 'quarter_length'),
                ParameterOption(id: '50', translationKey: 'half_length'),
                ParameterOption(
                    id: '75', translationKey: 'three_quarters_length'),
              ],
              defaultDropdown: '50',
            ),
          ],
        ),

        // Aba de Expandir
        ToolTab(
          id: 'expand',
          translationKey: 'expand',
          icon: Icons.expand,
          promptTemplate:
              '{expand_following_text}: {input_text}. {add} {expansion_type} {to_enrich_content}.',
          parameters: [
            ToolParameter(
              id: 'expansion_type',
              translationKey: 'expansion_type',
              type: ParameterType.dropdown,
              options: [
                ParameterOption(id: 'examples', translationKey: 'examples'),
                ParameterOption(id: 'details', translationKey: 'details'),
                ParameterOption(id: 'statistics', translationKey: 'statistics'),
                ParameterOption(
                    id: 'explanations', translationKey: 'explanations'),
                ParameterOption(id: 'quotes', translationKey: 'quotes'),
              ],
              defaultDropdown: 'details',
            ),
          ],
        ),
      ],
    );
  }
}
