import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'dart:developer' as developer;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../i18n/language_controller.dart';
import 'dart:async';
import '../services/api_service.dart'; // Importar para usar baseUrl
import '../util/app_constants.dart'; // Importar constantes

/// Serviço para interação com a API OpenAI.
/// Este serviço suporta comunicação com a API OpenAI para várias funcionalidades:
/// - Perguntas e respostas (Q&A)
/// - Processamento de imagens
/// - Transcrição de áudio
/// - Resumo de documentos
/// - Ajuda com código
///
/// Todas as respostas da IA são entregues no idioma do dispositivo,
/// utilizando o LanguageController para determinar o idioma atual.
class AIService {
  static const String _apiKey =
      "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";
  static const String _baseUrl = "https://api.openai.com/v1/chat/completions";
  static const String _model = "gpt-4o-mini";

  // Preços em dólares por 1000 tokens para diferentes modelos
  // Valores aproximados baseados na documentação da OpenAI
  static const Map<String, Map<String, double>> _modelCosts = {
    "gpt-4o-mini": {
      "input":
          0.00015, // $0.15 por milhão de tokens de input = $0.00015 por 1000 tokens
      "output":
          0.0006, // $0.60 por milhão de tokens de output = $0.0006 por 1000 tokens
    },
    "gpt-4o": {
      "input": 0.05, // $0.05 por 1000 tokens de input
      "output": 0.15, // $0.15 por 1000 tokens de output
    },
  };

  // Função para estimar o número de tokens em um texto
  // Esta é uma estimativa aproximada - para inglês: ~4 caracteres = 1 token
  // Para português e outros idiomas com acentos: ~3.5 caracteres = 1 token
  int estimateTokenCount(String text) {
    // Para português, divisão por 3.5 dá uma estimativa razoável
    return (text.length / 3.5).ceil();
  }

  // Calcula e registra o custo estimado de uma chamada de API
  void _logTokensAndCost(String promptText, String systemPrompt,
      int outputTokens, String methodName) {
    final inputTokensPrompt = estimateTokenCount(promptText);
    final inputTokensSystem = estimateTokenCount(systemPrompt);
    final totalInputTokens = inputTokensPrompt + inputTokensSystem;

    // Obter os custos por 1000 tokens para o modelo atual
    final costInfo = _modelCosts[_model] ?? {"input": 0.015, "output": 0.06};

    // Calcular custo do input e output
    final inputCost = (totalInputTokens / 1000) * costInfo["input"]!;
    final outputCost = (outputTokens / 1000) * costInfo["output"]!;
    final totalCost = inputCost + outputCost;

    print('💰 $methodName - ESTIMATIVA DE CUSTO:');
    print('   📊 Tokens de entrada (prompt): $inputTokensPrompt');
    print('   📊 Tokens de entrada (sistema): $inputTokensSystem');
    print('   📊 Total de tokens de entrada: $totalInputTokens');
    print('   📊 Tokens de saída (resposta): $outputTokens');
    print('   📊 Total de tokens: ${totalInputTokens + outputTokens}');
    print('   💵 Custo de entrada: \$${inputCost.toStringAsFixed(5)}');
    print('   💵 Custo de saída: \$${outputCost.toStringAsFixed(5)}');
    print('   💵 CUSTO TOTAL: \$${totalCost.toStringAsFixed(5)}');
  }

  // Headers for OpenAI API requests
  Map<String, String> get _headers => {
        'Content-Type': 'application/json; charset=utf-8',
        'Authorization': 'Bearer $_apiKey',
      };

  // Método auxiliar para obter o idioma atual do dispositivo
  String getCurrentLanguageCode(LanguageController? languageController) {
    if (languageController == null) {
      return 'pt_BR'; // Valor padrão se o controlador não estiver disponível
    }

    try {
      return languageController
          .localeToString(languageController.currentLocale);
    } catch (e) {
      print('❌ Erro ao obter código de idioma: $e');
      return 'pt_BR'; // Valor padrão em caso de erro
    }
  }

