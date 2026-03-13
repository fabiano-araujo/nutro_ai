import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../services/ai_service.dart';
import '../services/storage_service.dart';
import '../services/auth_service.dart';
import '../widgets/message_notifier.dart';
import '../utils/ai_interaction_helper.dart';
import '../models/study_item.dart';
import '../utils/conversation_helper.dart';
import '../i18n/language_controller.dart';
import '../i18n/app_localizations.dart';
import '../providers/credit_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../utils/screen_utils.dart';
import '../mixins/text_to_speech_mixin.dart';
import '../mixins/ai_tutor_speech_mixin.dart';
import '../services/rate_app_service.dart';
import '../widgets/reward_ad_dialog.dart';
import '../screens/settings_screen.dart';
import '../screens/subscription_screen.dart';
import '../providers/meal_types_provider.dart';
import '../services/app_agent_service.dart';
import '../utils/food_json_parser.dart';

/// Controller para gerenciar o estado e a lógica do Assistente de Nutrição
class NutroChatController with ChangeNotifier {
  // Serviços
  final AIService _aiService = AIService();
  final StorageService _storageService = StorageService();

  // Estado das mensagens
  List<Map<String, dynamic>> _messages = [];
  MessageNotifier? _messageNotifier;
  StreamSubscription? _aiStreamSubscription;
  int? _streamingMessageIndex;
  String? _activeConnectionId; // ID da conexão ativa para interrupção

  // Estado da conversa
  String? _currentConversationId;
  int? _currentlySpeakingMessageIndex;

  // Data selecionada atual para as mensagens (formato yyyy-MM-dd)
  DateTime _selectedDate = DateTime.now();

  // Estados de carregamento
  bool _isLoading = false;
  bool _isProcessingMedia = false;
  bool _isRecording = false;

  // Estado de imagem
  Uint8List? _selectedImageBytes;
  ImageSource? _selectedImageSource;
  bool _hasSelectedImage = false;

  // Valor para controlar a frequência de atualização no Android
  int _androidUpdateCounter = 0;

  // Referências aos mixins
  final NutroChatSpeechMixinRef speechMixin;
  final TextToSpeechMixinRef ttsRef;

  // Contador de interações bem-sucedidas
  int _successfulInteractions = 0;
  static const int _interactionsBeforeRating = 3;

  // Flag para saber se o usuário enviou mensagem nesta sessão
  bool _userSentMessage = false;

  // Tipo de ferramenta que está usando o controlador
  final String toolType;
  final String?
      rawInitialPromptJson; // NOVO: Para armazenar o JSON bruto da ferramenta

  // Salvar o último contexto usado em sendMessage
  BuildContext? _lastContext;
  int _agenticCommandExecutions = 0;
  static const int _maxAgenticCommandExecutions = 1;

  // Getters
  List<Map<String, dynamic>> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isProcessingMedia => _isProcessingMedia;
  bool get isRecording => _isRecording;
  bool get hasSelectedImage => _hasSelectedImage;
  Uint8List? get selectedImageBytes => _selectedImageBytes;
  String? get currentConversationId => _currentConversationId;
  int? get currentlySpeakingMessageIndex => _currentlySpeakingMessageIndex;
  DateTime get selectedDate => _selectedDate;

  NutroChatController({
    required this.speechMixin,
    required this.ttsRef,
    String? conversationId,
    bool showWelcomeMessage = true,
    this.toolType = 'chat',
    this.rawInitialPromptJson,
    List<Map<String, dynamic>>? initialMessages,
    DateTime? initialDate,
  }) {
    // Inicializar a data selecionada
    if (initialDate != null) {
      _selectedDate =
          DateTime(initialDate.year, initialDate.month, initialDate.day);
    }

    print(
        '🤖 NutroChatController - Construtor: conversationId: $conversationId, showWelcomeMessage: $showWelcomeMessage, toolType: $toolType, hasInitialMessages: ${initialMessages != null && initialMessages.isNotEmpty}, selectedDate: ${_formatDateKey(_selectedDate)}');
    if (initialMessages != null && initialMessages.isNotEmpty) {
      // Prioridade máxima: se mensagens iniciais são fornecidas, usá-las.
      _messages = initialMessages;

      // Log formatado das mensagens iniciais
      print('\n');
      print(
          '📊 ==================== AI TUTOR CONTROLLER - MENSAGENS INICIAIS ====================');
      print('📊 Número total de mensagens: ${initialMessages.length}');

      // Exibir mensagens para verificação
      if (initialMessages.isNotEmpty) {
        print('📊 Detalhes das mensagens recebidas:');
        for (int i = 0; i < initialMessages.length; i++) {
          var msg = initialMessages[i];
          String prefix = msg['isUser'] == true ? '👤 Usuário:' : '🤖 IA:';

          // Obter texto da mensagem
          String text = '';
          if (msg.containsKey('message')) {
            text = msg['message'] as String? ?? '';
          } else if (msg.containsKey('notifier')) {
            var notifier = msg['notifier'];
            text = notifier?.message ?? '';
          }

          // Truncar texto longo
          if (text.length > 50) {
            text = text.substring(0, 50) + '...';
          }

          // Obter timestamp
          String timestamp = '';
          if (msg.containsKey('timestamp')) {
            timestamp = msg['timestamp'] is DateTime
                ? (msg['timestamp'] as DateTime).toString()
                : msg['timestamp'].toString();
          }

          print('   ${i + 1}. $prefix $text [${timestamp.split('.').first}]');
        }
      }

      // Verificar a sequência
      if (initialMessages.length >= 2) {
        print('📊 Verificação de sequência:');
        bool sequenciaOK = true;
        for (int i = 0; i < initialMessages.length - 1; i++) {
          var atual = initialMessages[i];
          var proximo = initialMessages[i + 1];

          // Verificar alternância usuário/IA
          if (atual['isUser'] == proximo['isUser']) {
            print(
                '   ⚠️ Erro na sequência: mensagens ${i + 1} e ${i + 2} são ambas de ${atual['isUser'] ? 'usuário' : 'IA'}');
            sequenciaOK = false;
          }

          // Verificar timestamps
          if (atual.containsKey('timestamp') &&
              proximo.containsKey('timestamp') &&
              atual['timestamp'] is DateTime &&
              proximo['timestamp'] is DateTime) {
            DateTime timestampAtual = atual['timestamp'] as DateTime;
            DateTime timestampProximo = proximo['timestamp'] as DateTime;
            if (timestampAtual.isAfter(timestampProximo)) {
              print(
                  '   ⚠️ Erro de timestamp: mensagem ${i + 1} é posterior à mensagem ${i + 2}');
              sequenciaOK = false;
            }
          }
        }

        if (sequenciaOK) {
          print('   ✅ Sequência de mensagens está correta');
        }
      }

      print(
          '📊 ==============================================================================\n');

      print(
          '✅ NutroChatController: Inicializado com ${initialMessages.length} mensagens fornecidas via initialMessages.');
      // Se estamos usando initialMessages, geralmente não queremos carregar uma conversationId separadamente,
      // a menos que seja um caso de uso específico para mesclar/continuar.
      // Por agora, se initialMessages é provido, ele é a fonte da verdade para o estado inicial.
      if (conversationId != null) {
        _currentConversationId =
            conversationId; // Manter o ID se fornecido, mesmo usando initialMessages
        print(
            '   ➡️ conversationId ($conversationId) também foi fornecido e será mantido.');
      }
      // Não chamar notifyListeners() aqui; a NutroChatScreen o fará após a configuração completa se necessário.
    } else if (conversationId != null) {
      // Se não há initialMessages, mas há um conversationId, carregar a conversa.
      print(
          '📂 NutroChatController: Carregando conversa por ID: $conversationId');
      _loadConversation(conversationId);
      _currentConversationId = conversationId;
    } else if (showWelcomeMessage) {
      // Nenhuma mensagem inicial e nenhum ID de conversa, e showWelcomeMessage é true.
      // Esta é a única condição em que a mensagem de boas-vindas deve ser adicionada.
      print('👋 NutroChatController: Adicionando mensagem de boas-vindas.');
      _addWelcomeMessage(); // _addWelcomeMessage já chama notifyListeners
    } else {
      print(
          '🤷 NutroChatController: Nenhuma mensagem inicial, nenhum ID de conversa, e showWelcomeMessage é false.');
      // Carregar mensagens da data inicial (se houver)
      print(
          '📅 NutroChatController: Carregando mensagens da data inicial: ${_formatDateKey(_selectedDate)}');
      _loadMessagesForDate(_selectedDate);
      // notifyListeners será chamado por _loadMessagesForDate após o carregamento
    }
  }

