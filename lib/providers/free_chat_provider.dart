import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/user_app_state_service.dart';

/// Modelo para uma conversa livre
class FreeChatConversation {
  final String id;
  String title;
  final DateTime createdAt;
  DateTime lastUpdated;
  List<Map<String, dynamic>> messages;

  FreeChatConversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.lastUpdated,
    required this.messages,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'lastUpdated': lastUpdated.toIso8601String(),
      'messages': messages.map((m) {
        // Converter DateTime para String se necessário
        final Map<String, dynamic> msg = Map.from(m);
        if (msg['timestamp'] is DateTime) {
          msg['timestamp'] = (msg['timestamp'] as DateTime).toIso8601String();
        }
        return msg;
      }).toList(),
    };
  }

  factory FreeChatConversation.fromJson(Map<String, dynamic> json) {
    return FreeChatConversation(
      id: json['id'],
      title: json['title'],
      createdAt: DateTime.parse(json['createdAt']),
      lastUpdated: DateTime.parse(json['lastUpdated']),
      messages: (json['messages'] as List).map((m) {
        final Map<String, dynamic> msg = Map<String, dynamic>.from(m);
        // Converter String para DateTime se necessário
        if (msg['timestamp'] is String) {
          msg['timestamp'] = DateTime.parse(msg['timestamp']);
        }
        return msg;
      }).toList(),
    );
  }
}

/// Provider para gerenciar conversas livres
class FreeChatProvider extends ChangeNotifier {
  static const String _storageKey = 'free_chat_conversations';
  static const String _pendingSyncKey = 'free_chat_pending_server_sync';
  static const String _syncErrorKey = 'free_chat_last_server_sync_error';

  List<FreeChatConversation> _conversations = [];
  final UserAppStateService _appStateService = UserAppStateService();
  String? _authToken;
  int? _authUserId;
  Timer? _syncDebounce;
  bool _isSyncingWithServer = false;
  bool _hasPendingServerSync = false;
  String? _lastServerSyncError;
  int _stateRevision = 0;

  List<FreeChatConversation> get conversations => _conversations;
  bool get isSyncingWithServer => _isSyncingWithServer;
  bool get hasPendingServerSync => _hasPendingServerSync;
  String? get lastServerSyncError => _lastServerSyncError;

  FreeChatProvider() {
    _loadConversations();
  }

  /// Carrega conversas do armazenamento local
  Future<void> _loadConversations() async {
    print(
        '[🔄 AUTH_DATA] FreeChatProvider._loadConversations() - Iniciando carregamento...');
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? data = prefs.getString(_storageKey);

      print(
          '[🔄 AUTH_DATA] FreeChatProvider._loadConversations() - Dados no storage: ${data != null ? "${data.length} chars" : "null"}');

      if (data != null && data.isNotEmpty) {
        final List<dynamic> jsonList = jsonDecode(data);
        _conversations = jsonList
            .map((json) => FreeChatConversation.fromJson(json))
            .toList();

        // Ordenar por última atualização (mais recente primeiro)
        _conversations.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));

