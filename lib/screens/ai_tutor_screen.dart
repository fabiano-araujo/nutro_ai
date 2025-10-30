import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../controllers/ai_tutor_controller.dart'; // Novo import para o controller
import '../services/ai_service.dart';
import '../services/storage_service.dart';
import '../services/ad_manager.dart';
import '../services/auth_service.dart';
import '../models/study_item.dart';
import '../theme/app_theme.dart';
import '../providers/credit_provider.dart';
import '../providers/nutrition_goals_provider.dart';
import '../providers/daily_meals_provider.dart';
import 'settings_screen.dart';
import '../widgets/message_notifier.dart';
import '../utils/code_detector.dart';
import 'html_preview_screen.dart';
import '../utils/message_formatter.dart';
import '../mixins/ai_tutor_speech_mixin.dart';
import '../mixins/text_to_speech_mixin.dart';
import '../utils/message_ui_helper.dart';
import '../utils/conversation_helper.dart';
import '../utils/screen_utils.dart';
import '../i18n/app_localizations.dart';
import 'package:intl/intl.dart';
import '../i18n/language_controller.dart';
import '../utils/media_picker_helper.dart';
import '../utils/ai_interaction_helper.dart';
import 'dart:convert';
import '../i18n/app_localizations_extension.dart';
import '../widgets/weekly_calendar.dart';
import '../widgets/nutrition_card.dart';
import 'daily_meals_screen.dart';
import 'food_search_screen.dart';

// Singleton para gerenciar o estado da tela AITutor em toda a aplicação
// Este padrão de design é usado para resolver o problema do ciclo de vida
// com IndexedStack, que não chama deactivate() quando mudamos de aba.
class AITutorManager {
  static final AITutorManager _instance = AITutorManager._internal();
  AITutorScreenState? activeState;

  factory AITutorManager() {
    return _instance;
  }

  AITutorManager._internal();

  void register(AITutorScreenState state) {
    activeState = state;
  }

  void unregister(AITutorScreenState state) {
    if (activeState == state) {
      activeState = null;
    }
  }

  // Método que simula o deactivate para mostrar anúncio ao sair da tab
  // Isso é chamado externamente quando detectamos que o usuário mudou de aba
  void handleTabExit() {
    activeState?.handleTabChanged();
  }
}

// Singleton global para facilitar acesso de qualquer lugar do app
final aiTutorManager = AITutorManager();

class AITutorScreen extends StatefulWidget {
  final String? conversationId; // ID da conversa a ser carregada
  final String?
      initialPrompt; // Prompt inicial a ser processado (pode ser JSON de ferramenta)
  final String?
      initialToolResponse; // NOVO: Resposta da IA para o initialPrompt da ferramenta

  const AITutorScreen({
    Key? key,
    this.conversationId,
    this.initialPrompt,
    this.initialToolResponse, // NOVO
  }) : super(key: key);

  @override
  AITutorScreenState createState() => AITutorScreenState();

  // Método que permite chamar a lógica de deactivate externamente
  static void handleTabExit() {
    aiTutorManager.handleTabExit();
  }
}

