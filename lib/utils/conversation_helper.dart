import 'package:flutter/material.dart';

import '../i18n/app_localizations.dart';
import '../main.dart';
import '../models/study_item.dart';
import '../services/storage_service.dart';
import 'dart:convert';

/// Classe utilitária para gerenciar conversas e seus formatos
class ConversationHelper {
  // Marcadores para separar corretamente as mensagens
  static const String userContentMarker = "###USER_MESSAGE###";
  static const String aiResponseMarker = "###AI_RESPONSE###";

  /// Extrai mensagens do usuário e da IA a partir do formato antigo
  static List<Map<String, dynamic>> extractMessagesFromOldFormat(
      StudyItem item) {
    List<Map<String, dynamic>> conversationMessages = [];

    // Dividir por parágrafos
    List<String> userMessages = item.content
        .split('\n\n')
        .where((msg) => msg.trim().isNotEmpty)
        .toList();

    List<String> aiMessages = item.response
        .split('\n\n')
        .where((msg) => msg.trim().isNotEmpty)
        .toList();

    // Se houver apenas uma mensagem de cada lado, exibi-las como estão
    if (userMessages.length == 1 && aiMessages.length == 1) {
      // Adicionar mensagem do usuário
      conversationMessages.add({
        'isUser': true,
        'message': userMessages[0],
        'timestamp': item.timestamp,
      });

      // Adicionar resposta da IA
      conversationMessages.add({
        'isUser': false,
        'message': aiMessages[0],
        'timestamp': item.timestamp.add(Duration(milliseconds: 500)),
      });
    } else {
      // Tentar corresponder mensagens, mas com cuidado para não criar pares errados
      // Em caso de dúvida, mostramos todas as mensagens do usuário primeiro, depois as respostas

      // Adicionar mensagens do usuário
      for (int i = 0; i < userMessages.length; i++) {
        conversationMessages.add({
          'isUser': true,
          'message': userMessages[i],
          'timestamp': item.timestamp.add(Duration(milliseconds: i * 500)),
        });
      }

      // Adicionar respostas da IA
      for (int i = 0; i < aiMessages.length; i++) {
        conversationMessages.add({
          'isUser': false,
          'message': aiMessages[i],
          'timestamp': item.timestamp
              .add(Duration(milliseconds: (userMessages.length + i) * 500)),
        });
      }
    }

    return conversationMessages;
  }

  /// Extrai mensagens do usuário e da IA a partir do formato com marcadores
  static List<Map<String, dynamic>> extractMessagesFromMarkedFormat(
      StudyItem item) {
    List<Map<String, dynamic>> conversationMessages = [];

    List<String> userMessages = item.content
        .split(userContentMarker)
        .where((msg) => msg.trim().isNotEmpty)
        .toList();

    List<String> aiMessages = item.response
        .split(aiResponseMarker)
        .where((msg) => msg.trim().isNotEmpty)
        .toList();

    // Garantir que temos o mesmo número de mensagens
    final int minLength = userMessages.length < aiMessages.length
        ? userMessages.length
        : aiMessages.length;

    for (int i = 0; i < minLength; i++) {
      // Adicionar mensagem do usuário
      conversationMessages.add({
        'isUser': true,
        'message': userMessages[i].trim(),
        'timestamp': item.timestamp.add(Duration(milliseconds: i * 500)),
      });

      // Adicionar resposta da IA
      conversationMessages.add({
        'isUser': false,
        'message': aiMessages[i].trim(),
        'timestamp': item.timestamp.add(Duration(milliseconds: i * 500 + 250)),
      });
    }

    return conversationMessages;
  }

  /// Compila as mensagens da conversa para armazenamento
  static Map<String, String> compileConversationMessages(
      List<Map<String, dynamic>> messages) {
    String userContent = '';
    String aiResponse = '';

    // Criar listas para mensagens do usuário e da IA
    List<String> userMessages = [];
    List<String> aiMessages = [];

    // Percorrer todas as mensagens para compilar o conteúdo completo
    int currentUserMessage = -1;

    for (var msg in messages) {
      if (msg['isUser'] == true) {
        currentUserMessage++;
        // Se não existir uma entrada para este índice, adicione-a
        if (userMessages.length <= currentUserMessage) {
          userMessages.add("");
          aiMessages.add("");
        }

        String messageText = msg['message'] ?? '';
        if (msg.containsKey('hasImage') && msg['hasImage'] == true) {
          final context = navigatorKey.currentContext;
          final localizations = context == null
              ? AppLocalizations(const Locale('pt', 'BR'))
              : AppLocalizations.of(context);
          messageText = localizations
              .translate('image_sent_message')
              .replaceAll('{message}', messageText);
        }

        userMessages[currentUserMessage] = messageText;
      } else {
        // Pegar o conteúdo da mensagem da IA
        String content = '';
        if (msg.containsKey('message')) {
          content = msg['message'];
        } else if (msg.containsKey('notifier')) {
          var notifier = msg['notifier'];
          if (notifier != null) {
            content = notifier.message;
          }
        }

        // Se tivermos uma mensagem válida e um índice de usuário válido
        if (content.isNotEmpty &&
            currentUserMessage >= 0 &&
            currentUserMessage < aiMessages.length) {
          aiMessages[currentUserMessage] = content;
        }
      }
    }

    // Construir as strings finais usando os marcadores
    for (int i = 0; i < userMessages.length; i++) {
      if (userMessages[i].isNotEmpty) {
        userContent += userContentMarker + userMessages[i] + "\n\n";
      }

      if (aiMessages[i].isNotEmpty) {
        aiResponse += aiResponseMarker + aiMessages[i] + "\n\n";
      }
    }

    return {
      'userContent': userContent.trim(),
      'aiResponse': aiResponse.trim(),
    };
  }

