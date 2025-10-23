import 'package:flutter/material.dart';
import '../generic_ai_screen.dart';

class SummarizerToolConfig {
  static ToolConfig getConfig() {
    return ToolConfig(
      titleTranslationKey: 'document_summary',
      tabs: [
        // Aba de Resumidor de texto
        ToolTab(
          id: 'text_summary',
          translationKey: 'text_summary',
          icon: Icons.article,
          promptTemplate:
              'Faça um resumo {summary_length} do seguinte texto: {input_text}. Mantenha as principais ideias e conceitos.',
          parameters: [
            ToolParameter(
              id: 'summary_length',
              translationKey: 'summary_length',
              type: ParameterType.dropdown,
              options: [
                ParameterOption(id: 'short', translationKey: 'short_summary'),
                ParameterOption(id: 'medium', translationKey: 'medium_summary'),
                ParameterOption(
                    id: 'detailed', translationKey: 'detailed_summary'),
              ],
              defaultDropdown: 'medium',
            ),
          ],
        ),

        // Aba de Resumidor de livros
        ToolTab(
          id: 'book_summary',
          translationKey: 'book_summary',
          icon: Icons.menu_book,
          promptTemplate:
              'Crie um resumo {summary_type} do seguinte livro ou capítulo: {input_text}. Organize o resumo por {organization_type}.',
          parameters: [
            ToolParameter(
              id: 'summary_type',
              translationKey: 'summary_type',
              type: ParameterType.dropdown,
              options: [
                ParameterOption(id: 'plot', translationKey: 'plot_summary'),
                ParameterOption(
                    id: 'academic', translationKey: 'academic_summary'),
                ParameterOption(
                    id: 'critical', translationKey: 'critical_summary'),
                ParameterOption(
                    id: 'character', translationKey: 'character_summary'),
              ],
              defaultDropdown: 'plot',
            ),
            ToolParameter(
              id: 'organization_type',
              translationKey: 'organization_type',
              type: ParameterType.dropdown,
              options: [
                ParameterOption(id: 'chapters', translationKey: 'by_chapters'),
                ParameterOption(id: 'themes', translationKey: 'by_themes'),
                ParameterOption(id: 'events', translationKey: 'by_events'),
                ParameterOption(
                    id: 'characters', translationKey: 'by_characters'),
              ],
              defaultDropdown: 'chapters',
            ),
          ],
        ),

        // Aba de Extrator de palavras-chave
        ToolTab(
          id: 'keyword_extractor',
          translationKey: 'keyword_extractor',
          icon: Icons.key,
          promptTemplate:
              'Extraia as {keyword_count} palavras-chave mais importantes do seguinte texto: {input_text}. {include_explanation}.',
          parameters: [
            ToolParameter(
              id: 'keyword_count',
              translationKey: 'keyword_count',
              type: ParameterType.dropdown,
              options: [
                ParameterOption(id: '5', translationKey: 'five_keywords'),
                ParameterOption(id: '10', translationKey: 'ten_keywords'),
                ParameterOption(id: '15', translationKey: 'fifteen_keywords'),
                ParameterOption(id: '20', translationKey: 'twenty_keywords'),
              ],
              defaultDropdown: '10',
            ),
            ToolParameter(
              id: 'include_explanation',
              translationKey: 'include_explanation',
              type: ParameterType.toggle,
              defaultToggle: true,
            ),
          ],
        ),
      ],
    );
  }
}
