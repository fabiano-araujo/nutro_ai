import 'package:flutter/material.dart';
import '../generic_ai_screen.dart';

class ContentGeneratorToolConfig {
  static ToolConfig getConfig() {
    return ToolConfig(
      titleTranslationKey: 'content_generator',
      tabs: [
        // Aba de Poema
        ToolTab(
          id: 'poem',
          translationKey: 'poem',
          icon: Icons.format_quote,
          promptTemplate:
              '{create_poem_style} {poem_style}, {with_emotion} {poem_emotion} {and_length} {poem_length} {about}: {input_text}. {use_language}.',
          parameters: [
            // Parâmetros específicos para poema
            ToolParameter(
              id: 'poem_style',
              translationKey: 'poem_style',
              type: ParameterType.dropdown,
              options: [
                ParameterOption(id: 'free_verse', translationKey: 'free_verse'),
                ParameterOption(id: 'sonnet', translationKey: 'sonnet'),
                ParameterOption(id: 'haiku', translationKey: 'haiku'),
                ParameterOption(id: 'limerick', translationKey: 'limerick'),
                ParameterOption(id: 'ballad', translationKey: 'ballad'),
                ParameterOption(id: 'acrostic', translationKey: 'acrostic'),
              ],
              defaultDropdown: 'free_verse',
            ),
            ToolParameter(
              id: 'poem_emotion',
              translationKey: 'poem_emotion',
              type: ParameterType.dropdown,
              options: [
                ParameterOption(id: 'joy', translationKey: 'joy'),
                ParameterOption(id: 'sadness', translationKey: 'sadness'),
                ParameterOption(id: 'love', translationKey: 'love'),
                ParameterOption(id: 'nostalgia', translationKey: 'nostalgia'),
                ParameterOption(id: 'anger', translationKey: 'anger'),
                ParameterOption(id: 'hope', translationKey: 'hope'),
              ],
              defaultDropdown: 'joy',
            ),
            ToolParameter(
              id: 'poem_length',
              translationKey: 'poem_length',
              type: ParameterType.dropdown,
              options: [
                ParameterOption(id: 'short', translationKey: 'short'),
                ParameterOption(id: 'medium', translationKey: 'medium'),
                ParameterOption(id: 'long', translationKey: 'long'),
              ],
              defaultDropdown: 'medium',
            ),
          ],
        ),

        // Aba de Roteiro
        ToolTab(
          id: 'script',
          translationKey: 'script',
          icon: Icons.movie,
          promptTemplate:
              '{create_script_for_audience} {script_target_audience}, {with_language_level} {script_language_level} {and_genre} {script_genre} {about}: {input_text}. {use_language}.',
          parameters: [
            // Parâmetros específicos para roteiro
            ToolParameter(
              id: 'script_target_audience',
              translationKey: 'script_target_audience',
              type: ParameterType.dropdown,
              options: [
                ParameterOption(
                    id: 'general', translationKey: 'general_audience'),
                ParameterOption(
                    id: 'children', translationKey: 'children_audience'),
                ParameterOption(id: 'youth', translationKey: 'youth_audience'),
                ParameterOption(id: 'adult', translationKey: 'adult_audience'),
                ParameterOption(
                    id: 'specialized', translationKey: 'specialized_audience'),
              ],
              defaultDropdown: 'general',
            ),
            ToolParameter(
              id: 'script_language_level',
              translationKey: 'script_language_level',
              type: ParameterType.dropdown,
              options: [
                ParameterOption(id: 'basic', translationKey: 'basic_level'),
                ParameterOption(
                    id: 'intermediate', translationKey: 'intermediate_level'),
                ParameterOption(
                    id: 'advanced', translationKey: 'advanced_level'),
                ParameterOption(id: 'expert', translationKey: 'expert_level'),
              ],
              defaultDropdown: 'intermediate',
            ),
            ToolParameter(
              id: 'script_genre',
              translationKey: 'script_genre',
              type: ParameterType.dropdown,
              options: [
                ParameterOption(id: 'drama', translationKey: 'drama_genre'),
                ParameterOption(id: 'comedy', translationKey: 'comedy_genre'),
                ParameterOption(id: 'action', translationKey: 'action_genre'),
                ParameterOption(id: 'romance', translationKey: 'romance_genre'),
                ParameterOption(id: 'horror', translationKey: 'horror_genre'),
                ParameterOption(
                    id: 'documentary', translationKey: 'documentary_genre'),
              ],
              defaultDropdown: 'drama',
            ),
          ],
        ),

        // Aba de Ensaio
        ToolTab(
          id: 'essay',
          translationKey: 'essay',
          icon: Icons.article,
          promptTemplate:
              '{create_essay_type} {essay_type} {with_structure} {essay_structure} {and_tone} {essay_tone} {about_theme}: {input_text}. {use_language}.',
          parameters: [
            // Parâmetros específicos para ensaio
            ToolParameter(
              id: 'essay_type',
              translationKey: 'essay_type',
              type: ParameterType.dropdown,
              options: [
                ParameterOption(
                    id: 'analytical', translationKey: 'analytical_essay'),
                ParameterOption(
                    id: 'argumentative', translationKey: 'argumentative_essay'),
                ParameterOption(
                    id: 'expository', translationKey: 'expository_essay'),
                ParameterOption(
                    id: 'narrative', translationKey: 'narrative_essay'),
                ParameterOption(
                    id: 'descriptive', translationKey: 'descriptive_essay'),
                ParameterOption(
                    id: 'persuasive', translationKey: 'persuasive_essay'),
              ],
              defaultDropdown: 'analytical',
            ),
            ToolParameter(
              id: 'essay_structure',
              translationKey: 'essay_structure',
              type: ParameterType.dropdown,
              options: [
                ParameterOption(
                    id: 'standard', translationKey: 'standard_structure'),
                ParameterOption(
                    id: 'thesis', translationKey: 'thesis_structure'),
                ParameterOption(
                    id: 'compare_contrast',
                    translationKey: 'compare_contrast_structure'),
                ParameterOption(
                    id: 'problem_solution',
                    translationKey: 'problem_solution_structure'),
                ParameterOption(
                    id: 'chronological',
                    translationKey: 'chronological_structure'),
              ],
              defaultDropdown: 'standard',
            ),
            ToolParameter(
              id: 'essay_tone',
              translationKey: 'essay_tone',
              type: ParameterType.dropdown,
              options: [
                ParameterOption(id: 'formal', translationKey: 'formal_tone'),
                ParameterOption(id: 'neutral', translationKey: 'neutral_tone'),
                ParameterOption(
                    id: 'critical', translationKey: 'critical_tone'),
                ParameterOption(
                    id: 'reflective', translationKey: 'reflective_tone'),
                ParameterOption(
                    id: 'academic', translationKey: 'academic_tone'),
              ],
              defaultDropdown: 'formal',
            ),
          ],
        ),

        // Aba de Blog
        ToolTab(
          id: 'blog',
          translationKey: 'blog',
          icon: Icons.rss_feed,
          promptTemplate:
              '{create_blog_article_with_tone} {blog_tone}, {for_audience} {blog_target_audience}, {with_language_level} {blog_language_level} {about_theme}: {input_text}. {use_language}.',
          parameters: [
            // Parâmetros específicos para blog
            ToolParameter(
              id: 'blog_tone',
              translationKey: 'blog_tone',
              type: ParameterType.dropdown,
              options: [
                ParameterOption(id: 'casual', translationKey: 'casual_tone'),
                ParameterOption(
                    id: 'professional', translationKey: 'professional_tone'),
                ParameterOption(
                    id: 'humorous', translationKey: 'humorous_tone'),
                ParameterOption(
                    id: 'informative', translationKey: 'informative_tone'),
                ParameterOption(
                    id: 'inspirational', translationKey: 'inspirational_tone'),
              ],
              defaultDropdown: 'casual',
            ),
            ToolParameter(
              id: 'blog_target_audience',
              translationKey: 'blog_target_audience',
              type: ParameterType.dropdown,
              options: [
                ParameterOption(
                    id: 'general', translationKey: 'general_audience'),
                ParameterOption(
                    id: 'business', translationKey: 'business_audience'),
                ParameterOption(
                    id: 'technical', translationKey: 'technical_audience'),
                ParameterOption(
                    id: 'academic', translationKey: 'academic_audience'),
                ParameterOption(id: 'youth', translationKey: 'youth_audience'),
              ],
              defaultDropdown: 'general',
            ),
            ToolParameter(
              id: 'blog_language_level',
              translationKey: 'blog_language_level',
              type: ParameterType.dropdown,
              options: [
                ParameterOption(id: 'basic', translationKey: 'basic_level'),
                ParameterOption(
                    id: 'intermediate', translationKey: 'intermediate_level'),
                ParameterOption(
                    id: 'advanced', translationKey: 'advanced_level'),
                ParameterOption(id: 'expert', translationKey: 'expert_level'),
              ],
              defaultDropdown: 'intermediate',
            ),
          ],
        ),
      ],
    );
  }
}