  // Get answer to a text question with streaming
  Stream<String> getAnswerStream(String question,
      {String subject = '',
      String languageCode = 'pt_BR',
      String quality = 'bom',
      String userId = '',
      String agentType = 'nutrition',
      String provider = ''}) async* {
    print('\n🚀 Iniciando nova solicitação de resposta');
    try {
      final systemContent =
          'Você é um assistente de estudos. Forneça respostas educativas claras. Use linguagem simples e clara. ' +
              (subject.isNotEmpty ? " O tópico é $subject." : "") +
              " Você deve responder no idioma: $languageCode";

      print('\n📤 PROMPT COMPLETO:');
      print('----------------------------------------');
      print('System: $systemContent');
      print('User: $question');
      print('UserId: $userId');
      print('----------------------------------------\n');

      // Calcular e registrar os tokens de entrada
      final inputTokensEstimate =
          estimateTokenCount(question) + estimateTokenCount(systemContent);
      print('📊 Tokens de entrada estimados: $inputTokensEstimate');

      // Registrar horário de início para medir tempo de resposta
      final startTime = DateTime.now();

      // Novo endpoint e configuração da requisição
      final endpoint = '${AppConstants.API_BASE_URL}/ai/generate-text';
      final request = http.Request('POST', Uri.parse(endpoint));
      request.headers.addAll({
        'Content-Type': 'application/json',
      });

      // Novo formato de corpo da requisição
      final requestBody = {
        'prompt': '$systemContent\n\nUsuário: $question',
        'temperature': 0.5,
        'model': quality, // Usar o parâmetro de qualidade passado
        'streaming': true,
        'userId': userId, // Adicionando o userId na requisição
        'agentType': agentType, // Tipo de agent a ser usado
      };

      // Adicionar provider se especificado
      if (provider.isNotEmpty) {
        requestBody['provider'] = provider;
      }

      request.body = jsonEncode(requestBody);

      print('🔄 Aguardando resposta da nova API...');
      final response = await http.Client().send(request);

      if (response.statusCode == 200) {
        print('✅ Conexão estabelecida, iniciando streaming');
        int chunkCount = 0;
        String allContent = '';

        // Formatação correta do stream de entrada para SSE
        final streamController = StreamController<String>();
        String buffer = '';

        response.stream.transform(utf8.decoder).listen(
          (chunk) {
            // Adicionar o novo chunk ao buffer
            buffer += chunk;

            print(
                '📥 AIService - Stream recebeu chunk: ${chunk.length} caracteres');
            if (chunk.length < 200) {
              print('📥 AIService - Conteúdo do chunk: $chunk');
            } else {
              print(
                  '📥 AIService - Primeiros 200 caracteres: ${chunk.substring(0, 200)}');
            }

            // Processar linhas completas (eventos SSE)
            while (buffer.contains('\n\n')) {
              final parts = buffer.split('\n\n');
              final event = parts[0];

              // Atualizar o buffer com o restante
              buffer = parts.sublist(1).join('\n\n');

              // Processar o evento se começar com "data: "
              if (event.trim().startsWith('data: ')) {
                final jsonString = event.trim().substring(6);
                try {
                  print('🔍 AIService - Analisando JSON: $jsonString');
                  final jsonData = jsonDecode(jsonString);
                  print('🔄 AIService - Dados JSON: $jsonData');

                  if (jsonData.containsKey('text') &&
                      jsonData['text'] != null) {
                    // Evento de texto
                    final content = jsonData['text'];
                    chunkCount++;
                    allContent += content;
                    streamController.add(content);

                    // Log a cada 20 chunks
                    if (chunkCount % 20 == 0) {
                      print('📦 Chunks recebidos: $chunkCount');
                    }
                  } else if (jsonData.containsKey('done') &&
                      jsonData['done'] == true) {
                    // Evento de conclusão
                    print('✅ Servidor indicou conclusão do streaming');
                  } else if (jsonData.containsKey('error')) {
                    // Evento de erro
                    print(
                        '❌ Erro reportado pelo servidor: ${jsonData['error']}');
                    streamController.add('\nErro: ${jsonData['error']}');
                  } else if (jsonData.containsKey('status')) {
                    // Evento de status
                    print(
                        '[CONEXAO_STATUS] Status do servidor: ${jsonData['status']}');

                    // Verificar se tem connectionId
                    if (jsonData.containsKey('connectionId')) {
                      final connectionId = jsonData['connectionId'];
                      print(
                          '[CONEXAO_STATUS] ✅ Recebido ID de conexão: $connectionId');
                      print(
                          '[CONEXAO_STATUS] Tipo: ${connectionId.runtimeType}');

                      // Enviar o connectionId de volta pelo streamController
                      // Isso permite que quem consome o stream possa extrair este valor
                      streamController.add('[CONEXAO_ID]' + connectionId);
                    } else {
                      print(
                          '[CONEXAO_STATUS] ❌ Não encontrou connectionId no evento status');
                      print('[CONEXAO_STATUS] JSON completo: $jsonData');
                    }
                  }
                } catch (e) {
                  print('❌ Erro ao processar evento SSE: $e');
                  print('Evento problemático: $event');
                }
              }
            }
          },
          onDone: () {
            // Quando a stream terminar, registrar estatísticas
            final duration = DateTime.now().difference(startTime);
            final outputTokens = estimateTokenCount(allContent);

            print('\n✅ Streaming concluído:');
            print('- Chunks totais: $chunkCount');
            print('- Tempo total: ${duration.inMilliseconds}ms');
            print('- Tokens na resposta: $outputTokens');
            print(
                '- Velocidade: ${(outputTokens / (duration.inMilliseconds / 1000)).round()} tokens/segundo\n');

            // Registrar custos estimados
            _logTokensAndCost(
                question, systemContent, outputTokens, 'getAnswerStream');

            // Fechar o controlador
            streamController.close();
          },
          onError: (error) {
            print('❌ Erro na stream: $error');
            streamController.addError(error);
            streamController.close();
          },
        );

        // Retornar a stream do controlador
        yield* streamController.stream;
      } else {
        final responseBody = await response.stream.bytesToString();
        final errorMsg =
            'Desculpe, ocorreu um erro ao processar sua solicitação. Por favor, tente novamente.';
        print('❌ $errorMsg');
        yield errorMsg;
      }
    } catch (e) {
      final errorMsg =
          'Desculpe, ocorreu um erro ao processar sua solicitação. Por favor, tente novamente.';
      print('❌ Erro ao processar a solicitação (getAnswer): $e');
      yield errorMsg;
    }
  }

  // Método de processamento de imagem com streaming
  Stream<String> processImageStream(Uint8List imageBytes, String prompt,
      {String languageCode = 'pt_BR',
      String quality = 'baixo',
      String userId = '',
      String agentType = 'nutrition'}) async* {
    print('\n🚀 Iniciando processamento de imagem com streaming');

    try {
      final imageBase64 = base64Encode(imageBytes);
      final systemContent =
          'Você é um assistente de estudos. Analise a imagem e forneça uma solução detalhada. Você deve responder no idioma: $languageCode';

      print('\n📤 ENVIANDO IMAGEM COM PROMPT:');
      print('----------------------------------------');
      print('System: $systemContent');
      print('User: $prompt');
      print('UserId: $userId');
      print(
          'Imagem: [Base64 imagem - tamanho: ${imageBase64.length} caracteres]');
      print('----------------------------------------\n');

      // Registrar horário de início para medir tempo de resposta
      final startTime = DateTime.now();

      // Novo endpoint e configuração da requisição
      final endpoint = '${AppConstants.API_BASE_URL}/ai/analyze-image';
      final request = http.Request('POST', Uri.parse(endpoint));
      request.headers.addAll({
        'Content-Type': 'application/json',
      });

      // Formato do corpo da requisição para o novo endpoint
      request.body = jsonEncode({
        'prompt': '$systemContent\n\nUsuário: $prompt',
        'model':
            quality, // Usar o parâmetro de qualidade (otimo, bom, mediano, ruim)
        'streaming': true,
        'imageBase64': 'data:image/jpeg;base64,' + imageBase64,
        'userId': userId, // Adicionando o userId na requisição
        'agentType': agentType, // Tipo de agent a ser usado
      });

      print('🔄 Aguardando resposta da nova API para a imagem...');
      final response = await http.Client().send(request);

      if (response.statusCode == 200) {
        print(
            '✅ Conexão estabelecida, iniciando streaming de resposta para imagem');
        int chunkCount = 0;
        String allContent = '';

        // Formatação correta do stream de entrada para SSE
        final streamController = StreamController<String>();
        String buffer = '';

        response.stream.transform(utf8.decoder).listen(
          (chunk) {
            // Adicionar o novo chunk ao buffer
            buffer += chunk;

            // Processar linhas completas (eventos SSE)
            while (buffer.contains('\n\n')) {
              final parts = buffer.split('\n\n');
              final event = parts[0];

              // Atualizar o buffer com o restante
              buffer = parts.sublist(1).join('\n\n');

              // Processar o evento se começar com "data: "
              if (event.trim().startsWith('data: ')) {
                final jsonString = event.trim().substring(6);
                try {
                  final jsonData = jsonDecode(jsonString);

                  if (jsonData.containsKey('text') &&
                      jsonData['text'] != null) {
                    // Evento de texto
                    final content = jsonData['text'];
                    chunkCount++;
                    allContent += content;
                    streamController.add(content);

                    // Log a cada 20 chunks
                    if (chunkCount % 20 == 0) {
                      print('📦 Chunks de imagem recebidos: $chunkCount');
                    }
                  } else if (jsonData.containsKey('done') &&
                      jsonData['done'] == true) {
                    // Evento de conclusão
                    print(
                        '✅ Servidor indicou conclusão do streaming para imagem');
                  } else if (jsonData.containsKey('error')) {
                    // Evento de erro
                    print(
                        '❌ Erro reportado pelo servidor para imagem: ${jsonData['error']}');
                    streamController.add('\nErro: ${jsonData['error']}');
                  } else if (jsonData.containsKey('status')) {
                    // Evento de status
                    print(
                        'ℹ️ Status do servidor para imagem: ${jsonData['status']}');
                  }
                } catch (e) {
                  print('❌ Erro ao processar evento SSE da imagem: $e');
                  print('Evento problemático: $event');
                }
              }
            }
          },
          onDone: () {
            // Quando a stream terminar, registrar estatísticas
            final duration = DateTime.now().difference(startTime);
            final outputTokens = estimateTokenCount(allContent);

            print('\n✅ Streaming de processamento de imagem concluído:');
            print('- Chunks totais: $chunkCount');
            print('- Tempo total: ${duration.inMilliseconds}ms');
            print('- Tokens na resposta: $outputTokens');
            print(
                '- Velocidade: ${(outputTokens / (duration.inMilliseconds / 1000)).round()} tokens/segundo\n');

            // Registrar custos estimados
            _logTokensAndCost(
                prompt, systemContent, outputTokens, 'processImageStream');

            // Fechar o controlador
            streamController.close();
          },
          onError: (error) {
            print('❌ Erro na stream de imagem: $error');
            streamController.addError(error);
            streamController.close();
          },
        );

        // Retornar a stream do controlador
        yield* streamController.stream;
      } else {
        final responseBody = await response.stream.bytesToString();
        final errorMsg =
            'Desculpe, ocorreu um erro ao processar sua imagem. Por favor, tente novamente.';
        print(
            '❌ Erro na requisição de imagem: ${response.statusCode}, Resposta: $responseBody');
        yield errorMsg;
      }
    } catch (e) {
      final errorMsg =
          'Desculpe, ocorreu um erro ao processar sua imagem. Por favor, tente novamente.';
      print('❌ Erro ao processar a imagem com streaming: $e');
      yield errorMsg;
    }
  }

