import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../controllers/ai_tutor_controller.dart'; // Novo import para o controller
import '../services/ai_service.dart';
import '../services/storage_service.dart';
import '../services/ad_manager.dart';
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
import '../widgets/food_json_display.dart';
import '../providers/free_chat_provider.dart';
import 'daily_meals_screen.dart';
import 'food_search_screen.dart';
import 'camera_scan_screen.dart';
import 'profile_screen.dart';
import 'login_screen.dart';
import 'nutrition_goals_wizard_screen.dart';
import '../utils/food_json_parser.dart';

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
  final bool isFreeChat; // Indica se é modo conversa livre (sem JSON)
  final String? freeChatId; // ID da conversa livre
  final VoidCallback? onOpenDrawer;
  final String? toolType;

  const AITutorScreen({
    Key? key,
    this.conversationId,
    this.initialPrompt,
    this.initialToolResponse,
    this.isFreeChat = false,
    this.freeChatId,
    this.onOpenDrawer,
    this.toolType,
  }) : super(key: key);

  @override
  AITutorScreenState createState() => AITutorScreenState();

  // Método que permite chamar a lógica de deactivate externamente
  static void handleTabExit() {
    aiTutorManager.handleTabExit();
  }
}

class AITutorScreenState extends State<AITutorScreen>
    with
        TickerProviderStateMixin,
        AITutorSpeechMixin,
        TextToSpeechMixin,
        WidgetsBindingObserver {
  // Controller que gerenciará o estado e lógica (será inicializado no initState)
  late AITutorController _controller;

  // Serviços - Agora gerenciados pelo Controller
  // final AIService _aiService = AIService();
  // final StorageService _storageService = StorageService();

  // Controllers para UI
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();

  // Para animação do ícone pulsante
  late AnimationController _animationController;

  // Controle de visibilidade do header (calendário + nutrition card)
  // Usa offset gradual para efeito suave como o AppBar nativo
  double _headerOffset = 0.0; // 0 = totalmente visível, negativo = parcialmente escondido
  double _lastScrollPosition = 0.0;
  final GlobalKey _lastAiMessageKey =
      GlobalKey(); // Key para rastrear a última mensagem da IA
  bool _isScrollingProgrammatically =
      false; // Flag para ignorar scroll automático no _handleScroll

  // Contador de mensagens do usuário
  int _userMessageCount = 0;

  // Anúncio intersticial
  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdReady = false;

  // Dados da ferramenta quando vem de GenericAIScreen
  Map<String, dynamic>? _toolData;
  bool _showToolTranscript =
      false; // Estado para controlar a visibilidade da transcrição no card

  // Lista de sugestões para mostrar ao usuário
  List<String> _suggestions = [];

  // Controlar estado anterior do teclado para detectar quando fecha
  double _lastKeyboardHeight = 0;

  // Flag para controlar se já fizemos o scroll inicial após carregar mensagens
  bool _hasScrolledToInitialMessages = false;

  // Método para mostrar sugestões baseado na ação
  void _showSuggestionsForAction(String actionType) {
    setState(() {
      switch (actionType) {
        case 'registrar_refeicao':
          _suggestions = [
            'Comi 2 pães de forma com 1 copo de leite',
            'Comi um pedaço grande de bolo de chocolate',
            '200g de feijão com 150g de arroz e carne',
            '1 filé de frango cru 120g, salada e 2 colheres de arroz',
          ];
          break;
        case 'sugestoes_refeicoes':
          _suggestions = [
            'Me sugira um almoço saudável e prático',
            'O que posso comer no café da manhã para emagrecer?',
            'O que comer para ganhar peso sendo magro?',
            'Monte um cardápio completo para o meu dia',
          ];
          break;
        case 'perguntar_nutricao':
          _suggestions = [
            'Não consigo emagrecer, o que posso estar fazendo errado?',
            'Como ganhar massa muscular rapidamente?',
            'Como controlar a vontade de comer doces?',
            'Posso comer carboidrato à noite?',
          ];
          break;
        default:
          _suggestions = [];
      }
    });
    // Focar no input após construir o widget
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      FocusScope.of(context).requestFocus(_inputFocusNode);
      SystemChannels.textInput.invokeMethod('TextInput.show');
    });
  }

  // Método para limpar sugestões
  void _clearSuggestions() {
    if (mounted) {
      setState(() {
        _suggestions = [];
      });
    }
  }

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

  // ID da conversa livre atual
  String? _currentFreeChatId;

  @override
  void initState() {
    super.initState();
    print('🚀 AITutorScreen - initState chamado');
    print('   - conversationId: ${widget.conversationId}');
    print('   - isFreeChat: ${widget.isFreeChat}');
    print('   - freeChatId: ${widget.freeChatId}');
    print(
        '   - initialPrompt (JSON da ferramenta): ${widget.initialPrompt?.substring(0, math.min(100, widget.initialPrompt?.length ?? 0))}...');
    print(
        '   - initialToolResponse (Resposta da IA para ferramenta): ${widget.initialToolResponse?.substring(0, math.min(100, widget.initialToolResponse?.length ?? 0))}...');

    aiTutorManager.register(this);
    _animationController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    // Adicionar listener para controlar a visibilidade do header
    _scrollController.addListener(_handleScroll);

    // Registrar observer para detectar mudanças no teclado
    WidgetsBinding.instance.addObserver(this);

    // MODO CONVERSA LIVRE
    if (widget.isFreeChat) {
      _initFreeChatMode();
      return;
    }

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

    // Obter a data selecionada do provider
    final mealsProvider =
        Provider.of<DailyMealsProvider>(context, listen: false);
    final selectedDate = mealsProvider.selectedDate;

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
      initialDate: selectedDate, // Passa a data inicial do calendário
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
      // Rolar até a última resposta da IA ao carregar uma conversa existente
      Future.delayed(Duration(milliseconds: 500), () {
        _scrollToLastAiResponse();
      });
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

  /// Inicializa o modo de conversa livre
  void _initFreeChatMode() {
    // Determinar o toolType baseado no parâmetro widget.toolType
    final effectiveToolType = widget.toolType ?? 'free_chat';
    print(
        '💬 AITutorScreen: Iniciando modo conversa livre (toolType: $effectiveToolType)');

    final freeChatProvider =
        Provider.of<FreeChatProvider>(context, listen: false);
    List<Map<String, dynamic>>? initialMessages;

    // Verificar se tem um freeChatId para carregar
    if (widget.freeChatId != null) {
      _currentFreeChatId = widget.freeChatId;
      initialMessages = freeChatProvider.getMessages(widget.freeChatId!);
      print(
          '📂 AITutorScreen: Carregando conversa livre existente: ${widget.freeChatId}');
    } else {
      // Criar nova conversa
      _currentFreeChatId = freeChatProvider.createConversation();
      print(
          '📝 AITutorScreen: Nova conversa livre criada: $_currentFreeChatId');
    }

    // Inicializar controller para conversa livre
    _controller = AITutorController(
      speechMixin: _speechMixinRef,
      ttsRef: _ttsMixinRef,
      toolType: effectiveToolType,
      showWelcomeMessage: initialMessages == null || initialMessages.isEmpty,
      initialMessages: initialMessages,
    );

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
  void didChangeMetrics() {
    // Detecta mudanças nas métricas (incluindo o teclado)
    final bottomInset = View.of(context).viewInsets.bottom;

    // Detectar apenas quando o teclado FECHA (estava aberto e agora fechou)
    // Se tinha altura anterior > 0 e agora é 0, o teclado fechou
    if (_lastKeyboardHeight > 0 &&
        bottomInset == 0 &&
        _suggestions.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _suggestions = [];
          });
        }
      });
    }

    // Atualizar a altura anterior
    _lastKeyboardHeight = bottomInset;
  }

  @override
  void dispose() {
    print('🧹 AITutorScreen - dispose chamado');

    // Remover observer
    WidgetsBinding.instance.removeObserver(this);

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
    _inputFocusNode.dispose();
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

  // Método para rolar até o início da última resposta da IA
  void _scrollToLastAiResponse({bool animate = false}) {
    if (!_scrollController.hasClients) return;

    final messages = _controller.messages;
    if (messages.isEmpty) return;

    // Encontrar o índice da última mensagem da IA (isUser == false)
    int lastAiMessageIndex = -1;
    for (int i = messages.length - 1; i >= 0; i--) {
      if (messages[i]['isUser'] == false) {
        lastAiMessageIndex = i;
        break;
      }
    }

    // Se não encontrou mensagem da IA, não faz nada
    if (lastAiMessageIndex == -1) return;

    // Aguardar o próximo frame para garantir que as mensagens foram renderizadas
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients || !mounted) return;

      // Tentar usar Scrollable.ensureVisible que considera automaticamente o viewport
      try {
        final context = _lastAiMessageKey.currentContext;
        if (context != null) {
          // Ativar flag para ignorar eventos de scroll automático no _handleScroll
          _isScrollingProgrammatically = true;

          // Usar ensureVisible com alinhamento no topo do viewport
          Scrollable.ensureVisible(
            context,
            alignment: 0.0, // 0.0 = topo do viewport, 1.0 = bottom
            duration: animate ? Duration(milliseconds: 300) : Duration.zero,
            curve: animate ? Curves.easeOut : Curves.linear,
          ).then((_) {
            _isScrollingProgrammatically = false;
          });
          return;
        }
      } catch (e) {
        print('Erro ao usar ensureVisible: $e');
      }

      // Fallback: usar estimativa se não conseguir pegar a posição real
      final adjustedIndex =
          _toolData != null ? lastAiMessageIndex + 1 : lastAiMessageIndex;
      final estimatedItemHeight = 80.0;
      final targetPosition = (adjustedIndex * estimatedItemHeight) * 0.7;
      final maxScroll = _scrollController.position.maxScrollExtent;
      final scrollPosition = targetPosition.clamp(0.0, maxScroll);

      _isScrollingProgrammatically = true;

      if (animate) {
        _scrollController
            .animateTo(
          scrollPosition,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        )
            .then((_) {
          _isScrollingProgrammatically = false;
        });
      } else {
        _scrollController.jumpTo(scrollPosition);
        Future.delayed(Duration(milliseconds: 50), () {
          _isScrollingProgrammatically = false;
        });
      }
    });
  }

  // Método simples para controlar visibilidade do header baseado na direção do scroll
  // Similar ao comportamento nativo do AppBar com floating: true, snap: true
  void _handleScroll() {
    if (!_scrollController.hasClients) return;

    // Ignorar se for scroll programático (automático)
    if (_isScrollingProgrammatically) {
      _lastScrollPosition = _scrollController.offset;
      return;
    }

    final currentScrollPosition = _scrollController.offset;
    final scrollDelta = currentScrollPosition - _lastScrollPosition;

    // Threshold mínimo para evitar mudanças por micro-movimentos
    if (scrollDelta.abs() < 2) return;

    setState(() {
      // Se estiver no topo, sempre mostrar o header completamente
      if (currentScrollPosition < 10) {
        _headerOffset = 0.0;
      } else {
        // Atualizar offset gradualmente baseado no movimento do scroll
        // scrollDelta > 0 = scrollando para baixo = esconder (offset negativo)
        // scrollDelta < 0 = scrollando para cima = mostrar (offset volta para 0)
        _headerOffset = (_headerOffset - scrollDelta).clamp(-175.0, 0.0);
      }

      _lastScrollPosition = currentScrollPosition;
    });
  }

  // Método para mostrar o header programaticamente
  void _showHeader() {
    if (_headerOffset < 0) {
      setState(() {
        _headerOffset = 0.0;
      });
    }
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

      // Rolar até o início da última resposta da IA com animação
      Future.delayed(Duration(milliseconds: 100), () {
        _scrollToLastAiResponse(animate: true);
      });
    }
  }

  // Método para mostrar o menu de opções ao fazer long press
  void _showMessageOptions(String message, bool isUser) {
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
              // Opção de editar - apenas para mensagens do usuário
              if (isUser)
                ListTile(
                  leading: Icon(Icons.edit,
                      color: Theme.of(context).textTheme.bodyMedium?.color),
                  title: Text('Editar',
                      style: TextStyle(
                          color: Theme.of(context).textTheme.bodyLarge?.color)),
                  onTap: () {
                    Navigator.pop(context);
                    // Preencher o campo de texto com a mensagem
                    _messageController.text = message;
                    // Focar no campo de texto
                    FocusScope.of(context).requestFocus(_inputFocusNode);
                    // Mover o cursor para o final do texto
                    _messageController.selection = TextSelection.fromPosition(
                      TextPosition(offset: _messageController.text.length),
                    );
                  },
                ),
              // Ler em voz alta - apenas para mensagens da IA
              if (!isUser)
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
              // Gerar resposta novamente - apenas para mensagens da IA
              if (!isUser)
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

                    // Após iniciar a regeneração, rolar até o início da última resposta da IA (apenas se houver créditos)
                    if (hadEnoughCredits) {
                      Future.delayed(Duration(milliseconds: 100), () {
                        _scrollToLastAiResponse(animate: true);
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

          // Fazer scroll para as mensagens carregadas inicialmente (apenas uma vez)
          if (!_hasScrolledToInitialMessages &&
              messages.isNotEmpty &&
              !isLoading) {
            _hasScrolledToInitialMessages = true;
            print(
                '📱 AITutorScreen: Mensagens carregadas, fazendo scroll inicial');
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollToLastAiResponse();
            });
          }

          return PopScope(
            canPop: _suggestions.isEmpty,
            onPopInvokedWithResult: (didPop, result) {
              if (!didPop && _suggestions.isNotEmpty) {
                // Se tem sugestões visíveis, limpar em vez de sair
                _clearSuggestions();
              }
            },
            child: Scaffold(
              backgroundColor: currentScaffoldBackgroundColor,
              body: SafeArea(
              child: Column(
                children: [
                  // AppBar sempre fixo (não se move com o scroll)
                  Consumer<DailyMealsProvider>(
                    builder: (context, mealsProvider, child) {
                      return WeeklyCalendar(
                        selectedDate: mealsProvider.selectedDate,
                        showAppBar: true, // Mostrar apenas o AppBar
                        showCalendar: false, // Sem o calendário semanal
                        isFreeChat: widget.isFreeChat, // Modo conversa livre
                        onOpenDrawer: widget.onOpenDrawer,
                        onDaySelected: widget.isFreeChat
                            ? null
                            : (date) async {
                                print('Data selecionada: $date');

                                // Limpar sugestões ao mudar de dia
                                _clearSuggestions();

                                // Mostrar o header ao clicar em um dia
                                _showHeader();

                                mealsProvider.setSelectedDate(date);
                                await _controller.changeSelectedDate(date);

                                // Scroll instantâneo para a última resposta da IA
                                _scrollToLastAiResponse();
                              },
                        onSearchPressed: widget.isFreeChat
                            ? null
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const FoodSearchScreen(),
                                  ),
                                );
                              },
                      );
                    },
                  ),

                  // Calendário semanal + Nutrition card com comportamento de toolbar Android
                  // Usa Transform.translate para movimento gradual suave
                  // Não mostrar no modo conversa livre
                  if (!widget.isFreeChat)
                    Consumer<DailyMealsProvider>(
                      builder: (context, mealsProvider, child) {
                        // Calcular altura baseado se tem refeições
                        final bool hasMeals = mealsProvider.todayMeals.isNotEmpty;
                        final double maxHeight = hasMeals ? 175.0 : 75.0;
                        // Altura visível = maxHeight + offset (offset é negativo)
                        final double visibleHeight =
                            (maxHeight + _headerOffset).clamp(0.0, maxHeight);

                        return SizedBox(
                          height: visibleHeight,
                          child: ClipRect(
                            child: OverflowBox(
                              maxHeight: maxHeight,
                              alignment: Alignment.topCenter,
                              child: Transform.translate(
                                offset: Offset(0, _headerOffset),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Calendário semanal (apenas os dias da semana)
                                    WeeklyCalendar(
                                      selectedDate: mealsProvider.selectedDate,
                                      showAppBar: false,
                                      showCalendar: true,
                                      onDaySelected: (date) async {
                                        print('Data selecionada: $date');
                                        _clearSuggestions();
                                        _showHeader();
                                        mealsProvider.setSelectedDate(date);
                                        await _controller.changeSelectedDate(date);
                                        _scrollToLastAiResponse();
                                      },
                                      onSearchPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                const FoodSearchScreen(),
                                          ),
                                        );
                                      },
                                    ),

                                    // Nutrition card
                                    if (hasMeals)
                                      Consumer2<NutritionGoalsProvider,
                                          DailyMealsProvider>(
                                        builder: (context, nutritionProvider,
                                            mealsProvider, child) {
                                          return NutritionCard(
                                            caloriesConsumed:
                                                mealsProvider.totalCalories,
                                            caloriesGoal:
                                                nutritionProvider.caloriesGoal,
                                            proteinConsumed: mealsProvider
                                                .totalProtein
                                                .toInt(),
                                            proteinGoal:
                                                nutritionProvider.proteinGoal,
                                            carbsConsumed:
                                                mealsProvider.totalCarbs.toInt(),
                                            carbsGoal: nutritionProvider.carbsGoal,
                                            fatsConsumed:
                                                mealsProvider.totalFat.toInt(),
                                            fatsGoal: nutritionProvider.fatGoal,
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      const DailyMealsScreen(),
                                                ),
                                              );
                                            },
                                          );
                                        },
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
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
                                // Verificar se é a última mensagem da IA
                                final isAiMessage =
                                    messages[adjustedIndex]['isUser'] == false;
                                int lastAiMessageIndex = -1;
                                for (int i = messages.length - 1; i >= 0; i--) {
                                  if (messages[i]['isUser'] == false) {
                                    lastAiMessageIndex = i;
                                    break;
                                  }
                                }
                                final isLastAiMessage = isAiMessage &&
                                    adjustedIndex == lastAiMessageIndex;

                                final messageBubble = _buildMessageBubble(
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

                                // Se for a última mensagem da IA, adicionar a key para rastreamento
                                if (isLastAiMessage) {
                                  return Container(
                                    key: _lastAiMessageKey,
                                    child: messageBubble,
                                  );
                                }

                                return messageBubble;
                              } else {
                                // Exibir botões de ação após a última mensagem da IA
                                return _buildActionButtons(
                                    currentlySpeakingMessageIndex);
                              }
                            },
                          ),

                        // Sugestões sobreposta (ocupam todo o espaço disponível)
                        if (messages.isEmpty && _suggestions.isNotEmpty)
                          Positioned.fill(
                            child: Container(
                              color: currentScaffoldBackgroundColor,
                              child: SingleChildScrollView(
                                padding: EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: _suggestions.map((suggestion) {
                                    return GestureDetector(
                                      onTap: () {
                                        _messageController.text = suggestion;
                                        _clearSuggestions();
                                        _handleSendMessage();
                                      },
                                      child: Container(
                                        margin: EdgeInsets.only(bottom: 12),
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 14),
                                        decoration: BoxDecoration(
                                          color: isDarkMode
                                              ? Color(0xFF2C2C2C)
                                              : Color(0xFFF5F5F5),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          suggestion,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: isDarkMode
                                                ? Colors.white
                                                    .withValues(alpha: 0.9)
                                                : Color(0xFF333333),
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ),

                        // Mensagem de boas-vindas sobreposta (só aparece quando não há mensagens e não há sugestões)
                        if (messages.isEmpty && _suggestions.isEmpty)
                          Positioned.fill(
                            child: Container(
                              color: currentScaffoldBackgroundColor,
                              child: Align(
                                alignment: Alignment(-1.0,
                                    -0.3), // À esquerda e mais próximo do topo
                                child: SingleChildScrollView(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 16),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Saudação baseada no horário
                                      Text(
                                        _getTimeBasedGreeting(context),
                                        style: TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.getSoftTextColor(isDarkMode),
                                          height: 1.3,
                                        ),
                                      ),
                                      SizedBox(height: 24),
                                      // Grid de ações 2x2
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildActionCard(
                                              icon: Icons.restaurant_menu,
                                              title: 'Registrar',
                                              subtitle: 'Adicionar refeição',
                                              isDarkMode: isDarkMode,
                                              isPrimary: true,
                                              onTap: () {
                                                _showSuggestionsForAction('registrar_refeicao');
                                              },
                                            ),
                                          ),
                                          SizedBox(width: 12),
                                          Expanded(
                                            child: _buildActionCard(
                                              icon: Icons.camera_alt,
                                              title: 'Foto',
                                              subtitle: 'Analisar com IA',
                                              isDarkMode: isDarkMode,
                                              onTap: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => CameraScanScreen(),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 12),
                                      // Segunda linha do grid
                                      Consumer<NutritionGoalsProvider>(
                                        builder: (context, nutritionProvider, child) {
                                          if (!nutritionProvider.hasConfiguredGoals) {
                                            // Usuário não configurou metas
                                            return Row(
                                              children: [
                                                Expanded(
                                                  child: _buildActionCard(
                                                    icon: Icons.person_outline,
                                                    title: 'Perfil',
                                                    subtitle: 'Configurar dados',
                                                    isDarkMode: isDarkMode,
                                                    onTap: () {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (context) =>
                                                              const NutritionGoalsWizardScreen(),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ),
                                                SizedBox(width: 12),
                                                Expanded(
                                                  child: _buildActionCard(
                                                    icon: Icons.flag_outlined,
                                                    title: 'Metas',
                                                    subtitle: 'Definir objetivos',
                                                    isDarkMode: isDarkMode,
                                                    onTap: () {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (context) =>
                                                              const NutritionGoalsWizardScreen(),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ],
                                            );
                                          } else {
                                            // Usuário já configurou
                                            return Row(
                                              children: [
                                                Expanded(
                                                  child: _buildActionCard(
                                                    icon: Icons.lightbulb_outline,
                                                    title: 'Sugestões',
                                                    subtitle: 'Ideias de refeição',
                                                    isDarkMode: isDarkMode,
                                                    onTap: () {
                                                      _showSuggestionsForAction('sugestoes_refeicoes');
                                                    },
                                                  ),
                                                ),
                                                SizedBox(width: 12),
                                                Expanded(
                                                  child: _buildActionCard(
                                                    icon: Icons.help_outline,
                                                    title: 'Perguntar',
                                                    subtitle: 'Dúvidas nutrição',
                                                    isDarkMode: isDarkMode,
                                                    onTap: () {
                                                      _showSuggestionsForAction('perguntar_nutricao');
                                                    },
                                                  ),
                                                ),
                                              ],
                                            );
                                          }
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
                                  focusNode: _inputFocusNode,
                                  decoration: InputDecoration(
                                    hintText:
                                        context.tr.translate('ask_anything'),
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
                                    if (_suggestions.isNotEmpty) {
                                      _clearSuggestions();
                                    }
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

    // Verificar se a mensagem contém JSON de alimentos (apenas para mensagens da IA)
    final bool hasFoodJson =
        !isUser && FoodJsonParser.containsFoodJson(message);
    final String displayMessage =
        hasFoodJson ? FoodJsonParser.removeJsonFromMessage(message) : message;

    // Se for notificador, vamos usar um ChangeNotifierProvider para atualizar apenas este widget
    if (usingNotifier) {
      return ChangeNotifierProvider.value(
        value: messageData as MessageNotifier,
        child: Consumer<MessageNotifier>(
          builder: (context, notifier, _) {
            final hasJsonInNotifier =
                FoodJsonParser.containsFoodJson(notifier.message);
            final cleanMessage = hasJsonInNotifier
                ? FoodJsonParser.removeJsonFromMessage(notifier.message)
                : notifier.message;

            // Se tem JSON e o texto limpo está vazio, só mostra o FoodJsonDisplay
            final bool showMessageBubble = cleanMessage.trim().isNotEmpty || notifier.isStreaming;

            return Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showMessageBubble)
                  MessageUIHelper.buildSimpleMessageBubble(
                    context: context,
                    message: cleanMessage,
                    isUser: isUser,
                    isError: notifier.isError,
                    isStreaming: notifier.isStreaming,
                    onLongPress: () =>
                        _showMessageOptions(notifier.message, isUser),
                    bottomSpacing:
                        hasJsonInNotifier && !notifier.isStreaming ? 4 : 8,
                  ),
                if (hasJsonInNotifier && !notifier.isStreaming)
                  Consumer<DailyMealsProvider>(
                    builder: (context, mealsProvider, _) {
                      return FoodJsonDisplay(
                        message: notifier.message,
                        isDarkMode: isDarkMode,
                        selectedDate: mealsProvider.selectedDate,
                        messageId: index.toString(),
                        onDeleteMessage: () {
                          _controller.deleteMessagePair(index);
                        },
                      );
                    },
                  ),
              ],
            );
          },
        ),
      );
    } else {
      // Se não for notificador, usamos a forma tradicional
      // Se tem JSON e o texto limpo está vazio, só mostra o FoodJsonDisplay
      final bool showMessageBubble = displayMessage.trim().isNotEmpty || isStreaming;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showMessageBubble)
            MessageUIHelper.buildSimpleMessageBubble(
              context: context,
              message: displayMessage,
              isUser: isUser,
              isError: isError,
              isStreaming: isStreaming,
              onLongPress: () => _showMessageOptions(message, isUser),
              imageBytes: imageBytes,
              bottomSpacing: hasFoodJson && !isStreaming ? 4 : 8,
            ),
          if (hasFoodJson && !isStreaming) ...[
            Consumer<DailyMealsProvider>(
              builder: (context, mealsProvider, _) {
                return FoodJsonDisplay(
                  message: message,
                  isDarkMode: isDarkMode,
                  selectedDate: mealsProvider.selectedDate,
                  messageId: index.toString(),
                  onDeleteMessage: () {
                    _controller.deleteMessagePair(index);
                  },
                );
              },
            ),
          ],
        ],
      );
    }
  }

  // Widget para os botões de ação abaixo da última mensagem
  Widget _buildActionButtons(int? currentlySpeakingMessageIndex) {
    final messages = _controller.messages;

    return Container(
      padding: EdgeInsets.only(top: 0, bottom: 4),
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

            // Rolar até o início da última resposta da IA apenas se houver créditos
            if (hadEnoughCredits) {
              Future.delayed(Duration(milliseconds: 100), () {
                _scrollToLastAiResponse(animate: true);
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
                  child: CachedNetworkImage(
                    imageUrl: thumbnailUrl,
                    height: 180,
                    width: 180,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 180,
                      width: 180,
                      color: Colors.grey[300],
                      child: Center(child: Icon(Icons.image, color: Colors.grey)),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 180,
                      width: 180,
                      color: Colors.grey[300],
                      child: Center(child: Icon(Icons.broken_image)),
                    ),
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

  // Retorna saudação e sugestão baseada no horário
  String _getTimeBasedGreeting(BuildContext context) {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 10) {
      return AppLocalizations.of(context).translate('greeting_breakfast') ??
             'Bom dia! Já tomou café?';
    } else if (hour >= 10 && hour < 12) {
      return AppLocalizations.of(context).translate('greeting_morning_snack') ??
             'Hora do lanche da manhã?';
    } else if (hour >= 12 && hour < 14) {
      return AppLocalizations.of(context).translate('greeting_lunch') ??
             'Hora do almoço!';
    } else if (hour >= 14 && hour < 18) {
      return AppLocalizations.of(context).translate('greeting_afternoon') ??
             'Boa tarde! Como posso ajudar?';
    } else if (hour >= 18 && hour < 21) {
      return AppLocalizations.of(context).translate('greeting_dinner') ??
             'Hora do jantar!';
    } else {
      return AppLocalizations.of(context).translate('greeting_night') ??
             'Boa noite!';
    }
  }

  // Retorna o placeholder do input baseado no horário
  String _getTimeBasedPlaceholder(BuildContext context) {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 10) {
      return 'Ex: Pão com ovo e café';
    } else if (hour >= 10 && hour < 12) {
      return 'Ex: Fruta ou iogurte';
    } else if (hour >= 12 && hour < 14) {
      return 'Ex: Arroz, feijão e frango';
    } else if (hour >= 14 && hour < 18) {
      return 'Ex: Lanche da tarde';
    } else if (hour >= 18 && hour < 21) {
      return 'Ex: Salada com proteína';
    } else {
      return 'O que você comeu?';
    }
  }

  // Card de ação para o grid (estilo moderno)
  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDarkMode,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isPrimary
              ? Theme.of(context).primaryColor.withValues(alpha: 0.15)
              : (isDarkMode ? Color(0xFF1E1E1E) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: isPrimary
              ? Border.all(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                  width: 1.5,
                )
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isPrimary
                    ? Theme.of(context).primaryColor.withValues(alpha: 0.2)
                    : (isDarkMode ? Color(0xFF2A2A2A) : Color(0xFFF5F5F5)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 24,
                color: isPrimary
                    ? Theme.of(context).primaryColor
                    : (isDarkMode ? Colors.white70 : Colors.black54),
              ),
            ),
            SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: isDarkMode ? Colors.white54 : Colors.black45,
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