  /// Adiciona uma mensagem de boas-vindas padrão
  void _addWelcomeMessage() {
    _messages.add({
      'isUser': false,
      'message': 'Olá! Sou seu assistente de nutrição. O que você comeu hoje?',
      'timestamp': DateTime.now(),
    });
    notifyListeners();
  }

  /// Atualiza a mensagem de boas-vindas com o idioma correto
  void updateWelcomeMessage(BuildContext context) {
    if (_messages.isEmpty || _currentConversationId != null) return;

    try {
      // Tentar obter a mensagem de boas-vindas do AppLocalizations
      AppLocalizations appLocalizations = AppLocalizations.of(context);
      String welcomeMessage =
          appLocalizations.translate('ai_tutor_short_welcome');

      // Se a chave não existir, ele retorna a própria chave
      if (welcomeMessage == 'ai_tutor_short_welcome') {
        // Fallback para o idioma específico
        final String locale = Localizations.localeOf(context).toString();
        switch (locale) {
          case 'pt_BR':
            welcomeMessage =
                'Olá! Sou seu assistente de nutrição. O que você comeu hoje?';
            break;
          case 'en_US':
            welcomeMessage =
                'Hi! I\'m your nutrition assistant. What did you eat today?';
            break;
          // ... outros casos
          default:
            welcomeMessage =
                'Olá! Sou seu assistente de nutrição. O que você comeu hoje?';
        }
      }

      // Atualiza a mensagem se houver mensagens
      if (_messages.isNotEmpty) {
        _messages[0]['message'] = welcomeMessage;
        notifyListeners();
      }
    } catch (e) {
      print('⚠️ NutroChatController - Erro ao obter tradução: $e');
    }
  }