  /// Carrega e analisa uma conversa do armazenamento.
  ///
  /// Retorna a lista de mensagens formatada ou null se a conversa não for encontrada.
  static Future<List<Map<String, dynamic>>?> loadAndParseConversation(
      String conversationId, StorageService storageService) async {
    print(
        '📂 ConversationHelper - Carregando conversa com ID: $conversationId');
    try {
      // Tentar carregar a conversa do armazenamento
      final StudyItem? item = await storageService.getItemById(conversationId);

      if (item != null) {
        print('📄 ConversationHelper - Item encontrado, analisando formato...');

        // NOVO: Verificar se é um JSON de ferramenta com histórico
        if (item.content.startsWith('{') && item.content.endsWith('}')) {
          try {
            Map<String, dynamic> toolData = Map<String, dynamic>.from(
                (item.content.isEmpty) ? {} : jsonDecode(item.content));

            if (toolData.containsKey('conversationHistory')) {
              print(
                  '✅ ConversationHelper - Histórico da ferramenta detectado. Extraindo...');
              return extractMessagesFromToolHistory(toolData);
            }
          } catch (e) {
            print(
                '⚠️ ConversationHelper - Erro ao analisar JSON da ferramenta: $e');
            // Continuar com as outras opções de extração
          }
        }

        // Verificar se estamos usando o formato novo ou antigo
        if (item.content.contains(ConversationHelper.userContentMarker) &&
            item.response.contains(ConversationHelper.aiResponseMarker)) {
          print('✅ ConversationHelper - Formato novo detectado. Extraindo...');
          // Novo formato - extrair usando marcadores
          return ConversationHelper.extractMessagesFromMarkedFormat(item);
        } else {
          print(
              '⚠️ ConversationHelper - Formato antigo detectado. Extraindo...');
          // Formato antigo - tentar dividir por parágrafos
          return ConversationHelper.extractMessagesFromOldFormat(item);
        }
      } else {
        print(
            '❓ ConversationHelper - Conversa não encontrada no armazenamento.');
        return null; // Conversa não encontrada
      }
    } catch (e) {
      print('❌ ConversationHelper - Erro ao carregar/analisar conversa: $e');
      return null; // Erro durante o carregamento
    }
  }

  /// Extrai mensagens do campo conversationHistory do JSON da ferramenta
  static List<Map<String, dynamic>>? extractMessagesFromToolHistory(
      Map<String, dynamic> toolData) {
    try {
      if (toolData.containsKey('conversationHistory') &&
          toolData['conversationHistory'] is Map<String, dynamic>) {
        // Log detalhado para depuração
        print('📋 ConversationHelper: Estrutura do conversationHistory:');
        print(
            '   - Chaves disponíveis: ${toolData['conversationHistory'].keys.toList()}');

        if (toolData['conversationHistory'].containsKey('messages')) {
          final rawMessages = toolData['conversationHistory']['messages'];

          if (rawMessages is List && rawMessages.isNotEmpty) {
            print(
                '📚 ConversationHelper: Encontradas ${rawMessages.length} mensagens no histórico');

            // Verificar primeiro elemento para diagnóstico
            if (rawMessages.isNotEmpty) {
              print('   - Primeira mensagem: ${rawMessages.first}');
            }

            // Converter para o formato esperado
            final messages = rawMessages
                .map((msg) {
                  // Garantir que estamos trabalhando com um Map
                  if (msg is! Map) {
                    print('⚠️ ConversationHelper: Mensagem não é um Map: $msg');
                    return null;
                  }

                  final Map<String, dynamic> message =
                      Map<String, dynamic>.from(msg);

                  // Verificar se a mensagem tem os campos obrigatórios
                  if (!message.containsKey('isUser') ||
                      !message.containsKey('message')) {
                    print(
                        '⚠️ ConversationHelper: Mensagem com formato inválido: $message');
                    return null;
                  }

                  // Converter timestamp de String para DateTime se necessário
                  if (message.containsKey('timestamp') &&
                      message['timestamp'] is String) {
                    try {
                      message['timestamp'] =
                          DateTime.parse(message['timestamp']);
                    } catch (e) {
                      print(
                          '⚠️ ConversationHelper: Erro ao converter timestamp: $e');
                      message['timestamp'] = DateTime.now();
                    }
                  } else if (!message.containsKey('timestamp')) {
                    message['timestamp'] = DateTime.now();
                  }

                  return message;
                })
                .where((msg) => msg != null) // Remover entradas nulas
                .toList()
                .cast<Map<String, dynamic>>();

            print(
                '✅ ConversationHelper: Processadas ${messages.length} mensagens válidas do toolData');

            // Ordenar por timestamp se necessário
            if (messages.length > 1) {
              messages.sort((a, b) => (a['timestamp'] as DateTime)
                  .compareTo(b['timestamp'] as DateTime));
            }

            return messages;
          } else {
            print(
                '⚠️ ConversationHelper: Campo "messages" vazio ou não é uma lista: $rawMessages');
          }
        } else {
          print(
              '⚠️ ConversationHelper: Campo "messages" não encontrado no conversationHistory');
        }
      } else {
        print(
            '⚠️ ConversationHelper: Formato de conversationHistory inválido ou ausente: ${toolData['conversationHistory']}');
      }
    } catch (e) {
      print(
          '❌ ConversationHelper - Erro ao extrair mensagens do histórico da ferramenta: $e');
    }

    return null;
  }
}
