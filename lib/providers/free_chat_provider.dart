import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  List<FreeChatConversation> _conversations = [];

  List<FreeChatConversation> get conversations => _conversations;

  FreeChatProvider() {
    _loadConversations();
  }

  /// Carrega conversas do armazenamento local
  Future<void> _loadConversations() async {
    print('[🔄 AUTH_DATA] FreeChatProvider._loadConversations() - Iniciando carregamento...');
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? data = prefs.getString(_storageKey);

      print('[🔄 AUTH_DATA] FreeChatProvider._loadConversations() - Dados no storage: ${data != null ? "${data.length} chars" : "null"}');

      if (data != null && data.isNotEmpty) {
        final List<dynamic> jsonList = jsonDecode(data);
        _conversations = jsonList
            .map((json) => FreeChatConversation.fromJson(json))
            .toList();

        // Ordenar por última atualização (mais recente primeiro)
        _conversations.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));

        print('[🔄 AUTH_DATA] FreeChatProvider._loadConversations() - ✅ Carregadas ${_conversations.length} conversas');
        for (var conv in _conversations) {
          print('[🔄 AUTH_DATA]   - "${conv.title}" (${conv.messages.length} msgs, ${conv.lastUpdated})');
        }
        notifyListeners();
      } else {
        print('[🔄 AUTH_DATA] FreeChatProvider._loadConversations() - Nenhuma conversa encontrada no storage');
        _conversations = [];
      }
    } catch (e) {
      print('[🔄 AUTH_DATA] FreeChatProvider._loadConversations() - ❌ ERRO: $e');
    }
  }

  /// Recarrega conversas do storage (usado após login)
  Future<void> reloadConversations() async {
    print('[🔄 AUTH_DATA] FreeChatProvider.reloadConversations() - Chamado');
    await _loadConversations();
  }

  /// Salva conversas no armazenamento local
  Future<void> _saveConversations() async {
    print('[🔄 AUTH_DATA] FreeChatProvider._saveConversations() - Salvando ${_conversations.length} conversas...');
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _conversations.map((c) => c.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      await prefs.setString(_storageKey, jsonString);
      print('[🔄 AUTH_DATA] FreeChatProvider._saveConversations() - ✅ Salvo (${jsonString.length} chars)');
    } catch (e) {
      print('[🔄 AUTH_DATA] FreeChatProvider._saveConversations() - ❌ ERRO: $e');
    }
  }

  /// Cria uma nova conversa e retorna o ID
  String createConversation() {
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

  /// Obtém as mensagens de uma conversa
  List<Map<String, dynamic>> getMessages(String id) {
    final conversation = getConversation(id);
    return conversation?.messages ?? [];
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
  void updateMessages(String conversationId, List<Map<String, dynamic>> messages) {
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
    print('[🔄 AUTH_DATA] FreeChatProvider.clearAll() - Limpando ${_conversations.length} conversas...');

    // Limpar lista em memória
    _conversations.clear();

    // Limpar diretamente do SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final removed = await prefs.remove(_storageKey);
      print('[🔄 AUTH_DATA] FreeChatProvider.clearAll() - SharedPreferences.remove("$_storageKey"): $removed');

      // Verificar se realmente foi removido
      final checkData = prefs.getString(_storageKey);
      print('[🔄 AUTH_DATA] FreeChatProvider.clearAll() - Verificação após remoção: ${checkData == null ? "NULL (OK)" : "AINDA TEM DADOS!"}');
    } catch (e) {
      print('[🔄 AUTH_DATA] FreeChatProvider.clearAll() - ❌ ERRO ao limpar SharedPreferences: $e');
    }

    notifyListeners();
    print('[🔄 AUTH_DATA] FreeChatProvider.clearAll() - ✅ Concluído. Lista atual: ${_conversations.length} conversas');
  }
}