class AITutorScreenState extends State<AITutorScreen>
    with TickerProviderStateMixin, AITutorSpeechMixin, TextToSpeechMixin {
  // Controller que gerenciará o estado e lógica (será inicializado no initState)
  late AITutorController _controller;

  // Serviços - Agora gerenciados pelo Controller
  // final AIService _aiService = AIService();
  // final StorageService _storageService = StorageService();

  // Controllers para UI
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Para animação do ícone pulsante
  late AnimationController _animationController;

  // Controle de visibilidade do NutritionCard
  bool _showNutritionCard = true;
  double _lastScrollOffset = 0.0;

  // Contador de mensagens do usuário
  int _userMessageCount = 0;

  // Anúncio intersticial
  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdReady = false;

  // Dados da ferramenta quando vem de GenericAIScreen
  Map<String, dynamic>? _toolData;
  bool _showToolTranscript =
      false; // Estado para controlar a visibilidade da transcrição no card

  // Implementação dos getters e métodos requeridos pelo AITutorSpeechMixin
  @override
  TextEditingController get messageController => _messageController;

  @override
  AnimationController get animationController => _animationController;

  @override
  void keepScreenOn(bool keepOn) => _keepScreenOn(keepOn);

  @override
  void incrementAndroidUpdateCounter() =>
      _controller.incrementAndroidUpdateCounter();

  @override
  int get androidUpdateCounter => 0; // Não precisamos mais desta variável

  // Classes para adaptação dos mixins
  late final _speechMixinRef = _SpeechMixinRefImpl(this);
  late final _ttsMixinRef = _TTSMixinRefImpl(this);

  @override
  void initState() {
    super.initState();
    print('🚀 AITutorScreen - initState chamado');
    print('   - conversationId: ${widget.conversationId}');
    print(
        '   - initialPrompt (JSON da ferramenta): ${widget.initialPrompt?.substring(0, math.min(100, widget.initialPrompt?.length ?? 0))}...');
    print(
        '   - initialToolResponse (Resposta da IA para ferramenta): ${widget.initialToolResponse?.substring(0, math.min(100, widget.initialToolResponse?.length ?? 0))}...');

    aiTutorManager.register(this);
    _animationController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    // Adicionar listener para controlar a visibilidade do NutritionCard
    _scrollController.addListener(_handleScroll);

    bool isFromTool = false;
    String toolType = 'chat';
    String? conversationIdFromToolData;
    List<Map<String, dynamic>>?
        messagesFromToolData; // Histórico completo da ferramenta

    // Verificar se tem JSON de ferramenta (para exibir card e processar)
    if (widget.initialPrompt != null && widget.initialPrompt!.isNotEmpty) {
      try {
        _toolData = jsonDecode(widget.initialPrompt!);
        isFromTool = _toolData != null && _toolData!.containsKey('toolName');
        if (isFromTool) {
          toolType = _toolData!['sourceType'] as String? ??
              _toolData!['toolName']
                  .toString()
                  .toLowerCase()
                  .replaceAll(' ', '_') ??
              'chat';
          print(
              '📱 AITutorScreen: Detectado JSON de ferramenta. ToolType: $toolType');

          // Tentar obter conversationId do toolData
          if (_toolData!.containsKey('conversationId') &&
              _toolData!['conversationId'] != null &&
              _toolData!['conversationId'].toString().isNotEmpty) {
            conversationIdFromToolData =
                _toolData!['conversationId'].toString();
          }

          // Verificar se há histórico no toolData
          if (_toolData!.containsKey('conversationHistory') &&
              _toolData!['conversationHistory'] is Map) {
            try {
              // NOVO: Log formatado do histórico de conversa recebido
              print('\n');
              print(
                  '📋 ==================== AI TUTOR - HISTÓRICO RECEBIDO ====================');
              print('📋 Ferramenta: ${_toolData!['toolName']}');
              print('📋 Tipo: $toolType');
              print('📋 ConversationId: $conversationIdFromToolData');

              if (_toolData!['conversationHistory'].containsKey('messages')) {
                final messages = _toolData!['conversationHistory']['messages'];
                if (messages is List) {
                  print('📋 Número total de mensagens: ${messages.length}');

                  // Mostrar detalhes das mensagens
                  if (messages.isNotEmpty) {
                    print('📋 Detalhes das mensagens:');
                    int validMessageCount = 0;
                    for (int i = 0; i < messages.length; i++) {
                      final msg = messages[i];
                      if (msg is Map &&
                          msg.containsKey('isUser') &&
                          msg.containsKey('message')) {
                        validMessageCount++;
                        bool isUser = msg['isUser'] == true;
                        String text = msg['message'] as String? ?? '';
                        if (text.length > 50) {
                          text = text.substring(0, 50) + '...';
                        }
                        print(
                            '   ${i + 1}. ${isUser ? '👤 Usuário:' : '🤖 IA:'} $text');
                      } else {
                        print('   ${i + 1}. ⚠️ Formato inválido: $msg');
                      }
                    }
                    print(
                        '📋 Mensagens válidas: $validMessageCount de ${messages.length}');
                  }
                } else {
                  print('⚠️ O campo "messages" não é uma lista válida');
                }
              } else {
                print(
                    '⚠️ Campo "messages" não encontrado no conversationHistory');
              }

              print(
                  '📋 ===================================================================\n');

              // IMPORTANTE: Extrair as mensagens para uso pelo controller
              final extractedMessages =
                  ConversationHelper.extractMessagesFromToolHistory(_toolData!);
              if (extractedMessages != null && extractedMessages.isNotEmpty) {
                messagesFromToolData = extractedMessages;
                print(
                    '✅ AITutorScreen: Extraídas ${extractedMessages.length} mensagens do histórico da ferramenta');

                // Verificar formato das mensagens
                if (extractedMessages.length > 0) {
                  print(
                      '   - Primeira mensagem extraída: ${extractedMessages.first}');
                }
              } else {
                print(
                    '⚠️ AITutorScreen: Nenhuma mensagem válida extraída do histórico da ferramenta');
              }
            } catch (e) {
              print(
                  '❌ AITutorScreen: Erro ao processar histórico da ferramenta: $e');
            }
          }
        }
      } catch (e) {
        print(
            '⚠️ AITutorScreen: Erro ao decodificar initialPrompt como JSON: $e');
        isFromTool = false;
      }
    }

    // Determinar o estado de carregamento de conversa existente
    bool loadingExistingConversation =
        widget.conversationId != null || conversationIdFromToolData != null;

    // Inicializar o controller com as opções corretas
    _controller = AITutorController(
      speechMixin: _speechMixinRef,
      ttsRef: _ttsMixinRef,
      toolType: toolType,
      conversationId: widget.conversationId ?? conversationIdFromToolData,
      showWelcomeMessage: false, // Usando overlay em vez de mensagem no chat
      rawInitialPromptJson: isFromTool
          ? widget.initialPrompt
          : null, // Passa o JSON completo se for ferramenta
      initialMessages:
          messagesFromToolData, // Passa as mensagens extraídas do toolData, se houver
    );

    // Lógica de ação PÓS-inicialização do controller
    // Se isLoadingFullConversation é true, o controller já foi inicializado com as mensagens (seja de initialMessages ou carregadas por ID).
    // Não precisamos fazer mais nada em termos de popular mensagens.
    // Se for uma *nova* interação de ferramenta (sem histórico, sem initialToolResponse), aí sim processamos.
    if (!loadingExistingConversation) {
      if (isFromTool &&
          (widget.initialPrompt != null && widget.initialPrompt!.isNotEmpty)) {
        // Nova interação de ferramenta (initialToolResponse é nulo/vazio, mas temos o prompt da ferramenta).
        // E não estamos carregando conversa completa.
        print(
            '⚙️ AITutorScreen: Nova interação de ferramenta. Processando prompt silenciosamente.');
        String promptToUse = _toolData!['fullPrompt'] ?? widget.initialPrompt!;
        Uint8List? cameraBytes;
        if (_toolData!['sourceType'] == 'camera' &&
            _toolData!.containsKey('imageData')) {
          try {
            cameraBytes = base64Decode(_toolData!['imageData']);
          } catch (e) {
            print('Erro ao decodificar imagem: $e');
          }
        }
        Future.delayed(Duration(milliseconds: 100), () {
          _controller.processSilently(promptToUse, context,
              imageBytes: cameraBytes);
        });
      } else if (widget.initialPrompt != null &&
          widget.initialPrompt!.isNotEmpty) {
        // Não é de ferramenta (ou caso de ferramenta não coberto), mas temos um prompt inicial.
        // E não estamos carregando uma conversa completa.
        print('💬 AITutorScreen: Novo prompt de chat. Enviando mensagem.');
        Future.delayed(Duration(milliseconds: 100), () {
          _messageController.text = widget.initialPrompt!;
          _handleSendMessage();
        });
      }
      // Se nenhuma das condições acima, a tela espera input do usuário.
      // A mensagem de boas-vindas só é adicionada pelo controller se showWelcomeMessage for true.
    } else {
      print(
          '📱 AITutorScreen: Controller inicializado com histórico ou initialToolResponse. Nenhuma ação de prompt adicional.');
    }

    if (!kIsWeb && Platform.isAndroid) {
      Future.delayed(Duration(milliseconds: 1000), () {
        initSpeechRecognition();
      });
    } else {
      initSpeechRecognition();
    }
    _carregarAnuncioIntersticial();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Mensagem de boas-vindas agora é exibida como overlay
    // _controller.updateWelcomeMessage(context);
  }

  @override
  void dispose() {
    print('🧹 AITutorScreen - dispose chamado');

    // Remover registro no singleton manager
    aiTutorManager.unregister(this);

    // Garantir que a tela pode desligar quando o componente for destruído
    if (!kIsWeb && Platform.isAndroid) {
      _keepScreenOn(false);
    }

    // Garantir que o reconhecimento de voz seja parado
    disposeSpeechResources(); // Chama o método do mixin para liberar recursos de voz

    // Não mostrar anúncio no dispose, pois já está sendo mostrado quando o usuário envia 3 mensagens

    // Liberar recursos do anúncio
    _interstitialAd?.dispose();

    // Remover listener do scroll
    _scrollController.removeListener(_handleScroll);

    _messageController.dispose();
    _scrollController.dispose();
    _animationController.dispose();
    _controller.dispose();

    super.dispose();
  }

  @override
  void deactivate() {
    // Este método é chamado quando a tela é removida da árvore de widgets
    // mas pode ser adicionada novamente, como quando muda de abas
    print('AITutorScreen - deactivate chamado');

    // Verificar se o usuário enviou pelo menos 2 mensagens
    if (_userMessageCount >= 2 &&
        _isInterstitialAdReady &&
        _interstitialAd != null) {
      print(
          "Mostrando anúncio intersticial ao sair após $_userMessageCount mensagens");
      _interstitialAd!.show();

      // Resetar contador após mostrar o anúncio
      _userMessageCount = 0;

      // Carregar novo anúncio para a próxima vez
      Future.delayed(Duration(seconds: 1), () {
        _carregarAnuncioIntersticial();
      });
    }

    super.deactivate();
  }

  // --- Métodos mantidos na View ---

  // Método para manter a tela ligada
  void _keepScreenOn(bool keepOn) {
    ScreenUtils.keepScreenOn(keepOn);
  }

  // Método para rolar para o final da lista
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // Método para controlar a visibilidade do NutritionCard baseado no scroll
  void _handleScroll() {
    if (!_scrollController.hasClients) return;

    final currentOffset = _scrollController.offset;
    final scrollDelta = currentOffset - _lastScrollOffset;

    // Detectar direção do scroll (threshold de 5 pixels para evitar mudanças muito sensíveis)
    if (scrollDelta > 5 && _showNutritionCard) {
      // Rolando para baixo - esconder card
      setState(() {
        _showNutritionCard = false;
      });
    } else if (scrollDelta < -5 && !_showNutritionCard) {
      // Rolando para cima - mostrar card
      setState(() {
        _showNutritionCard = true;
      });
    }

    _lastScrollOffset = currentOffset;
  }

  // --- Métodos removidos (agora no controller) ---

  // void _addWelcomeMessage() {...}
  // void _updateWelcomeMessage() {...}
  // Future<void> _loadConversation(String conversationId) {...}
  // Future<void> _sendMessage() {...}
  // Future<void> _processMessageForAI(String message) {...}
  // Future<void> _processImageForAI(Uint8List imageBytes, String prompt) {...}
  // void _scrollToLastAiResponse() {...}

  // --- UI Widgets ---

  // Mostrar diálogo para configurar a voz
  void _showVoiceSettingsDialog() {
    if (availableVoices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não há vozes disponíveis no momento.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Filtrar vozes em português quando disponíveis
    var ptVoices = availableVoices
        .where((voice) =>
            voice['locale'] != null &&
            voice['locale']!.toLowerCase().startsWith('pt'))
        .toList();
    var voicesToShow = ptVoices.isEmpty ? availableVoices : ptVoices;

    // Limitar para exibir apenas 10 vozes para não sobrecarregar a UI
    if (voicesToShow.length > 10) {
      voicesToShow = voicesToShow.sublist(0, 10);
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              title: Text('Configurações de Voz',
                  style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color)),
              content: Container(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Velocidade da fala:',
                        style: TextStyle(
                            color:
                                Theme.of(context).textTheme.bodyLarge?.color)),
                    Slider(
                      value: rate,
                      min: 0.1,
                      max: 1.0,
                      divisions: 9,
                      label: rate.toStringAsFixed(1),
                      onChanged: (value) {
                        setState(() {
                          setRate(value);
                        });
                      },
                      activeColor: Theme.of(context).primaryColor,
                    ),
                    Text('Tom de voz:',
                        style: TextStyle(
                            color:
                                Theme.of(context).textTheme.bodyLarge?.color)),
                    Slider(
                      value: pitch,
                      min: 0.5,
                      max: 2.0,
                      divisions: 15,
                      label: pitch.toStringAsFixed(1),
                      onChanged: (value) {
                        setState(() {
                          setPitch(value);
                        });
                      },
                      activeColor: Theme.of(context).primaryColor,
                    ),
                    SizedBox(height: 16),
                    Text('Selecione uma voz:',
                        style: TextStyle(
                            color:
                                Theme.of(context).textTheme.bodyLarge?.color)),
                    SizedBox(height: 4),
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: voicesToShow.length,
                        itemBuilder: (context, index) {
                          var voice = voicesToShow[index];
                          var voiceName = voice['name'] ?? 'Voz $index';
                          var isSelected = currentVoice == voiceName;

                          return ListTile(
                            title: Text(voiceName,
                                style: TextStyle(
                                    color: isSelected
                                        ? Theme.of(context).primaryColor
                                        : Theme.of(context)
                                            .textTheme
                                            .bodyLarge
                                            ?.color)),
                            subtitle: Text(
                                voice['locale'] ?? 'Idioma desconhecido',
                                style: TextStyle(
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.color)),
                            selected: isSelected,
                            onTap: () async {
                              if (voice['name'] != null) {
                                await setVoice(voice['name']!);
                                setState(() {}); // Atualizar UI
                                // Falar uma frase de teste
                                speak('Esta é uma demonstração da voz.');
                              }
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: Text('Fechar',
                      style: TextStyle(color: Theme.of(context).primaryColor)),
                  onPressed: () {
                    stopSpeech(); // Parar qualquer voz de teste
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Lidar com a seleção de imagem
  Future<void> _handleImageSelection(ImageSource source) async {
    // Mostrar indicador de carregamento
    _controller.setProcessingMedia(true);

    // Usar o helper para selecionar a imagem
    final bytes = await MediaPickerHelper.pickImage(source, context);

    // O helper já lidou com erros, então apenas desativar o indicador se não houver bytes
    if (bytes == null) {
      _controller.setProcessingMedia(false);
      return;
    }

    // Atualizar o controller com a imagem selecionada
    _controller.setSelectedImage(bytes, source);

    // Foco no campo de texto após selecionar a imagem
    FocusScope.of(context).requestFocus();
  }

  // Método para lidar com o envio de mensagem (botão Enviar ou Enter)
  Future<void> _handleSendMessage() async {
    final message = _messageController.text;

    // Incrementar contador de mensagens do usuário se a mensagem não estiver vazia
    if (message.trim().isNotEmpty) {
      _userMessageCount++;
      print("Contador de mensagens incrementado: $_userMessageCount");
    }

    // Enviar a mensagem e verificar se foi processada (se tinha créditos suficientes)
    final hadEnoughCredits = await _controller.sendMessage(message, context);

    // Apenas limpar o campo se a mensagem foi processada com sucesso
    if (hadEnoughCredits) {
      _messageController.clear();

      // Rolar para o final para mostrar a nova mensagem
      Future.delayed(Duration(milliseconds: 100), () {
        _scrollToBottom();
      });
    }
  }

  // Método para mostrar o menu de opções ao fazer long press
  void _showMessageOptions(String message) {
    final appLocalizations = AppLocalizations.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: Icon(Icons.content_copy,
                    color: Theme.of(context).textTheme.bodyMedium?.color),
                title: Text('Copiar',
                    style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color)),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: message));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(appLocalizations.translate('text_copied')),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.text_fields,
                    color: Theme.of(context).textTheme.bodyMedium?.color),
                title: Text('Selecionar texto',
                    style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color)),
                onTap: () {
                  Navigator.pop(context);
                  // Implementar seleção de texto: copiar para a área de transferência
                  // e mostrar diálogo para facilitar a seleção
                  _showSelectableTextDialog(message);
                },
              ),
              ListTile(
                leading: Icon(
                    isSpeaking ? Icons.stop : Icons.volume_up_outlined,
                    color: Theme.of(context).textTheme.bodyMedium?.color),
                title: Text('Ler em voz alta',
                    style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color)),
                onTap: () {
                  Navigator.pop(context);

                  try {
                    // Encontrar índice da mensagem no array de mensagens
                    int messageIndex = -1;
                    final messages = _controller.messages;
                    for (int i = 0; i < messages.length; i++) {
                      if ((messages[i].containsKey('message') &&
                              messages[i]['message'] == message) ||
                          (messages[i].containsKey('notifier') &&
                              messages[i]['notifier'].message == message)) {
                        messageIndex = i;
                        break;
                      }
                    }

                    if (messageIndex >= 0) {
                      _controller.handleVoiceButtonPressed(
                          messageIndex, context);
                    } else {
                      // Se não encontrar a mensagem específica, lê o texto atual
                      if (isSpeaking) {
                        stopSpeech();
                      } else {
                        speak(message).catchError((error) {
                          print('Erro ao iniciar leitura: $error');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Não foi possível ler o texto. Verifique as permissões do aplicativo.'),
                              backgroundColor: Colors.red,
                              duration: Duration(seconds: 3),
                            ),
                          );
                        });
                      }
                    }
                  } catch (e) {
                    print('Erro ao iniciar leitura de voz: $e');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Função de leitura não disponível no momento.'),
                        backgroundColor: Colors.red,
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.refresh_outlined,
                    color: Theme.of(context).textTheme.bodyMedium?.color),
                title: Text('Gerar resposta novamente',
                    style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color)),
                onTap: () async {
                  Navigator.pop(context);
                  // Chamar o método regenerateLastResponse do controller
                  final hadEnoughCredits =
                      await _controller.regenerateLastResponse(context);

                  // Após iniciar a regeneração, rolar para o final da lista (apenas se houver créditos)
                  if (hadEnoughCredits) {
                    Future.delayed(Duration(milliseconds: 100), () {
                      _scrollToBottom();
                    });
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Método para mostrar o diálogo com texto selecionável
  void _showSelectableTextDialog(String message) {
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            title: Text('Selecionar Texto',
                style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color)),
            content: Container(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: SelectableText(
                  message,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                    fontSize: 16,
                  ),
                  toolbarOptions: ToolbarOptions(
                    copy: true,
                    selectAll: true,
                    cut: false,
                    paste: false,
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                child: Text('Fechar',
                    style: TextStyle(color: Theme.of(context).primaryColor)),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: Text('Copiar Tudo',
                    style: TextStyle(color: Theme.of(context).primaryColor)),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: message));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppLocalizations.of(context)
                          .translate('text_copied')),
                      duration: Duration(seconds: 1),
                    ),
                  );
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDarkMode = brightness == Brightness.dark;
    final appLocalizations = AppLocalizations.of(context);

    // Usar a constante diretamente para garantir a cor
    final Color currentScaffoldBackgroundColor =
        isDarkMode ? AppTheme.darkBackgroundColor : AppTheme.backgroundColor;

    // Usar AnimatedBuilder para reconstruir apenas quando o controller mudar
    return AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final messages = _controller.messages;
          final isLoading = _controller.isLoading;
          // isProcessingMedia no longer used as we removed the condition from TextField enabled property
          final hasSelectedImage = _controller.hasSelectedImage;
          final selectedImageBytes = _controller.selectedImageBytes;
          final currentlySpeakingMessageIndex =
              _controller.currentlySpeakingMessageIndex;

          return Scaffold(
            backgroundColor: currentScaffoldBackgroundColor,
            body: SafeArea(
              child: Column(
                children: [
                  // Calendário semanal
                  Consumer<DailyMealsProvider>(
                    builder: (context, mealsProvider, child) {
                      return WeeklyCalendar(
                        selectedDate: mealsProvider.selectedDate,
                        onDaySelected: (date) {
                          print('Data selecionada: $date');
                          mealsProvider.setSelectedDate(date);
                        },
                        onSearchPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const FoodSearchScreen(),
                            ),
                          );
                        },
                      );
                    },
                  ),

                  // Nutrition card (com animação de visibilidade)
                  AnimatedSize(
                    duration: Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: _showNutritionCard
                        ? Consumer2<NutritionGoalsProvider, DailyMealsProvider>(
                            builder: (context, nutritionProvider, mealsProvider, child) {
                              // Ocultar o card se não houver refeições registradas no dia
                              if (mealsProvider.todayMeals.isEmpty) {
                                return SizedBox.shrink();
                              }

                              return NutritionCard(
                                caloriesConsumed: mealsProvider.totalCalories,
                                caloriesGoal: nutritionProvider.caloriesGoal,
                                proteinConsumed: mealsProvider.totalProtein.toInt(),
                                proteinGoal: nutritionProvider.proteinGoal,
                                carbsConsumed: mealsProvider.totalCarbs.toInt(),
                                carbsGoal: nutritionProvider.carbsGoal,
                                fatsConsumed: mealsProvider.totalFat.toInt(),
                                fatsGoal: nutritionProvider.fatGoal,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const DailyMealsScreen(),
                                    ),
                                  );
                                },
                              );
                            },
                          )
                        : SizedBox.shrink(),
                  ),

                  // Lista de mensagens
                  Expanded(
                    child: Stack(
                      children: [
                        // ListView (só renderiza quando há mensagens)
                        if (messages.isNotEmpty)
                          ListView.builder(
                            controller: _scrollController,
                            padding: EdgeInsets.all(16),
                            // Adicionar +1 para o card de ferramentas quando existir
                            itemCount: messages.length +
                                (_toolData != null ? 1 : 0) +
                                (messages.isNotEmpty && !messages.last['isUser']
                                    ? 1
                                    : 0),
                            itemBuilder: (context, index) {
                              // Mostrar o card de ferramentas como primeiro item
                              if (_toolData != null && index == 0) {
                                return _buildToolCard(isDarkMode);
                              }

                              // Ajustar índice para compensar o card de ferramentas
                              final adjustedIndex =
                                  _toolData != null ? index - 1 : index;

                              if (adjustedIndex < messages.length) {
                                return _buildMessageBubble(
                                  messageData: messages[adjustedIndex]
                                          .containsKey('notifier')
                                      ? messages[adjustedIndex]['notifier']
                                      : messages[adjustedIndex],
                                  isUser: messages[adjustedIndex]['isUser'],
                                  timestamp: messages[adjustedIndex]
                                      ['timestamp'],
                                  isDarkMode: isDarkMode,
                                  index: adjustedIndex,
                                  currentlySpeakingMessageIndex:
                                      currentlySpeakingMessageIndex,
                                );
                              } else {
                                // Exibir botões de ação após a última mensagem da IA
                                return Padding(
                                  padding: EdgeInsets.only(top: 4),
                                  child: _buildActionButtons(
                                      currentlySpeakingMessageIndex),
                                );
                              }
                            },
                          ),

                        // Mensagem de boas-vindas sobreposta (só aparece quando não há mensagens)
                        if (messages.isEmpty)
                          Positioned.fill(
                            child: Container(
                              color: currentScaffoldBackgroundColor,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Saudação personalizada
                                      Consumer<AuthService>(
                                        builder: (context, authService, child) {
                                          final userName = authService.currentUser?.name?.split(' ').first ?? 'Olá';
                                          return RichText(
                                            text: TextSpan(
                                              children: [
                                                TextSpan(
                                                  text: authService.isAuthenticated ? 'Olá, $userName,\n' : 'Olá,\n',
                                                  style: TextStyle(
                                                    fontSize: 24,
                                                    fontWeight: FontWeight.w300,
                                                    color: isDarkMode
                                                        ? Colors.white
                                                        : AppTheme.textPrimaryColor,
                                                    height: 1.2,
                                                  ),
                                                ),
                                                TextSpan(
                                                  text: 'Como posso\najudar você?',
                                                  style: TextStyle(
                                                    fontSize: 32,
                                                    fontWeight: FontWeight.bold,
                                                    color: isDarkMode
                                                        ? Colors.white
                                                        : AppTheme.textPrimaryColor,
                                                    height: 1.2,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                      SizedBox(height: 32),
                                      // Botões de ação sugeridos
                                      _buildSuggestionButton(
                                        icon: '🍽️',
                                        text: 'Registrar refeição',
                                        isDarkMode: isDarkMode,
                                        onTap: () {
                                          _messageController.text = 'Quero registrar uma refeição';
                                          _handleSendMessage();
                                        },
                                      ),
                                      SizedBox(height: 12),
                                      _buildSuggestionButton(
                                        icon: '📸',
                                        text: 'Tirar foto e analisar',
                                        isDarkMode: isDarkMode,
                                        onTap: () {
                                          _handleImageSelection(ImageSource.camera);
                                        },
                                      ),
                                      SizedBox(height: 12),
                                      _buildSuggestionButton(
                                        text: 'Perguntar sobre nutrição',
                                        isDarkMode: isDarkMode,
                                        onTap: () {
                                          FocusScope.of(context).requestFocus();
                                        },
                                      ),
                                      SizedBox(height: 12),
                                      _buildSuggestionButton(
                                        text: 'Ver meu progresso',
                                        isDarkMode: isDarkMode,
                                        onTap: () {
                                          _messageController.text = 'Quero ver meu progresso nutricional';
                                          _handleSendMessage();
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Área de input
                  Container(
                    decoration: BoxDecoration(
                      color: currentScaffoldBackgroundColor,
                    ),
                    padding:
                        EdgeInsets.only(left: 16, right: 16, bottom: 6, top: 8),
                    child: Column(
                      children: [
                        // Exibir miniatura da imagem selecionada
                        if (hasSelectedImage && selectedImageBytes != null)
                          Padding(
                            padding:
                                EdgeInsets.only(left: 16, right: 16, bottom: 8),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isDarkMode
                                      ? Color(0xFF303030)
                                      : AppTheme.surfaceColor,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                width: 80,
                                height: 80,
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.memory(
                                        selectedImageBytes,
                                        height: 80,
                                        width: 80,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: GestureDetector(
                                        onTap: () {
                                          _controller.clearSelectedImage();
                                        },
                                        child: Container(
                                          padding: EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: isDarkMode
                                                ? Colors.black.withOpacity(0.6)
                                                : AppTheme.surfaceColor,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.close,
                                            color: isDarkMode
                                                ? Colors.white
                                                : AppTheme.textPrimaryColor,
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        Container(
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? Color(0xFF303030)
                                : AppTheme
                                    .surfaceColor, // Cor de fundo escuro para o input
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding:
                              EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Row(
                            children: [
                              // Botão de galeria/foto
                              IconButton(
                                icon: Icon(Icons.camera_alt,
                                    color: isDarkMode
                                        ? Colors.grey[400]
                                        : AppTheme.textSecondaryColor),
                                onPressed: () {
                                  showModalBottomSheet(
                                    context: context,
                                    backgroundColor: Theme.of(context)
                                        .scaffoldBackgroundColor,
                                    builder: (context) => SafeArea(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          ListTile(
                                            leading: Icon(Icons.photo_library,
                                                color: isDarkMode
                                                    ? Colors.white70
                                                    : AppTheme
                                                        .textSecondaryColor),
                                            title: Text('Galeria',
                                                style: TextStyle(
                                                    color: isDarkMode
                                                        ? Colors.white
                                                        : AppTheme
                                                            .textPrimaryColor)),
                                            onTap: () {
                                              Navigator.pop(context);
                                              _handleImageSelection(
                                                  ImageSource.gallery);
                                            },
                                          ),
                                          ListTile(
                                            leading: Icon(Icons.camera_alt,
                                                color: isDarkMode
                                                    ? Colors.white70
                                                    : AppTheme
                                                        .textSecondaryColor),
                                            title: Text('Câmera',
                                                style: TextStyle(
                                                    color: isDarkMode
                                                        ? Colors.white
                                                        : AppTheme
                                                            .textPrimaryColor)),
                                            onTap: () {
                                              Navigator.pop(context);
                                              _handleImageSelection(
                                                  ImageSource.camera);
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                                splashRadius: 20,
                              ),

                              // Campo de texto
                              Expanded(
                                child: TextField(
                                  controller: _messageController,
                                  decoration: InputDecoration(
                                    hintText:
                                        context.tr.translate('ask_anything') ??
                                            "Pergunte qualquer coisa",
                                    hintStyle: TextStyle(
                                      fontSize: 15,
                                      color: isListening
                                          ? Colors.red
                                          : isDarkMode
                                              ? Colors.grey[500]
                                              : AppTheme.textSecondaryColor,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                        vertical: 10, horizontal: 0),
                                    focusedBorder: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    errorBorder: InputBorder.none,
                                    disabledBorder: InputBorder.none,
                                    fillColor: isListening
                                        ? Color(
                                            0xFF3B2E2E) // Tom avermelhado quando gravando
                                        : isDarkMode
                                            ? Color(0xFF303030)
                                            : AppTheme.surfaceColor,
                                    filled: true,
                                  ),
                                  style: TextStyle(
                                      color: isDarkMode
                                          ? Colors.white
                                          : AppTheme.textPrimaryColor),
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  maxLines: null,
                                  onChanged: (text) {
                                    setState(() {});
                                  },
                                  enabled:
                                      true, // Sempre habilitado, mesmo durante o carregamento
                                  cursorColor: isDarkMode
                                      ? Colors.grey[400]
                                      : AppTheme.textPrimaryColor,
                                ),
                              ),

                              // Botão de microfone ou enviar
                              IconButton(
                                icon: isListening
                                    ? Icon(
                                        Icons.stop_circle,
                                        color: Colors.red,
                                        size: 28,
                                      )
                                    : Icon(
                                        isLoading
                                            ? Icons.stop_circle
                                            : _messageController.text
                                                        .trim()
                                                        .isEmpty &&
                                                    !hasSelectedImage
                                                ? Icons.mic
                                                : Icons.send,
                                        color: isLoading
                                            ? Colors.red
                                            : isDarkMode
                                                ? Colors.grey[400]
                                                : AppTheme.textSecondaryColor,
                                      ),
                                onPressed: () {
                                  if (isLoading) {
                                    // Se estiver carregando, interromper a geração
                                    _controller.stopGeneration();
                                  } else if (isListening) {
                                    stopListening();
                                    // Forçar atualização da UI após parar
                                    setState(() {});
                                  } else if (_messageController.text
                                          .trim()
                                          .isEmpty &&
                                      !hasSelectedImage) {
                                    startListening();
                                  } else {
                                    _handleSendMessage();
                                  }
                                },
                                splashRadius: 20,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        });
  }

  Widget _buildMessageBubble({
    required dynamic messageData,
    required bool isUser,
    required DateTime timestamp,
    required bool isDarkMode,
    required int index,
    required int? currentlySpeakingMessageIndex,
  }) {
    // Verifica se estamos usando o notificador ou mensagem direta
    final bool usingNotifier = messageData is MessageNotifier;
    final bool isError = usingNotifier
        ? messageData.isError
        : messageData.containsKey('error')
            ? messageData['error'] ?? false
            : false;
    final bool isStreaming = usingNotifier
        ? messageData.isStreaming
        : messageData.containsKey('streaming')
            ? messageData['streaming'] ?? false
            : false;

    // Obter a mensagem
    String message = '';
    if (usingNotifier) {
      message = messageData.message;
    } else if (messageData.containsKey('message')) {
      message = messageData['message'];
    }

    // Verificar se tem imagem
    Uint8List? imageBytes;
    if (!usingNotifier &&
        messageData.containsKey('hasImage') &&
        messageData['hasImage'] == true) {
      imageBytes = messageData['imageBytes'];
    }

    // Se for notificador, vamos usar um ChangeNotifierProvider para atualizar apenas este widget
    if (usingNotifier) {
      return ChangeNotifierProvider.value(
        value: messageData as MessageNotifier,
        child: Consumer<MessageNotifier>(
          builder: (context, notifier, _) {
            return MessageUIHelper.buildSimpleMessageBubble(
              context: context,
              message: notifier.message,
              isUser: isUser,
              isError: notifier.isError,
              isStreaming: notifier.isStreaming,
              onLongPress: () => _showMessageOptions(notifier.message),
            );
          },
        ),
      );
    } else {
      // Se não for notificador, usamos a forma tradicional
      return MessageUIHelper.buildSimpleMessageBubble(
        context: context,
        message: message,
        isUser: isUser,
        isError: isError,
        isStreaming: isStreaming,
        onLongPress: () => _showMessageOptions(message),
        imageBytes: imageBytes,
      );
    }
  }

  // Widget para os botões de ação abaixo da última mensagem
  Widget _buildActionButtons(int? currentlySpeakingMessageIndex) {
    final messages = _controller.messages;

    return Container(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          MessageUIHelper.buildActionButton(Icons.content_copy, () {
            // Copiar última mensagem da IA
            if (messages.isNotEmpty) {
              int lastAIIndex = messages.length - 1;
              if (!messages[lastAIIndex]['isUser']) {
                String message = '';
                if (messages[lastAIIndex].containsKey('message')) {
                  message = messages[lastAIIndex]['message'];
                } else if (messages[lastAIIndex].containsKey('notifier')) {
                  message = messages[lastAIIndex]['notifier'].message;
                }
                Clipboard.setData(ClipboardData(text: message));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        AppLocalizations.of(context).translate('text_copied')),
                    duration: Duration(seconds: 1),
                  ),
                );
              }
            }
          }),
          SizedBox(width: 12), // Espaçamento menor entre os ícones
          GestureDetector(
            onLongPress: _showVoiceSettingsDialog,
            child: MessageUIHelper.buildActionButton(
                isSpeaking &&
                        currentlySpeakingMessageIndex == messages.length - 1
                    ? Icons.stop
                    : Icons.volume_up_outlined, () {
              // Ler ou parar a leitura da mensagem da IA
              _controller.handleVoiceButtonPressed(
                  messages.length - 1, context);
            }),
          ),
          SizedBox(width: 16),
          MessageUIHelper.buildActionButton(Icons.refresh_outlined, () async {
            // Regenerar resposta - verificar se há créditos suficientes
            final hadEnoughCredits =
                await _controller.regenerateLastResponse(context);

            // Rolar para o final da lista apenas se houver créditos
            if (hadEnoughCredits) {
              Future.delayed(Duration(milliseconds: 100), () {
                _scrollToBottom();
              });
            }
          }),
        ],
      ),
    );
  }

  // Carregar anúncio intersticial usando o AdManager
  void _carregarAnuncioIntersticial() {
    // Não carregar anúncios na web
    if (kIsWeb) {
      print("AITutorScreen: Pulando carregamento de anúncios na versão web");
      return;
    }

    AdManager.loadInterstitialAd(
      onAdLoaded: (ad) {
        _interstitialAd = ad;
        _isInterstitialAdReady = true;
        print("Anúncio intersticial carregado com sucesso no AI Tutor");
      },
      onAdFailedToLoad: (error) {
        print(
            'AI Tutor: Falha ao carregar anúncio intersticial: ${error.message}');
        _isInterstitialAdReady = false;
      },
      onAdDismissed: (ad) {
        _isInterstitialAdReady = false;
      },
    );
  }

  // Método público que pode ser chamado de fora para simular o comportamento do deactivate
  // Este método contém a mesma lógica que o método deactivate() original
  void handleTabChanged() {
    print('AITutorScreen - handleTabChanged chamado ao trocar de aba');

    // Não mostrar anúncios na web
    if (kIsWeb) {
      return;
    }

    // Verificar se o usuário enviou pelo menos 2 mensagens
    if (_userMessageCount >= 2 &&
        _isInterstitialAdReady &&
        _interstitialAd != null) {
      print(
          "Mostrando anúncio intersticial ao trocar de aba após $_userMessageCount mensagens");
      _interstitialAd!.show();

      // Resetar contador após mostrar o anúncio
      _userMessageCount = 0;

      // Carregar novo anúncio para a próxima vez
      Future.delayed(Duration(seconds: 1), () {
        _carregarAnuncioIntersticial();
      });
    }
  }

  Widget _buildToolCard(bool isDarkMode) {
    final toolName = _toolData?['toolName'] ?? 'Ferramenta';
    final toolTab = _toolData?['toolTab'] ?? '';
    final userInput = _toolData?['userInput'] ?? '';
    final thumbnailUrl = _toolData?['thumbnailUrl'] as String?;
    final hasTranscript = _toolData?['hasTranscript'] as bool? ?? false;
    final transcript = _toolData?['transcript'] as String? ?? '';

    // Parâmetros avançados extraídos diretamente do JSON
    final Map<String, dynamic>? advancedParams = _toolData?['advancedParams'];

    // Verificar se há imagem da câmera
    final String? imageData = _toolData?['imageData'] as String?;
    final bool isFromCamera = _toolData?['sourceType'] == 'camera';
    Uint8List? cameraImageBytes;

    // Decodificar imagem base64 se existir
    if (isFromCamera && imageData != null && imageData.isNotEmpty) {
      try {
        cameraImageBytes = base64Decode(imageData);
      } catch (e) {
        print('Erro ao decodificar imagem: $e');
      }
    }

    return Container(
      padding: EdgeInsets.all(16),
      margin: EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      decoration: BoxDecoration(
        color: isDarkMode ? Color(0xFF303030) : AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode
              ? Colors.grey.withOpacity(0.3)
              : Colors.grey.withOpacity(0.2),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho com nome da ferramenta e aba
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                size: 20,
                color: Theme.of(context).primaryColor,
              ),
              SizedBox(width: 8),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: toolName,
                        style: TextStyle(
                          color: isDarkMode
                              ? Colors.white
                              : AppTheme.textPrimaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (toolTab.isNotEmpty)
                        TextSpan(
                          text: ' › $toolTab',
                          style: TextStyle(
                            color: isDarkMode
                                ? Colors.white70
                                : AppTheme.textSecondaryColor,
                            fontSize: 14,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Separador
          Divider(
            height: 16,
            thickness: 0.5,
            color: isDarkMode
                ? Colors.grey.withOpacity(0.3)
                : Colors.grey.withOpacity(0.2),
          ),

          // Thumbnail do vídeo (YouTube) ou imagem da câmera
          if (thumbnailUrl != null && thumbnailUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: Image.network(
                    thumbnailUrl,
                    height: 180,
                    width: 180,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 180,
                        width: 180,
                        color: Colors.grey[300],
                        child: Center(child: Icon(Icons.broken_image)),
                      );
                    },
                  ),
                ),
              ),
            )
          else if (isFromCamera && cameraImageBytes != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: Image.memory(
                    cameraImageBytes,
                    height: 180,
                    width: 180,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 180,
                        width: 180,
                        color: Colors.grey[300],
                        child: Center(child: Icon(Icons.broken_image)),
                      );
                    },
                  ),
                ),
              ),
            ),

          // Conteúdo do usuário ou Título do vídeo
          if (userInput.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                userInput,
                style: TextStyle(
                  color: isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

          // Botão para ver/ocultar transcrição
          if (hasTranscript && transcript.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _showToolTranscript = !_showToolTranscript;
                  });
                },
                icon: Icon(
                  _showToolTranscript ? Icons.visibility_off : Icons.visibility,
                  size: 18,
                ),
                label: Text(
                  _showToolTranscript
                      ? context.tr.translate('hide_transcript')
                      : context.tr.translate('view_full_transcript'),
                  style: TextStyle(fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  side: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
            ),

          // Texto da transcrição (se visível)
          if (hasTranscript && _showToolTranscript && transcript.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.grey.withOpacity(0.1)
                      : Colors.grey.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  transcript,
                  style: TextStyle(
                    color: isDarkMode
                        ? Colors.white70
                        : AppTheme.textSecondaryColor,
                    fontSize: 13,
                  ),
                ),
              ),
            ),

          // Parâmetros avançados como tags
          if (advancedParams != null &&
              advancedParams.isNotEmpty &&
              toolName != 'YouTube Summary') ...[
            SizedBox(height: 12),
            Text(
              'Parâmetros:',
              style: TextStyle(
                color:
                    isDarkMode ? Colors.white70 : AppTheme.textSecondaryColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: advancedParams.entries.map((entry) {
                return Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.grey.withOpacity(0.15)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).primaryColor.withOpacity(0.3),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    '${entry.key}: ${entry.value}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode
                          ? Theme.of(context).primaryColor.withOpacity(0.9)
                          : Theme.of(context).primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // Widget para botões de sugestão na tela de boas-vindas
  Widget _buildSuggestionButton({
    String? icon,
    required String text,
    required bool isDarkMode,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: isDarkMode
              ? Color(0xFF1E1E1E)
              : Colors.white,
          borderRadius: BorderRadius.circular(50),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Text(
                icon,
                style: TextStyle(fontSize: 20),
              ),
              SizedBox(width: 12),
            ],
            Text(
              text,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: isDarkMode ? Colors.white.withValues(alpha: 0.9) : Color(0xFF333333),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Implementação de AITutorSpeechMixinRef que delega para o mixin
class _SpeechMixinRefImpl implements AITutorSpeechMixinRef {
  final AITutorSpeechMixin _mixin;

  _SpeechMixinRefImpl(this._mixin);

  @override
  bool get isListening => _mixin.isListening;

  @override
  Future<void> releaseAudioResources() => _mixin.releaseAudioResources();

  @override
  void stopListening() => _mixin.stopListening();
}

// Implementação de TextToSpeechMixinRef que delega para o mixin
class _TTSMixinRefImpl implements TextToSpeechMixinRef {
  final TextToSpeechMixin _mixin;

  _TTSMixinRefImpl(this._mixin);

  @override
  bool get isSpeaking => _mixin.isSpeaking;

  @override
  Future<void> speak(String text) => _mixin.speak(text);

  @override
  void stopSpeech() => _mixin.stopSpeech();
}
