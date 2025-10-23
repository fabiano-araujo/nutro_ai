import 'package:flutter/material.dart';
import '../screens/generic_ai_screen.dart';
import '../widgets/generic_ai_bottom_sheet.dart';

class AIBottomSheetExample extends StatelessWidget {
  const AIBottomSheetExample({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('AI Tools'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            // Exemplo de configuração para o BottomSheet de IA
            final toolConfig = ToolConfig(
              titleTranslationKey: 'ai_assistant',
              tabs: [
                ToolTab(
                  id: 'chat',
                  translationKey: 'chat',
                  icon: Icons.chat,
                  parameters: [
                    ToolParameter(
                      id: 'temperature',
                      translationKey: 'creativity',
                      type: ParameterType.slider,
                      minValue: 0.0,
                      maxValue: 1.0,
                      defaultValue: 0.7,
                    ),
                  ],
                  promptTemplate:
                      'Por favor responda: {input_text}\nTemperatura: {temperature}',
                ),
                ToolTab(
                  id: 'summarize',
                  translationKey: 'summarize',
                  icon: Icons.summarize,
                  parameters: [
                    ToolParameter(
                      id: 'length',
                      translationKey: 'summary_length',
                      type: ParameterType.dropdown,
                      options: [
                        ParameterOption(id: 'short', translationKey: 'short'),
                        ParameterOption(id: 'medium', translationKey: 'medium'),
                        ParameterOption(id: 'long', translationKey: 'long'),
                      ],
                      defaultDropdown: 'medium',
                    ),
                  ],
                  promptTemplate:
                      'Resuma o seguinte texto em um resumo {length}: {input_text}',
                ),
              ],
            );

            // Mostra o BottomSheet
            GenericAIBottomSheet.show(context, toolConfig);
          },
          child: Text('Abrir Assistente IA'),
        ),
      ),
    );
  }
}
