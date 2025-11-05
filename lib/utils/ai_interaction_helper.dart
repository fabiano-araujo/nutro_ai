import 'dart:async';
import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../models/study_item.dart';
import '../widgets/message_notifier.dart';
import '../utils/conversation_helper.dart';
import 'package:provider/provider.dart';
import '../i18n/language_controller.dart'; // Importar para obter o título traduzido
import '../i18n/app_localizations.dart';
import 'dart:convert';
import 'dart:math' as math;
import '../utils/food_json_parser.dart';
import '../providers/daily_meals_provider.dart';
import '../models/meal_model.dart';

class AIInteractionHelper {
  /// Lida com o stream de resposta da IA, atualiza o notifier e salva no histórico.
  static StreamSubscription handleAIStream({
    required BuildContext
        context, // Necessário para AppLocalizations e ConversationHelper
    required Stream<String> aiStream,
    required MessageNotifier messageNotifier,
    required List<Map<String, dynamic>> messages, // Lista mutável
    required int streamingMessageIndex,
    required StorageService storageService,
    required String? currentConversationId,
    required String studyItemType, // 'tutor' ou 'image_analysis'
    // Callbacks para atualizar o estado da AITutorScreen
    required Function(bool) setLoading,
    required Function(String?) setConversationId,
    required Function(int?) setStreamingIndex,
    required Function(bool) setProcessingMedia, // Específico para imagem
    // Novo callback para rastrear o ID da conexão
    Function(String?)? setConnectionId,
    String? toolDataJson, // NOVO PARÂMETRO
  }) {
    int receivedChunks = 0;
    String acumuladoAtual = '';
    StreamSubscription? subscription;
    String? activeConnectionId;

    subscription = aiStream.listen(
      (chunk) {
        receivedChunks++;

        // Debug: mostrar o chunk recebido para análise com tag específica para rastreamento de conexão
        print('[ID_CONEXAO] Recebido chunk: ${chunk.length} bytes');
        print(
            '[ID_CONEXAO] Primeiros 100 chars: ${chunk.substring(0, math.min(100, chunk.length))}');

        // Verifica se o chunk contém o marcador especial de conexão
        if (chunk.contains('[CONEXAO_ID]')) {
          try {
            print('[ID_CONEXAO] ✨ Detectado marcador de conexão especial!');
            final marcadorIndex = chunk.indexOf('[CONEXAO_ID]');
            // Extrai o ID de conexão após o marcador
            final connectionId = chunk
                .substring(marcadorIndex + 12); // 12 = tamanho de [CONEXAO_ID]

            print(
                '[ID_CONEXAO] 🔑 ID obtido pelo marcador especial: $connectionId');

            activeConnectionId = connectionId;

            // Chamar o callback para armazenar o ID da conexão no controller
            if (setConnectionId != null) {
              setConnectionId(activeConnectionId);
              print(
                  '[ID_CONEXAO] ✅ ID da conexão enviado para o controller via marcador especial');
            } else {
              print(
                  '[ID_CONEXAO] ⚠️ Callback setConnectionId não fornecido (marcador especial)');
            }

            // Remover o marcador do chunk para não exibi-lo para o usuário
            chunk = chunk.replaceAll('[CONEXAO_ID]$connectionId', '');
            if (chunk.isEmpty) {
              return; // Se o chunk ficou vazio, não processá-lo mais
            }
          } catch (e) {
            print('[ID_CONEXAO] ❌ Erro ao processar marcador especial: $e');
          }
        }

        // Verificar se o chunk contém informações sobre o ID da conexão
        // O formato do SSE envia eventos como "data: {...}"
        try {
          if (chunk.trim().startsWith('data: ')) {
            // Extrair e analisar o JSON
            final jsonString = chunk.trim().substring(6);
            print('[ID_CONEXAO] JSON string: $jsonString');

            try {
              final jsonData = jsonDecode(jsonString);
              print('[ID_CONEXAO] Dados JSON: $jsonData');

              // Verificar se contém status e connectionId
              if (jsonData.containsKey('status') &&
                  jsonData['status'] == 'conectado' &&
                  jsonData.containsKey('connectionId')) {
                activeConnectionId = jsonData['connectionId'];
                print('[ID_CONEXAO] ID da conexão obtido: $activeConnectionId');

                // Chamar o callback para armazenar o ID da conexão no controller
                if (setConnectionId != null) {
                  setConnectionId(activeConnectionId);
                  print('[ID_CONEXAO] ID da conexão enviado para o controller');
                  print('[ID_CONEXAO] Valor enviado: $activeConnectionId');
                } else {
                  print('[ID_CONEXAO] Callback setConnectionId não fornecido');
                }

                // Não adicionar este chunk à resposta
                return;
              } else {
                print(
                    '[ID_CONEXAO] Evento sem ID de conexão ou com formato diferente');
                // Debug de todos os campos
                if (jsonData.containsKey('status')) {
                  print('[ID_CONEXAO] Status: ${jsonData['status']}');
                }
                if (jsonData.containsKey('connectionId')) {
                  print(
                      '[ID_CONEXAO] ConnectionId: ${jsonData['connectionId']}');
                }
              }

              // Se for um evento de texto, extrair e adicionar
              if (jsonData.containsKey('text') && jsonData['text'] != null) {
                final textContent = jsonData['text'];
                acumuladoAtual += textContent;

                // Atualizar notificador
                messageNotifier.updateMessage(acumuladoAtual);

                // Log a cada 5 chunks para não sobrecarregar o console
                if (receivedChunks % 5 == 0) {
                  print(
                      '📨 AIInteractionHelper - Chunk #$receivedChunks recebido (stream: ${aiStream.hashCode})');
                }

                // Não continuar processando este chunk
                return;
              }
            } catch (e) {
              print('[ID_CONEXAO] Erro ao decodificar JSON: $e');
              print('[ID_CONEXAO] String problemática: $jsonString');
            }
          } else {
            // Padrão antigo - apenas adicionar o chunk diretamente
            acumuladoAtual += chunk;

            // Log a cada 5 chunks para não sobrecarregar o console
            if (receivedChunks % 5 == 0 || chunk.contains('\n')) {
              print(
                  '📨 AIInteractionHelper - Chunk #$receivedChunks recebido (modo legado - stream: ${aiStream.hashCode})');
            }

            // Atualizar apenas o notificador
            messageNotifier.updateMessage(acumuladoAtual);
          }
        } catch (e) {
          // Em caso de erro, tratamos como um chunk normal
          print('[ID_CONEXAO] Erro ao processar chunk: $e');
          acumuladoAtual += chunk;
          messageNotifier.updateMessage(acumuladoAtual);
        }
      },
      onDone: () async {
        print(
            '✅ AIInteractionHelper - Streaming concluído (stream: ${aiStream.hashCode}), total de $receivedChunks chunks');

        final responseContent = messageNotifier.message;
        print(
            '📊 AIInteractionHelper - Resposta final: ${responseContent.length} caracteres');

        // Detectar e adicionar alimentos automaticamente se houver JSON
        if (FoodJsonParser.containsFoodJson(responseContent)) {
          print('🍽️ AIInteractionHelper - JSON de alimentos detectado na resposta');
          try {
            final jsonStr = FoodJsonParser.extractFoodJson(responseContent);
            if (jsonStr != null) {
              final foods = FoodJsonParser.parseFoodJson(jsonStr);
              if (foods != null && foods.isNotEmpty) {
                // Obter o provider de refeições
                if (context.mounted) {
                  final mealsProvider = Provider.of<DailyMealsProvider>(context, listen: false);

                  // Adicionar cada alimento como refeição livre
                  for (final food in foods) {
                    mealsProvider.addFoodToMeal(MealType.freeMeal, food);
                    print('🍽️ AIInteractionHelper - Alimento adicionado: ${food.name}');
                  }

                  print('✅ AIInteractionHelper - ${foods.length} alimentos adicionados automaticamente');
                }
              }
            }
          } catch (e) {
            print('❌ AIInteractionHelper - Erro ao processar JSON de alimentos: $e');
          }
        }

        // Marcar que não está mais em streaming
        messageNotifier.setStreaming(false);

        // Atualizar o estado na AITutorScreen via callbacks
        setLoading(false);
        if (studyItemType == 'image_analysis') {
          setProcessingMedia(false);
        }

        // Garantir que a mensagem seja adequadamente armazenada no histórico local
        // Devemos verificar se o índice ainda é válido e se a mensagem existe
        if (streamingMessageIndex < messages.length &&
            messages[streamingMessageIndex]['notifier'] == messageNotifier) {
          // Converter de notificador para mensagem normal na lista local
          messages[streamingMessageIndex] = {
            'isUser': false,
            'message': responseContent,
            'timestamp': messages[streamingMessageIndex]['timestamp'],
          };
        } else {
          print(
              '⚠️ AIInteractionHelper - Índice de streaming ($streamingMessageIndex) inválido ou notifier diferente ao concluir. Não atualizando a lista local diretamente.');
          // Considerar adicionar a mensagem se ela não existir mais no índice esperado.
        }

        // Compilar e salvar no histórico
        try {
          StudyItem studyItem;

          if (toolDataJson != null && toolDataJson.isNotEmpty) {
            final Map<String, dynamic> toolData = jsonDecode(toolDataJson);

            String toolName = toolData['toolName'] as String? ??
                (context.mounted
                    ? AppLocalizations.of(context).translate('ai_tool')
                    : 'AI Tool');
            String userInput = toolData['userInput'] as String? ?? '';

            // Sempre dar prioridade ao sourceType da ferramenta se existir
            String itemType = toolData['sourceType'] as String? ?? '';
            if (itemType.isEmpty) {
              String? toolNameForType = toolData['toolName'] as String?;
              if (toolNameForType != null && toolNameForType.isNotEmpty) {
                itemType = toolNameForType.toLowerCase().replaceAll(' ', '_');
              }
            }
            // Fallback garantido para o tipo
            if (itemType.isEmpty) {
              itemType = 'tool_interaction'; // Fallback absoluto para o tipo
            }

            // NOVO: Salvar o conversationId no toolData para recuperação futura
            String studyItemId =
                currentConversationId ?? UniqueKey().toString();

            // Atualizar toolData para incluir o conversationId
            toolData['conversationId'] = studyItemId;

            // NOVO: Compilar e adicionar o histórico completo da conversa ao toolData
            try {
              final compiledData =
                  ConversationHelper.compileConversationMessages(messages);
              final userContent = compiledData['userContent'] ?? '';
              final aiResponse = compiledData['aiResponse'] ?? '';

              // Adicionar histórico completo ao toolData
              toolData['conversationHistory'] = {
                'userContent': userContent,
                'aiResponse': aiResponse,
                'messages': messages.map((msg) {
                  // Criar uma cópia limpa das mensagens (sem notifiers)
                  final newMsg = <String, dynamic>{
                    'isUser': msg['isUser'],
                    'timestamp': msg['timestamp'].toIso8601String(),
                  };

                  // Adicionar a mensagem real
                  if (msg.containsKey('message')) {
                    newMsg['message'] = msg['message'];
                  } else if (msg.containsKey('notifier')) {
                    newMsg['message'] = msg['notifier'].message;
                  }

                  // Adicionar informações de imagem se existir
                  if (msg.containsKey('hasImage') && msg['hasImage'] == true) {
                    newMsg['hasImage'] = true;
                    // Não incluir os bytes da imagem no histórico para não sobrecarregar
                    newMsg['hasImageReference'] = true;
                  }

                  return newMsg;
                }).toList(),
              };

              print(
                  '💾 AIInteractionHelper - Adicionado histórico completo ao toolData com ${messages.length} mensagens');
            } catch (e) {
              print(
                  '⚠️ AIInteractionHelper - Erro ao compilar histórico para toolData: $e');
            }

            // Recodificar o toolData atualizado
            String updatedToolDataJson = jsonEncode(toolData);

            studyItem = StudyItem(
              id: studyItemId, // Usar o ID da conversa ou gerar um novo
              title: toolName, // Título do StudyItem é o nome da ferramenta
              content:
                  updatedToolDataJson, // JSON atualizado com conversationId e histórico
              response: responseContent,
              type: itemType,
              timestamp: messages.isNotEmpty &&
                      messages.length > streamingMessageIndex &&
                      messages[streamingMessageIndex].containsKey('timestamp')
                  ? messages[streamingMessageIndex]['timestamp'] as DateTime
                  : DateTime.now(),
            );
            print(
                '💾 AIInteractionHelper - Salvando StudyItem originado de FERRAMENTA: type=$itemType, title=$toolName (userInput: $userInput) com conversationId=$studyItemId');
          } else {
            final compiledData =
                ConversationHelper.compileConversationMessages(messages);
            final userContent = compiledData['userContent'] ?? '';
            final aiResponse = compiledData['aiResponse'] ?? '';

            String title = (context.mounted
                ? AppLocalizations.of(context).translate('ai_tutor_chat_title')
                : 'AI Tutor Chat');
            if (studyItemType == 'image_analysis') {
              try {
                if (context.mounted) {
                  title = AppLocalizations.of(context)
                          .translate('image_analysis') ??
                      'Image Analysis';
                } else {
                  title = 'Image Analysis';
                }
              } catch (e) {
                print(
                    "⚠️ AIInteractionHelper - Erro ao obter título traduzido para image_analysis: $e");
                title = 'Image Analysis'; // Fallback
              }
            }
            // Garantir que o título não seja nulo ou vazio
            if (title.isEmpty) {
              title = studyItemType == 'image_analysis'
                  ? 'Image Analysis'
                  : 'AI Tutor Chat';
            }

            studyItem = StudyItem(
              id: currentConversationId, // Usar o ID da conversa atual se disponível
              title: title,
              content: userContent,
              response: aiResponse,
              type: studyItemType,
              timestamp: messages.isNotEmpty &&
                      messages.length > streamingMessageIndex &&
                      messages[streamingMessageIndex].containsKey('timestamp')
                  ? messages[streamingMessageIndex]['timestamp'] as DateTime
                  : DateTime.now(),
            );
            print(
                '💾 AIInteractionHelper - Salvando StudyItem de CHAT/IMAGEM normal: type=$studyItemType, title=$title');
          }

          await storageService.saveToHistory(studyItem);
          print(
              '💾 AIInteractionHelper - Conversa salva no histórico com ID: ${studyItem.id}');

          // Atualizar o ID da conversa atual apenas se for uma nova conversa
          if (currentConversationId == null) {
            setConversationId(studyItem.id);
          }
        } catch (e) {
          print(
              '❌ AIInteractionHelper - Erro ao compilar ou salvar histórico: $e');
          // Não mostrar erro direto ao usuário aqui, talvez logar?
        }

        // Limpar o índice de streaming
        setStreamingIndex(null);
      },
      onError: (error) {
        print(
            '❌ AIInteractionHelper - Erro durante streaming (stream: ${aiStream.hashCode}): $error');

        // Mensagem de erro genérica para o usuário
        messageNotifier.setError(true,
            'Desculpe, ocorreu um erro durante a comunicação. Por favor, tente novamente.');

        // Atualizar o estado na AITutorScreen via callbacks
        setLoading(false);
        if (studyItemType == 'image_analysis') {
          setProcessingMedia(false);
        }
        // Não limpar o streaming index aqui, pois a mensagem de erro está visível
      },
      cancelOnError: true, // Cancelar a inscrição em caso de erro
    );

    return subscription;
  }
}