  // Método para obter a resposta completa de um stream como string
  Future<String> processImage(Uint8List imageBytes, String prompt,
      {String languageCode = 'pt_BR',
      String quality = 'baixo',
      String userId = '',
      String agentType = 'nutrition'}) async {
    try {
      final completer = Completer<String>();
      final buffer = StringBuffer();

      final stream = processImageStream(
        imageBytes,
        prompt,
        languageCode: languageCode,
        quality: quality,
        userId: userId, // Passando o userId para o método de streaming
        agentType: agentType, // Passando o agentType
      );

      final subscription = stream.listen(
        (data) {
          buffer.write(data);
        },
        onError: (e) {
          if (!completer.isCompleted) {
            completer.completeError("Erro ao processar imagem: $e");
          }
        },
        onDone: () {
          if (!completer.isCompleted) {
            completer.complete(buffer.toString());
          }
        },
      );

      final result = await completer.future;
      subscription.cancel();
      return result;
    } catch (e) {
      final errorMsg =
          'Desculpe, ocorreu um erro ao processar sua imagem. Por favor, tente novamente.';
      print('Erro ao processar imagem (sync): $e');
      return errorMsg;
    }
  }

  // Process audio and transcribe it
  Future<String> processAudio(Uint8List audioBytes,
      {bool translateToPt = true, String languageCode = 'pt_BR'}) async {
    try {
      final audioBase64 = base64Encode(audioBytes);

      // URL específica para a API de transcrição de áudio
      final transcriptionUrl = 'https://api.openai.com/v1/audio/transcriptions';

      // Preparar o form data com o arquivo de áudio
      var request = http.MultipartRequest('POST', Uri.parse(transcriptionUrl));
      request.headers['Authorization'] = 'Bearer $_apiKey';

      // Adicionar o arquivo de áudio como campo de formulário
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          audioBytes,
          filename: 'audio.mp3',
        ),
      );

      // Definir o modelo e outras configurações
      request.fields['model'] = 'whisper-1';
      request.fields['response_format'] = 'json';

      // Extrair o código de idioma da string completa (por exemplo, pt_BR -> pt)
      final targetLanguage = languageCode.split('_')[0];

      // Se deve traduzir para o idioma especificado
      if (translateToPt) {
        request.fields['language'] = targetLanguage;
      }