        print(
            '[🔄 AUTH_DATA] FreeChatProvider._loadConversations() - ✅ Carregadas ${_conversations.length} conversas');
        for (var conv in _conversations) {
          print(
              '[🔄 AUTH_DATA]   - "${conv.title}" (${conv.messages.length} msgs, ${conv.lastUpdated})');
        }
        notifyListeners();
      } else {
        print(
            '[🔄 AUTH_DATA] FreeChatProvider._loadConversations() - Nenhuma conversa encontrada no storage');
        _conversations = [];
      }
      _hasPendingServerSync = prefs.getBool(_pendingSyncKey) ?? false;
      _lastServerSyncError = prefs.getString(_syncErrorKey);
    } catch (e) {
      print(
          '[🔄 AUTH_DATA] FreeChatProvider._loadConversations() - ❌ ERRO: $e');
    }
  }

  Future<void> setAuth(
    String token,
    int userId, {
    List<dynamic>? serverConversations,
  }) async {
    _authToken = token;
    _authUserId = userId;
    await _loadConversations();

    if (_hasPendingServerSync) {
      await syncPendingIfNeeded();
      return;
    }

    if (serverConversations != null) {
      if (serverConversations.isEmpty && _conversations.isNotEmpty) {
        _hasPendingServerSync = true;
        await _saveConversations(markPendingSync: false);
        await syncPendingIfNeeded();
        return;
      }

      await applyServerConversations(serverConversations);
    }
  }

  void clearAuth() {
    _authToken = null;
    _authUserId = null;
    _syncDebounce?.cancel();
    _isSyncingWithServer = false;
  }

  Future<void> applyServerConversations(List<dynamic> conversations) async {
    final parsed = conversations
        .whereType<Map>()
        .map((json) =>
            FreeChatConversation.fromJson(json.cast<String, dynamic>()))
        .toList();

    parsed.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
    _conversations = parsed;
    _hasPendingServerSync = false;
    _lastServerSyncError = null;
    await _saveConversations(markPendingSync: false);
    notifyListeners();
  }

  /// Recarrega conversas do storage (usado após login)
  Future<void> reloadConversations() async {
    print('[🔄 AUTH_DATA] FreeChatProvider.reloadConversations() - Chamado');
    await _loadConversations();
  }

  /// Salva conversas no armazenamento local
  Future<void> _saveConversations({bool markPendingSync = true}) async {
    print(
        '[🔄 AUTH_DATA] FreeChatProvider._saveConversations() - Salvando ${_conversations.length} conversas...');
    try {
      if (markPendingSync && _authToken != null && _authUserId != null) {
        _stateRevision++;
        _hasPendingServerSync = true;
        _lastServerSyncError = null;
      }

      final prefs = await SharedPreferences.getInstance();
      final jsonList = _conversations.map((c) => c.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      await prefs.setString(_storageKey, jsonString);
      await prefs.setBool(_pendingSyncKey, _hasPendingServerSync);
      if (_lastServerSyncError != null) {
        await prefs.setString(_syncErrorKey, _lastServerSyncError!);
      } else {
        await prefs.remove(_syncErrorKey);
      }
      print(
          '[🔄 AUTH_DATA] FreeChatProvider._saveConversations() - ✅ Salvo (${jsonString.length} chars)');

      if (markPendingSync) {
        _scheduleSync();
      }
    } catch (e) {
      print(
          '[🔄 AUTH_DATA] FreeChatProvider._saveConversations() - ❌ ERRO: $e');
    }
  }

  List<Map<String, dynamic>> getServerConversationsSnapshot() {
    return _conversations.map((conversation) => conversation.toJson()).toList();
  }

  Future<void> syncPendingIfNeeded() async {
    if (!_hasPendingServerSync || _authToken == null || _authUserId == null) {
      return;
    }

    await _syncToServer();
  }

  void _scheduleSync() {
    if (!_hasPendingServerSync || _authToken == null || _authUserId == null) {
      return;
    }

    _syncDebounce?.cancel();
    _syncDebounce = Timer(const Duration(seconds: 2), _syncToServer);
  }

  Future<void> _syncToServer() async {
    final token = _authToken;
    if (_isSyncingWithServer ||
        token == null ||
        _authUserId == null ||
        !_hasPendingServerSync) {
      return;
    }

    final syncRevision = _stateRevision;
    _isSyncingWithServer = true;
    notifyListeners();

    try {
      await _appStateService.syncAppState(
        token: token,
        freeChatConversations: getServerConversationsSnapshot(),
      );

      if (_stateRevision == syncRevision) {
        _hasPendingServerSync = false;
        _lastServerSyncError = null;
        await _saveConversations(markPendingSync: false);
      }
    } catch (e) {
      _lastServerSyncError = e.toString();
      await _saveConversations(markPendingSync: false);
      print('[FreeChatProvider] Erro ao sincronizar conversas: $e');
    } finally {
      _isSyncingWithServer = false;
      notifyListeners();
      if (_hasPendingServerSync && _stateRevision != syncRevision) {
        _scheduleSync();
      }
    }
  }

  /// Cria uma nova conversa e retorna o ID.
  /// Se já existir uma conversa vazia, reutiliza ela
  /// para evitar acumular "Nova conversa" duplicadas no histórico.
  String createConversation({bool reuseEmpty = true}) {
    if (reuseEmpty) {
      try {
        final empty = _conversations.firstWhere((c) => c.messages.isEmpty);
        print('♻️ FreeChatProvider: Reutilizando conversa vazia: ${empty.id}');
        return empty.id;
      } catch (_) {
        // nenhuma vazia encontrada -> cria nova abaixo
      }
    }
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final conversation = FreeChatConversation(
      id: id,
      title: 'Nova conversa',
      createdAt: DateTime.now(),
      lastUpdated: DateTime.now(),
      messages: [],
    );

    _conversations.insert(0, conversation);
    _saveConversations();
    notifyListeners();

    print('✅ FreeChatProvider: Nova conversa criada: $id');
    return id;
  }

  /// Obtém uma conversa pelo ID
  FreeChatConversation? getConversation(String id) {
    try {
      return _conversations.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Obtém as mensagens de uma conversa (garante timestamp como DateTime)
  List<Map<String, dynamic>> getMessages(String id) {
    final conversation = getConversation(id);
    final msgs = conversation?.messages ?? [];
    return msgs.map((m) {
      final copy = Map<String, dynamic>.from(m);
      final ts = copy['timestamp'];
      if (ts is String) {
        try {
          copy['timestamp'] = DateTime.parse(ts);
        } catch (_) {
          copy['timestamp'] = DateTime.now();
        }
      } else if (ts is! DateTime) {
        copy['timestamp'] = DateTime.now();
      }
      return copy;
    }).toList();
  }

  /// Atualiza o título de uma conversa
  void updateTitle(String id, String newTitle) {
    final index = _conversations.indexWhere((c) => c.id == id);
    if (index != -1) {
      _conversations[index].title = newTitle;
      _conversations[index].lastUpdated = DateTime.now();

      // Reordenar por última atualização
      _conversations.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));

      _saveConversations();
      notifyListeners();
    }
  }

  /// Adiciona uma mensagem a uma conversa
  void addMessage(String conversationId, Map<String, dynamic> message) {
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index != -1) {
      _conversations[index].messages.add(message);
      _conversations[index].lastUpdated = DateTime.now();

      // Se for a primeira mensagem do usuário, usar como título
      if (_conversations[index].messages.length == 1 &&
          message['isUser'] == true) {
        String title = message['message'] ?? 'Nova conversa';
        if (title.length > 50) {
          title = title.substring(0, 50) + '...';
        }
        _conversations[index].title = title;
      }

      // Reordenar por última atualização
      _conversations.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));

      _saveConversations();
      notifyListeners();
    }
  }

  /// Atualiza todas as mensagens de uma conversa
  void updateMessages(
      String conversationId, List<Map<String, dynamic>> messages) {
    final index = _conversations.indexWhere((c) => c.id == conversationId);
    if (index != -1) {
      _conversations[index].messages = messages;
      _conversations[index].lastUpdated = DateTime.now();

      // Se for a primeira mensagem do usuário, usar como título
      if (messages.isNotEmpty) {
        final firstUserMessage = messages.firstWhere(
          (m) => m['isUser'] == true,
          orElse: () => {},
        );
        if (firstUserMessage.isNotEmpty) {
          String title = firstUserMessage['message'] ?? 'Nova conversa';
          if (title.length > 50) {
            title = title.substring(0, 50) + '...';
          }
          _conversations[index].title = title;
        }
      }

      // Reordenar por última atualização
      _conversations.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));

      _saveConversations();
      notifyListeners();
    }
  }

  /// Deleta uma conversa
  void deleteConversation(String id) {
    _conversations.removeWhere((c) => c.id == id);
    _saveConversations();
    notifyListeners();
    print('✅ FreeChatProvider: Conversa deletada: $id');
  }

  /// Limpa todas as conversas
  Future<void> clearAll() async {
    print(
        '[🔄 AUTH_DATA] FreeChatProvider.clearAll() - Limpando ${_conversations.length} conversas...');

    // Limpar lista em memória
    _conversations.clear();
    _syncDebounce?.cancel();
    _hasPendingServerSync = false;
    _isSyncingWithServer = false;
    _lastServerSyncError = null;

    // Limpar diretamente do SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final removed = await prefs.remove(_storageKey);
      await prefs.remove(_pendingSyncKey);
      await prefs.remove(_syncErrorKey);
      print(
          '[🔄 AUTH_DATA] FreeChatProvider.clearAll() - SharedPreferences.remove("$_storageKey"): $removed');

      // Verificar se realmente foi removido
      final checkData = prefs.getString(_storageKey);
      print(
          '[🔄 AUTH_DATA] FreeChatProvider.clearAll() - Verificação após remoção: ${checkData == null ? "NULL (OK)" : "AINDA TEM DADOS!"}');
    } catch (e) {
      print(
          '[🔄 AUTH_DATA] FreeChatProvider.clearAll() - ❌ ERRO ao limpar SharedPreferences: $e');
    }

    notifyListeners();
    print(
        '[🔄 AUTH_DATA] FreeChatProvider.clearAll() - ✅ Concluído. Lista atual: ${_conversations.length} conversas');
  }
}
