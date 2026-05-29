import 'dart:async';

import 'storage_service.dart';
import 'user_app_state_service.dart';

/// Sincroniza o chat diário do AI Tutor (chaves locais
/// `nutrition_chat_<scope>_<data>`) com o servidor, usando o mesmo endpoint
/// `/user/app-state` das demais fatias (refeições, conversa livre, etc.).
///
/// Diferente das refeições, o chat diário era apenas local — então ao limpar
/// os dados do app / reinstalar / trocar de aparelho, as mensagens de texto se
/// perdiam. Este serviço envia um snapshot `{ 'YYYY-MM-DD': { 'messages': [...] } }`
/// para o servidor e restaura na próxima sessão.
///
/// Singleton porque o histórico do chat é gravado pelo
/// `NutritionAssistantController` (criado por tela/conversa), que não participa
/// da árvore de Providers nem possui o token de autenticação.
class DailyChatSyncService {
  DailyChatSyncService._();
  static final DailyChatSyncService instance = DailyChatSyncService._();

  static const String _chatKeyPrefix = 'nutrition_chat_';
  static final RegExp _dateSuffix = RegExp(r'_(\d{4}-\d{2}-\d{2})$');

  final StorageService _storage = StorageService();
  final UserAppStateService _appStateService = UserAppStateService();

  String? _token;
  int? _userId;
  Timer? _debounce;
  bool _isSyncing = false;
  bool _hasPending = false;

  /// Define as credenciais usadas no upload. Chamado no login/restauração.
  void setAuth(String token, int userId) {
    _token = token;
    _userId = userId;
  }

  /// Limpa as credenciais (logout). Cancela qualquer sync pendente.
  void clearAuth() {
    _token = null;
    _userId = null;
    _debounce?.cancel();
    _debounce = null;
    _hasPending = false;
  }

  /// Restaura as conversas vindas do servidor para o armazenamento local.
  ///
  /// [serverChat] tem o formato `{ 'YYYY-MM-DD': { 'messages': [...] }, ... }`.
  /// [scope] é o escopo atual do controller (ex.: `user_<id>`). Não sobrescreve
  /// uma conversa local que já seja igual ou maior, para não descartar
  /// mensagens recentes ainda não enviadas.
  Future<void> restoreFromServer(
    Map<String, dynamic>? serverChat, {
    required String scope,
  }) async {
    if (serverChat == null || serverChat.isEmpty) return;

    var restored = 0;
    for (final entry in serverChat.entries) {
      final dateKey = entry.key;
      if (!_dateSuffix.hasMatch('_$dateKey')) continue;

      final value = entry.value;
      if (value is! Map) continue;
      final messages = value['messages'];
      if (messages is! List || messages.isEmpty) continue;

      final localKey = '$_chatKeyPrefix${scope}_$dateKey';
      final existing = await _storage.getData(localKey);
      final existingMsgs = existing?['messages'];
      if (existingMsgs is List && existingMsgs.length >= messages.length) {
        // Conversa local já está igual/maior — preservar.
        continue;
      }

      await _storage.saveData(localKey, {'messages': messages});
      restored++;
    }

    if (restored > 0) {
      print(
          '♻️ DailyChatSyncService - $restored conversa(s) restaurada(s) do servidor (scope=$scope)');
    }
  }

  /// Agenda um upload do chat diário (debounced). Chamado após cada save local.
  void scheduleSync() {
    if (_token == null || _userId == null) return;
    _hasPending = true;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), _syncToServer);
  }

  Future<void> _syncToServer() async {
    final token = _token;
    if (_isSyncing || token == null || _userId == null || !_hasPending) {
      return;
    }

    _isSyncing = true;
    try {
      final snapshot = await _buildSnapshot();
      if (snapshot.isEmpty) {
        _hasPending = false;
        return;
      }
      await _appStateService.syncAppState(
        token: token,
        nutritionChatByDate: snapshot,
      );
      _hasPending = false;
      print(
          '✅ DailyChatSyncService - ${snapshot.length} dia(s) de chat sincronizado(s) com o servidor');
    } catch (e) {
      print('⚠️ DailyChatSyncService - Erro ao sincronizar chat: $e');
      // Mantém _hasPending = true para nova tentativa em um próximo save.
    } finally {
      _isSyncing = false;
    }
  }

  /// Lê todas as chaves `nutrition_chat_*` locais e monta o snapshot por data.
  /// Quando a mesma data existe em mais de um escopo (ex.: 'guest' e
  /// 'user_<id>' por causa do timing de restauração do login), mantém a versão
  /// com mais mensagens.
  Future<Map<String, dynamic>> _buildSnapshot() async {
    final keys = await _storage.getAllKeys();
    final chatKeys = keys.where((k) => k.startsWith(_chatKeyPrefix));

    final result = <String, dynamic>{};
    for (final key in chatKeys) {
      final match = _dateSuffix.firstMatch(key);
      final dateKey = match?.group(1);
      if (dateKey == null) continue;

      final data = await _storage.getData(key);
      final msgs = data?['messages'];
      if (msgs is! List || msgs.isEmpty) continue;

      final existing = result[dateKey];
      if (existing is Map &&
          existing['messages'] is List &&
          (existing['messages'] as List).length >= msgs.length) {
        continue;
      }
      result[dateKey] = {'messages': msgs};
    }
    return result;
  }
}