      print('🎙️ Enviando áudio para transcrição');
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
        final transcription = jsonResponse['text'];
        print('✅ Transcrição concluída com sucesso: $transcription');
        return transcription;
      } else {
        final errorMsg =
            'Desculpe, ocorreu um erro ao processar seu áudio. Por favor, tente novamente.';
        print(
            '❌ Erro na transcrição: ${response.statusCode} - ${utf8.decode(response.bodyBytes)}');
        return errorMsg;
      }
    } catch (e) {
      final errorMsg =
          'Desculpe, ocorreu um erro ao processar seu áudio. Por favor, tente novamente.';
      print('❌ Exceção ao transcrever áudio: $e');
      return errorMsg;
    }
  }

  // Método para melhorar texto com streaming
  Stream<String> enhanceTextStream(String text, String enhancementType,
      {int? targetWordCount,
      String languageCode = 'pt_BR',
      String quality = 'mediano',
      String userId = '',
      String agentType = 'nutrition'}) async* {
    print('\n🚀 Iniciando aprimoramento de texto com streaming');

    try {
      String instruction = '';

      switch (enhancementType) {
        case 'paraphrase':
          instruction =
              'Paraphrase the following text while maintaining its meaning:';
          break;
        case 'simplify':
          instruction =
              'Simplify the following text to make it easier to understand:';
          break;
        case 'expand':
          instruction =
              'Expand on the following text with more details and explanations:';
          break;
        case 'academicTone':
          instruction = 'Rewrite the following text in an academic tone:';
          break;
        default:
          instruction = 'Improve the following text:';
      }

      if (targetWordCount != null) {
        instruction += ' Target approximately $targetWordCount words.';
      }

      final systemContent =
          'Você é um assistente de escrita para estudantes. Você deve responder no idioma: $languageCode';
      final prompt = '$instruction\n\n$text';

      print('\n📤 PROMPT PARA MELHORIA DE TEXTO:');
      print('----------------------------------------');
      print('Tipo: $enhancementType');
      print('System: $systemContent');
      print('Instrução: $instruction');
      print('UserId: $userId');
      print('----------------------------------------\n');

      // Registrar horário de início para medir tempo de resposta
      final startTime = DateTime.now();

      // Novo endpoint e configuração da requisição
      final endpoint = '${AppConstants.API_BASE_URL}/ai/generate-text';
      final request = http.Request('POST', Uri.parse(endpoint));
      request.headers.addAll({
        'Content-Type': 'application/json',
      });

      // Novo formato de corpo da requisição
      request.body = jsonEncode({
        'prompt': '$systemContent\n\nUsuário: $prompt',
        'temperature': 0.5,
        'model': quality,
        'streaming': true,
        'userId': userId, // Adicionando o userId na requisição
        'agentType': agentType, // Tipo de agent a ser usado
      });

      print('🔄 Aguardando resposta da API para melhoria de texto...');
      final response = await http.Client().send(request);

      if (response.statusCode == 200) {
        print(
            '✅ Conexão estabelecida, iniciando streaming para melhoria de texto');
        int chunkCount = 0;
        String allContent = '';

        // Formatação correta do stream de entrada para SSE
        final streamController = StreamController<String>();
        String buffer = '';

        response.stream.transform(utf8.decoder).listen(
          (chunk) {
            // Adicionar o novo chunk ao buffer
            buffer += chunk;

            // Processar linhas completas (eventos SSE)
            while (buffer.contains('\n\n')) {
              final parts = buffer.split('\n\n');
              final event = parts[0];

              // Atualizar o buffer com o restante
              buffer = parts.sublist(1).join('\n\n');

              // Processar o evento se começar com "data: "
              if (event.trim().startsWith('data: ')) {
                final jsonString = event.trim().substring(6);
                try {
                  final jsonData = jsonDecode(jsonString);

                  if (jsonData.containsKey('text') &&
                      jsonData['text'] != null) {
                    // Evento de texto
                    final content = jsonData['text'];
                    chunkCount++;
                    allContent += content;
                    streamController.add(content);

                    // Log a cada 20 chunks
                    if (chunkCount % 20 == 0) {
                      print(
                          '📦 Chunks de melhoria de texto recebidos: $chunkCount');
                    }
                  } else if (jsonData.containsKey('done') &&
                      jsonData['done'] == true) {
                    // Evento de conclusão
                    print(
                        '✅ Servidor indicou conclusão do streaming para melhoria de texto');
                  } else if (jsonData.containsKey('error')) {
                    // Evento de erro
                    print(
                        '❌ Erro reportado pelo servidor para melhoria de texto: ${jsonData['error']}');
                    streamController.add('\nErro: ${jsonData['error']}');
                  } else if (jsonData.containsKey('status')) {
                    // Evento de status
                    print(
                        'ℹ️ Status do servidor para melhoria de texto: ${jsonData['status']}');
                  }
                } catch (e) {
                  print(
                      '❌ Erro ao processar evento SSE de melhoria de texto: $e');
                  print('Evento problemático: $event');
                }
              }
            }
          },
          onDone: () {
            // Quando a stream terminar, registrar estatísticas
            final duration = DateTime.now().difference(startTime);
            final outputTokens = estimateTokenCount(allContent);

            print('\n✅ Streaming de melhoria de texto concluído:');
            print('- Chunks totais: $chunkCount');
            print('- Tempo total: ${duration.inMilliseconds}ms');
            print('- Tokens na resposta: $outputTokens');
            print(
                '- Velocidade: ${(outputTokens / (duration.inMilliseconds / 1000)).round()} tokens/segundo\n');

            // Registrar custos estimados
            _logTokensAndCost(
                prompt, systemContent, outputTokens, 'enhanceTextStream');

            // Fechar o controlador
            streamController.close();
          },
          onError: (error) {
            print('❌ Erro na stream de melhoria de texto: $error');
            streamController.addError(error);
            streamController.close();
          },
        );

        // Retornar a stream do controlador
        yield* streamController.stream;
      } else {
        final responseBody = await response.stream.bytesToString();
        final errorMsg =
            'Desculpe, ocorreu um erro ao aprimorar o texto. Por favor, tente novamente.';
        print(
            '❌ Erro na requisição de melhoria de texto: ${response.statusCode}, Resposta: $responseBody');
        yield errorMsg;
      }
    } catch (e) {
      final errorMsg =
          'Desculpe, ocorreu um erro ao aprimorar o texto. Por favor, tente novamente.';
      print('❌ Erro ao melhorar o texto com streaming: $e');
      yield errorMsg;
    }
  }

  // Enhance text (paraphrase, simplify, expand, etc.)
  Future<String> enhanceText(String text, String enhancementType,
      {int? targetWordCount,
      String languageCode = 'pt_BR',
      String quality = 'mediano',
      String userId = '',
      String agentType = 'nutrition'}) async {
    try {
      final completer = Completer<String>();
      final buffer = StringBuffer();

      final stream = enhanceTextStream(
        text,
        enhancementType,
        targetWordCount: targetWordCount,
        languageCode: languageCode,
        quality: quality,
        userId: userId, // Passando o userId para o método de streaming
        agentType: agentType, // Passando o agentType
      );

      final subscription = stream.listen(
        (data) {
          buffer.write(data);
        },
        onError: (e) {
          if (!completer.isCompleted) {
            completer.completeError("Erro ao melhorar texto: $e");
          }
        },
        onDone: () {
          if (!completer.isCompleted) {
            completer.complete(buffer.toString());
          }
        },
      );

      final result = await completer.future;
      subscription.cancel();
      return result;
    } catch (e) {
      final errorMsg =
          'Desculpe, ocorreu um erro ao aprimorar o texto. Por favor, tente novamente.';
      print('Erro ao melhorar texto (sync): $e');
      return errorMsg;
    }
  }

  // Summarize document with streaming
  Stream<String> summarizeDocumentStream(String documentText,
      {String summaryLength = 'medium',
      String languageCode = 'pt_BR',
      String quality = 'mediano',
      String userId = '',
      String agentType = 'nutrition'}) async* {
    print(
        '📡 AIService.summarizeDocumentStream - Iniciando com tamanho: $summaryLength, tamanho do documento: ${documentText.length} caracteres');

    try {
      String instruction = '';

      switch (summaryLength) {
        case 'short':
          instruction =
              'Provide a brief summary of the following document in 1-2 paragraphs:';
          break;
        case 'medium':
          instruction =
              'Provide a comprehensive summary of the following document, highlighting key points:';
          break;
        case 'detailed':
          instruction =
              'Provide a detailed summary of the following document with section breakdowns:';
          break;
        default:
          instruction = 'Summarize the following document:';
      }

      print('📝 AIService.summarizeDocumentStream - Instrução: $instruction');
      print('📝 AIService.summarizeDocumentStream - UserId: $userId');

      final systemContent =
          'Você é um assistente que cria resumos claros e estruturados. Você deve responder no idioma: $languageCode';
      final prompt = '$instruction\n\n$documentText';

      // Registrar horário de início para medir tempo de resposta
      final startTime = DateTime.now();

      // Novo endpoint e configuração da requisição
      final endpoint = '${AppConstants.API_BASE_URL}/ai/generate-text';
      final request = http.Request('POST', Uri.parse(endpoint));
      request.headers.addAll({
        'Content-Type': 'application/json',
      });

      // Novo formato de corpo da requisição
      request.body = jsonEncode({
        'prompt': '$systemContent\n\nUsuário: $prompt',
        'temperature': 0.3,
        'model': quality,
        'streaming': true,
        'userId': userId,
        'agentType': agentType,
      });

      print(
          '🚀 AIService.summarizeDocumentStream - Enviando requisição para a nova API');

      final response = await http.Client().send(request);

      if (response.statusCode == 200) {
        print(
            '✅ AIService.summarizeDocumentStream - Resposta 200 OK, iniciando streaming');
        int chunkCount = 0;
        String allContent = '';

        // Formatação correta do stream de entrada para SSE
        final streamController = StreamController<String>();
        String buffer = '';

        response.stream.transform(utf8.decoder).listen(
          (chunk) {
            // Adicionar o novo chunk ao buffer
            buffer += chunk;

            // Processar linhas completas (eventos SSE)
            while (buffer.contains('\n\n')) {
              final parts = buffer.split('\n\n');
              final event = parts[0];

              // Atualizar o buffer com o restante
              buffer = parts.sublist(1).join('\n\n');

              // Processar o evento se começar com "data: "
              if (event.trim().startsWith('data: ')) {
                final jsonString = event.trim().substring(6);
                try {
                  final jsonData = jsonDecode(jsonString);

                  if (jsonData.containsKey('text') &&
                      jsonData['text'] != null) {
                    // Evento de texto
                    final content = jsonData['text'];
                    chunkCount++;
                    allContent += content;
                    streamController.add(content);

                    // Log a cada 10 chunks
                    if (chunkCount % 10 == 0) {
                      print(
                          '📦 AIService.summarizeDocumentStream - Recebidos $chunkCount chunks até agora');
                    }
                  } else if (jsonData.containsKey('done') &&
                      jsonData['done'] == true) {
                    // Evento de conclusão
                    print(
                        '✅ AIService.summarizeDocumentStream - Servidor indicou conclusão do streaming');
                  } else if (jsonData.containsKey('error')) {
                    // Evento de erro
                    print(
                        '❌ AIService.summarizeDocumentStream - Erro reportado pelo servidor: ${jsonData['error']}');
                    streamController.add('\nErro: ${jsonData['error']}');
                  } else if (jsonData.containsKey('status')) {
                    // Evento de status
                    print(
                        'ℹ️ AIService.summarizeDocumentStream - Status do servidor: ${jsonData['status']}');
                  }
                } catch (e) {
                  print(
                      '❌ AIService.summarizeDocumentStream - Erro ao processar evento SSE: $e');
                  print('Evento problemático: $event');
                }
              }
            }
          },
          onDone: () {
            // Quando a stream terminar, registrar estatísticas
            final duration = DateTime.now().difference(startTime);
            final outputTokens = estimateTokenCount(allContent);

            print(
                '\n✅ AIService.summarizeDocumentStream - Streaming concluído:');
            print('- Chunks totais: $chunkCount');
            print('- Tempo total: ${duration.inMilliseconds}ms');
            print('- Tokens na resposta: $outputTokens');
            print(
                '- Velocidade: ${(outputTokens / (duration.inMilliseconds / 1000)).round()} tokens/segundo\n');

            // Registrar custos estimados
            _logTokensAndCost(
                prompt, systemContent, outputTokens, 'summarizeDocumentStream');

            // Fechar o controlador
            streamController.close();
          },
          onError: (error) {
            print(
                '❌ AIService.summarizeDocumentStream - Erro na stream: $error');
            streamController.addError(error);
            streamController.close();
          },
        );

        // Retornar a stream do controlador
        yield* streamController.stream;
      } else {
        final responseBody = await response.stream.bytesToString();
        final errorMsg =
            'Desculpe, ocorreu um erro ao resumir o documento. Por favor, tente novamente.';
        print(
            '❌ AIService.summarizeDocumentStream - Erro na requisição: ${response.statusCode}, Resposta: $responseBody');
        yield errorMsg;
      }
    } catch (e) {
      final errorMsg =
          'Desculpe, ocorreu um erro ao resumir o documento. Por favor, tente novamente.';
      print(
          '❌ AIService.summarizeDocumentStream - Erro ao resumir o documento: $e');
      yield errorMsg;
    }
  }

  // Método para obter o resumo completo como string
  Future<String> summarizeDocument(String documentText,
      {String summaryLength = 'medium',
      String languageCode = 'pt_BR',
      String quality = 'mediano',
      String userId = '',
      String agentType = 'nutrition'}) async {
    try {
      final completer = Completer<String>();
      final buffer = StringBuffer();

      final stream = summarizeDocumentStream(
        documentText,
        summaryLength: summaryLength,
        languageCode: languageCode,
        quality: quality,
        userId: userId, // Passando o userId para o método de streaming
        agentType: agentType, // Passando o agentType
      );

      final subscription = stream.listen(
        (data) {
          buffer.write(data);
        },
        onError: (e) {
          if (!completer.isCompleted) {
            completer.completeError("Erro ao resumir documento: $e");
          }
        },
        onDone: () {
          if (!completer.isCompleted) {
            completer.complete(buffer.toString());
          }
        },
      );

      final result = await completer.future;
      subscription.cancel();
      return result;
    } catch (e) {
      final errorMsg =
          'Desculpe, ocorreu um erro ao resumir o documento. Por favor, tente novamente.';
      print('Erro ao resumir documento (sync): $e');
      return errorMsg;
    }
  }

  // Método para ajuda com código via streaming
  Stream<String> getCodeHelpStream(
      String code, String language, String requestType,
      {String languageCode = 'pt_BR',
      String quality = 'bom',
      String userId = '',
      String agentType = 'nutrition'}) async* {
    print('\n🚀 Iniciando ajuda com código (streaming)');

    try {
      String instruction = '';

      switch (requestType) {
        case 'explain':
          instruction = 'Explique o seguinte código $language em detalhes:';
          break;
        case 'optimize':
          instruction =
              'Otimize o seguinte código $language e explique suas melhorias:';
          break;
        case 'debug':
          instruction =
              'Depure o seguinte código $language, identifique problemas e forneça correções:';
          break;
        default:
          instruction = 'Analise o seguinte código $language:';
      }

      final systemContent =
          'Você é um tutor de programação. Forneça explicações educativas sobre código. Você deve responder no idioma: $languageCode';
      final prompt = '$instruction\n```$language\n$code\n```';

      print('\n📤 PROMPT PARA AJUDA COM CÓDIGO:');
      print('----------------------------------------');
      print('Tipo: $requestType, Linguagem: $language');
      print('System: $systemContent');
      print('Instrução: $instruction');
      print('UserId: $userId');
      print('----------------------------------------\n');

      // Registrar horário de início para medir tempo de resposta
      final startTime = DateTime.now();

      // Novo endpoint e configuração da requisição
      final endpoint = '${AppConstants.API_BASE_URL}/ai/generate-text';
      final request = http.Request('POST', Uri.parse(endpoint));
      request.headers.addAll({
        'Content-Type': 'application/json',
      });

      // Novo formato de corpo da requisição
      request.body = jsonEncode({
        'prompt': '$systemContent\n\nUsuário: $prompt',
        'temperature': 0.3,
        'model': quality,
        'streaming': true,
        'userId': userId,
        'agentType': agentType,
      });

      print('🔄 Aguardando resposta da API para ajuda com código...');

      final response = await http.Client().send(request);

      if (response.statusCode == 200) {
        print(
            '✅ Conexão estabelecida, iniciando streaming para ajuda com código');
        int chunkCount = 0;
        String allContent = '';

        // Formatação correta do stream de entrada para SSE
        final streamController = StreamController<String>();
        String buffer = '';

        response.stream.transform(utf8.decoder).listen(
          (chunk) {
            // Adicionar o novo chunk ao buffer
            buffer += chunk;

            // Processar linhas completas (eventos SSE)
            while (buffer.contains('\n\n')) {
              final parts = buffer.split('\n\n');
              final event = parts[0];

              // Atualizar o buffer com o restante
              buffer = parts.sublist(1).join('\n\n');

              // Processar o evento se começar com "data: "
              if (event.trim().startsWith('data: ')) {
                final jsonString = event.trim().substring(6);
                try {
                  final jsonData = jsonDecode(jsonString);

                  if (jsonData.containsKey('text') &&
                      jsonData['text'] != null) {
                    // Evento de texto
                    final content = jsonData['text'];
                    chunkCount++;
                    allContent += content;
                    streamController.add(content);

                    // Log a cada 20 chunks
                    if (chunkCount % 20 == 0) {
                      print(
                          '📦 Chunks de ajuda com código recebidos: $chunkCount');
                    }
                  } else if (jsonData.containsKey('done') &&
                      jsonData['done'] == true) {
                    // Evento de conclusão
                    print(
                        '✅ Servidor indicou conclusão do streaming para ajuda com código');
                  } else if (jsonData.containsKey('error')) {
                    // Evento de erro
                    print(
                        '❌ Erro reportado pelo servidor para ajuda com código: ${jsonData['error']}');
                    streamController.add('\nErro: ${jsonData['error']}');
                  } else if (jsonData.containsKey('status')) {
                    // Evento de status
                    print(
                        'ℹ️ Status do servidor para ajuda com código: ${jsonData['status']}');
                  }
                } catch (e) {
                  print(
                      '❌ Erro ao processar evento SSE de ajuda com código: $e');
                  print('Evento problemático: $event');
                }
              }
            }
          },
          onDone: () {
            // Quando a stream terminar, registrar estatísticas
            final duration = DateTime.now().difference(startTime);
            final outputTokens = estimateTokenCount(allContent);

            print('\n✅ Streaming de ajuda com código concluído:');
            print('- Chunks totais: $chunkCount');
            print('- Tempo total: ${duration.inMilliseconds}ms');
            print('- Tokens na resposta: $outputTokens');
            print(
                '- Velocidade: ${(outputTokens / (duration.inMilliseconds / 1000)).round()} tokens/segundo\n');

            // Registrar custos estimados
            _logTokensAndCost(
                prompt, systemContent, outputTokens, 'getCodeHelpStream');

            // Fechar o controlador
            streamController.close();
          },
          onError: (error) {
            print('❌ Erro na stream de ajuda com código: $error');
            streamController.addError(error);
            streamController.close();
          },
        );

        // Retornar a stream do controlador
        yield* streamController.stream;
      } else {
        final responseBody = await response.stream.bytesToString();
        final errorMsg =
            'Desculpe, ocorreu um erro ao processar o código. Por favor, tente novamente.';
        print(
            '❌ Erro na requisição de ajuda com código: ${response.statusCode}, Resposta: $responseBody');
        yield errorMsg;
      }
    } catch (e) {
      final errorMsg =
          'Desculpe, ocorreu um erro ao processar o código. Por favor, tente novamente.';
      print('❌ Erro ao processar a ajuda com código: $e');
      yield errorMsg;
    }
  }

  // Get help with code (versão síncrona usando stream)
  Future<String> getCodeHelp(String code, String language, String requestType,
      {String languageCode = 'pt_BR',
      String quality = 'bom',
      String userId = '',
      String agentType = 'nutrition'}) async {
    try {
      final completer = Completer<String>();
      final buffer = StringBuffer();

      final stream = getCodeHelpStream(
        code,
        language,
        requestType,
        languageCode: languageCode,
        quality: quality,
        userId: userId, // Passando o userId para o método de streaming
        agentType: agentType, // Passando o agentType
      );

      final subscription = stream.listen(
        (data) {
          buffer.write(data);
        },
        onError: (e) {
          if (!completer.isCompleted) {
            completer.completeError("Erro ao processar código: $e");
          }
        },
        onDone: () {
          if (!completer.isCompleted) {
            completer.complete(buffer.toString());
          }
        },
      );

      final result = await completer.future;
      subscription.cancel();
      return result;
    } catch (e) {
      final errorMsg =
          'Desculpe, ocorreu um erro ao processar o código. Por favor, tente novamente.';
      print('Erro ao processar código (sync): $e');
      return errorMsg;
    }
  }

  // Método para obter resumo de transcrição do YouTube com streaming
  Stream<String> summarizeYouTubeTranscriptStream(String transcript,
      {String videoTitle = '',
      String languageCode = 'pt_BR',
      String quality = 'ruim',
      String userId = '',
      String agentType = 'nutrition'}) async* {
    print('\n🚀 Iniciando resumo de transcrição do YouTube (streaming)');

    try {
      final systemContent =
          'Você é um assistente especializado em analisar e resumir conteúdo educacional de vídeos. Você deve responder no idioma: $languageCode';

      final prompt =
          '''Analise a seguinte transcrição de um vídeo do YouTube${videoTitle.isNotEmpty ? ' intitulado "$videoTitle"' : ''} e forneça:

1. Um resumo conciso do conteúdo (máximo 3 parágrafos)
2. Os tópicos principais abordados (máximo 5 tópicos em formato de lista)
3. Palavras-chave importantes (máximo 10 palavras ou termos curtos, separados por vírgula)
4. Uma avaliação de complexidade do conteúdo (básico, intermediário ou avançado) e do público-alvo

Formate sua resposta com os seguintes cabeçalhos:
RESUMO:
TÓPICOS PRINCIPAIS:
PALAVRAS-CHAVE:
AVALIAÇÃO:

Transcrição do vídeo:
$transcript
''';

      print('\n📤 PROMPT PARA RESUMO DE VÍDEO:');
      print('----------------------------------------');
      print('Vídeo: ${videoTitle.isNotEmpty ? videoTitle : '[Sem título]'}');
      print('System: $systemContent');
      print('UserId: $userId');
      print('----------------------------------------\n');

      // Registrar horário de início para medir tempo de resposta
      final startTime = DateTime.now();

      // Novo endpoint e configuração da requisição
      final endpoint = '${AppConstants.API_BASE_URL}/ai/generate-text';
      final request = http.Request('POST', Uri.parse(endpoint));
      request.headers.addAll({
        'Content-Type': 'application/json',
      });

      // Novo formato de corpo da requisição
      request.body = jsonEncode({
        'prompt': '$systemContent\n\nUsuário: $prompt',
        'temperature': 0.3,
        'model': quality,
        'streaming': true,
        'userId': userId,
        'agentType': agentType,
      });

      print('🔄 Aguardando resposta da API para resumo de vídeo...');

      final response = await http.Client().send(request);

      if (response.statusCode == 200) {
        print(
            '✅ Conexão estabelecida, iniciando streaming para resumo de vídeo');
        int chunkCount = 0;
        String allContent = '';

        // Formatação correta do stream de entrada para SSE
        final streamController = StreamController<String>();
        String buffer = '';

        response.stream.transform(utf8.decoder).listen(
          (chunk) {
            // Adicionar o novo chunk ao buffer
            buffer += chunk;

            // Processar linhas completas (eventos SSE)
            while (buffer.contains('\n\n')) {
              final parts = buffer.split('\n\n');
              final event = parts[0];

              // Atualizar o buffer com o restante
              buffer = parts.sublist(1).join('\n\n');

              // Processar o evento se começar com "data: "
              if (event.trim().startsWith('data: ')) {
                final jsonString = event.trim().substring(6);
                try {
                  final jsonData = jsonDecode(jsonString);

                  if (jsonData.containsKey('text') &&
                      jsonData['text'] != null) {
                    // Evento de texto
                    final content = jsonData['text'];
                    chunkCount++;
                    allContent += content;
                    streamController.add(content);

                    // Log a cada 20 chunks
                    if (chunkCount % 20 == 0) {
                      print(
                          '📦 Chunks de resumo de vídeo recebidos: $chunkCount');
                    }
                  } else if (jsonData.containsKey('done') &&
                      jsonData['done'] == true) {
                    // Evento de conclusão
                    print(
                        '✅ Servidor indicou conclusão do streaming para resumo de vídeo');
                  } else if (jsonData.containsKey('error')) {
                    // Evento de erro
                    print(
                        '❌ Erro reportado pelo servidor para resumo de vídeo: ${jsonData['error']}');
                    streamController.add('\nErro: ${jsonData['error']}');
                  } else if (jsonData.containsKey('status')) {
                    // Evento de status
                    print(
                        'ℹ️ Status do servidor para resumo de vídeo: ${jsonData['status']}');
                  }
                } catch (e) {
                  print(
                      '❌ Erro ao processar evento SSE de resumo de vídeo: $e');
                  print('Evento problemático: $event');
                }
              }
            }
          },
          onDone: () {
            // Quando a stream terminar, registrar estatísticas
            final duration = DateTime.now().difference(startTime);
            final outputTokens = estimateTokenCount(allContent);

            print('\n✅ Streaming de resumo de vídeo concluído:');
            print('- Chunks totais: $chunkCount');
            print('- Tempo total: ${duration.inMilliseconds}ms');
            print('- Tokens na resposta: $outputTokens');
            print(
                '- Velocidade: ${(outputTokens / (duration.inMilliseconds / 1000)).round()} tokens/segundo\n');

            // Registrar custos estimados
            _logTokensAndCost(prompt, systemContent, outputTokens,
                'summarizeYouTubeTranscriptStream');

            // Fechar o controlador
            streamController.close();
          },
          onError: (error) {
            print('❌ Erro na stream de resumo de vídeo: $error');
            streamController.addError(error);
            streamController.close();
          },
        );

        // Retornar a stream do controlador
        yield* streamController.stream;
      } else {
        final responseBody = await response.stream.bytesToString();
        final errorMsg =
            'Desculpe, ocorreu um erro ao resumir o vídeo. Por favor, tente novamente.';
        print(
            '❌ Erro na requisição de resumo de vídeo: ${response.statusCode}, Resposta: $responseBody');
        yield errorMsg;
      }
    } catch (e) {
      final errorMsg =
          'Desculpe, ocorreu um erro ao resumir o vídeo. Por favor, tente novamente.';
      print('❌ Erro ao resumir transcrição de vídeo: $e');
      yield errorMsg;
    }
  }

  // Summarize YouTube transcript
  Future<Map<String, String>> summarizeYouTubeTranscript(String transcript,
      {String videoTitle = '',
      String languageCode = 'pt_BR',
      String quality = 'ruim',
      String userId = '',
      String agentType = 'nutrition'}) async {
    try {
      final completer = Completer<String>();
      final buffer = StringBuffer();

      final stream = summarizeYouTubeTranscriptStream(
        transcript,
        videoTitle: videoTitle,
        languageCode: languageCode,
        quality: quality,
        userId: userId, // Passando o userId para o método de streaming
        agentType: agentType, // Passando o agentType
      );

      final subscription = stream.listen(
        (data) {
          buffer.write(data);
        },
        onError: (e) {
          if (!completer.isCompleted) {
            completer.completeError("Erro ao resumir transcrição: $e");
          }
        },
        onDone: () {
          if (!completer.isCompleted) {
            completer.complete(buffer.toString());
          }
        },
      );

      final content = await completer.future;
      subscription.cancel();

      // Processar a resposta para extrair as diferentes seções
      Map<String, String> result = {
        'full_response': content,
        'summary': '',
        'main_topics': '',
        'keywords': '',
        'assessment': '',
      };

      // Extrair o resumo
      final resumoMatch =
          RegExp(r'RESUMO:(.*?)(?=TÓPICOS PRINCIPAIS:|$)', dotAll: true)
              .firstMatch(content);
      if (resumoMatch != null) {
        result['summary'] = resumoMatch.group(1)?.trim() ??
            'Não foi possível gerar um resumo para este vídeo.';
      }

      // Extrair os tópicos principais
      final topicosMatch =
          RegExp(r'TÓPICOS PRINCIPAIS:(.*?)(?=PALAVRAS-CHAVE:|$)', dotAll: true)
              .firstMatch(content);
      if (topicosMatch != null) {
        result['main_topics'] = topicosMatch.group(1)?.trim() ??
            'Não foram identificados tópicos principais.';
      }

      // Extrair as palavras-chave
      final palavrasChaveMatch =
          RegExp(r'PALAVRAS-CHAVE:(.*?)(?=AVALIAÇÃO:|$)', dotAll: true)
              .firstMatch(content);
      if (palavrasChaveMatch != null) {
        result['keywords'] = palavrasChaveMatch.group(1)?.trim() ??
            'Não foram identificadas palavras-chave.';
      }

      // Extrair a avaliação
      final avaliacaoMatch =
          RegExp(r'AVALIAÇÃO:(.*?)$', dotAll: true).firstMatch(content);
      if (avaliacaoMatch != null) {
        result['assessment'] = avaliacaoMatch.group(1)?.trim() ??
            'Não foi possível avaliar a complexidade deste conteúdo.';
      }

      return result;
    } catch (e) {
      final errorMsg =
          'Desculpe, ocorreu um erro ao resumir o vídeo. Por favor, tente novamente.';
      print('Erro ao resumir a transcrição do vídeo (sync): $e');
      return {
        'error': errorMsg,
        'full_response': errorMsg,
        'summary': 'Erro ao gerar resumo.',
        'main_topics': 'Não foi possível extrair os tópicos principais.',
        'keywords': 'Não foi possível extrair palavras-chave.',
        'assessment': 'Não foi possível avaliar o conteúdo.',
      };
    }
  }

  // Método para gerenciar o contexto da conversa
  // Mantém apenas as mensagens mais recentes até o limite de tokens
  Future<String> limitConversationHistory(List<Map<String, dynamic>> messages,
      {int maxTokenLimit = 1900}) async {
    print(
        '\n📋 Preparando contexto de conversa (limite: $maxTokenLimit tokens)...');
    print('📑 Total de mensagens a processar: ${messages.length}');

    if (messages.isEmpty) {
      print('📝 Nenhuma mensagem para processar, retornando contexto vazio');
      return '';
    }

    // Converter todas as mensagens para texto para poder analisar
    final List<Map<String, dynamic>> messagesWithTokens = [];

    for (var msg in messages) {
      // Verificar a forma de obter o conteúdo da mensagem
      String messageContent = '';

      try {
        print(
            'Processando mensagem: ${msg.toString().substring(0, math.min(100, msg.toString().length))}...');

        if (msg.containsKey('message') && msg['message'] != null) {
          messageContent = msg['message'].toString();
          print(
              '📄 Obtido conteúdo da chave message: ${messageContent.substring(0, math.min(50, messageContent.length))}...');
        } else if (msg.containsKey('notifier')) {
          var notifier = msg['notifier'];
          if (notifier != null) {
            // Se for um MessageNotifier, obter a mensagem a partir dele
            messageContent = notifier.message ?? '';
            print(
                '📄 Obtido conteúdo do notificador: ${messageContent.substring(0, math.min(50, messageContent.length))}...');
          }
        } else if (msg.containsKey('content')) {
          // Para compatibilidade com o formato de Message direto
          messageContent = msg['content']?.toString() ?? '';
          print(
              '📄 Obtido conteúdo da chave content: ${messageContent.substring(0, math.min(50, messageContent.length))}...');
        }
      } catch (e) {
        print('❌ Erro ao extrair conteúdo da mensagem: $e');
        messageContent = msg.toString();
      }

      String formattedMsg = msg['isUser'] == true
          ? 'Humano: $messageContent\n'
          : 'IA: $messageContent\n';

      int tokenCount = estimateTokenCount(formattedMsg);

      messagesWithTokens.add({
        'message': formattedMsg,
        'tokens': tokenCount,
        'timestamp': msg['timestamp'],
        'isUser': msg['isUser'],
      });

      print(
          '✅ Mensagem processada: ${tokenCount} tokens, isUser: ${msg['isUser']}');
    }

    // Ordenar mensagens da mais antiga para a mais recente para manter a ordem da conversa
    messagesWithTokens.sort((a, b) =>
        (a['timestamp'] as DateTime).compareTo(b['timestamp'] as DateTime));
    print('🔄 Mensagens ordenadas da mais antiga para a mais recente');

    // Construir o contexto a partir das mensagens mais recentes
    int totalTokens = 0;
    List<String> contextParts = [];

    // Começamos incluindo as mensagens mais antigas
    // Se extrapolar o limite, começamos a remover do início (as mais antigas)
    for (var msg in messagesWithTokens) {
      contextParts.add(msg['message'] as String);
      totalTokens += msg['tokens'] as int;

      print(
          '➕ Adicionada mensagem ao contexto: ${(msg['tokens'] as int)} tokens, total: $totalTokens');

      // Enquanto o total de tokens exceder o limite, removemos mensagens antigas
      while (totalTokens > maxTokenLimit && contextParts.length > 1) {
        final removedMsg = contextParts.removeAt(0);
        final removedTokens = estimateTokenCount(removedMsg);
        totalTokens -= removedTokens;
        print(
            '🔍 Removendo mensagem antiga para manter limite de tokens: ${removedMsg.length} caracteres, ~$removedTokens tokens, restantes: $totalTokens');
      }
    }

    final context = contextParts.join();

    // Calcular tokens economizados
    final fullContextTokens =
        messagesWithTokens.fold(0, (sum, msg) => sum + (msg['tokens'] as int));
    final savedTokens = fullContextTokens - totalTokens;
    final messagesIncluded = contextParts.length;
    final messagesTotal = messagesWithTokens.length;

    print('📝 Contexto limitado a $maxTokenLimit tokens');
    print('📊 Mensagens incluídas: $messagesIncluded de $messagesTotal');
    print(
        '📊 Tokens no contexto: $totalTokens de $fullContextTokens disponíveis');

    if (savedTokens > 0) {
      print(
          '📊 Tokens economizados: $savedTokens (${messagesTotal - messagesIncluded} mensagens antigas descartadas)');
    }

    // Log final para verificação
    print('📝 CONTEXTO FINAL (primeiros 100 caracteres):');
    if (context.isNotEmpty) {
      print(context.substring(0, math.min(100, context.length)) + '...');
    } else {
      print('[Contexto vazio]');
    }

    return context;
  }

  // Método para interromper uma geração em andamento no servidor, se houver suporte
  Future<bool> stopGenerationOnServer(String? connectionId,
      {String userId = ''}) async {
    print('\n🛑 [AIServiceStop] SOLICITAÇÃO DE PARADA DE GERAÇÃO:');
    print('----------------------------------------');
    print('[AIServiceStop] ID da conexão: $connectionId');
    print('[AIServiceStop] ID do usuário: $userId');
    print('----------------------------------------\n');

    if (connectionId == null || connectionId.isEmpty) {
      print(
          '❌ [AIServiceStop] Não é possível interromper geração: ID de conexão ausente');
      return false;
    }

    try {
      // Configurar a URL com os parâmetros corretos
      final endpoint = '${AppConstants.API_BASE_URL}/ai/stop-generation';
      final uri =
          Uri.parse('$endpoint?connectionId=$connectionId&userId=$userId');

      print('🌐 [AIServiceStop] Enviando requisição para: $uri');

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      print('📡 [AIServiceStop] Código de resposta: ${response.statusCode}');
      print('📡 [AIServiceStop] Corpo da resposta: ${response.body}');

      if (response.statusCode == 200) {
        try {
          final jsonResponse = jsonDecode(response.body);
          print('✅ [AIServiceStop] Resposta decodificada: $jsonResponse');

          if (jsonResponse.containsKey('success') &&
              jsonResponse['success'] == true) {
            print(
                '🎉 [AIServiceStop] Geração interrompida no servidor com sucesso!');
            return true;
          } else {
            print(
                '⚠️ [AIServiceStop] Servidor respondeu com sucesso=false ou formato diferente');
            return false;
          }
        } catch (e) {
          print('⚠️ [AIServiceStop] Erro ao decodificar resposta JSON: $e');
          return true; // Consideramos sucesso se o código foi 200, mesmo com erro no JSON
        }
      } else {
        print(
            '❌ [AIServiceStop] Erro ao interromper geração no servidor: ${response.statusCode}');
        print('[AIServiceStop] Resposta: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ [AIServiceStop] Exceção ao interromper geração no servidor: $e');
      return false;
    }
  }
}
