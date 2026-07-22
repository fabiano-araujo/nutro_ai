import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../services/ai_service.dart';
import '../services/storage_service.dart';
import '../services/daily_chat_sync_service.dart';
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
import '../mixins/nutrition_assistant_speech_mixin.dart';
import '../services/rate_app_service.dart';
import '../widgets/reward_ad_dialog.dart';
import '../screens/settings_screen.dart';
import '../screens/subscription_screen.dart';
import '../providers/meal_types_provider.dart';
import '../providers/nutrition_goals_provider.dart';
import '../providers/diet_plan_provider.dart';
import '../services/app_agent_service.dart';
import '../utils/food_json_parser.dart';
import '../models/meal_model.dart';

/// Controller para gerenciar o estado e a lógica do Assistente de Nutrição
class NutritionAssistantController with ChangeNotifier {
  static const macroGoalsToolType = 'macro_goals_chat';

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
  int _dateChangeRequestId = 0;
  static const Duration _dateChangeLoadingLead = Duration(milliseconds: 120);

  // Estados de carregamento
  bool _isLoading = false;
  bool _isLoadingMessages = false;
  bool _isProcessingMedia = false;
  bool _isRecording = false;

  // Estado de imagem
  Uint8List? _selectedImageBytes;
  ImageSource? _selectedImageSource;
  bool _hasSelectedImage = false;

  // Valor para controlar a frequência de atualização no Android
  int _androidUpdateCounter = 0;

  // Referências aos mixins
  final NutritionAssistantSpeechMixinRef speechMixin;
  final TextToSpeechMixinRef ttsRef;

  // Contador de interações bem-sucedidas
  int _successfulInteractions = 0;
  static const int _interactionsBeforeRating = 3;

  // Flag para saber se o usuário enviou mensagem nesta sessão
  bool _userSentMessage = false;

  // Evita transformar uma tela vazia recém-aberta em exclusão real do chat.
  bool _currentDateHadStoredChatState = false;
  bool _emptyChatDeletionPending = false;

  // Flag para evitar notifyListeners após o controller ser descartado
  bool _disposed = false;

  // Tipo de ferramenta que está usando o controlador
  final String toolType;
  final String storageScope;
  final String?
      rawInitialPromptJson; // NOVO: Para armazenar o JSON bruto da ferramenta

  // Salvar o último contexto usado em sendMessage
  BuildContext? _lastContext;
  int _agenticCommandExecutions = 0;
  static const int _maxAgenticCommandExecutions = 4;

  // Getters
  List<Map<String, dynamic>> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isLoadingMessages => _isLoadingMessages;
  bool get isProcessingMedia => _isProcessingMedia;
  bool get isRecording => _isRecording;
  bool get hasSelectedImage => _hasSelectedImage;
  Uint8List? get selectedImageBytes => _selectedImageBytes;

  String _defaultMessageId(bool isUser, DateTime timestamp) {
    return '${isUser ? 'usr' : 'msg'}-${timestamp.microsecondsSinceEpoch}';
  }

  DateTime _messageTimestamp(Map<String, dynamic> message) {
    final value = message['timestamp'];
    if (value is DateTime) return value;
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    return DateTime.now();
  }

  void _ensureMessageIdentityAndLinks(
    List<Map<String, dynamic>> messages,
  ) {
    Map<String, dynamic>? latestUserMessage;

    for (final message in messages) {
      final isUser = message['isUser'] == true;
      final timestamp = _messageTimestamp(message);
      message['timestamp'] = timestamp;

      final existingId = message['id']?.toString().trim();
      if (existingId == null || existingId.isEmpty) {
        message['id'] = _defaultMessageId(isUser, timestamp);
      }

      if (isUser) {
        final existingTurnId = message['turnId']?.toString().trim();
        if (existingTurnId == null || existingTurnId.isEmpty) {
          message['turnId'] = 'turn-${timestamp.microsecondsSinceEpoch}';
        }
        latestUserMessage = message;
        continue;
      }

      if (message['recoveredLegacyMealCard'] == true &&
          message['sourceUserMessageId'] == null) {
        continue;
      }
      if (latestUserMessage == null) continue;
      final turnId = message['turnId']?.toString().trim();
      if (turnId == null || turnId.isEmpty) {
        message['turnId'] = latestUserMessage['turnId'];
      }
      final replyTo = message['replyToMessageId']?.toString().trim();
      if (replyTo == null || replyTo.isEmpty) {
        message['replyToMessageId'] = latestUserMessage['id'];
      }
    }
  }

  List<Map<String, dynamic>> _restoreEmbeddedSourceMessages(
    List<Map<String, dynamic>> messages,
  ) {
    final knownIds = messages
        .map((message) => message['id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();
    final restored = <Map<String, dynamic>>[];

    for (final message in messages) {
      if (message['isUser'] != true) {
        var sourceMessage = message['sourceUserMessage'];
        if (message['recoveredLegacyMealCard'] == true &&
            (sourceMessage is! String || sourceMessage.trim().isEmpty)) {
          final recoveredPrompt =
              _buildRecoveredMealPrompt(message['mealSnapshots']);
          if (recoveredPrompt != null) {
            final assistantId = message['id']?.toString() ??
                'msg-${_messageTimestamp(message).microsecondsSinceEpoch}';
            final recoveredUserId = 'usr-recovered-$assistantId';
            final recoveredUserTimestamp = _messageTimestamp(message)
                .subtract(const Duration(milliseconds: 1));
            message['turnId'] = 'turn-recovered-$assistantId';
            message['replyToMessageId'] = recoveredUserId;
            message['sourceUserMessage'] = recoveredPrompt;
            message['sourceUserMessageId'] = recoveredUserId;
            message['sourceUserTimestamp'] =
                recoveredUserTimestamp.toIso8601String();
            message['sourceUserReconstructed'] = true;
            sourceMessage = recoveredPrompt;
          }
        }
        final sourceHadImage = message['sourceUserHadImage'] == true;
        final sourceMessageId =
            message['sourceUserMessageId']?.toString().trim();
        if (((sourceMessage is String && sourceMessage.trim().isNotEmpty) ||
                sourceHadImage) &&
            sourceMessageId != null &&
            sourceMessageId.isNotEmpty &&
            !knownIds.contains(sourceMessageId)) {
          final sourceTimestamp = DateTime.tryParse(
                  message['sourceUserTimestamp']?.toString() ?? '') ??
              _messageTimestamp(message)
                  .subtract(const Duration(milliseconds: 1));
          restored.add({
            'id': sourceMessageId,
            'turnId': message['turnId'] ??
                'turn-${sourceTimestamp.microsecondsSinceEpoch}',
            'isUser': true,
            'message': sourceMessage is String ? sourceMessage : '',
            'timestamp': sourceTimestamp,
            if (sourceHadImage) 'hadImage': true,
            'restoredFromMealSnapshot': true,
            if (message['sourceUserReconstructed'] == true)
              'sourceUserReconstructed': true,
          });
          knownIds.add(sourceMessageId);
        }
      }
      restored.add(message);
    }
    return restored;
  }

  String? _buildRecoveredMealPrompt(dynamic rawSnapshots) {
    if (rawSnapshots is! List) return null;
    final foodNames = <String>[];
    final seen = <String>{};

    for (final rawSnapshot in rawSnapshots) {
      try {
        final snapshot = rawSnapshot is Map<String, dynamic>
            ? rawSnapshot
            : rawSnapshot is Map
                ? Map<String, dynamic>.from(rawSnapshot)
                : null;
        if (snapshot == null) continue;
        final meal = Meal.fromJson(snapshot);
        for (final food in meal.foods) {
          final name = food.name.trim();
          if (name.isNotEmpty && seen.add(name.toLowerCase())) {
            foodNames.add(name);
          }
        }
      } catch (_) {
        // Um snapshot invalido nao deve impedir a recuperacao dos demais.
      }
    }
    if (foodNames.isEmpty) return null;
    return foodNames.join(', ');
  }

  /// Persiste o estado final dos cards dentro da propria resposta do chat.
  /// Assim o turno completo (usuario + resposta + refeicoes editadas) continua
  /// renderizavel offline e tambem via snapshot sincronizado do chat.
  void persistMealSnapshotsForMessage({
    required String messageId,
    required List<Meal> meals,
  }) {
    if (messageId.trim().isEmpty) return;
    _ensureMessageIdentityAndLinks(_messages);

    final messageIndex = _messages.indexWhere((message) {
      if (message['isUser'] == true) return false;
      return message['id']?.toString() == messageId;
    });
    if (messageIndex == -1) return;

    final assistantMessage = _messages[messageIndex];
    final snapshots =
        meals.map((meal) => meal.toJson()).toList(growable: false);
    final previousSnapshots = assistantMessage['mealSnapshots'];
    var changed = false;
    if (snapshots.isEmpty) {
      changed = assistantMessage.remove('mealSnapshots') != null;
    } else if (jsonEncode(previousSnapshots) != jsonEncode(snapshots)) {
      assistantMessage['mealSnapshots'] = snapshots;
      changed = true;
    }
    if (assistantMessage.remove('replaceExistingMeals') != null) {
      changed = true;
    }

    final replyToMessageId = assistantMessage['replyToMessageId']?.toString();
    Map<String, dynamic>? sourceUserMessage;
    if (replyToMessageId != null && replyToMessageId.isNotEmpty) {
      for (final candidate in _messages) {
        if (candidate['isUser'] == true &&
            candidate['id']?.toString() == replyToMessageId) {
          sourceUserMessage = candidate;
          break;
        }
      }
    }
    if (sourceUserMessage == null) {
      for (var index = messageIndex - 1; index >= 0; index--) {
        if (_messages[index]['isUser'] == true) {
          sourceUserMessage = _messages[index];
          break;
        }
      }
    }

    if (sourceUserMessage != null) {
      final sourceId = sourceUserMessage['id'];
      final sourceTimestamp =
          _messageTimestamp(sourceUserMessage).toIso8601String();
      if (assistantMessage['sourceUserMessageId'] != sourceId) {
        assistantMessage['sourceUserMessageId'] = sourceId;
        changed = true;
      }
      if (assistantMessage['sourceUserTimestamp'] != sourceTimestamp) {
        assistantMessage['sourceUserTimestamp'] = sourceTimestamp;
        changed = true;
      }
      final sourceText = sourceUserMessage['message'];
      if (sourceText is String &&
          sourceText.trim().isNotEmpty &&
          assistantMessage['sourceUserMessage'] != sourceText) {
        assistantMessage['sourceUserMessage'] = sourceText;
        changed = true;
      }
      if (sourceUserMessage['hasImage'] == true ||
          sourceUserMessage['hadImage'] == true) {
        if (assistantMessage['sourceUserHadImage'] != true) {
          assistantMessage['sourceUserHadImage'] = true;
          changed = true;
        }
      }
    }

    if (!changed) return;
    notifyListeners();
    unawaited(_saveMessagesForCurrentDate());
  }

  /// Converte refeicoes antigas, que sobreviveram apenas no diario, em
  /// mensagens de card na posicao original da conversa. Quando a mensagem
  /// original ja foi perdida, cria uma bolha factual apenas com os nomes dos
  /// alimentos que continuam armazenados no proprio card.
  void recoverLegacyMealSnapshotMessages(List<Meal> meals) {
    if (meals.isEmpty) return;
    _ensureMessageIdentityAndLinks(_messages);

    final grouped = <String, List<Meal>>{};
    for (final meal in meals) {
      final rawId = meal.messageId?.trim();
      if (rawId == null || rawId.isEmpty) continue;
      final withoutMealSuffix = rawId.split('#meal-').first;
      final legacyMatch =
          RegExp(r'^(msg-\d+)-\d+$').firstMatch(withoutMealSuffix);
      final groupId = legacyMatch?.group(1) ?? withoutMealSuffix;
      if (!RegExp(r'^msg-\d+$').hasMatch(groupId)) continue;
      (grouped[groupId] ??= <Meal>[]).add(meal);
    }
    if (grouped.isEmpty) return;

    var changed = false;
    for (final entry in grouped.entries) {
      if (_messages.any((message) => message['id'] == entry.key)) {
        continue;
      }
      final micros = int.tryParse(entry.key.substring('msg-'.length));
      if (micros == null) continue;
      final timestamp = DateTime.fromMicrosecondsSinceEpoch(micros);

      Map<String, dynamic>? sourceUserMessage;
      Duration? closestDistance;
      for (final candidate in _messages) {
        if (candidate['isUser'] != true) continue;
        final candidateTimestamp = _messageTimestamp(candidate);
        if (candidateTimestamp.isAfter(timestamp)) continue;
        final distance = timestamp.difference(candidateTimestamp);
        if (distance > const Duration(minutes: 5)) continue;
        if (closestDistance == null || distance < closestDistance) {
          sourceUserMessage = candidate;
          closestDistance = distance;
        }
      }

      final recoveredMessage = <String, dynamic>{
        'id': entry.key,
        'isUser': false,
        'message': '',
        'timestamp': timestamp,
        'mealSnapshots':
            entry.value.map((meal) => meal.toJson()).toList(growable: false),
        'recoveredLegacyMealCard': true,
      };
      if (sourceUserMessage != null) {
        recoveredMessage['turnId'] = sourceUserMessage['turnId'];
        recoveredMessage['replyToMessageId'] = sourceUserMessage['id'];
        recoveredMessage['sourceUserMessageId'] = sourceUserMessage['id'];
        recoveredMessage['sourceUserTimestamp'] =
            _messageTimestamp(sourceUserMessage).toIso8601String();
        final sourceText = sourceUserMessage['message'];
        if (sourceText is String && sourceText.trim().isNotEmpty) {
          recoveredMessage['sourceUserMessage'] = sourceText;
        }
      }

      final insertionIndex = _messages.indexWhere(
        (message) => _messageTimestamp(message).isAfter(timestamp),
      );
      if (insertionIndex == -1) {
        _messages.add(recoveredMessage);
      } else {
        _messages.insert(insertionIndex, recoveredMessage);
      }
      changed = true;
    }

    if (!changed) return;
    _messages = _restoreEmbeddedSourceMessages(_messages);
    _ensureMessageIdentityAndLinks(_messages);
    notifyListeners();
    unawaited(_saveMessagesForCurrentDate());
  }

  String? get currentConversationId => _currentConversationId;
  int? get currentlySpeakingMessageIndex => _currentlySpeakingMessageIndex;
  DateTime get selectedDate => _selectedDate;

  void _logDailyChatTrace(
    String event, [
    Map<String, Object?> data = const {},
  ]) {
    final payload = data.isEmpty ? '' : ' ${jsonEncode(data)}';
    debugPrint('[DAILY_CHAT_TRACE] $event$payload');
  }

  String _messageText(Map<String, dynamic> msg) {
    final value = msg['message'];
    if (value is String) return value;

    final notifier = msg['notifier'];
    if (notifier is MessageNotifier) return notifier.message;

    return '';
  }

  String _messagePreview(String text) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= 80) return normalized;
    return '${normalized.substring(0, 80)}...';
  }

