import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/study_item.dart';
import 'event_service.dart';

class StorageService {
  static const String _historyKey = 'study_history';
  static const String _favoritesKey = 'study_favorites';
  static const String _settingsKey = 'app_settings';
  static const String _creditDataKey = 'user_credit_data';

  final EventService _eventService = EventService();

  // Save a study item to history
  Future<bool> saveToHistory(StudyItem item) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> history = prefs.getStringList(_historyKey) ?? [];

      // Verificar se já existe um item com o mesmo ID
      bool itemExists = false;
      int existingItemIndex = -1;
      StudyItem? existingItem;

      for (int i = 0; i < history.length; i++) {
        existingItem = StudyItem.fromJson(jsonDecode(history[i]));
        if (existingItem.id == item.id) {
          itemExists = true;
          existingItemIndex = i;
          break;
        }
      }

      if (itemExists && existingItem != null) {
        // NOVA LÓGICA: Verificar se o item existente é uma ferramenta (tem content como JSON)
        bool isExistingTool = false;
        Map<String, dynamic>? existingToolData;

        try {
          if (existingItem.content.startsWith('{') &&
              existingItem.content.endsWith('}')) {
            existingToolData = jsonDecode(existingItem.content);
            isExistingTool = existingToolData != null &&
                (existingToolData.containsKey('toolName') ||
                    existingToolData.containsKey('sourceType')) &&
                (existingToolData.containsKey('fullPrompt') ||
                    existingToolData.containsKey('conversationHistory'));
          }
        } catch (e) {
          print('Erro ao verificar se item existente é ferramenta: $e');
          isExistingTool = false;
        }

        // Verificar se o novo item tem padrão de chat (com marcadores USER_MESSAGE/AI_RESPONSE)
        bool isNewItemChat = item.content.contains('###USER_MESSAGE###') &&
            item.response.contains('###AI_RESPONSE###');

        if (isExistingTool && isNewItemChat && existingToolData != null) {
          print(
              '📝 StorageService: Detectado atualização de ferramenta com nova mensagem');

          // Atualizar o histórico de conversa da ferramenta existente mantendo suas propriedades originais
          if (!existingToolData.containsKey('conversationHistory')) {
            existingToolData['conversationHistory'] = {
              'userContent': '',
              'aiResponse': '',
              'messages': []
            };
          }

          // Extrair mensagem do usuário
          String userMessage =
              item.content.replaceAll('###USER_MESSAGE###', '').trim();
          // Extrair resposta da IA
          String aiResponse =
              item.response.replaceAll('###AI_RESPONSE###', '').trim();

          // Adicionar novas mensagens ao histórico existente
          if (existingToolData['conversationHistory'] != null &&
              existingToolData['conversationHistory'] is Map &&
              existingToolData['conversationHistory'].containsKey('messages')) {
            // Adicionar a mensagem do usuário
            existingToolData['conversationHistory']['messages'].add({
              'isUser': true,
              'timestamp': item.timestamp.toIso8601String(),
              'message': userMessage
            });

            // Adicionar a resposta da IA
            existingToolData['conversationHistory']['messages'].add({
              'isUser': false,
              'timestamp': item.timestamp.toIso8601String(),
              'message': aiResponse
            });

            print(
                '✅ StorageService: Adicionadas 2 novas mensagens ao histórico da ferramenta');

            // Criar um novo StudyItem preservando as propriedades originais mas com o conteúdo atualizado
            final updatedItem = StudyItem(
              id: existingItem.id,
              title: existingItem.title,
              content: jsonEncode(existingToolData),
              response: item.response,
              type: existingItem.type,
              timestamp: item.timestamp, // Usar o timestamp mais recente
            );

            // Atualizar o item na lista
            history[existingItemIndex] = jsonEncode(updatedItem.toJson());

            // Mover para o topo se não estiver lá
            if (existingItemIndex > 0) {
              final updatedString = history.removeAt(existingItemIndex);
              history.insert(0, updatedString);
            }

            final result = await prefs.setStringList(_historyKey, history);
            _eventService.notifyHistoryUpdated();
            return result;
          }
        }

        // Caso não seja ferramenta ou a estrutura esperada, segue com o fluxo normal
        // Atualizar o item existente em vez de criar um novo
        history[existingItemIndex] = jsonEncode(item.toJson());

        // Mover o item atualizado para o topo da lista se não estiver lá
        if (existingItemIndex > 0) {
          final updatedItem = history.removeAt(existingItemIndex);
          history.insert(0, updatedItem);
        }
      } else {
        // Adicionar novo item no início da lista
        history.insert(0, jsonEncode(item.toJson()));

        // Limitar histórico a 50 itens
        if (history.length > 50) {
          history = history.sublist(0, 50);
        }
      }

      final result = await prefs.setStringList(_historyKey, history);

      // Notificar que o histórico foi atualizado
      _eventService.notifyHistoryUpdated();

