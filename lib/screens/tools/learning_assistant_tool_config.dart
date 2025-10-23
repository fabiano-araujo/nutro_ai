import 'package:flutter/material.dart';
import '../generic_ai_screen.dart';

class LearningAssistantToolConfig {
  static ToolConfig getConfig() {
    return ToolConfig(
      titleTranslationKey: 'ai_tutor',
      tabs: [
        // Aba de Pergunte qualquer coisa
        ToolTab(
          id: 'ask_anything',
          translationKey: 'ask_anything',
          icon: Icons.question_answer,
          promptTemplate:
              '{answer_following_question}: {input_text}. {response_detail} {include_sources}',
          parameters: [
            ToolParameter(
              id: 'response_detail',
              translationKey: 'response_detail',
              type: ParameterType.dropdown,
              options: [
                ParameterOption(id: 'brief', translationKey: 'brief_response'),
                ParameterOption(
                    id: 'detailed', translationKey: 'detailed_response'),
                ParameterOption(
                    id: 'comprehensive',
                    translationKey: 'comprehensive_response'),
              ],
              defaultDropdown: 'detailed',
            ),
            ToolParameter(
              id: 'include_sources',
              translationKey: 'include_sources',
              type: ParameterType.toggle,
              defaultToggle: true,
            ),
          ],
        ),

        // Aba de Explique conceitos
        ToolTab(
          id: 'explain_concepts',
          translationKey: 'explain_concepts',
          icon: Icons.school,
          promptTemplate:
              '{explain_following_concept}: {input_text}. {use_explanation_level} {explanation_level} {and} {include_examples}. {include_related_concepts}',
          parameters: [
            ToolParameter(
              id: 'explanation_level',
              translationKey: 'explanation_level',
              type: ParameterType.dropdown,
              options: [
                ParameterOption(
                    id: 'beginner', translationKey: 'beginner_level'),
                ParameterOption(
                    id: 'intermediate', translationKey: 'intermediate_level'),
                ParameterOption(
                    id: 'advanced', translationKey: 'advanced_level'),
              ],
              defaultDropdown: 'intermediate',
            ),
            ToolParameter(
              id: 'include_examples',
              translationKey: 'include_examples',
              type: ParameterType.toggle,
              defaultToggle: true,
            ),
            ToolParameter(
              id: 'include_related_concepts',
              translationKey: 'include_related_concepts',
              type: ParameterType.toggle,
              defaultToggle: false,
            ),
          ],
        ),

        // Aba de Trivia interativa
        ToolTab(
          id: 'quiz_generator',
          translationKey: 'quiz_generator',
          icon: Icons.quiz,
          promptTemplate:
              '{generate_quiz_about}: {input_text}. {difficulty_should_be} {difficulty_level} {with} {question_count} {questions}. {show_answers_immediately}',
          parameters: [
            ToolParameter(
              id: 'difficulty_level',
              translationKey: 'difficulty_level',
              type: ParameterType.dropdown,
              options: [
                ParameterOption(id: 'easy', translationKey: 'easy_difficulty'),
                ParameterOption(
                    id: 'medium', translationKey: 'medium_difficulty'),
                ParameterOption(id: 'hard', translationKey: 'hard_difficulty'),
                ParameterOption(
                    id: 'mixed', translationKey: 'mixed_difficulty'),
              ],
              defaultDropdown: 'medium',
            ),
            ToolParameter(
              id: 'question_count',
              translationKey: 'question_count',
              type: ParameterType.dropdown,
              options: [
                ParameterOption(id: '3', translationKey: 'three_questions'),
                ParameterOption(id: '5', translationKey: 'five_questions'),
                ParameterOption(id: '10', translationKey: 'ten_questions'),
              ],
              defaultDropdown: '5',
            ),
            ToolParameter(
              id: 'show_answers_immediately',
              translationKey: 'show_answers_immediately',
              type: ParameterType.toggle,
              defaultToggle: false,
            ),
          ],
        ),
      ],
    );
  }
}