  Map<String, Object?> _summarizeMessages(
    Iterable<Map<String, dynamic>> messages,
  ) {
    var total = 0;
    var user = 0;
    var assistant = 0;
    var emptyText = 0;
    var notifier = 0;
    var foodJson = 0;
    var images = 0;
    String? firstPreview;
    String? lastPreview;
    String? firstTimestamp;
    String? lastTimestamp;

    for (final msg in messages) {
      total++;
      final isUser = msg['isUser'] == true;
      if (isUser) {
        user++;
      } else {
        assistant++;
      }

      if (msg.containsKey('notifier')) {
        notifier++;
      }
      if (msg['hasImage'] == true || msg['hadImage'] == true) {
        images++;
      }

      final text = _messageText(msg);
      if (text.trim().isEmpty) {
        emptyText++;
      }
      if (FoodJsonParser.hasFoodJsonSignal(text)) {
        foodJson++;
      }

      final previewPrefix = isUser ? 'user' : 'assistant';
      final preview = '$previewPrefix:${_messagePreview(text)}';
      firstPreview ??= preview;
      lastPreview = preview;

      final timestamp = msg['timestamp'];
      final timestampText = timestamp is DateTime
          ? timestamp.toIso8601String()
          : timestamp?.toString();
      firstTimestamp ??= timestampText;
      lastTimestamp = timestampText;
    }

    return {
      'total': total,
      'user': user,
      'assistant': assistant,
      'emptyText': emptyText,
      'notifier': notifier,
      'foodJson': foodJson,
      'images': images,
      'first': firstPreview,
      'last': lastPreview,
      'firstTimestamp': firstTimestamp,
      'lastTimestamp': lastTimestamp,
    };
  }

  Map<String, dynamic>? _normalizeStoredChatData(Map<String, dynamic>? data) {
    if (data == null) return null;
    final messages = data['messages'];
    if (messages is! List) return data;

    return {
      ...data,
      'messages': messages
          .whereType<Map>()
          .map((msg) => Map<String, dynamic>.from(msg))
          .toList(growable: false),
    };
  }

  Map<String, Object?> _summarizeStoredChatData(Map<String, dynamic>? data) {
    final normalized = _normalizeStoredChatData(data);
    final messages = normalized?['messages'];
    if (messages is! List<Map<String, dynamic>>) {
      return const {
        'total': 0,
        'user': 0,
        'assistant': 0,
        'emptyText': 0,
        'notifier': 0,
        'foodJson': 0,
        'images': 0,
      };
    }
    return _summarizeMessages(messages);
  }

  bool get _usesFreeNutritionAgent =>
      toolType == 'free_chat' ||
      toolType == 'my_diet' ||
      toolType == macroGoalsToolType;

  bool get _shouldAutoRegisterFoods =>
      toolType != 'free_chat' && toolType != macroGoalsToolType;

  String _buildToolScopedInstructions() {
    if (toolType == 'free_chat') {
      return '''
Conversation mode: free nutrition chat.
Do not log, save, register, or add foods, meals, or food macros to the diary.
Do not return meal food JSON. If the user mentions a food without a clear question, answer with general nutrition context or ask what they want to know.
''';
    }

    if (toolType != macroGoalsToolType) {
      return '';
    }

    return '''
Conversation mode: nutrition goal and macro target review.
Use fixed app actions when the request needs app data or mutation.
If saving a broad goal needs confirmation, answer naturally and append APP_PENDING_ACTION for the intended app_command.
If APP_PENDING_ACTION is present and the user semantically approves or continues it, return that app_command only.
Do not enter diet-preference or meal-plan flow unless the latest user request explicitly asks for a diet plan.
''';
  }

