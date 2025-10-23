import 'package:flutter/material.dart';
import '../generic_ai_screen.dart';

class CodeEnhancerToolConfig {
  static ToolConfig getConfig() {
    return ToolConfig(
      titleTranslationKey: 'code_enhancer',
      tabs: [
        // Aba de Analisar código
        ToolTab(
          id: 'code_analysis',
          translationKey: 'code_analysis',
          icon: Icons.bar_chart,
          promptTemplate:
              'Analise o seguinte código: {input_text}. Forneça uma análise {analysis_depth} focando em {analysis_focus}.',
          parameters: [
            ToolParameter(
              id: 'analysis_depth',
              translationKey: 'analysis_depth',
              type: ParameterType.dropdown,
              options: [
                ParameterOption(id: 'basic', translationKey: 'basic_analysis'),
                ParameterOption(
                    id: 'intermediate',
                    translationKey: 'intermediate_analysis'),
                ParameterOption(
                    id: 'advanced', translationKey: 'advanced_analysis'),
              ],
              defaultDropdown: 'intermediate',
            ),
            ToolParameter(
              id: 'analysis_focus',
              translationKey: 'analysis_focus',
              type: ParameterType.dropdown,
              options: [
                ParameterOption(
                    id: 'structure', translationKey: 'code_structure'),
                ParameterOption(
                    id: 'performance', translationKey: 'code_performance'),
                ParameterOption(
                    id: 'readability', translationKey: 'code_readability'),
                ParameterOption(
                    id: 'security', translationKey: 'code_security'),
                ParameterOption(id: 'all', translationKey: 'all_aspects'),
              ],
              defaultDropdown: 'all',
            ),
          ],
        ),

        // Aba de Verificar código
        ToolTab(
          id: 'code_check',
          translationKey: 'code_check',
          icon: Icons.checklist,
          promptTemplate:
              'Verifique o seguinte código: {input_text}. Identifique {check_items} e {suggest_fixes}.',
          parameters: [
            ToolParameter(
              id: 'check_items',
              translationKey: 'check_items',
              type: ParameterType.dropdown,
              options: [
                ParameterOption(id: 'bugs', translationKey: 'bugs_check'),
                ParameterOption(id: 'style', translationKey: 'style_check'),
                ParameterOption(
                    id: 'best_practices',
                    translationKey: 'best_practices_check'),
                ParameterOption(
                    id: 'everything', translationKey: 'everything_check'),
              ],
              defaultDropdown: 'everything',
            ),
            ToolParameter(
              id: 'suggest_fixes',
              translationKey: 'suggest_fixes',
              type: ParameterType.toggle,
              defaultToggle: true,
            ),
          ],
        ),

        // Aba de Otimizar código
        ToolTab(
          id: 'code_optimize',
          translationKey: 'code_optimize',
          icon: Icons.auto_fix_high,
          promptTemplate:
              'Otimize o seguinte código: {input_text}. Foque na otimização de {optimization_focus} e {keep_comments}.',
          parameters: [
            ToolParameter(
              id: 'optimization_focus',
              translationKey: 'optimization_focus',
              type: ParameterType.dropdown,
              options: [
                ParameterOption(
                    id: 'performance', translationKey: 'performance_focus'),
                ParameterOption(
                    id: 'readability', translationKey: 'readability_focus'),
                ParameterOption(id: 'size', translationKey: 'code_size_focus'),
                ParameterOption(
                    id: 'balance', translationKey: 'balanced_focus'),
              ],
              defaultDropdown: 'balance',
            ),
            ToolParameter(
              id: 'keep_comments',
              translationKey: 'keep_comments',
              type: ParameterType.toggle,
              defaultToggle: true,
            ),
          ],
        ),
      ],
    );
  }
}