  /// Carrega uma conversa pelo ID
  Future<void> _loadConversation(String conversationId) async {
    print(
        '📂 NutroChatController - Iniciando carregamento da conversa ID: $conversationId');
    _isLoading = true;
    _messages = []; // Limpar mensagens antigas enquanto carrega
    notifyListeners();

    try {
      // Usar o helper para carregar e analisar a conversa
      final List<Map<String, dynamic>>? loadedMessages =
          await ConversationHelper.loadAndParseConversation(
              conversationId, _storageService);

      if (loadedMessages != null) {
        _messages = loadedMessages;
        _isLoading = false;
        notifyListeners();
        print(
            '✅ NutroChatController - Conversa carregada com sucesso via Helper');
      } else {
        print(
            '⚠️ NutroChatController - Conversa não encontrada ou erro no Helper, mostrando mensagem padrão');
        _addWelcomeMessage();
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      print('❌ NutroChatController - Erro inesperado ao carregar conversa: $e');
      _addWelcomeMessage();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Envia uma mensagem para a IA
  Future<bool> sendMessage(String message, BuildContext context) async {
    _lastContext = context;
    _userSentMessage =
        true; // Flag para marcação de sessão com mensagem enviada pelo usuário

    if (message.trim().isEmpty && !_hasSelectedImage) {
      // Não processar se a mensagem estiver vazia e não houver imagem
      return true; // Não consumiu créditos, mas não é um erro
    }

    // Verificar se há créditos suficientes
    final creditProvider = Provider.of<CreditProvider>(context, listen: false);
    final hasSufficientCredits;

    if (_hasSelectedImage) {
      hasSufficientCredits = await creditProvider.consumeImageAnalysisCredit();
    } else {
      hasSufficientCredits = await creditProvider.consumeTextMessageCredit();
    }

    if (!hasSufficientCredits) {
      // Mostrar diálogo personalizado com RewardAdDialog e botão PRO
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.0),
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).colorScheme.primary.withOpacity(0.8),
                    Theme.of(context).colorScheme.secondary.withOpacity(0.9),
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Ícone animado
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.card_giftcard,
                      size: 50,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Título
                  Text(
                    'Sem créditos restantes!',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),

                  // Descrição
                  Text(
                    'Você pode assistir a um anúncio para ganhar 7 créditos ou fazer o upgrade para a versão PRO e ter créditos ilimitados.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Botão PRO
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SubscriptionScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black87,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.workspace_premium, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Obter versão PRO',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Botão de anúncio
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      RewardAdDialog.showRewardedAd(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_arrow, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Assistir anúncio',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Cancelar
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white.withOpacity(0.8),
                    ),
                    child: Text('Cancelar'),
                  ),
                ],
              ),
            ),
          );
        },
      );
      return false; // Não havia créditos suficientes
    }

    // Cria um novo notificador para a mensagem que vamos receber
    _messageNotifier = MessageNotifier();

    // Cria cópias locais dos dados da imagem para não perder referência
    final bool enviandoImagem = _hasSelectedImage;
    final Uint8List? imagemBytes = _selectedImageBytes;

    // Adicionar mensagem do usuário
    if (enviandoImagem && imagemBytes != null) {
      // Mensagem com imagem
      _messages.add({
        'isUser': true,
        'message': message
            .trim(), // Removido texto padrão, agora envia string vazia quando não há mensagem
        'hasImage': true,
        'imageBytes': imagemBytes,
        'timestamp': DateTime.now(),
      });

      // Resetar a imagem selecionada
      _hasSelectedImage = false;
      _selectedImageBytes = null;
      _selectedImageSource = null;
      _isProcessingMedia = true;
    } else {
      // Mensagem apenas com texto
      _messages.add({
        'isUser': true,
        'message': message.trim(),
        'timestamp': DateTime.now(),
      });
    }

    // Marcar que o usuário enviou mensagem nesta sessão
    _userSentMessage = true;

    // Adiciona a mensagem com o notifier em vez do conteúdo direto
    _messages.add({
      'isUser': false,
      'notifier': _messageNotifier,
      'timestamp': DateTime.now(),
    });

    _isLoading = true;
    notifyListeners();

    final aiMessageIndex = _messages.length - 1;
    _streamingMessageIndex = aiMessageIndex;

    // Processar a mensagem para obter resposta da IA
    if (_messages[aiMessageIndex - 1].containsKey('hasImage') &&
        _messages[aiMessageIndex - 1]['hasImage'] == true) {
      // Se a mensagem anterior contém uma imagem, processe a imagem
      final imageBytes = _messages[aiMessageIndex - 1]['imageBytes'];
      final prompt = message.isEmpty
          ? "Analise esta imagem e explique o que está vendo." // Prompt oculto para a IA, não aparece na bolha do usuário
          : message;
      _processImageForAI(imageBytes, prompt, context);
    } else {
      // Processar mensagem de texto normal
      _processMessageForAI(message, context);
    }

    // Salvar o último contexto usado em sendMessage
    _lastContext = context;
    return true; // Consumiu créditos, é um sucesso
  }

  /// Processa mensagem de texto para a IA
  Future<void> _processMessageForAI(
      String message, BuildContext context) async {
    if (_messageNotifier == null || _streamingMessageIndex == null) {
      print(
          '❌ NutroChatController - _messageNotifier ou _streamingMessageIndex nulo antes de processar texto.');
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      // Iniciar medição de tempo para logging
      final startPrepTime = DateTime.now();

      // Preparar o contexto da conversa
      String contextPrompt = '';

      // Usar uma cópia da lista para evitar modificação concorrente durante a compilação do prompt
      final currentMessagesForPrompt =
          List<Map<String, dynamic>>.from(_messages);
      if (currentMessagesForPrompt.length > 2) {
        // Obter o histórico exceto a mensagem do usuário atual e a mensagem de resposta da IA
        // que está sendo gerada (as duas últimas mensagens)
        final messageHistory = currentMessagesForPrompt.sublist(
            0, currentMessagesForPrompt.length - 2);
        contextPrompt = await _aiService
            .limitConversationHistory(messageHistory, maxTokenLimit: 1900);
      }

      // Registrar tempo
      final prepDuration = DateTime.now().difference(startPrepTime);
      print(
          '⏱️ NutroChatController - Tempo de preparação do contexto: ${prepDuration.inMilliseconds}ms');

      // Montar o prompt com contexto da conversa e mensagem do usuário
      // O system prompt de nutrição agora vem da API através do agentType='nutrition'
      final prompt =
          contextPrompt.isNotEmpty ? "$contextPrompt\n\n$message" : message;

      // Obter o controlador de idioma
      final languageController =
          Provider.of<LanguageController>(context, listen: false);
      final languageCode =
          _aiService.getCurrentLanguageCode(languageController);

      // Determinar o modelo baseado no toolType
      String quality = '';
      String provider = 'Hyperbolic';

      // Para 'my_diet', usar o modelo Gemini Flash
      if (toolType == 'my_diet') {
        quality = 'google/gemini-3-flash-preview';
        provider = ''; // Deixar o OpenRouter escolher o provider
        print('📱 Usando modelo Gemini Flash para Minha Dieta');
      } else if (toolType == 'free_chat') {
        quality = 'google/gemini-2.5-flash-lite-preview-09-2025';
        provider =
            ''; // Deixar vazio para escolher automaticamente (geralmente o mais barato/disponível)
        print('📱 Usando modelo Gemini 2.5 Flash Lite para Free Chat');
      } else {
        print(
            '📱 Usando qualidade padrão (modelo padrão do servidor) para o tutor de nutrição');
        print('🔌 Usando provider Hyperbolic para o agent nutricional');
      }

      // Determinar o agentType baseado no toolType
      // free_chat e my_diet usam o agent 'free-nutrition' que não retorna JSON formatado
      String agentType = (toolType == 'free_chat' || toolType == 'my_diet')
          ? 'free-nutrition'
          : 'nutrition';
      print('🤖 Usando agentType: $agentType para toolType: $toolType');

      // Obter o usuário logado para pegar o ID
      final authService = Provider.of<AuthService>(context, listen: false);
      String userId = '';

      // Verificar se há um usuário autenticado
      if (authService.isAuthenticated && authService.currentUser != null) {
        userId = authService.currentUser!.id.toString();
        print(
            '👤 NutroChatController - Usuário logado: ${authService.currentUser!.name}, ID: $userId');
      } else {
        print(
            '⚠️ NutroChatController - Nenhum usuário autenticado, usando ID vazio');
      }

      // Obter tipos de refeição do usuário para classificação pela IA
      List<Map<String, String>>? mealTypesForAI;
      try {
        final mealTypesProvider =
            Provider.of<MealTypesProvider>(context, listen: false);
        mealTypesForAI = mealTypesProvider.mealTypes
            .map((mt) => {'id': mt.id, 'name': mt.name})
            .toList();
        print('🍽️ NutroChatController - Tipos de refeição: $mealTypesForAI');
      } catch (e) {
        print(
            '⚠️ NutroChatController - Não foi possível obter tipos de refeição: $e');
      }

      // Obter o stream da IA
      final stream = _aiService.getAnswerStream(prompt,
          subject: 'education',
          languageCode: languageCode,
          quality: quality, // Usar a qualidade determinada pelo toolType
          userId: userId, // Passando o ID do usuário logado
          agentType: agentType, // Usando o agent determinado pelo toolType
          provider: provider, // Usando o provider Hyperbolic
          mealTypes: mealTypesForAI // Tipos de refeição do usuário
          );

      // Usar o Helper para lidar com o stream
      String? toolDataForHistory;
      // Se rawInitialPromptJson existir, sempre o utilizamos para manter a natureza da ferramenta
      if (rawInitialPromptJson != null) {
        toolDataForHistory = rawInitialPromptJson;
        print(
            '📝 NutroChatController: Passando toolDataJson (rawInitialPromptJson) para histórico (mensagem de texto)');
      }

      _aiStreamSubscription = AIInteractionHelper.handleAIStream(
        context: context,
        aiStream: stream,
        messageNotifier: _messageNotifier!,
        messages: _messages,
        streamingMessageIndex: _streamingMessageIndex!,
        storageService: _storageService,
        currentConversationId: _currentConversationId,
        studyItemType:
            'tutor', // O helper vai sobrescrever se toolDataForHistory for provido
        setLoading: (loading) {
          _isLoading = loading;
          notifyListeners();
        },
        setConversationId: (id) {
          _currentConversationId = id;
        },
        setStreamingIndex: (index) {
          _streamingMessageIndex = index;
        },
        setProcessingMedia: (processing) {}, // Não aplicável para texto
        setConnectionId: (id) {
          print(
              '[CONEXAO_DEBUG] Callback setConnectionId chamado no processamento de texto');
          print('[CONEXAO_DEBUG] ID recebido: $id');
          setActiveConnectionId(id);
        },
        toolDataJson: toolDataForHistory,
        // Não auto-registrar alimentos no modo Conversa Livre (free_chat)
        autoRegisterFoods: toolType != 'free_chat',
        displayContentBuilder: (rawContent) => _buildTextDisplayContent(
          rawContent,
          autoRegisterFoods: toolType != 'free_chat',
        ),
        interceptFinalResponse: (responseContent, notifier) =>
            _handleAgenticCommandResponse(
          responseContent: responseContent,
          notifier: notifier,
          originalUserMessage: message,
          conversationContext: contextPrompt,
          context: context,
          languageCode: languageCode,
          quality: quality,
          provider: provider,
          agentType: agentType,
          userId: userId,
          mealTypesForAI: mealTypesForAI,
          toolDataForHistory: toolDataForHistory,
        ),
        onStreamComplete: () {
          _agenticCommandExecutions = 0;
          // Salvar mensagens após cada resposta da IA
          _saveMessagesForCurrentDate();
        },
      );
    } catch (e) {
      print(
          '❌ NutroChatController - Exceção ao preparar/iniciar stream de texto: $e');
      if (_messageNotifier != null) {
        // Mensagem de erro genérica para o usuário
        _messageNotifier!.setError(true,
            'Desculpe, ocorreu um erro ao processar sua solicitação. Por favor, tente novamente.');
      }
      _isLoading = false;
      notifyListeners();
    }
  }

  String _buildTextDisplayContent(
    String rawContent, {
    required bool autoRegisterFoods,
  }) {
    return AppAgentService.sanitizeDisplayMessage(
      rawContent,
      autoRegisterFoods: autoRegisterFoods,
      fallbackSanitizer: (content) {
        if (!autoRegisterFoods) {
          return content;
        }
        return FoodJsonParser.removeJsonCandidateFromMessage(content);
      },
    );
  }

  Future<bool> _handleAgenticCommandResponse({
    required String responseContent,
    required MessageNotifier notifier,
    required String originalUserMessage,
    required String conversationContext,
    required BuildContext context,
    required String languageCode,
    required String quality,
    required String provider,
    required String agentType,
    required String userId,
    required List<Map<String, String>>? mealTypesForAI,
    required String? toolDataForHistory,
  }) async {
    final commandBatch = AppAgentCommand.tryParseBatch(responseContent);
    if (commandBatch == null || commandBatch.commands.isEmpty) {
      return false;
    }

    if (_agenticCommandExecutions >= _maxAgenticCommandExecutions) {
      final fallbackMessage =
          AppLocalizations.of(context).translate('agent_command_limit_reached');
      _finalizeInterceptedMessage(notifier, fallbackMessage);
      return true;
    }

    _agenticCommandExecutions++;

    final loadingMessage = commandBatch.commands.length == 1
        ? AppAgentService.buildLoadingMessage(
            context,
            commandBatch.commands.first.name,
          )
        : AppLocalizations.of(context).translate('agent_loading_generic');
    notifier.updateMessage(commandBatch.rawJson,
        displayContent: loadingMessage);
    notifyListeners();

    try {
      final executionResults = <AppAgentExecutionResult>[];
      for (final command in commandBatch.commands) {
        final executionResult =
            await AppAgentService.executeCommand(command, context);
        executionResults.add(executionResult);

        if (!executionResult.success) {
          break;
        }
      }

      final followUpPrompt = AppAgentService.buildFollowUpPrompt(
        originalUserMessage: originalUserMessage,
        executionResults: executionResults,
        conversationContext: conversationContext,
      );

      final followUpStream = _aiService.getAnswerStream(
        followUpPrompt,
        subject: 'education',
        languageCode: languageCode,
        quality: quality,
        userId: userId,
        agentType: agentType,
        provider: provider,
        mealTypes: mealTypesForAI,
      );

      _aiStreamSubscription = AIInteractionHelper.handleAIStream(
        context: context,
        aiStream: followUpStream,
        messageNotifier: notifier,
        messages: _messages,
        streamingMessageIndex: _streamingMessageIndex!,
        storageService: _storageService,
        currentConversationId: _currentConversationId,
        studyItemType: 'tutor',
        setLoading: (loading) {
          _isLoading = loading;
          notifyListeners();
        },
        setConversationId: (id) {
          _currentConversationId = id;
        },
        setStreamingIndex: (index) {
          _streamingMessageIndex = index;
        },
        setProcessingMedia: (processing) {},
        setConnectionId: (id) {
          print(
              '[CONEXAO_DEBUG] Callback setConnectionId chamado no follow-up agêntico');
          print('[CONEXAO_DEBUG] ID recebido: $id');
          setActiveConnectionId(id);
        },
        toolDataJson: toolDataForHistory,
        autoRegisterFoods: toolType != 'free_chat',
        displayContentBuilder: (rawContent) => _buildTextDisplayContent(
          rawContent,
          autoRegisterFoods: toolType != 'free_chat',
        ),
        onStreamComplete: () {
          _agenticCommandExecutions = 0;
          _saveMessagesForCurrentDate();
        },
      );
    } catch (e) {
      print('❌ NutroChatController - Erro ao executar comando agêntico: $e');
      _finalizeInterceptedMessage(
        notifier,
        'Desculpe, ocorreu um erro ao acessar seus dados no app. Tente novamente.',
      );
    }

    return true;
  }

  void _finalizeInterceptedMessage(
    MessageNotifier notifier,
    String finalContent,
  ) {
    notifier.updateMessage(finalContent, displayContent: finalContent);
    notifier.setStreaming(false);
    _isLoading = false;
    _agenticCommandExecutions = 0;

    final streamingIndex = _streamingMessageIndex;
    if (streamingIndex != null &&
        streamingIndex < _messages.length &&
        _messages[streamingIndex]['notifier'] == notifier) {
      _messages[streamingIndex] = {
        'isUser': false,
        'message': finalContent,
        'timestamp': _messages[streamingIndex]['timestamp'],
      };
    }

    notifyListeners();
    _saveMessagesForCurrentDate();
  }

  /// Processa imagem para a IA
  Future<void> _processImageForAI(
      Uint8List imageBytes, String prompt, BuildContext context) async {
    if (_messageNotifier == null || _streamingMessageIndex == null) {
      print(
          '❌ NutroChatController - _messageNotifier ou _streamingMessageIndex nulo antes de processar imagem.');
      _isLoading = false;
      _isProcessingMedia = false;
      notifyListeners();
      return;
    }

    try {
      // Obter o controlador de idioma
      final languageController =
          Provider.of<LanguageController>(context, listen: false);
      final languageCode =
          _aiService.getCurrentLanguageCode(languageController);

      // Obter o usuário logado para pegar o ID
      final authService = Provider.of<AuthService>(context, listen: false);
      String userId = '';

      // Verificar se há um usuário autenticado
      if (authService.isAuthenticated && authService.currentUser != null) {
        userId = authService.currentUser!.id.toString();
        print(
            '👤 NutroChatController - Usuário logado: ${authService.currentUser!.name}, ID: $userId');
      } else {
        print(
            '⚠️ NutroChatController - Nenhum usuário autenticado, usando ID vazio');
      }

      // Para imagens, usar modelo específico e agent free-image
      String quality =
          'google/gemini-2.5-flash-lite-preview-09-2025'; // Modelo específico para análise de imagem e quantidade dos alimentos
      String agentType =
          'free-image'; // Agent especializado em análise de imagem
      String provider =
          ''; // Deixar o OpenRouter escolher o provider compatível

      print(
          '📸 Usando modelo $quality com agent $agentType via provider $provider para análise de imagem');

      // Obter o stream da IA para imagem
      final stream = _aiService.processImageStream(imageBytes, prompt,
          languageCode: languageCode,
          quality: quality,
          agentType: agentType,
          provider: provider,
          userId: userId // Passando o ID do usuário logado
          );

      // Usar o Helper para lidar com o stream
      String? toolDataForHistory;
      // Se rawInitialPromptJson existir, sempre o utilizamos para manter a natureza da ferramenta
      if (rawInitialPromptJson != null) {
        toolDataForHistory = rawInitialPromptJson;
        print(
            '📝 NutroChatController: Passando toolDataJson (rawInitialPromptJson) para histórico (imagem)');
      }

      _aiStreamSubscription = AIInteractionHelper.handleAIStream(
        context: context,
        aiStream: stream,
        messageNotifier: _messageNotifier!,
        messages: _messages,
        streamingMessageIndex: _streamingMessageIndex!,
        storageService: _storageService,
        currentConversationId: _currentConversationId,
        studyItemType:
            'image_analysis', // O helper vai sobrescrever se toolDataForHistory for provido
        setLoading: (loading) {
          _isLoading = loading;
          notifyListeners();
        },
        setConversationId: (id) {
          _currentConversationId = id;
        },
        setStreamingIndex: (index) {
          _streamingMessageIndex = index;
        },
        setProcessingMedia: (processing) {
          _isProcessingMedia = processing;
          notifyListeners();
        },
        setConnectionId: (id) {
          print(
              '[CONEXAO_DEBUG] Callback setConnectionId chamado no processamento de imagem');
          print('[CONEXAO_DEBUG] ID recebido: $id');
          setActiveConnectionId(id);
        },
        toolDataJson: toolDataForHistory,
        // Não auto-registrar alimentos no modo Conversa Livre (free_chat)
        autoRegisterFoods: toolType != 'free_chat',
        onStreamComplete: () {
          // Salvar mensagens após cada resposta da IA
          _saveMessagesForCurrentDate();
        },
      );
    } catch (e) {
      print(
          '❌ NutroChatController - Exceção ao preparar/iniciar stream de imagem: $e');
      if (_messageNotifier != null) {
        // Mensagem de erro genérica para o usuário
        _messageNotifier!.setError(true,
            'Desculpe, ocorreu um erro ao processar sua imagem. Por favor, tente novamente.');
      }
      _isLoading = false;
      _isProcessingMedia = false;
      notifyListeners();
    }
  }

  /// Salva uma nova imagem selecionada
  void setSelectedImage(Uint8List bytes, ImageSource source) {
    _selectedImageBytes = bytes;
    _selectedImageSource = source;
    _hasSelectedImage = true;
    notifyListeners();
  }

  /// Limpa a imagem selecionada
  void clearSelectedImage() {
    _selectedImageBytes = null;
    _selectedImageSource = null;
    _hasSelectedImage = false;
    notifyListeners();
  }

  /// Define estado de processamento de mídia
  void setProcessingMedia(bool isProcessing) {
    _isProcessingMedia = isProcessing;
    notifyListeners();
  }

  /// Define o índice da mensagem que está sendo lida
  void setCurrentlySpeakingMessageIndex(int? index) {
    _currentlySpeakingMessageIndex = index;
    notifyListeners();
  }

  /// Incrementa o contador de atualização Android
  void incrementAndroidUpdateCounter() {
    _androidUpdateCounter++;
  }

  /// Método para lidar com o botão de voz clicado
  void handleVoiceButtonPressed(int messageIndex, BuildContext context) {
    if (messageIndex < 0 || messageIndex >= _messages.length) return;

    // Verifica se é uma mensagem do usuário
    if (_messages[messageIndex]['isUser'] == true) return;

    // Obtém o texto da mensagem
    String messageText = '';
    if (_messages[messageIndex].containsKey('message')) {
      messageText = _messages[messageIndex]['message'];
    } else if (_messages[messageIndex].containsKey('notifier')) {
      messageText = _messages[messageIndex]['notifier'].message;
    }

    if (messageText.isEmpty) return;

    try {
      // Se já estiver falando a mesma mensagem, para a leitura
      if (ttsRef.isSpeaking && _currentlySpeakingMessageIndex == messageIndex) {
        ttsRef.stopSpeech();
        setCurrentlySpeakingMessageIndex(null);
      } else {
        // Para qualquer leitura anterior e inicia a nova
        ttsRef.stopSpeech();
        setCurrentlySpeakingMessageIndex(messageIndex);
        ttsRef.speak(messageText).catchError((error) {
          print('Erro ao iniciar leitura: $error');
          setCurrentlySpeakingMessageIndex(null);

          // Mostrar mensagem de erro para o usuário
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
    } catch (e) {
      print('Erro ao manipular botão de leitura: $e');
      setCurrentlySpeakingMessageIndex(null);

      // Mostrar mensagem de erro para o usuário
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Função de leitura não disponível no momento.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  /// Verifica se deve mostrar o diálogo de avaliação após interações bem-sucedidas
  void checkAndPromptForRating(BuildContext context) {
    _successfulInteractions++;

    // Mostrar o diálogo de avaliação após um número determinado de interações bem-sucedidas
    if (_successfulInteractions >= _interactionsBeforeRating) {
      _successfulInteractions = 0; // Resetar contador
      // Usar o serviço para verificar se deve mostrar o diálogo
      RateAppService.promptAfterPositiveAction(context);
    }
  }

  /// Limpa recursos ao destruir o controller
  @override
  void dispose() {
    // Salvar mensagens da data atual antes de destruir
    _saveMessagesForCurrentDate();

    _aiStreamSubscription?.cancel();
    // Se o usuário enviou mensagem nesta sessão, checar se deve mostrar rate_app
    if (_userSentMessage) {
      // Precisa de contexto, então salve o último contexto usado em sendMessage
      if (_lastContext != null) {
        RateAppService.promptForRatingByMessage(_lastContext!);
      }
    }
    super.dispose();
  }

  /// Interrompe a geração de resposta da IA em andamento
  Future<void> stopGeneration() async {
    print('\n🚫 [NutritionAssistantStop] INICIANDO PROCESSO DE INTERRUPÇÃO:');
    print('----------------------------------------');

    if (_aiStreamSubscription == null) {
      print(
          '❌ [NutritionAssistantStop] Nenhuma geração em andamento para interromper');
      return;
    }

    print('✅ [NutritionAssistantStop] Stream de geração ativa encontrada');
    print(
        '[NutritionAssistantStop] ID da conexão armazenada: $_activeConnectionId');
    print(
        '[NutritionAssistantStop] _activeConnectionId is null? ${_activeConnectionId == null}');
    print(
        '[NutritionAssistantStop] _activeConnectionId está vazio? ${_activeConnectionId?.isEmpty}');
    print(
        '[NutritionAssistantStop] Tipo de _activeConnectionId: ${_activeConnectionId?.runtimeType}');

    // Tentar interromper no servidor primeiro, se tivermos o ID da conexão
    if (_activeConnectionId != null && _activeConnectionId!.isNotEmpty) {
      try {
        // Obter ID do usuário logado, se disponível
        String userId = '';
        if (_lastContext != null) {
          final authService =
              Provider.of<AuthService>(_lastContext!, listen: false);
          if (authService.isAuthenticated && authService.currentUser != null) {
            userId = authService.currentUser!.id.toString();
            print(
                '[NutritionAssistantStop] Usando ID de usuário autenticado: $userId');
          } else {
            print(
                '[NutritionAssistantStop] Nenhum usuário autenticado encontrado');
          }
        } else {
          print(
              '[NutritionAssistantStop] Sem contexto disponível para obter usuário autenticado');
        }

        print(
            '[NutritionAssistantStop] Enviando requisição para parar geração no servidor:');
        print('[NutritionAssistantStop] ID da conexão: $_activeConnectionId');
        print('[NutritionAssistantStop] ID do usuário: $userId');

        // Tentar interromper no servidor
        final bool servidorInterrompido = await _aiService
            .stopGenerationOnServer(_activeConnectionId, userId: userId);

        if (servidorInterrompido) {
          print(
              '🎉 [NutritionAssistantStop] Geração interrompida no servidor com sucesso!');
        } else {
          print(
              '⚠️ [NutritionAssistantStop] O servidor não confirmou a interrupção da geração');
        }
      } catch (e) {
        print(
            '⚠️ [NutritionAssistantStop] Erro ao interromper no servidor: $e');
      }
    } else {
      print(
          '⚠️ [NutritionAssistantStop] Sem ID de conexão disponível para parar geração no servidor');
      // ATENÇÃO: Este é o problema principal - _activeConnectionId não está sendo definido
      print(
          '[NutritionAssistantStop] Tentando forçar a interrupção mesmo sem ID de conexão');

      try {
        // Obter ID do usuário logado, se disponível
        String userId = '';
        if (_lastContext != null) {
          final authService =
              Provider.of<AuthService>(_lastContext!, listen: false);
          if (authService.isAuthenticated && authService.currentUser != null) {
            userId = authService.currentUser!.id.toString();
            print(
                '[NutritionAssistantStop] Usando ID de usuário autenticado: $userId');
          } else {
            print(
                '[NutritionAssistantStop] Nenhum usuário autenticado encontrado');
          }
        } else {
          print(
              '[NutritionAssistantStop] Sem contexto disponível para obter usuário autenticado');
        }

        // Tentar com uma requisição genérica como último recurso
        final bool resultado = await _aiService
            .stopGenerationOnServer('conexao_indefinida', userId: userId);
        print(
            '[NutritionAssistantStop] Tentativa de forçar interrupção: $resultado');
      } catch (e) {
        print(
            '[NutritionAssistantStop] Erro na tentativa de forçar interrupção: $e');
      }
    }

    // Cancelar a stream subscription localmente, independentemente do resultado no servidor
    print('[NutritionAssistantStop] Cancelando stream subscription local');
    try {
      await _aiStreamSubscription?.cancel();
      print(
          '✅ [NutritionAssistantStop] Stream subscription cancelada com sucesso');
    } catch (e) {
      print(
          '❌ [NutritionAssistantStop] Erro ao cancelar stream subscription: $e');
    }

    _aiStreamSubscription = null;
    _activeConnectionId = null;

    // Marcar que não está mais carregando
    _isLoading = false;

    // Se tiver uma mensagem em streaming, indicar que foi interrompida
    if (_streamingMessageIndex != null && _messageNotifier != null) {
      print(
          '[NutritionAssistantStop] Atualizando mensagem para indicar interrupção');
      // Não adicionar texto de interrupção à mensagem
      _messageNotifier?.setStreaming(false);
      _streamingMessageIndex = null;
      _messageNotifier = null;
      print('✅ [NutritionAssistantStop] Mensagem atualizada com sucesso');
    }

    print('✅ [NutritionAssistantStop] Processo de interrupção concluído');
    print('----------------------------------------\n');

    notifyListeners();
  }

  // Método para definir explicitamente o ID da conexão ativa
  void setActiveConnectionId(String? connectionId) {
    print(
        '[CONEXAO_DEBUG] setActiveConnectionId chamado com valor: $connectionId');
    print('[CONEXAO_DEBUG] tipo do valor: ${connectionId?.runtimeType}');
    print('[CONEXAO_DEBUG] valor atual antes: $_activeConnectionId');

    _activeConnectionId = connectionId;

    print('[CONEXAO_DEBUG] valor após definição: $_activeConnectionId');
    print(
        '[CONEXAO_DEBUG] _activeConnectionId is null? ${_activeConnectionId == null}');

    // Não notifica os listeners pois isso não afeta a UI diretamente
  }

  /// Processa um prompt silenciosamente (sem mostrar a mensagem do usuário)
  /// Usado principalmente quando o prompt vem de ferramentas GenericAIScreen
  Future<bool> processSilently(String prompt, BuildContext context,
      {Uint8List? imageBytes}) async {
    _lastContext = context;

    // Verificar se há créditos suficientes
    final creditProvider = Provider.of<CreditProvider>(context, listen: false);
    final bool hasSufficientCredits;

    // Consumir crédito apropriado (imagem ou texto)
    if (imageBytes != null) {
      hasSufficientCredits = await creditProvider.consumeImageAnalysisCredit();
    } else {
      hasSufficientCredits = await creditProvider.consumeTextMessageCredit();
    }

    if (!hasSufficientCredits) {
      // Mostrar diálogo modificado com RewardAdDialog
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.0),
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).colorScheme.primary.withOpacity(0.8),
                    Theme.of(context).colorScheme.secondary.withOpacity(0.9),
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Ícone animado
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.card_giftcard,
                      size: 50,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Título
                  Text(
                    'Sem créditos restantes!',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),

                  // Descrição
                  Text(
                    'Você pode assistir a um anúncio para ganhar 7 créditos ou fazer o upgrade para a versão PRO e ter créditos ilimitados.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Botão PRO
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SubscriptionScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black87,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.workspace_premium, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Obter versão PRO',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Botão de anúncio
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      RewardAdDialog.showRewardedAd(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_arrow, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Assistir anúncio',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Cancelar
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white.withOpacity(0.8),
                    ),
                    child: Text('Cancelar'),
                  ),
                ],
              ),
            ),
          );
        },
      );
      return false; // Não havia créditos suficientes
    }

    // Obter o controlador de idioma
    final languageController =
        Provider.of<LanguageController>(context, listen: false);
    final languageCode = _aiService.getCurrentLanguageCode(languageController);

    // Configurar para começar a responder
    _isLoading = true;
    notifyListeners();

    // Criar notificador para a mensagem da IA
    _messageNotifier = MessageNotifier();
    _messageNotifier!.setStreaming(true);

    // Adicionar a mensagem da IA (sem adicionar a mensagem do usuário)
    _messages.add({
      'isUser': false,
      'notifier': _messageNotifier,
      'timestamp': DateTime.now(),
    });

    _streamingMessageIndex = _messages.length - 1;
    notifyListeners();

    // Processar imagem ou texto
    if (imageBytes != null) {
      print('📸 Processando imagem silenciosamente...');
      // Usar o prompt fornecido ou um padrão se estiver vazio
      final imagePrompt = prompt.isEmpty
          ? "Analise esta imagem e explique o que está vendo."
          : prompt;
      _processImageForAI(imageBytes, imagePrompt, context);
    } else {
      print('📝 Processando texto silenciosamente...');
      // Determinar a qualidade com base no tipo de ferramenta
      String quality = 'bom';

      // Definir a qualidade com base no tipo de ferramenta
      if (toolType == 'youtube') {
        quality = 'baixo';
        print('📱 Usando qualidade BAIXO para ferramenta do tipo: $toolType');
      } else {
        print(
            '📱 Usando qualidade padrão (BOM) para ferramenta do tipo: $toolType');
      }

      // Obter tipos de refeição do usuário
      List<Map<String, String>>? mealTypesForAI;
      try {
        final mealTypesProvider =
            Provider.of<MealTypesProvider>(context, listen: false);
        mealTypesForAI = mealTypesProvider.mealTypes
            .map((mt) => {'id': mt.id, 'name': mt.name})
            .toList();
      } catch (e) {
        print(
            '⚠️ NutroChatController (processSilently) - Não foi possível obter tipos de refeição: $e');
      }

      // Obter stream da IA para texto
      try {
        final stream = _aiService.getAnswerStream(prompt,
            languageCode: languageCode,
            quality: quality,
            mealTypes: mealTypesForAI);

        // Usar o helper para lidar com o stream
        String? toolDataForHistory;
        // Se rawInitialPromptJson existir, sempre o utilizamos para manter a natureza da ferramenta
        if (rawInitialPromptJson != null) {
          toolDataForHistory = rawInitialPromptJson;
          print(
              '📝 NutroChatController (processSilently): Passando toolDataJson (rawInitialPromptJson) para histórico (texto)');
        }

        _aiStreamSubscription = AIInteractionHelper.handleAIStream(
          context: context,
          aiStream: stream,
          messageNotifier: _messageNotifier!,
          messages: _messages,
          streamingMessageIndex: _streamingMessageIndex!,
          storageService: _storageService,
          currentConversationId: _currentConversationId,
          studyItemType:
              'chat_message', // O helper vai sobrescrever se toolDataForHistory for provido
          setLoading: (loading) {
            _isLoading = loading;
            notifyListeners();
          },
          setConversationId: (id) {
            _currentConversationId = id;
          },
          setStreamingIndex: (index) {
            _streamingMessageIndex = index;
          },
          setProcessingMedia: (processing) {
            _isProcessingMedia = processing;
            notifyListeners();
          },
          setConnectionId: (id) {
            setActiveConnectionId(id);
          },
          toolDataJson: toolDataForHistory,
          // Não auto-registrar alimentos no modo Conversa Livre (free_chat)
          autoRegisterFoods: toolType != 'free_chat',
          onStreamComplete: () {
            // Salvar mensagens após cada resposta da IA
            _saveMessagesForCurrentDate();
          },
        );

        // Incrementar as interações bem-sucedidas
        _successfulInteractions++;

        // Verificar se deve pedir avaliação do app
        if (_successfulInteractions >= _interactionsBeforeRating) {
          _successfulInteractions = 0;
        }
      } catch (e) {
        print(
            '❌ NutroChatController - Erro ao processar texto silenciosamente: $e');
        if (_messageNotifier != null) {
          _messageNotifier!.setError(true,
              'Erro ao processar sua solicitação. Por favor, tente novamente.');
        }

        _isLoading = false;
        notifyListeners();
      }
    }
    return true; // Consumiu créditos, é um sucesso
  }

  /// Regenera a última resposta da IA
  Future<bool> regenerateLastResponse(BuildContext context) async {
    // Verificar se há mensagens para regenerar
    if (_messages.isEmpty) return true; // Nada a fazer, não é um erro

    // Encontrar a última mensagem do usuário
    int lastUserMessageIndex = -1;
    for (int i = _messages.length - 1; i >= 0; i--) {
      if (_messages[i]['isUser'] == true) {
        lastUserMessageIndex = i;
        break;
      }
    }

    if (lastUserMessageIndex == -1) return true; // Nada a fazer, não é um erro

    // Verificar se há créditos suficientes
    final creditProvider = Provider.of<CreditProvider>(context, listen: false);
    final hasSufficientCredits;

    // Obter a mensagem do usuário para regenerar
    String userMessage = '';
    if (_messages[lastUserMessageIndex].containsKey('message')) {
      userMessage = _messages[lastUserMessageIndex]['message'];
    }

    // Verificar se a mensagem contém imagem
    bool hasImage = _messages[lastUserMessageIndex].containsKey('hasImage') &&
        _messages[lastUserMessageIndex]['hasImage'] == true;

    Uint8List? imageBytes;
    if (hasImage) {
      imageBytes = _messages[lastUserMessageIndex]['imageBytes'];
      hasSufficientCredits = await creditProvider.consumeImageAnalysisCredit();
    } else {
      hasSufficientCredits = await creditProvider.consumeTextMessageCredit();
    }

    if (!hasSufficientCredits) {
      // Mostrar diálogo personalizado com RewardAdDialog e botão PRO
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.0),
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).colorScheme.primary.withOpacity(0.8),
                    Theme.of(context).colorScheme.secondary.withOpacity(0.9),
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Ícone animado
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.card_giftcard,
                      size: 50,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Título
                  Text(
                    'Sem créditos restantes!',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),

                  // Descrição
                  Text(
                    'Você pode assistir a um anúncio para ganhar 7 créditos ou fazer o upgrade para a versão PRO e ter créditos ilimitados.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Botão PRO
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SubscriptionScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black87,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.workspace_premium, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Obter versão PRO',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Botão de anúncio
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      RewardAdDialog.showRewardedAd(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_arrow, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Assistir anúncio',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Cancelar
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white.withOpacity(0.8),
                    ),
                    child: Text('Cancelar'),
                  ),
                ],
              ),
            ),
          );
        },
      );
      return false; // Não havia créditos suficientes
    }

    // Remover a última resposta da IA
    if (_messages.length > lastUserMessageIndex + 1) {
      _messages.removeAt(lastUserMessageIndex + 1);
    }

    // Criar um novo notificador para a mensagem que vamos receber
    _messageNotifier = MessageNotifier();

    // Adicionar uma nova resposta vazia da IA
    _messages.add({
      'isUser': false,
      'notifier': _messageNotifier,
      'timestamp': DateTime.now(),
    });

    _isLoading = true;
    notifyListeners();

    final aiMessageIndex = _messages.length - 1;
    _streamingMessageIndex = aiMessageIndex;

    // Processar a mensagem para obter resposta da IA
    if (hasImage && imageBytes != null) {
      // Se a mensagem contém uma imagem, processe a imagem
      final prompt = userMessage.isEmpty
          ? "Analise esta imagem e explique o que está vendo."
          : userMessage;
      _processImageForAI(imageBytes, prompt, context);
    } else {
      // Processar mensagem de texto normal
      _processMessageForAI(userMessage, context);
    }

    // Salvar o último contexto usado
    _lastContext = context;
    return true; // Consumiu créditos, é um sucesso
  }

  /// Adiciona uma resposta histórica de ferramenta como a primeira mensagem da IA.
  void addHistoricalToolResponse(String response) {
    // Garante que não haja mensagens ou que a primeira mensagem não seja da IA (evita duplicar se já carregou algo)
    if (_messages.isEmpty || _messages.first['isUser'] == true) {
      _messages.insert(0, {
        'isUser': false,
        'message': response,
        'timestamp': DateTime
            .now(), // Pode ser ajustado se o timestamp original for necessário e disponível
        'streaming': false, // Marcar como não streaming
      });
      notifyListeners();
      print(
          '💬 NutroChatController: Resposta histórica da ferramenta adicionada às mensagens.');
    } else if (_messages.first['isUser'] == false &&
        _messages.first['message'] == null &&
        _messages.first['notifier'] != null) {
      // Caso especial: a primeira mensagem é um notifier vazio (ex: de processSilently)
      // Substituímos o notifier pela resposta histórica.
      _messages[0] = {
        'isUser': false,
        'message': response,
        'timestamp': DateTime.now(),
        'streaming': false,
      };
      notifyListeners();
      print(
          '💬 NutroChatController: Resposta histórica da ferramenta substituiu notifier vazio.');
    }
  }

  /// Deleta uma mensagem e sua correspondente (usuário + IA) pelo índice
  /// Se a mensagem deletada for da IA, também deleta a mensagem do usuário anterior
  /// Se a mensagem deletada for do usuário, também deleta a resposta da IA seguinte
  void deleteMessagePair(int messageIndex) {
    if (messageIndex < 0 || messageIndex >= _messages.length) return;

    final isUser = _messages[messageIndex]['isUser'] == true;

    if (isUser) {
      // Se for mensagem do usuário, deletar ela e a resposta da IA seguinte
      if (messageIndex + 1 < _messages.length &&
          _messages[messageIndex + 1]['isUser'] == false) {
        _messages.removeAt(messageIndex + 1); // Remove resposta da IA primeiro
      }
      _messages.removeAt(messageIndex); // Remove mensagem do usuário
    } else {
      // Se for mensagem da IA, deletar ela e a mensagem do usuário anterior
      _messages.removeAt(messageIndex); // Remove resposta da IA primeiro
      if (messageIndex > 0 && _messages[messageIndex - 1]['isUser'] == true) {
        _messages.removeAt(messageIndex - 1); // Remove mensagem do usuário
      }
    }

    notifyListeners();
    _saveMessagesForCurrentDate();
    print(
        '🗑️ NutroChatController - Par de mensagens deletado no índice $messageIndex');
  }

  /// Formata a data para usar como chave de armazenamento (yyyy-MM-dd)
  String _formatDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Muda a data selecionada e carrega as mensagens dessa data
  Future<void> changeSelectedDate(DateTime newDate) async {
    print(
        '📅 NutroChatController - Mudando data de ${_formatDateKey(_selectedDate)} para ${_formatDateKey(newDate)}');

    // Salvar mensagens da data atual antes de mudar
    await _saveMessagesForCurrentDate();

    // Atualizar a data selecionada
    _selectedDate = DateTime(newDate.year, newDate.month, newDate.day);

    // Carregar mensagens da nova data
    await _loadMessagesForDate(_selectedDate);

    notifyListeners();
  }

  /// Salva as mensagens da data atual
  Future<void> _saveMessagesForCurrentDate() async {
    if (_messages.isEmpty) {
      print(
          '💾 NutroChatController - Nenhuma mensagem para salvar na data ${_formatDateKey(_selectedDate)}');
      return;
    }

    try {
      final dateKey = _formatDateKey(_selectedDate);
      final storageKey = 'nutrition_chat_$dateKey';

      // Converter mensagens para formato serializável
      final messagesData = _messages.map((msg) {
        final data = <String, dynamic>{
          'isUser': msg['isUser'],
          'timestamp':
              msg['timestamp']?.toString() ?? DateTime.now().toString(),
        };

        if (msg.containsKey('message')) {
          data['message'] = msg['message'];
        }

        if (msg.containsKey('hasImage') && msg['hasImage'] == true) {
          data['hasImage'] = true;
          // Converter bytes da imagem para base64 para armazenamento
          if (msg.containsKey('imageBytes')) {
            // Armazenar imagens seria muito pesado, então apenas marcamos que tinha uma imagem
            data['hadImage'] = true;
          }
        }

        // Se tiver um notifier, pegar a mensagem dele
        if (msg.containsKey('notifier')) {
          final notifier = msg['notifier'] as MessageNotifier?;
          if (notifier != null && notifier.message.isNotEmpty) {
            data['message'] = notifier.message;
          }
        }

        return data;
      }).toList();

      await _storageService.saveData(storageKey, {'messages': messagesData});
      print(
          '✅ NutroChatController - Mensagens salvas para data $dateKey: ${messagesData.length} mensagens');
    } catch (e) {
      print(
          '❌ NutroChatController - Erro ao salvar mensagens para data ${_formatDateKey(_selectedDate)}: $e');
    }
  }

  /// Carrega as mensagens de uma data específica
  Future<void> _loadMessagesForDate(DateTime date) async {
    try {
      final dateKey = _formatDateKey(date);
      final storageKey = 'nutrition_chat_$dateKey';

      final data = await _storageService.getData(storageKey);

      if (data == null || data.isEmpty) {
        print(
            '📭 NutroChatController - Nenhuma mensagem encontrada para data $dateKey');
        _messages = [];
        notifyListeners();
        return;
      }

      final List<dynamic> messagesData = data['messages'] ?? [];
      _messages = messagesData.map((msgData) {
        final msg = <String, dynamic>{
          'isUser': msgData['isUser'] ?? false,
          'timestamp': msgData['timestamp'] != null
              ? DateTime.parse(msgData['timestamp'])
              : DateTime.now(),
        };

        if (msgData.containsKey('message')) {
          msg['message'] = msgData['message'];
        }

        if (msgData.containsKey('hadImage') && msgData['hadImage'] == true) {
          msg['hadImage'] = true; // Marcar que tinha uma imagem
        }

        return msg;
      }).toList();

      print(
          '✅ NutroChatController - Mensagens carregadas para data $dateKey: ${_messages.length} mensagens');
      notifyListeners();
    } catch (e) {
      print(
          '❌ NutroChatController - Erro ao carregar mensagens para data ${_formatDateKey(date)}: $e');
      _messages = [];
      notifyListeners();
    }
  }
}

/// Interface para acessar os métodos necessários do NutroChatSpeechMixin
abstract class NutroChatSpeechMixinRef {
  bool get isListening;
  Future<void> releaseAudioResources();
  Future<void> stopListening();
}

/// Interface para acessar os métodos necessários do TextToSpeechMixin
abstract class TextToSpeechMixinRef {
  bool get isSpeaking;
  Future<void> speak(String text);
  void stopSpeech();
}