  NutritionAssistantController({
    required this.speechMixin,
    required this.ttsRef,
    String? conversationId,
    bool showWelcomeMessage = true,
    this.toolType = 'chat',
    this.storageScope = 'guest',
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
        '🤖 NutritionAssistantController - Construtor: conversationId: $conversationId, showWelcomeMessage: $showWelcomeMessage, toolType: $toolType, storageScope: $storageScope, hasInitialMessages: ${initialMessages != null && initialMessages.isNotEmpty}, selectedDate: ${_formatDateKey(_selectedDate)}');
    if (initialMessages != null) {
      // Prioridade máxima: se mensagens iniciais são fornecidas, usá-las.
      final restoredInitialMessages = _sanitizeRestoredMessages(
        List<Map<String, dynamic>>.from(initialMessages),
        source: 'initialMessages',
      );
      _messages = restoredInitialMessages;
      _currentDateHadStoredChatState = _messages.isNotEmpty;
      _logDailyChatTrace('controller_initial_messages', {
        'date': _formatDateKey(_selectedDate),
        'scope': storageScope,
        'toolType': toolType,
        'source': 'initialMessages',
        ..._summarizeMessages(_messages),
      });

      // Log formatado das mensagens iniciais
      print('\n');
      print(
          '📊 ==================== AI TUTOR CONTROLLER - MENSAGENS INICIAIS ====================');
      print('📊 Número total de mensagens: ${restoredInitialMessages.length}');

      // Exibir mensagens para verificação
      if (restoredInitialMessages.isNotEmpty) {
        print('📊 Detalhes das mensagens recebidas:');
        for (int i = 0; i < restoredInitialMessages.length; i++) {
          var msg = restoredInitialMessages[i];
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
      if (restoredInitialMessages.length >= 2) {
        print('📊 Verificação de sequência:');
        bool sequenciaOK = true;
        for (int i = 0; i < restoredInitialMessages.length - 1; i++) {
          var atual = restoredInitialMessages[i];
          var proximo = restoredInitialMessages[i + 1];

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
          '✅ NutritionAssistantController: Inicializado com ${restoredInitialMessages.length} mensagens fornecidas via initialMessages.');
      // Se estamos usando initialMessages, geralmente não queremos carregar uma conversationId separadamente,
      // a menos que seja um caso de uso específico para mesclar/continuar.
      // Por agora, se initialMessages é provido, ele é a fonte da verdade para o estado inicial.
      if (conversationId != null) {
        _currentConversationId =
            conversationId; // Manter o ID se fornecido, mesmo usando initialMessages
        print(
            '   ➡️ conversationId ($conversationId) também foi fornecido e será mantido.');
      }
      // Não chamar notifyListeners() aqui; a NutritionAssistantScreen o fará após a configuração completa se necessário.
    } else if (conversationId != null) {
      // Se não há initialMessages, mas há um conversationId, carregar a conversa.
      print(
          '📂 NutritionAssistantController: Carregando conversa por ID: $conversationId');
      _loadConversation(conversationId);
      _currentConversationId = conversationId;
    } else if (showWelcomeMessage) {
      // Nenhuma mensagem inicial e nenhum ID de conversa, e showWelcomeMessage é true.
      // Esta é a única condição em que a mensagem de boas-vindas deve ser adicionada.
      print(
          '👋 NutritionAssistantController: Adicionando mensagem de boas-vindas.');
      _addWelcomeMessage(); // _addWelcomeMessage já chama notifyListeners
    } else {
      print(
          '🤷 NutritionAssistantController: Nenhuma mensagem inicial, nenhum ID de conversa, e showWelcomeMessage é false.');
      // Carregar mensagens da data inicial (se houver)
      print(
          '📅 NutritionAssistantController: Carregando mensagens da data inicial: ${_formatDateKey(_selectedDate)}');
      _isLoadingMessages = true;
      _logDailyChatTrace('initial_date_load_scheduled', {
        'date': _formatDateKey(_selectedDate),
        'scope': storageScope,
        'toolType': toolType,
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_disposed) return;
        print(
            '[CHAT_LOAD_PERF] initial_load_after_first_frame date=${_formatDateKey(_selectedDate)}');
        unawaited(_loadMessagesForDate(_selectedDate));
      });
      // notifyListeners será chamado por _loadMessagesForDate após o carregamento
    }
  }

  /// Adiciona uma mensagem de boas-vindas padrão
  void _addWelcomeMessage() {
    _messages.add({
      'isUser': false,
      'message':
          'Olá! Sou Nutro AI, seu assistente de nutrição. Como posso te ajudar hoje?',
      'timestamp': DateTime.now(),
    });
    notifyListeners();
  }

  void _addCreditExhaustedAssistantMessage(BuildContext context) {
    final message =
        AppLocalizations.of(context).translate('chat_credit_exhausted_inline');
    _messages.add({
      'isUser': false,
      'message': message,
      'timestamp': DateTime.now(),
    });
    _isLoading = false;
    notifyListeners();
  }

  /// Remove do chat o aviso de "sem créditos" (e o botão de assistir anúncio
  /// que aparece junto dele). Chamado após o usuário ganhar a recompensa do
  /// anúncio premiado, já que o aviso deixa de ser relevante.
  void removeCreditExhaustedMessages() {
    if (_disposed) return;

    String extractText(Map<String, dynamic> msg) {
      final notifier = msg['notifier'];
      if (notifier is MessageNotifier) {
        return notifier.message;
      }
      final value = msg['message'];
      return value is String ? value : '';
    }

    final initialCount = _messages.length;
    _messages.removeWhere((msg) =>
        msg['isUser'] == false &&
        AppAgentService.isCreditExhaustedResponse(extractText(msg)));

    if (_messages.length == initialCount) return;

    notifyListeners();
    _saveMessagesForCurrentDate();
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
                'Olá! Sou Nutro AI, seu assistente de nutrição. Como posso te ajudar hoje?';
            break;
          case 'en_US':
            welcomeMessage =
                'Hi! I\'m Nutro AI, your nutrition assistant. How can I help you today?';
            break;
          case 'es_ES':
            welcomeMessage =
                '¡Hola! Soy Nutro AI, tu asistente de nutrición. ¿Cómo puedo ayudarte hoy?';
            break;
          case 'de_DE':
            welcomeMessage =
                'Hallo! Ich bin Nutro AI, dein Ernährungsassistent. Wie kann ich dir heute helfen?';
            break;
          case 'fr_FR':
            welcomeMessage =
                'Bonjour ! Je suis Nutro AI, votre assistant nutritionnel. Comment puis-je vous aider aujourd\'hui ?';
            break;
          case 'it_IT':
            welcomeMessage =
                'Ciao! Sono Nutro AI, il tuo assistente nutrizionale. Come posso aiutarti oggi?';
            break;
          default:
            welcomeMessage =
                'Hi! I\'m Nutro AI, your nutrition assistant. How can I help you today?';
        }
      }

      // Atualiza a mensagem se houver mensagens
      if (_messages.isNotEmpty) {
        _messages[0]['message'] = welcomeMessage;
        notifyListeners();
      }
    } catch (e) {
      print('⚠️ NutritionAssistantController - Erro ao obter tradução: $e');
    }
  }

  /// Carrega uma conversa pelo ID
  Future<void> _loadConversation(String conversationId) async {
    print(
        '📂 NutritionAssistantController - Iniciando carregamento da conversa ID: $conversationId');
    _isLoading = true;
    _isLoadingMessages = true;
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
        _isLoadingMessages = false;
        notifyListeners();
        print(
            '✅ NutritionAssistantController - Conversa carregada com sucesso via Helper');
      } else {
        print(
            '⚠️ NutritionAssistantController - Conversa não encontrada ou erro no Helper, mostrando mensagem padrão');
        _addWelcomeMessage();
        _isLoading = false;
        _isLoadingMessages = false;
        notifyListeners();
      }
    } catch (e) {
      print(
          '❌ NutritionAssistantController - Erro inesperado ao carregar conversa: $e');
      _addWelcomeMessage();
      _isLoading = false;
      _isLoadingMessages = false;
      notifyListeners();
    }
  }

  /// Envia uma mensagem para a IA
  Future<bool> sendMessage(String message, BuildContext context) async {
    final trimmedMessage = message.trim();
    _lastContext = context;
    _userSentMessage =
        true; // Flag para marcação de sessão com mensagem enviada pelo usuário

    if (trimmedMessage.isEmpty && !_hasSelectedImage) {
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
      _addCreditExhaustedAssistantMessage(context);
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
                    'Assista a um anúncio rápido e ganhe 7 créditos grátis para continuar agora mesmo.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Botão de anúncio (em destaque — caminho gratuito)
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      RewardAdDialog.showRewardedAd(_lastContext ?? context,
                          onRewardEarned: removeCreditExhaustedMessages);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black87,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 24),
                      minimumSize: const Size(double.infinity, 0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_arrow, size: 20),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Assistir anúncio • +7 créditos grátis',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Botão PRO (caminho premium — discreto)
                  OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SubscriptionScreen(),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                          color: Colors.white.withOpacity(0.6), width: 1.5),
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.workspace_premium, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Ou obter PRO ilimitado',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),

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
    final userTimestamp = DateTime.now();
    final userMessageId = _defaultMessageId(true, userTimestamp);
    final turnId = 'turn-${userTimestamp.microsecondsSinceEpoch}';

    // Adicionar mensagem do usuário
    if (enviandoImagem && imagemBytes != null) {
      // Mensagem com imagem
      _messages.add({
        'isUser': true,
        'message':
            trimmedMessage, // Removido texto padrão, agora envia string vazia quando não há mensagem
        'hasImage': true,
        'imageBytes': imagemBytes,
        'id': userMessageId,
        'turnId': turnId,
        'timestamp': userTimestamp,
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
        'message': trimmedMessage,
        'id': userMessageId,
        'turnId': turnId,
        'timestamp': userTimestamp,
      });
    }

    // Marcar que o usuário enviou mensagem nesta sessão
    _userSentMessage = true;
    _logDailyChatTrace('user_message_added', {
      'date': _formatDateKey(_selectedDate),
      'scope': storageScope,
      'toolType': toolType,
      'hasImage': enviandoImagem,
      'messageIndex': _messages.length - 1,
      'preview': _messagePreview(trimmedMessage),
      ..._summarizeMessages(_messages),
    });

    // Persistir imediatamente a mensagem do usuário, especialmente fotos.
    // A resposta da IA será salva novamente quando o stream terminar.
    unawaited(_saveMessagesForCurrentDate());

    // Adiciona a mensagem com o notifier em vez do conteúdo direto
    final assistantTimestamp = DateTime.now();
    _messages.add({
      'isUser': false,
      'notifier': _messageNotifier,
      'id': _defaultMessageId(false, assistantTimestamp),
      'turnId': turnId,
      'replyToMessageId': userMessageId,
      'timestamp': assistantTimestamp,
    });
    _logDailyChatTrace('assistant_placeholder_added', {
      'date': _formatDateKey(_selectedDate),
      'scope': storageScope,
      'toolType': toolType,
      'messageIndex': _messages.length - 1,
      ..._summarizeMessages(_messages),
    });

    _isLoading = true;
    notifyListeners();

    final aiMessageIndex = _messages.length - 1;
    _streamingMessageIndex = aiMessageIndex;

    // Deixa a bolha do usuário e o placeholder da IA renderizarem antes de
    // preparar prompt/histórico, que pode fazer trabalho síncrono perceptível.
    final userMessage = _messages[aiMessageIndex - 1];
    final hasImageMessage =
        userMessage.containsKey('hasImage') && userMessage['hasImage'] == true;
    final imageBytes = hasImageMessage ? userMessage['imageBytes'] : null;
    final imagePrompt = trimmedMessage.isEmpty
        ? "Analyze this image and explain what you see." // Hidden AI prompt; not shown in the user bubble
        : trimmedMessage;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || !context.mounted) return;

      if (hasImageMessage && imageBytes != null) {
        unawaited(_processImageForAI(imageBytes, imagePrompt, context));
      } else {
        unawaited(_processMessageForAI(trimmedMessage, context));
      }
    });

    // Salvar o último contexto usado em sendMessage
    _lastContext = context;
    return true; // Consumiu créditos, é um sucesso
  }

  /// Processa mensagem de texto para a IA
  Future<void> _processMessageForAI(
      String message, BuildContext context) async {
    if (_messageNotifier == null || _streamingMessageIndex == null) {
      print(
          '❌ NutritionAssistantController - _messageNotifier ou _streamingMessageIndex nulo antes de processar texto.');
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      // Iniciar medição de tempo para logging
      final startPrepTime = DateTime.now();

      // Preparar o contexto da conversa
      String contextPrompt = '';
      AppAgentPendingAction? pendingAction;

      // Usar uma cópia da lista para evitar modificação concorrente durante a compilação do prompt
      final currentMessagesForPrompt =
          List<Map<String, dynamic>>.from(_messages);
      if (currentMessagesForPrompt.length > 2) {
        // Obter o histórico exceto a mensagem do usuário atual e a mensagem de resposta da IA
        // que está sendo gerada (as duas últimas mensagens)
        final messageHistory = currentMessagesForPrompt.sublist(
            0, currentMessagesForPrompt.length - 2);
        pendingAction = AppAgentPendingAction.findLatestInTrailingAssistantTurn(
          messageHistory,
        );
        if (pendingAction == null &&
            AppAgentPendingAction.isLikelyApproval(message)) {
          pendingAction =
              AppAgentPendingAction.findLatestUnresolvedInConversation(
            messageHistory,
          );
        }
        if (pendingAction != null &&
            AppAgentPendingAction.isLikelyApproval(message)) {
          final handled = await _executePendingActionApproval(
            pendingAction: pendingAction,
            originalUserMessage: message,
            context: context,
          );
          if (handled) {
            return;
          }
        }
        final shouldIncludeContext =
            _shouldIncludeConversationContextForPrompt(message, messageHistory);
        final tokenLimit = toolType == 'free_chat' ? 8000 : 6000;
        final blockLimit = toolType == 'free_chat' ? 80 : 60;
        final charLimit = toolType == 'free_chat' ? 16000 : 12000;

        if (shouldIncludeContext) {
          contextPrompt = await _aiService.limitConversationHistory(
            messageHistory,
            maxTokenLimit: tokenLimit,
          );
          contextPrompt = AppAgentService.compactConversationContext(
            contextPrompt,
            maxBlocks: blockLimit,
            maxChars: charLimit,
          );
        }
        if (pendingAction != null) {
          contextPrompt = [
            'Current pending app action awaiting user confirmation:',
            pendingAction.toPromptBlock(),
            if (contextPrompt.isNotEmpty) contextPrompt,
          ].join('\n');
        }
      }

      // Registrar tempo
      final prepDuration = DateTime.now().difference(startPrepTime);
      print(
          '⏱️ NutritionAssistantController - Tempo de preparação do contexto: ${prepDuration.inMilliseconds}ms');

      // Montar o prompt com contexto da conversa e mensagem do usuário
      // O system prompt de nutrição agora vem da API através do agentType='nutrition'
      final goalsProvider =
          Provider.of<NutritionGoalsProvider>(context, listen: false);
      final dietProvider =
          Provider.of<DietPlanProvider>(context, listen: false);
      await goalsProvider.ensureLoaded();
      await dietProvider.ensureLoaded();

      final promptSections = <String>[];
      final toolScopedInstructions = _buildToolScopedInstructions();
      if (toolScopedInstructions.isNotEmpty) {
        promptSections.add(toolScopedInstructions);
      }
      if (contextPrompt.isNotEmpty) {
        promptSections.add(
          'Current chat history, oldest to newest '
          '(accessible conversation context):\n'
          '$contextPrompt',
        );
      }
      promptSections.add('User request:\n$message');
      final basePrompt = promptSections.join('\n\n');
      final prompt = await AppAgentService.buildPromptWithCurrentAppState(
        context: context,
        basePrompt: basePrompt,
      );

      // Obter o controlador de idioma
      final languageController =
          Provider.of<LanguageController>(context, listen: false);
      final languageCode =
          _aiService.getCurrentLanguageCode(languageController);

      // Determinar o modelo baseado no toolType
      String quality = '';
      String provider = 'Hyperbolic';

      // Para fluxos principais do app, usar Gemini Flash Lite com provider automático
      if (toolType == 'chat') {
        quality = 'google/gemini-2.5-flash-lite';
        provider = '';
        print('📱 Usando modelo Gemini 2.5 Flash Lite para o chat inicial');
      } else if (toolType == 'my_diet') {
        quality = 'google/gemini-3-flash-preview';
        provider = ''; // Deixar o OpenRouter escolher o provider
        print('📱 Usando modelo Gemini Flash para Minha Dieta');
      } else if (toolType == 'free_chat') {
        quality = 'google/gemini-2.5-flash-lite';
        provider =
            ''; // Deixar vazio para escolher automaticamente (geralmente o mais barato/disponível)
        print('📱 Usando modelo Gemini 2.5 Flash Lite para Free Chat');
      } else if (toolType == macroGoalsToolType) {
        quality = 'google/gemini-2.5-flash-lite';
        provider = '';
        print(
            '📱 Usando modelo Gemini 2.5 Flash Lite para conversa de metas/macros');
      } else {
        print(
            '📱 Usando qualidade padrão (modelo padrão do servidor) para o tutor de nutrição');
        print('🔌 Usando provider Hyperbolic para o agent nutricional');
      }

      // Determinar o agentType baseado no toolType
      // free_chat e my_diet usam o agent 'free-nutrition' que não retorna JSON formatado
      String agentType =
          _usesFreeNutritionAgent ? 'free-nutrition' : 'nutrition';
      print('🤖 Usando agentType: $agentType para toolType: $toolType');

      // Obter o usuário logado para pegar o ID
      final authService = Provider.of<AuthService>(context, listen: false);
      String userId = '';

      // Verificar se há um usuário autenticado
      if (authService.isAuthenticated && authService.currentUser != null) {
        userId = authService.currentUser!.id.toString();
        print(
            '👤 NutritionAssistantController - Usuário logado: ${authService.currentUser!.name}, ID: $userId');
      } else {
        print(
            '⚠️ NutritionAssistantController - Nenhum usuário autenticado, usando ID vazio');
      }

      // Obter tipos de refeição do usuário para classificação pela IA
      List<Map<String, String>>? mealTypesForAI;
      try {
        final mealTypesProvider =
            Provider.of<MealTypesProvider>(context, listen: false);
        mealTypesForAI = mealTypesProvider.mealTypes
            .map((mt) => {'id': mt.id, 'name': mt.name})
            .toList();
        print(
            '🍽️ NutritionAssistantController - Tipos de refeição: $mealTypesForAI');
      } catch (e) {
        print(
            '⚠️ NutritionAssistantController - Não foi possível obter tipos de refeição: $e');
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
            '📝 NutritionAssistantController: Passando toolDataJson (rawInitialPromptJson) para histórico (mensagem de texto)');
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
        autoRegisterFoods: _shouldAutoRegisterFoods,
        displayContentBuilder: (rawContent) => _buildTextDisplayContent(
          rawContent,
          autoRegisterFoods: _shouldAutoRegisterFoods,
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
          unawaited(_saveMessagesForCurrentDate(syncNow: true));
        },
      );
    } catch (e) {
      print(
          '❌ NutritionAssistantController - Exceção ao preparar/iniciar stream de texto: $e');
      if (_messageNotifier != null) {
        // Mensagem de erro genérica para o usuário
        _messageNotifier!.setError(true,
            'Desculpe, ocorreu um erro ao processar sua solicitação. Por favor, tente novamente.');
      }
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> _executePendingActionApproval({
    required AppAgentPendingAction pendingAction,
    required String originalUserMessage,
    required BuildContext context,
  }) async {
    final notifier = _messageNotifier;
    if (notifier == null) {
      return false;
    }

    final command =
        pendingAction.toExecutionCommand(rawJson: pendingAction.rawBlock);
    AppAgentService.logAgentDebug('pending_action_approval_local_execution', {
      'userMessage': originalUserMessage,
      'commandName': command.name,
      'arguments': command.arguments,
    });
    notifier.updateMessage(
      pendingAction.rawBlock,
      displayContent: AppAgentService.buildLoadingMessage(
        context,
        command.name,
      ),
    );
    notifyListeners();

    final executionResult = await AppAgentService.executeCommand(
      command,
      context,
    );
    final executionResults = [executionResult];
    final directMessage = AppAgentService.buildCommandResultFallbackMessage(
          context: context,
          executionResults: executionResults,
          originalUserMessage: originalUserMessage,
        ) ??
        AppAgentService.buildMacroGoalsCommandResultMessage(
          context: context,
          executionResults: executionResults,
        ) ??
        AppAgentService.buildDietGeneratedCommandResultMessage(
          context: context,
          executionResults: executionResults,
        ) ??
        AppLocalizations.of(context)
            .translate('agent_command_invalid_response');

    _finalizeInterceptedMessage(notifier, directMessage);
    unawaited(_saveMessagesForCurrentDate(syncNow: true));
    return true;
  }

  bool _shouldIncludeConversationContextForPrompt(
    String userMessage,
    List<Map<String, dynamic>> messageHistory,
  ) {
    if (messageHistory.isEmpty) {
      return false;
    }

    final hasPriorUserMessage =
        messageHistory.any((message) => message['isUser'] == true);
    if (!hasPriorUserMessage) {
      return false;
    }

    return AppAgentService.shouldIncludeConversationContext(userMessage);
  }

  String _buildTextDisplayContent(
    String rawContent, {
    required bool autoRegisterFoods,
  }) {
    final commandPlaceholder = _buildStreamingCommandPlaceholder(rawContent);
    if (commandPlaceholder != null) {
      return commandPlaceholder;
    }

    return AppAgentService.sanitizeDisplayMessage(
      rawContent,
      autoRegisterFoods: autoRegisterFoods,
      fallbackSanitizer: (content) {
        if (!autoRegisterFoods && FoodJsonParser.containsFoodJson(content)) {
          return FoodJsonParser.toReadableMessage(content);
        }
        if (!autoRegisterFoods && !FoodJsonParser.hasFoodJsonSignal(content)) {
          return content;
        }
        return FoodJsonParser.removeJsonCandidateFromMessage(content);
      },
    );
  }

  String? _buildStreamingCommandPlaceholder(String rawContent) {
    final normalized = rawContent.toLowerCase();
    final looksLikeCommand = AppAgentCommand.containsCommandCandidate(
          rawContent,
        ) ||
        RegExp(
          r'^\s*[,{\[]?\s*\\?"(?:name|app_?commands?)\\?"',
          caseSensitive: false,
        ).hasMatch(rawContent);
    if (!looksLikeCommand) {
      return null;
    }

    final context = _lastContext;
    if (context == null) {
      return '';
    }

    final key = normalized.contains('diet') || normalized.contains('dieta')
        ? 'agent_loading_generate_diet'
        : 'agent_loading_generic';
    return AppLocalizations.of(context).translate(key);
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
    List<AppAgentExecutionResult>? priorExecutionResults,
  }) async {
    final commandBatch = AppAgentCommand.tryParseBatch(responseContent);
    final initialVisibleContent = _buildTextDisplayContent(
      responseContent,
      autoRegisterFoods: _shouldAutoRegisterFoods,
    ).trim();
    AppAgentService.logAgentDebug('intercept_final_response', {
      'toolType': toolType,
      'agentType': agentType,
      'rawLength': responseContent.length,
      'visibleLength': initialVisibleContent.length,
      'containsCommandCandidate':
          AppAgentCommand.containsCommandCandidate(responseContent),
      'commandCount': commandBatch?.commands.length ?? 0,
      'commandNames':
          commandBatch?.commands.map((command) => command.name).toList() ??
              const [],
      'priorExecutionResults':
          priorExecutionResults?.map((result) => result.toJson()).toList() ??
              const [],
      'rawPreview': AppAgentService.debugPreview(responseContent),
      'visiblePreview': AppAgentService.debugPreview(initialVisibleContent),
      'userMessage': originalUserMessage,
    });
    if (commandBatch == null || commandBatch.commands.isEmpty) {
      final pendingAction = AppAgentPendingAction.tryParse(responseContent);
      if (pendingAction != null &&
          pendingAction.shouldExecuteImmediately(
            userMessage: originalUserMessage,
            visibleAssistantText: initialVisibleContent,
          )) {
        AppAgentService.logAgentDebug(
          'pending_action_immediate_execution',
          {
            'userMessage': originalUserMessage,
            'visiblePreview': AppAgentService.debugPreview(
              initialVisibleContent,
            ),
            'commandName': pendingAction.command.name,
            'arguments': pendingAction.command.arguments,
          },
        );
        final handled = await _executePendingActionApproval(
          pendingAction: pendingAction,
          originalUserMessage: originalUserMessage,
          context: context,
        );
        if (handled) {
          return true;
        }
      }

      final fallbackMacroStatusCommand =
          AppAgentService.buildMacroTargetsStatusCommandFromUserMessage(
        originalUserMessage,
        rawJson: responseContent,
        conversationContext: conversationContext,
      );
      if (fallbackMacroStatusCommand != null) {
        AppAgentService.logAgentDebug('fallback_macro_status_from_message', {
          'userMessage': originalUserMessage,
          'arguments': fallbackMacroStatusCommand.arguments,
          'conversationContext':
              AppAgentService.debugPreview(conversationContext),
        });
        final executionResult = await AppAgentService.executeCommand(
          fallbackMacroStatusCommand,
          context,
        );
        final directMessage =
            AppAgentService.buildMacroGoalsCommandResultMessage(
          context: context,
          executionResults: [executionResult],
        );
        if (directMessage != null) {
          _finalizeInterceptedMessage(notifier, directMessage);
          _saveMessagesForCurrentDate();
          return true;
        }
      }

      final fallbackDailyStatusCommand =
          AppAgentService.buildDailyNutritionStatusCommandFromUserMessage(
        originalUserMessage,
        rawJson: responseContent,
      );
      if (fallbackDailyStatusCommand != null) {
        AppAgentService.logAgentDebug('fallback_daily_status_from_message', {
          'userMessage': originalUserMessage,
          'arguments': fallbackDailyStatusCommand.arguments,
        });
        final executionResult = await AppAgentService.executeCommand(
          fallbackDailyStatusCommand,
          context,
        );
        final directMessage = AppAgentService.buildCommandResultFallbackMessage(
          context: context,
          executionResults: [executionResult],
          originalUserMessage: originalUserMessage,
        );
        if (directMessage != null) {
          _finalizeInterceptedMessage(notifier, directMessage);
          _saveMessagesForCurrentDate();
          return true;
        }
      }

      final fallbackMacroTargetsCommand =
          AppAgentService.buildMacroTargetsCommandFromUserMessage(
        originalUserMessage,
        rawJson: responseContent,
      );
      if (fallbackMacroTargetsCommand != null) {
        AppAgentService.logAgentDebug('fallback_macro_targets_from_message', {
          'userMessage': originalUserMessage,
          'arguments': fallbackMacroTargetsCommand.arguments,
        });
        final executionResult = await AppAgentService.executeCommand(
          fallbackMacroTargetsCommand,
          context,
        );
        final directMessage =
            AppAgentService.buildMacroGoalsCommandResultMessage(
          context: context,
          executionResults: [executionResult],
        );
        if (directMessage != null) {
          _finalizeInterceptedMessage(notifier, directMessage);
          _saveMessagesForCurrentDate();
          return true;
        }
      }

      final contextualMacroTargetsCommand =
          AppAgentService.buildMacroTargetsCommandFromContextualMessage(
        originalUserMessage,
        conversationContext,
        rawJson: responseContent,
      );
      if (contextualMacroTargetsCommand != null) {
        AppAgentService.logAgentDebug('fallback_macro_targets_from_context', {
          'userMessage': originalUserMessage,
          'arguments': contextualMacroTargetsCommand.arguments,
          'conversationContext':
              AppAgentService.debugPreview(conversationContext),
        });
        final executionResult = await AppAgentService.executeCommand(
          contextualMacroTargetsCommand,
          context,
        );
        final directMessage =
            AppAgentService.buildMacroGoalsCommandResultMessage(
          context: context,
          executionResults: [executionResult],
        );
        if (directMessage != null) {
          _finalizeInterceptedMessage(notifier, directMessage);
          _saveMessagesForCurrentDate();
          return true;
        }
      }

      final fallbackRecalculationCommand =
          AppAgentService.buildMacroRecalculationCommandFromContext(
        originalUserMessage,
        conversationContext,
        rawJson: responseContent,
      );
      if (fallbackRecalculationCommand != null) {
        AppAgentService.logAgentDebug('fallback_macro_recalc_from_context', {
          'userMessage': originalUserMessage,
          'conversationContext':
              AppAgentService.debugPreview(conversationContext),
        });
        final executionResult = await AppAgentService.executeCommand(
          fallbackRecalculationCommand,
          context,
        );
        final directMessage =
            AppAgentService.buildMacroGoalsCommandResultMessage(
          context: context,
          executionResults: [executionResult],
        );
        if (directMessage != null) {
          _finalizeInterceptedMessage(notifier, directMessage);
          _saveMessagesForCurrentDate();
          return true;
        }
      }

      if (AppAgentCommand.containsCommandCandidate(responseContent) &&
          AppAgentService.isDietGenerationRequest(originalUserMessage)) {
        final executionResults = <AppAgentExecutionResult>[];
        final inferredPreferencesCommand =
            AppAgentService.buildDietPreferenceUpdateFromUserMessage(
          originalUserMessage,
          rawJson: responseContent,
        );

        var requestedMealsPerDay =
            inferredPreferencesCommand?.arguments['mealsPerDay'];
        if (inferredPreferencesCommand != null) {
          final inferredResult = await AppAgentService.executeCommand(
            inferredPreferencesCommand,
            context,
          );
          executionResults.add(inferredResult);
        }

        final generateCommand = AppAgentCommand(
          name: AppAgentService.generateNewDietPlan,
          arguments: <String, dynamic>{
            if (requestedMealsPerDay != null)
              'mealsPerDay': requestedMealsPerDay,
          },
          rawJson: responseContent,
        );

        if (AppAgentService.shouldAskDietPersonalizationBeforeGeneration(
          generateCommand,
          originalUserMessage,
          context,
        )) {
          _finalizeInterceptedMessage(
            notifier,
            AppAgentService.buildDietPersonalizationQuestion(context),
          );
          _saveMessagesForCurrentDate();
          return true;
        }

        final generateResult = await AppAgentService.executeCommand(
          generateCommand,
          context,
        );
        executionResults.add(generateResult);

        final dietGeneratedMessage =
            AppAgentService.buildDietGeneratedCommandResultMessage(
          context: context,
          executionResults: executionResults,
        );
        _finalizeInterceptedMessage(
          notifier,
          dietGeneratedMessage ??
              AppLocalizations.of(context).translate(
                'agent_command_invalid_response',
              ),
        );
        _saveMessagesForCurrentDate();
        return true;
      }

      final fallbackMessage = priorExecutionResults == null
          ? null
          : AppAgentService.buildCreditExhaustedFallbackMessage(
              context: context,
              executionResults: priorExecutionResults,
              responseContent: responseContent,
            );
      if (fallbackMessage != null && fallbackMessage.trim().isNotEmpty) {
        AppAgentService.logAgentDebug('fallback_credit_exhausted', {
          'messagePreview': AppAgentService.debugPreview(fallbackMessage),
        });
        _finalizeInterceptedMessage(notifier, fallbackMessage);
        return true;
      }

      final visibleContent = initialVisibleContent;
      if (visibleContent.isEmpty) {
        final commandResultFallback = priorExecutionResults == null
            ? null
            : AppAgentService.buildCommandResultFallbackMessage(
                context: context,
                executionResults: priorExecutionResults,
                originalUserMessage: originalUserMessage,
              );
        if (commandResultFallback != null &&
            commandResultFallback.trim().isNotEmpty) {
          AppAgentService.logAgentDebug('fallback_command_result', {
            'messagePreview':
                AppAgentService.debugPreview(commandResultFallback),
            'priorCommandNames': priorExecutionResults
                ?.map((result) => result.commandName)
                .toList(),
          });
          _finalizeInterceptedMessage(notifier, commandResultFallback);
          _saveMessagesForCurrentDate();
          return true;
        }

        final macroAdviceFallback =
            AppAgentService.buildMacroTargetAdviceFallbackMessage(
          context: context,
          userMessage: originalUserMessage,
        );
        if (macroAdviceFallback != null &&
            macroAdviceFallback.trim().isNotEmpty) {
          AppAgentService.logAgentDebug('fallback_macro_advice', {
            'messagePreview': AppAgentService.debugPreview(macroAdviceFallback),
          });
          _finalizeInterceptedMessage(notifier, macroAdviceFallback);
          _saveMessagesForCurrentDate();
          return true;
        }
      }
      return false;
    }

    if (_agenticCommandExecutions >= _maxAgenticCommandExecutions) {
      final fallbackMessage =
          AppLocalizations.of(context).translate('agent_command_limit_reached');
      _finalizeInterceptedMessage(notifier, fallbackMessage);
      return true;
    }

    _agenticCommandExecutions++;

    final pendingAction = AppAgentPendingAction.tryParse(conversationContext);
    final shouldUseMacroRecalculationFromContext =
        AppAgentService.shouldTreatAsMacroRecalculationApproval(
      originalUserMessage,
      conversationContext,
    );
    final firstCommandName = commandBatch.commands.isNotEmpty &&
            shouldUseMacroRecalculationFromContext &&
            AppAgentService.shouldRedirectDietCommandToMacroRecalculation(
              commandBatch.commands.first,
              originalUserMessage,
              conversationContext,
            )
        ? AppAgentService.recalculateNutritionGoals
        : commandBatch.commands.first.name;
    final loadingMessage = commandBatch.commands.length == 1
        ? AppAgentService.buildLoadingMessage(
            context,
            firstCommandName,
          )
        : AppLocalizations.of(context).translate('agent_loading_generic');
    notifier.updateMessage(commandBatch.rawJson,
        displayContent: loadingMessage);
    notifyListeners();

    try {
      final executionResults = <AppAgentExecutionResult>[];
      var appliedInferredDietPreferences = false;
      var redirectedDietCommandToMacroRecalculation = false;
      final batchAlreadyGeneratesDiet = commandBatch.commands.any(
        (command) => command.name == AppAgentService.generateNewDietPlan,
      );
      for (final rawCommand in commandBatch.commands) {
        var command = AppAgentService.normalizeDietPreferenceApprovalCommand(
          rawCommand,
          originalUserMessage,
        );

        final inferredPreferencesCommand =
            AppAgentService.buildDietPreferenceUpdateFromUserMessage(
          originalUserMessage,
          rawJson: command.rawJson,
        );
        if (command.name == AppAgentService.updateDietGenerationPreferences &&
            inferredPreferencesCommand != null &&
            command.arguments.isNotEmpty) {
          command = AppAgentCommand(
            name: command.name,
            arguments: <String, dynamic>{
              ...inferredPreferencesCommand.arguments,
              ...command.arguments,
            },
            rawJson: command.rawJson,
          );
        }
        final inferredPreferencesFromMessage =
            command.name == AppAgentService.updateDietGenerationPreferences &&
                command.arguments.isEmpty &&
                inferredPreferencesCommand != null;
        if (inferredPreferencesFromMessage) {
          command = inferredPreferencesCommand;
        }

        final isApprovedPendingAction =
            pendingAction?.matchesCommand(command) == true;
        if (isApprovedPendingAction) {
          command = pendingAction!.toExecutionCommand(rawJson: command.rawJson);
        }

        if (shouldUseMacroRecalculationFromContext &&
            AppAgentService.shouldRedirectDietCommandToMacroRecalculation(
              command,
              originalUserMessage,
              conversationContext,
            )) {
          if (redirectedDietCommandToMacroRecalculation) {
            continue;
          }
          command = AppAgentCommand(
            name: AppAgentService.recalculateNutritionGoals,
            arguments: const {},
            rawJson: command.rawJson,
          );
          redirectedDietCommandToMacroRecalculation = true;
        }

        if (AppAgentService.shouldAskDietPersonalizationQuestion(
          command,
          originalUserMessage,
        )) {
          _finalizeInterceptedMessage(
            notifier,
            AppAgentService.buildDietPersonalizationQuestion(context),
          );
          _saveMessagesForCurrentDate();
          return true;
        }

        if (AppAgentService.shouldAskDietPersonalizationBeforeGeneration(
          command,
          originalUserMessage,
          context,
        )) {
          _finalizeInterceptedMessage(
            notifier,
            AppAgentService.buildDietPersonalizationQuestion(context),
          );
          _saveMessagesForCurrentDate();
          return true;
        }

        if (command.name == AppAgentService.generateNewDietPlan &&
            inferredPreferencesCommand != null &&
            !appliedInferredDietPreferences) {
          final inferredResult = await AppAgentService.executeCommand(
            inferredPreferencesCommand,
            context,
          );
          executionResults.add(inferredResult);
          appliedInferredDietPreferences = true;
        }

        if (AppAgentService.shouldBlockAmbiguousGoalMutation(
          command,
          originalUserMessage,
          approvedPendingAction: isApprovedPendingAction ? pendingAction : null,
        )) {
          executionResults.add(
            AppAgentService.buildBlockedGoalMutationResult(command),
          );
          continue;
        }

        if (AppAgentService.shouldSkipCommand(command)) {
          AppAgentService.logAgentDebug('command_skipped', {
            'name': command.name,
            'arguments': command.arguments,
          });
          continue;
        }

        final executionResult =
            await AppAgentService.executeCommand(command, context);
        executionResults.add(executionResult);
        if (command.name == AppAgentService.updateDietGenerationPreferences &&
            executionResult.success) {
          appliedInferredDietPreferences = true;
        }

        if (inferredPreferencesFromMessage &&
            executionResult.success &&
            !batchAlreadyGeneratesDiet &&
            AppAgentService.isDietGenerationRequest(originalUserMessage)) {
          final mealsPerDay = command.arguments['mealsPerDay'];
          final generateArguments = <String, dynamic>{
            if (mealsPerDay != null) 'mealsPerDay': mealsPerDay,
          };
          final generateResult = await AppAgentService.executeCommand(
            AppAgentCommand(
              name: AppAgentService.generateNewDietPlan,
              arguments: generateArguments,
              rawJson: command.rawJson,
            ),
            context,
          );
          executionResults.add(generateResult);
        }
      }

      if (executionResults.isEmpty) {
        final fallbackKey = toolType == macroGoalsToolType
            ? 'agent_macro_scope_fallback'
            : 'agent_command_invalid_response';
        _finalizeInterceptedMessage(
          notifier,
          AppLocalizations.of(context).translate(fallbackKey),
        );
        return true;
      }

      final directCommandMessage =
          AppAgentService.buildCommandResultFallbackMessage(
        context: context,
        executionResults: executionResults,
        originalUserMessage: originalUserMessage,
      );
      if (directCommandMessage != null &&
          directCommandMessage.trim().isNotEmpty) {
        AppAgentService.logAgentDebug('direct_command_result_message', {
          'messagePreview': AppAgentService.debugPreview(directCommandMessage),
          'commandNames':
              executionResults.map((result) => result.commandName).toList(),
        });
        _finalizeInterceptedMessage(notifier, directCommandMessage);
        _saveMessagesForCurrentDate();
        return true;
      }

      if (toolType == macroGoalsToolType &&
          executionResults.any((result) => result.success)) {
        final directMessage =
            AppAgentService.buildMacroGoalsCommandResultMessage(
          context: context,
          executionResults: executionResults,
        );
        if (directMessage != null) {
          _finalizeInterceptedMessage(notifier, directMessage);
          _saveMessagesForCurrentDate();
          return true;
        }
      }

      final dietGeneratedMessage =
          AppAgentService.buildDietGeneratedCommandResultMessage(
        context: context,
        executionResults: executionResults,
      );
      if (dietGeneratedMessage != null) {
        _finalizeInterceptedMessage(notifier, dietGeneratedMessage);
        _saveMessagesForCurrentDate();
        return true;
      }

      final followUpPrompt = await AppAgentService.buildFollowUpPrompt(
        originalUserMessage: originalUserMessage,
        executionResults: executionResults,
        context: context,
        conversationContext: conversationContext,
      );
      AppAgentService.logAgentDebug('follow_up_prompt_start', {
        'executionResults':
            executionResults.map((result) => result.toJson()).toList(),
        'promptLength': followUpPrompt.length,
        'promptPreview': AppAgentService.debugPreview(followUpPrompt),
      });

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
        autoRegisterFoods: _shouldAutoRegisterFoods,
        displayContentBuilder: (rawContent) => _buildTextDisplayContent(
          rawContent,
          autoRegisterFoods: _shouldAutoRegisterFoods,
        ),
        interceptFinalResponse: (responseContent, followUpNotifier) =>
            _handleAgenticCommandResponse(
          responseContent: responseContent,
          notifier: followUpNotifier,
          originalUserMessage: originalUserMessage,
          conversationContext: conversationContext,
          context: context,
          languageCode: languageCode,
          quality: quality,
          provider: provider,
          agentType: agentType,
          userId: userId,
          mealTypesForAI: mealTypesForAI,
          toolDataForHistory: toolDataForHistory,
          priorExecutionResults: executionResults,
        ),
        onStreamComplete: () {
          _agenticCommandExecutions = 0;
          unawaited(_saveMessagesForCurrentDate(syncNow: true));
        },
      );
    } catch (e) {
      print(
          '❌ NutritionAssistantController - Erro ao executar comando agêntico: $e');
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
    final displayContent = _buildTextDisplayContent(
      finalContent,
      autoRegisterFoods: _shouldAutoRegisterFoods,
    );
    notifier.updateMessage(finalContent, displayContent: displayContent);
    notifier.setStreaming(false);
    _isLoading = false;
    _agenticCommandExecutions = 0;

    final streamingIndex = _streamingMessageIndex;
    if (streamingIndex != null &&
        streamingIndex < _messages.length &&
        _messages[streamingIndex]['notifier'] == notifier) {
      final finalizedMessage =
          Map<String, dynamic>.from(_messages[streamingIndex]);
      finalizedMessage
        ..remove('notifier')
        ..['isUser'] = false
        ..['message'] = finalContent;
      _messages[streamingIndex] = finalizedMessage;
    }

    notifyListeners();
    unawaited(_saveMessagesForCurrentDate(syncNow: true));
  }

  /// Processa imagem para a IA
  Future<void> _processImageForAI(
      Uint8List imageBytes, String prompt, BuildContext context) async {
    if (_messageNotifier == null || _streamingMessageIndex == null) {
      print(
          '❌ NutritionAssistantController - _messageNotifier ou _streamingMessageIndex nulo antes de processar imagem.');
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
            '👤 NutritionAssistantController - Usuário logado: ${authService.currentUser!.name}, ID: $userId');
      } else {
        print(
            '⚠️ NutritionAssistantController - Nenhum usuário autenticado, usando ID vazio');
      }

      // Para imagens, usar modelo específico e agent free-image
      String quality =
          'google/gemini-2.5-flash-lite'; // Modelo específico para análise de imagem e quantidade dos alimentos
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
            '📝 NutritionAssistantController: Passando toolDataJson (rawInitialPromptJson) para histórico (imagem)');
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
        autoRegisterFoods: _shouldAutoRegisterFoods,
        onStreamComplete: () {
          // Salvar mensagens após cada resposta da IA
          unawaited(_saveMessagesForCurrentDate(syncNow: true));
        },
      );
    } catch (e) {
      print(
          '❌ NutritionAssistantController - Exceção ao preparar/iniciar stream de imagem: $e');
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
  void handleVoiceButtonPressed(
    int messageIndex,
    BuildContext context, {
    String? overrideText,
  }) {
    if (messageIndex < 0 || messageIndex >= _messages.length) return;

    // Verifica se é uma mensagem do usuário
    if (_messages[messageIndex]['isUser'] == true) return;

    // Obtém o texto da mensagem (ou usa override quando fornecido,
    // por exemplo quando ha um card de alimentos e queremos ler so
    // o conteudo visivel, nao o JSON cru).
    String messageText = '';
    if (overrideText != null && overrideText.trim().isNotEmpty) {
      messageText = overrideText;
    } else if (_messages[messageIndex].containsKey('message')) {
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
    _disposed = true;
    // Salvar mensagens da data atual antes de destruir
    unawaited(flushDailyChatState());

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
      _addCreditExhaustedAssistantMessage(context);
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
                    'Assista a um anúncio rápido e ganhe 7 créditos grátis para continuar agora mesmo.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Botão de anúncio (em destaque — caminho gratuito)
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      RewardAdDialog.showRewardedAd(_lastContext ?? context,
                          onRewardEarned: removeCreditExhaustedMessages);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black87,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 24),
                      minimumSize: const Size(double.infinity, 0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_arrow, size: 20),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Assistir anúncio • +7 créditos grátis',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Botão PRO (caminho premium — discreto)
                  OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SubscriptionScreen(),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                          color: Colors.white.withOpacity(0.6), width: 1.5),
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.workspace_premium, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Ou obter PRO ilimitado',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),

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

    // Se a interação silenciosa veio com imagem (ex: câmera), exibir bolha
    // do usuário com a foto. O prompt textual segue oculto.
    if (imageBytes != null) {
      _messages.add({
        'isUser': true,
        'message': '',
        'hasImage': true,
        'imageBytes': imageBytes,
        'timestamp': DateTime.now(),
      });
      _userSentMessage = true;
    }

    // Adicionar a mensagem da IA
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
          ? "Analyze this image and explain what you see."
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
            '⚠️ NutritionAssistantController (processSilently) - Não foi possível obter tipos de refeição: $e');
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
              '📝 NutritionAssistantController (processSilently): Passando toolDataJson (rawInitialPromptJson) para histórico (texto)');
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
          autoRegisterFoods: _shouldAutoRegisterFoods,
          onStreamComplete: () {
            // Salvar mensagens após cada resposta da IA
            unawaited(_saveMessagesForCurrentDate(syncNow: true));
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
            '❌ NutritionAssistantController - Erro ao processar texto silenciosamente: $e');
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

  /// Edita uma mensagem do usuário e gera novamente a resposta a partir dela.
  Future<bool> editUserMessageAndRegenerate(
    int messageIndex,
    String newMessage,
    BuildContext context,
  ) async {
    if (messageIndex < 0 || messageIndex >= _messages.length) return true;
    if (_messages[messageIndex]['isUser'] != true) return true;
    if (_isLoading) return false;

    final originalMessages = _messages
        .map((message) => Map<String, dynamic>.from(message))
        .toList(growable: true);
    final originalMessage = _messages[messageIndex];
    final hasImage = originalMessage['hasImage'] == true;
    final trimmedMessage = newMessage.trim();

    if (trimmedMessage.isEmpty && !hasImage) return false;

    final updatedMessage = Map<String, dynamic>.from(originalMessage);
    updatedMessage['message'] = trimmedMessage;
    updatedMessage['timestamp'] =
        originalMessage['timestamp'] ?? DateTime.now();

    _messages[messageIndex] = updatedMessage;
    if (messageIndex + 1 < _messages.length) {
      _messages.removeRange(messageIndex + 1, _messages.length);
    }

    notifyListeners();

    final hadEnoughCredits = await regenerateLastResponse(context);
    if (!hadEnoughCredits) {
      _messages = originalMessages;
      _isLoading = false;
      notifyListeners();
      unawaited(_saveMessagesForCurrentDate());
      return false;
    }

    _userSentMessage = true;
    _lastContext = context;
    unawaited(_saveMessagesForCurrentDate());
    print(
        '✏️ NutritionAssistantController - Mensagem do usuário editada no índice $messageIndex');
    return true;
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

    _ensureMessageIdentityAndLinks(_messages);
    final previousAssistantMessages = _messages
        .skip(lastUserMessageIndex + 1)
        .where((message) => message['isUser'] != true)
        .map((message) => Map<String, dynamic>.from(message))
        .toList(growable: false);
    final previousResponse = previousAssistantMessages.isEmpty
        ? null
        : previousAssistantMessages.first;
    final replacesMealCard = previousAssistantMessages.any((message) {
      if (message['replaceExistingMeals'] == true) return true;
      final snapshots = message['mealSnapshots'];
      if (snapshots is List && snapshots.isNotEmpty) return true;
      final content = message['message'];
      return content is String && FoodJsonParser.hasFoodJsonSignal(content);
    });

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
      _addCreditExhaustedAssistantMessage(context);
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
                    'Assista a um anúncio rápido e ganhe 7 créditos grátis para continuar agora mesmo.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Botão de anúncio (em destaque — caminho gratuito)
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      RewardAdDialog.showRewardedAd(_lastContext ?? context,
                          onRewardEarned: removeCreditExhaustedMessages);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black87,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 24),
                      minimumSize: const Size(double.infinity, 0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_arrow, size: 20),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Assistir anúncio • +7 créditos grátis',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Botão PRO (caminho premium — discreto)
                  OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SubscriptionScreen(),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                          color: Colors.white.withOpacity(0.6), width: 1.5),
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.workspace_premium, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Ou obter PRO ilimitado',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),

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

    // Remover todas as partes da resposta anterior deste turno. O placeholder
    // abaixo reutiliza a identidade do card, permitindo que o diario troque a
    // refeicao existente em vez de somar uma nova.
    if (_messages.length > lastUserMessageIndex + 1) {
      _messages.removeRange(lastUserMessageIndex + 1, _messages.length);
    }

    // Criar um novo notificador para a mensagem que vamos receber
    _messageNotifier = MessageNotifier();

    // Adicionar uma nova resposta vazia da IA, mantendo id, turno e horario da
    // resposta substituida. mealSnapshots sai temporariamente para o JSON novo
    // ser realmente processado quando o stream terminar.
    final userRecord = _messages[lastUserMessageIndex];
    final assistantTimestamp = previousResponse == null
        ? DateTime.now()
        : _messageTimestamp(previousResponse);
    final replacementRevision =
        (previousResponse?['regenerationRevision'] as int? ?? 0) + 1;
    final replacementMessage = previousResponse == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(previousResponse);
    replacementMessage
      ..remove('message')
      ..remove('mealSnapshots')
      ..remove('error')
      ..remove('streaming')
      ..remove('recoveredLegacyMealCard')
      ..remove('notifier')
      ..['isUser'] = false
      ..['notifier'] = _messageNotifier
      ..['id'] = previousResponse?['id'] ??
          _defaultMessageId(false, assistantTimestamp)
      ..['turnId'] = userRecord['turnId']
      ..['replyToMessageId'] = userRecord['id']
      ..['timestamp'] = assistantTimestamp
      ..['regenerationRevision'] = replacementRevision;
    if (replacesMealCard) {
      replacementMessage['replaceExistingMeals'] = true;
    } else {
      replacementMessage.remove('replaceExistingMeals');
    }
    _messages.add(replacementMessage);

    _isLoading = true;
    notifyListeners();

    final aiMessageIndex = _messages.length - 1;
    _streamingMessageIndex = aiMessageIndex;

    // Processar a mensagem para obter resposta da IA
    if (hasImage && imageBytes != null) {
      // Se a mensagem contém uma imagem, processe a imagem
      final prompt = userMessage.isEmpty
          ? "Analyze this image and explain what you see."
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
          '💬 NutritionAssistantController: Resposta histórica da ferramenta adicionada às mensagens.');
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
          '💬 NutritionAssistantController: Resposta histórica da ferramenta substituiu notifier vazio.');
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

    if (_messages.isEmpty) {
      _emptyChatDeletionPending = true;
    }

    notifyListeners();
    unawaited(_saveMessagesForCurrentDate());
    print(
        '🗑️ NutritionAssistantController - Par de mensagens deletado no índice $messageIndex');
  }

  /// Remove pares de mensagem apenas quando ha um tombstone de exclusao.
  /// Ausencia temporaria da refeicao nunca pode apagar a conversa: o sync do
  /// diario e o sync do chat sao independentes e podem concluir em momentos
  /// diferentes.
  Future<bool> pruneOrphanFoodDiaryMessagePairs({
    required bool Function(String messageId) hasMealsForMessageId,
    required bool Function(String messageId) isChatMealDeleted,
    Duration gracePeriod = const Duration(seconds: 15),
    DateTime? now,
    bool syncNow = true,
  }) async {
    if (_messages.isEmpty) return false;

    final indexesToRemove = <int>{};
    final orphanMessageIds = <String>[];

    for (var i = 0; i < _messages.length; i++) {
      final message = _messages[i];
      if (message['isUser'] == true || message['notifier'] != null) {
        continue;
      }

      final text = _messageText(message);
      if (!FoodJsonParser.containsFoodJson(text)) {
        continue;
      }

      final timestamp = message['timestamp'];
      if (timestamp is! DateTime) {
        continue;
      }

      final storedMessageId = message['id']?.toString().trim();
      final messageId = storedMessageId == null || storedMessageId.isEmpty
          ? 'msg-${timestamp.microsecondsSinceEpoch}'
          : storedMessageId;
      if (hasMealsForMessageId(messageId)) {
        continue;
      }

      if (!isChatMealDeleted(messageId)) continue;

      indexesToRemove.add(i);
      orphanMessageIds.add(messageId);
      if (i > 0 && _messages[i - 1]['isUser'] == true) {
        indexesToRemove.add(i - 1);
      }
    }

    if (indexesToRemove.isEmpty) {
      return false;
    }

    final sortedIndexes = indexesToRemove.toList()
      ..sort((a, b) => b.compareTo(a));
    for (final index in sortedIndexes) {
      if (index >= 0 && index < _messages.length) {
        _messages.removeAt(index);
      }
    }

    if (_messages.isEmpty) {
      _emptyChatDeletionPending = true;
    }

    _logDailyChatTrace('prune_orphan_food_messages', {
      'date': _formatDateKey(_selectedDate),
      'scope': storageScope,
      'removedIndexes': sortedIndexes.length,
      'orphanMessageIds': orphanMessageIds,
      ..._summarizeMessages(_messages),
    });

    notifyListeners();
    await _saveMessagesForCurrentDate(syncNow: syncNow);
    return true;
  }

  /// Formata a data para usar como chave de armazenamento (yyyy-MM-dd)
  String _formatDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _buildStorageKey(String dateKey) {
    return 'nutrition_chat_${storageScope}_$dateKey';
  }

  /// Muda a data selecionada e carrega as mensagens dessa data
  Future<void> changeSelectedDate(DateTime newDate) async {
    final normalizedDate = DateTime(newDate.year, newDate.month, newDate.day);
    if (_formatDateKey(normalizedDate) == _formatDateKey(_selectedDate)) {
      return;
    }

    print(
        '📅 NutritionAssistantController - Mudando data de ${_formatDateKey(_selectedDate)} para ${_formatDateKey(normalizedDate)}');

    // A persistência captura a data e as mensagens atuais antes do primeiro
    // await. Ela pode continuar em paralelo sem segurar o primeiro frame da
    // nova data.
    final savePreviousDate = _saveMessagesForCurrentDate();
    final requestId = ++_dateChangeRequestId;

    // Atualizar a interface imediatamente. Em dias com conversa grande,
    // esperar o SharedPreferences aqui fazia a data anterior permanecer
    // visível enquanto todo o JSON era salvo.
    _selectedDate = normalizedDate;
    _messages = [];
    _currentDateHadStoredChatState = false;
    _emptyChatDeletionPending = false;
    _isLoadingMessages = true;
    notifyListeners();

    // Reserva alguns frames para a UI desenhar o indicador antes de ler e
    // decodificar a conversa. Caches locais pequenos podem concluir entre dois
    // frames e, sem isso, o estado de loading nunca chega a ficar visível.
    await Future<void>.delayed(_dateChangeLoadingLead);
    if (!_isCurrentDateLoad(normalizedDate, requestId)) {
      await savePreviousDate;
      return;
    }

    // O carregamento da nova data também começa sem esperar a gravação da
    // anterior, pois cada operação usa uma chave independente.
    final loadSelectedDate = _loadMessagesForDate(
      normalizedDate,
      showLoading: true,
      dateChangeRequestId: requestId,
    );

    await Future.wait([savePreviousDate, loadSelectedDate]);
  }

  /// Salva as mensagens da data atual
  Future<void> flushDailyChatState() async {
    await _saveMessagesForCurrentDate(syncNow: true);
  }

  Future<void> _saveMessagesForCurrentDate({bool syncNow = false}) async {
    final dateKey = _formatDateKey(_selectedDate);
    final storageKey = _buildStorageKey(dateKey);
    if (_messages.isEmpty) {
      if (!_currentDateHadStoredChatState && !_emptyChatDeletionPending) {
        _logDailyChatTrace('cache_save_skip_empty_untracked', {
          'date': dateKey,
          'scope': storageScope,
          'toolType': toolType,
          'key': storageKey,
        });
        return;
      }

      final nowIso = DateTime.now().toUtc().toIso8601String();
      final saved = await _storageService.saveData(storageKey, {
        'messages': <Map<String, dynamic>>[],
        'updatedAt': nowIso,
        'deletedAt': nowIso,
        'deleted': true,
      });
      if (syncNow) {
        await DailyChatSyncService.instance.syncDeletedDate(dateKey);
      } else {
        DailyChatSyncService.instance.scheduleSync(dateKey: dateKey);
      }
      if (_formatDateKey(_selectedDate) == dateKey) {
        _currentDateHadStoredChatState = true;
        _emptyChatDeletionPending = false;
      }
      _logDailyChatTrace('cache_save_skip_empty', {
        'date': dateKey,
        'scope': storageScope,
        'toolType': toolType,
        'key': storageKey,
        'savedTombstone': saved,
      });
      print(
          '💾 NutritionAssistantController - Chat vazio marcado como removido para data $dateKey (saved=$saved)');
      return;
    }

    try {
      // Converter mensagens para formato serializável
      final messagesForStorage = _messages
          .where((message) => !_isRestoredAssistantPlaceholder(message))
          .toList(growable: false);
      _ensureMessageIdentityAndLinks(messagesForStorage);
      final droppedPlaceholders = _messages.length - messagesForStorage.length;
      if (droppedPlaceholders > 0) {
        _logDailyChatTrace('cache_save_dropped_empty_assistant', {
          'date': dateKey,
          'scope': storageScope,
          'toolType': toolType,
          'key': storageKey,
          'dropped': droppedPlaceholders,
          'remaining': messagesForStorage.length,
        });
      }

      final messagesData = messagesForStorage.map((msg) {
        final data = <String, dynamic>{
          'isUser': msg['isUser'],
          'timestamp':
              msg['timestamp']?.toString() ?? DateTime.now().toString(),
        };

        if (msg.containsKey('message')) {
          data['message'] = msg['message'];
        }

        for (final metadataKey in const [
          'id',
          'turnId',
          'replyToMessageId',
          'mealSnapshots',
          'sourceUserMessage',
          'sourceUserMessageId',
          'sourceUserTimestamp',
          'sourceUserHadImage',
          'sourceUserReconstructed',
          'restoredFromMealSnapshot',
          'recoveredLegacyMealCard',
        ]) {
          if (msg.containsKey(metadataKey) && msg[metadataKey] != null) {
            data[metadataKey] = msg[metadataKey];
          }
        }

        if (msg.containsKey('hasImage') && msg['hasImage'] == true) {
          data['hasImage'] = true;
          final imageBytes = msg['imageBytes'];
          if (imageBytes is Uint8List && imageBytes.isNotEmpty) {
            data['imageData'] = base64Encode(imageBytes);
            data['imageMimeType'] = msg['imageMimeType'] ?? 'image/jpeg';
          } else {
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

      _logDailyChatTrace('cache_save_start', {
        'date': dateKey,
        'scope': storageScope,
        'toolType': toolType,
        'key': storageKey,
        ..._summarizeMessages(messagesForStorage),
      });
      final saved = await _storageService.saveData(storageKey, {
        'messages': messagesData,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      });
      print(
          '✅ NutritionAssistantController - Mensagens salvas para data $dateKey: ${messagesData.length} mensagens (saved=$saved)');
      _logDailyChatTrace('cache_save_done', {
        'date': dateKey,
        'scope': storageScope,
        'toolType': toolType,
        'key': storageKey,
        'saved': saved,
        ..._summarizeStoredChatData({'messages': messagesData}),
      });
      // Enviar para o servidor (debounced) para o chat sobreviver a
      // limpeza de dados/reinstalação/troca de aparelho.
      DailyChatSyncService.instance.scheduleSync(dateKey: dateKey);
      if (syncNow) {
        await DailyChatSyncService.instance.syncPendingIfNeeded();
      }
      if (_formatDateKey(_selectedDate) == dateKey) {
        _currentDateHadStoredChatState = true;
        _emptyChatDeletionPending = false;
      }
    } catch (e) {
      print(
          '❌ NutritionAssistantController - Erro ao salvar mensagens para data $dateKey: $e');
    }
  }

  /// Carrega as mensagens de uma data específica
  Future<void> _loadMessagesForDate(
    DateTime date, {
    bool showLoading = false,
    int? dateChangeRequestId,
  }) async {
    final stopwatch = Stopwatch()..start();
    if (showLoading) {
      _isLoadingMessages = true;
      if (!_disposed) {
        notifyListeners();
      }
    }
    try {
      final dateKey = _formatDateKey(date);
      final storageKey = _buildStorageKey(dateKey);
      _currentDateHadStoredChatState = false;
      _emptyChatDeletionPending = false;
      print(
          '[CHAT_LOAD_PERF] load_messages_start date=$dateKey scope=$storageScope showLoading=$showLoading');
      _logDailyChatTrace('load_start', {
        'date': dateKey,
        'scope': storageScope,
        'toolType': toolType,
        'key': storageKey,
        'showLoading': showLoading,
      });

      var data = await _storageService.getData(storageKey);
      if (!_isCurrentDateLoad(date, dateChangeRequestId)) return;
      print(
          '[CHAT_LOAD_PERF] primary_cache_read elapsedMs=${stopwatch.elapsedMilliseconds} hasMessages=${_hasMessages(data)}');
      _logDailyChatTrace('cache_read_done', {
        'date': dateKey,
        'scope': storageScope,
        'toolType': toolType,
        'key': storageKey,
        'elapsedMs': stopwatch.elapsedMilliseconds,
        'hasMessages': _hasMessages(data),
        ..._summarizeStoredChatData(data),
      });

      if (_isDeletedChatMarker(data)) {
        print(
            '📭 NutritionAssistantController - Chat removido localmente para data $dateKey');
        _messages = [];
        _currentDateHadStoredChatState = true;
        _logDailyChatTrace('load_deleted_marker', {
          'date': dateKey,
          'scope': storageScope,
          'toolType': toolType,
          'elapsedMs': stopwatch.elapsedMilliseconds,
        });
        return;
      }

      // Fallback de "scope": a conversa pode ter sido salva sob outro escopo
      // de armazenamento (ex.: 'guest', gravado antes de o login terminar de
      // restaurar a sessão, ou um id de usuário diferente). Sem isso, um dia
      // com refeições registradas aparece com o chat vazio. Procuramos a mesma
      // data em outros escopos e reaproveitamos a conversa existente.
      if (!_hasMessages(data)) {
        final fallback = await _findMessagesInOtherScopes(dateKey, storageKey);
        if (!_isCurrentDateLoad(date, dateChangeRequestId)) return;
        if (fallback != null) {
          data = fallback;
          print(
              '♻️ NutritionAssistantController - Conversa recuperada de outro escopo para data $dateKey');
          _logDailyChatTrace('scope_fallback_restored', {
            'date': dateKey,
            'scope': storageScope,
            'toolType': toolType,
            'elapsedMs': stopwatch.elapsedMilliseconds,
            ..._summarizeStoredChatData(data),
          });
        }
      }

      if (!_hasMessages(data)) {
        if (!_isLoadingMessages) {
          _isLoadingMessages = true;
          if (!_disposed) {
            notifyListeners();
          }
        }
        _logDailyChatTrace('server_restore_start', {
          'date': dateKey,
          'scope': storageScope,
          'toolType': toolType,
          'elapsedMs': stopwatch.elapsedMilliseconds,
        });
        final restored = await DailyChatSyncService.instance
            .restoreDateFromServer(dateKey, scope: storageScope);
        if (!_isCurrentDateLoad(date, dateChangeRequestId)) return;
        _logDailyChatTrace('server_restore_done', {
          'date': dateKey,
          'scope': storageScope,
          'toolType': toolType,
          'elapsedMs': stopwatch.elapsedMilliseconds,
          'restored': restored,
        });
        if (restored) {
          data = await _storageService.getData(storageKey);
          if (!_isCurrentDateLoad(date, dateChangeRequestId)) return;
          _logDailyChatTrace('server_restored_cache_read', {
            'date': dateKey,
            'scope': storageScope,
            'toolType': toolType,
            'key': storageKey,
            'elapsedMs': stopwatch.elapsedMilliseconds,
            'hasMessages': _hasMessages(data),
            ..._summarizeStoredChatData(data),
          });
        }
      }

      if (!_hasMessages(data)) {
        print(
            '📭 NutritionAssistantController - Nenhuma mensagem encontrada para data $dateKey');
        _messages = [];
        _logDailyChatTrace('load_empty', {
          'date': dateKey,
          'scope': storageScope,
          'toolType': toolType,
          'elapsedMs': stopwatch.elapsedMilliseconds,
        });
        print(
            '[CHAT_LOAD_PERF] load_messages_empty elapsedMs=${stopwatch.elapsedMilliseconds} date=$dateKey');
        return;
      }

      final List<dynamic> messagesData = data!['messages'] ?? [];
      _currentDateHadStoredChatState = true;
      final restoredMessages = messagesData.map((msgData) {
        final msg = <String, dynamic>{
          'isUser': msgData['isUser'] ?? false,
          'timestamp': msgData['timestamp'] != null
              ? DateTime.parse(msgData['timestamp'])
              : DateTime.now(),
        };

        if (msgData.containsKey('message')) {
          msg['message'] = msgData['message'];
        }

        for (final metadataKey in const [
          'id',
          'turnId',
          'replyToMessageId',
          'mealSnapshots',
          'sourceUserMessage',
          'sourceUserMessageId',
          'sourceUserTimestamp',
          'sourceUserHadImage',
          'sourceUserReconstructed',
          'restoredFromMealSnapshot',
          'recoveredLegacyMealCard',
        ]) {
          if (msgData.containsKey(metadataKey) &&
              msgData[metadataKey] != null) {
            msg[metadataKey] = msgData[metadataKey];
          }
        }

        if (msgData['hasImage'] == true) {
          msg['hasImage'] = true;
          final imageData = msgData['imageData'];
          if (imageData is String && imageData.trim().isNotEmpty) {
            try {
              final normalizedImageData = imageData.contains(',')
                  ? imageData.substring(imageData.indexOf(',') + 1)
                  : imageData;
              msg['imageBytes'] = base64Decode(normalizedImageData);
              if (msgData['imageMimeType'] != null) {
                msg['imageMimeType'] = msgData['imageMimeType'];
              }
            } catch (e) {
              msg['hadImage'] = true;
              print(
                  '⚠️ NutritionAssistantController - Erro ao restaurar imagem do histórico: $e');
            }
          } else if (msgData['hadImage'] == true) {
            msg['hadImage'] = true;
          }
        } else if (msgData['hadImage'] == true) {
          msg['hadImage'] = true; // Histórico antigo sem bytes da imagem
        }

        return msg;
      }).toList();
      _messages = _sanitizeRestoredMessages(
        restoredMessages,
        source: 'dateLoad',
      );

      print(
          '✅ NutritionAssistantController - Mensagens carregadas para data $dateKey: ${_messages.length} mensagens');
      _logDailyChatTrace('load_done', {
        'date': dateKey,
        'scope': storageScope,
        'toolType': toolType,
        'elapsedMs': stopwatch.elapsedMilliseconds,
        ..._summarizeMessages(_messages),
      });
      print(
          '[CHAT_LOAD_PERF] load_messages_done elapsedMs=${stopwatch.elapsedMilliseconds} date=$dateKey count=${_messages.length}');
    } catch (e) {
      print(
          '❌ NutritionAssistantController - Erro ao carregar mensagens para data ${_formatDateKey(date)}: $e');
      if (_isCurrentDateLoad(date, dateChangeRequestId)) {
        _messages = [];
      }
    } finally {
      if (_isCurrentDateLoad(date, dateChangeRequestId)) {
        _isLoadingMessages = false;
      }
      if (!_disposed && _isCurrentDateLoad(date, dateChangeRequestId)) {
        notifyListeners();
      }
    }
  }

  bool _isCurrentDateLoad(DateTime date, int? requestId) {
    if (_disposed) return false;
    if (requestId != null && requestId != _dateChangeRequestId) {
      return false;
    }
    return _formatDateKey(date) == _formatDateKey(_selectedDate);
  }

  /// Verdadeiro se [data] contém uma lista de mensagens não vazia.
  bool _hasMessages(Map<String, dynamic>? data) {
    if (data == null) return false;
    final msgs = data['messages'];
    return msgs is List && msgs.isNotEmpty;
  }

  List<Map<String, dynamic>> _sanitizeRestoredMessages(
    List<Map<String, dynamic>> messages, {
    required String source,
  }) {
    var removed = 0;
    var clearedStreaming = 0;
    final sanitized = <Map<String, dynamic>>[];

    for (final message in messages) {
      if (_isRestoredAssistantPlaceholder(message)) {
        removed++;
        continue;
      }

      if (message['streaming'] == true) {
        sanitized.add({
          ...message,
          'streaming': false,
        });
        clearedStreaming++;
      } else {
        sanitized.add(message);
      }
    }

    if (removed > 0 || clearedStreaming > 0) {
      _logDailyChatTrace('restored_messages_sanitized', {
        'date': _formatDateKey(_selectedDate),
        'scope': storageScope,
        'toolType': toolType,
        'source': source,
        'removedEmptyAssistant': removed,
        'clearedStreaming': clearedStreaming,
        'remaining': sanitized.length,
      });
    }

    _ensureMessageIdentityAndLinks(sanitized);
    final withEmbeddedSources = _restoreEmbeddedSourceMessages(sanitized);
    _ensureMessageIdentityAndLinks(withEmbeddedSources);
    return withEmbeddedSources;
  }

  bool _isRestoredAssistantPlaceholder(Map<String, dynamic> message) {
    if (message['isUser'] == true) {
      return false;
    }

    final text = message['message'];
    final hasText = text is String && text.trim().isNotEmpty;
    final hasImage = message['hasImage'] == true || message['hadImage'] == true;
    final notifier = message['notifier'];
    final hasNotifierText =
        notifier is MessageNotifier && notifier.message.trim().isNotEmpty;
    final snapshots = message['mealSnapshots'];
    final hasMealSnapshots = snapshots is List && snapshots.isNotEmpty;

    return !hasText && !hasImage && !hasNotifierText && !hasMealSnapshots;
  }

  bool _isDeletedChatMarker(Map<String, dynamic>? data) {
    if (data == null) return false;
    final msgs = data['messages'];
    return data['deleted'] == true && msgs is List && msgs.isEmpty;
  }

  /// Procura mensagens da MESMA data salvas sob outro "scope" de armazenamento.
  ///
  /// Cobre o caso em que a conversa foi gravada como 'guest' (antes de o login
  /// restaurar a sessão) e agora é lida como 'user_<id>', ou vice-versa.
  /// Prefere o escopo 'guest' (dados pré-login do próprio dispositivo). Para
  /// não misturar dados entre contas distintas no mesmo aparelho, só recupera
  /// de um escopo de usuário quando o escopo atual é 'guest' e existe
  /// exatamente um candidato.
  Future<Map<String, dynamic>?> _findMessagesInOtherScopes(
      String dateKey, String currentKey) async {
    try {
      final allKeys = await _storageService.getAllKeys();
      final suffix = '_$dateKey';
      final siblings = allKeys
          .where((k) =>
              k != currentKey &&
              k.startsWith('nutrition_chat_') &&
              k.endsWith(suffix))
          .toList();
      _logDailyChatTrace('scope_fallback_scan', {
        'date': dateKey,
        'scope': storageScope,
        'currentKey': currentKey,
        'candidateKeys': siblings.length,
      });
      if (siblings.isEmpty) return null;

      // 1) Preferir 'guest' (dados pré-login do próprio usuário).
      const guestPrefix = 'nutrition_chat_guest';
      final guestKey = '${guestPrefix}_$dateKey';
      if (siblings.contains(guestKey)) {
        final data = await _storageService.getData(guestKey);
        if (_hasMessages(data)) {
          _logDailyChatTrace('scope_fallback_guest_hit', {
            'date': dateKey,
            'scope': storageScope,
            'fallbackKey': guestKey,
            ..._summarizeStoredChatData(data),
          });
          return data;
        }
      }

      // 2) Se o escopo atual é 'guest', tentar recuperar de um escopo de
      // usuário — mas apenas se houver exatamente um, para não escolher
      // arbitrariamente entre contas diferentes.
      if (currentKey == guestKey) {
        final userSiblings = siblings
            .where((k) => k.startsWith('nutrition_chat_user_'))
            .toList();
        if (userSiblings.length == 1) {
          final data = await _storageService.getData(userSiblings.first);
          if (_hasMessages(data)) {
            _logDailyChatTrace('scope_fallback_single_user_hit', {
              'date': dateKey,
              'scope': storageScope,
              'fallbackKey': userSiblings.first,
              ..._summarizeStoredChatData(data),
            });
            return data;
          }
        }
      }

      return null;
    } catch (e) {
      print(
          '⚠️ NutritionAssistantController - Erro ao procurar conversa em outros escopos: $e');
      return null;
    }
  }
}

/// Interface para acessar os métodos necessários do NutritionAssistantSpeechMixin
abstract class NutritionAssistantSpeechMixinRef {
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