      return result;
    } catch (e) {
      print('Error saving to history: $e');
      return false;
    }
  }

  // Get all history items
  Future<List<StudyItem>> getHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> history = prefs.getStringList(_historyKey) ?? [];

      return history
          .map((item) => StudyItem.fromJson(jsonDecode(item)))
          .toList();
    } catch (e) {
      print('Error getting history: $e');
      return [];
    }
  }

  // Save an item to favorites
  Future<bool> saveToFavorites(StudyItem item) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> favorites = prefs.getStringList(_favoritesKey) ?? [];

      // Check if the item is already in favorites
      bool exists = false;
      for (int i = 0; i < favorites.length; i++) {
        StudyItem favItem = StudyItem.fromJson(jsonDecode(favorites[i]));
        if (favItem.id == item.id) {
          exists = true;
          favorites[i] = jsonEncode(item.toJson()); // Update existing item
          break;
        }
      }

      // If the item doesn't exist, add it
      if (!exists) {
        favorites.add(jsonEncode(item.toJson()));
      }

      final result = await prefs.setStringList(_favoritesKey, favorites);

      // Notificar que o histórico foi atualizado (pois os favoritos podem ser exibidos na mesma tela)
      _eventService.notifyHistoryUpdated();

      return result;
    } catch (e) {
      print('Error saving to favorites: $e');
      return false;
    }
  }

  // Remove an item from favorites
  Future<bool> removeFromFavorites(String itemId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> favorites = prefs.getStringList(_favoritesKey) ?? [];

      // Find the item with matching ID
      int indexToRemove = -1;
      for (int i = 0; i < favorites.length; i++) {
        StudyItem favItem = StudyItem.fromJson(jsonDecode(favorites[i]));
        if (favItem.id == itemId) {
          indexToRemove = i;
          break;
        }
      }

      // Remove the item if found
      if (indexToRemove != -1) {
        favorites.removeAt(indexToRemove);
      }

      final result = await prefs.setStringList(_favoritesKey, favorites);

      // Notificar que o histórico foi atualizado
      _eventService.notifyHistoryUpdated();

      return result;
    } catch (e) {
      print('Error removing from favorites: $e');
      return false;
    }
  }

  // Remove an item from history
  Future<bool> removeFromHistory(String itemId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> history = prefs.getStringList(_historyKey) ?? [];

      // Find the item with matching ID
      int indexToRemove = -1;
      for (int i = 0; i < history.length; i++) {
        StudyItem historyItem = StudyItem.fromJson(jsonDecode(history[i]));
        if (historyItem.id == itemId) {
          indexToRemove = i;
          break;
        }
      }

      // Remove the item if found
      if (indexToRemove != -1) {
        history.removeAt(indexToRemove);
      }

      final result = await prefs.setStringList(_historyKey, history);

      // Notificar que o histórico foi atualizado
      _eventService.notifyHistoryUpdated();

      return result;
    } catch (e) {
      print('Error removing from history: $e');
      return false;
    }
  }

  // Get all favorite items
  Future<List<StudyItem>> getFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> favorites = prefs.getStringList(_favoritesKey) ?? [];

      return favorites
          .map((item) => StudyItem.fromJson(jsonDecode(item)))
          .toList();
    } catch (e) {
      print('Error getting favorites: $e');
      return [];
    }
  }

  // Save app settings
  Future<bool> saveSettings(Map<String, dynamic> settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_settingsKey, jsonEncode(settings));
    } catch (e) {
      print('Error saving settings: $e');
      return false;
    }
  }

  // Get app settings
  Future<Map<String, dynamic>> getSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? settingsString = prefs.getString(_settingsKey);

      if (settingsString != null) {
        return jsonDecode(settingsString) as Map<String, dynamic>;
      } else {
        // Return default settings
        return {
          'theme': 'system',
          'textSize': 'medium',
          'notificationsEnabled': false,
        };
      }
    } catch (e) {
      print('Error getting settings: $e');
      // Return default settings on error
      return {
        'theme': 'system',
        'textSize': 'medium',
        'notificationsEnabled': false,
      };
    }
  }

  // Buscar um item específico pelo ID
  Future<StudyItem?> getItemById(String id) async {
    try {
      // Primeiro procurar no histórico
      final history = await getHistory();
      for (var item in history) {
        if (item.id == id) {
          return item;
        }
      }

      // Se não encontrar no histórico, procurar nos favoritos
      final favorites = await getFavorites();
      for (var item in favorites) {
        if (item.id == id) {
          return item;
        }
      }

      // Se não encontrar em nenhum lugar, retornar null
      return null;
    } catch (e) {
      print('Error getting item by ID: $e');
      return null;
    }
  }

  // Salva os dados de crédito do usuário
  Future<bool> saveCreditData(Map<String, dynamic> creditData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_creditDataKey, jsonEncode(creditData));
    } catch (e) {
      print('Erro ao salvar dados de crédito: $e');
      return false;
    }
  }

  // Obtém os dados de crédito do usuário
  Future<Map<String, dynamic>?> getCreditData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? creditDataString = prefs.getString(_creditDataKey);

      if (creditDataString != null) {
        return jsonDecode(creditDataString) as Map<String, dynamic>;
      } else {
        return null;
      }
    } catch (e) {
      print('Erro ao obter dados de crédito: $e');
      return null;
    }
  }

  // Método genérico para salvar dados
  Future<bool> saveData(String key, Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(key, jsonEncode(data));
    } catch (e) {
      print('Erro ao salvar dados ($key): $e');
      return false;
    }
  }

  // Método genérico para obter dados
  Future<Map<String, dynamic>?> getData(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? dataString = prefs.getString(key);

      if (dataString != null) {
        return jsonDecode(dataString) as Map<String, dynamic>;
      } else {
        return null;
      }
    } catch (e) {
      print('Erro ao obter dados ($key): $e');
      return null;
    }
  }
}
