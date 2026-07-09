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
  final Set<String> _pendingDateKeys = {};

  bool get hasPending => _hasPending;

  /// Define as credenciais usadas no upload. Chamado no login/restauração.
  void setAuth(String token, int userId) {
    _token = token;
    _userId = userId;
    print(
        '[DAILY_CHAT_SYNC] set_auth userId=$userId hasToken=${token.isNotEmpty}');
  }

  /// Limpa as credenciais (logout). Cancela qualquer sync pendente.
  void clearAuth() {
    _token = null;
    _userId = null;
    _debounce?.cancel();
    _debounce = null;
    _hasPending = false;
    _pendingDateKeys.clear();
    print('[DAILY_CHAT_SYNC] clear_auth');
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
    print(
        '[DAILY_CHAT_SYNC] restore_from_server_start scope=$scope days=${serverChat?.length ?? 0}');
    if (serverChat == null || serverChat.isEmpty) {
      print('[DAILY_CHAT_SYNC] restore_from_server_skip_empty scope=$scope');
      return;
    }

    var restored = 0;
    var skippedExisting = 0;
    var skippedInvalid = 0;
    for (final entry in serverChat.entries) {
      final dateKey = entry.key;
      if (!_dateSuffix.hasMatch('_$dateKey')) {
        skippedInvalid++;
        continue;
      }

      final value = entry.value;
      if (value is! Map) {
        skippedInvalid++;
        continue;
      }
      final messages = value['messages'];
      if (messages is! List || messages.isEmpty) {
        skippedInvalid++;
        continue;
      }

      final localKey = '$_chatKeyPrefix${scope}_$dateKey';
      final existing = await _storage.getData(localKey);
      final incomingDay = _readChatDay(value.cast<String, dynamic>());
      final existingDay = _readChatDay(existing);
      if (incomingDay == null || !incomingDay.hasMessages) {
        skippedInvalid++;
        continue;
      }
      if (existingDay != null &&
          _compareChatDays(existingDay, incomingDay) >= 0) {
        // Conversa local já é igual/mais nova — preservar. Isso também cobre
        // tombstones locais de exclusão para não ressuscitar chat antigo.
        skippedExisting++;
        continue;
      }

      await _storage.saveData(localKey, _serializeChatDay(incomingDay));
      restored++;
    }

    if (restored > 0) {
      print(
          '♻️ DailyChatSyncService - $restored conversa(s) restaurada(s) do servidor (scope=$scope)');
    }
    print(
        '[DAILY_CHAT_SYNC] restore_from_server_done scope=$scope restored=$restored skippedExisting=$skippedExisting skippedInvalid=$skippedInvalid');
  }

  /// Busca e restaura do servidor somente o chat de [dateKey].
  ///
  /// Retorna true quando alguma conversa daquele dia foi encontrada/restaurada.
  Future<bool> restoreDateFromServer(
    String dateKey, {
    required String scope,
  }) async {
    final token = _token;
    if (token == null || _userId == null || !_isDateKey(dateKey)) {
      print(
          '[DAILY_CHAT_SYNC] restore_date_skip date=$dateKey scope=$scope reason=missing_auth_or_invalid_date hasToken=${token != null} hasUser=${_userId != null}');
      return false;
    }

    try {
      print(
          '[DAILY_CHAT_SYNC] restore_date_fetch_start date=$dateKey scope=$scope userId=$_userId');
      final appState = await _appStateService.fetchAppState(
        token: token,
        nutritionChatDateKey: dateKey,
        lightweight: true,
      );
      final chatByDate =
          (appState['nutritionChatByDate'] as Map?)?.cast<String, dynamic>();
      final day = chatByDate?[dateKey];
      if (day is! Map) {
        print(
            '[DAILY_CHAT_SYNC] restore_date_empty date=$dateKey scope=$scope reason=missing_day');
        return false;
      }

      final messages = day['messages'];
      if (messages is! List || messages.isEmpty) {
        print(
            '[DAILY_CHAT_SYNC] restore_date_empty date=$dateKey scope=$scope reason=empty_messages');
        return false;
      }

      final localKey = '$_chatKeyPrefix${scope}_$dateKey';
      final incomingDay = _readChatDay(day.cast<String, dynamic>());
      final existingDay = _readChatDay(await _storage.getData(localKey));
      if (incomingDay == null || !incomingDay.hasMessages) {
        return false;
      }
      if (existingDay != null &&
          _compareChatDays(existingDay, incomingDay) >= 0) {
        print(
            '[DAILY_CHAT_SYNC] restore_date_skip_newer_local date=$dateKey scope=$scope');
        return false;
      }

      await _storage.saveData(localKey, _serializeChatDay(incomingDay));
      print(
          '♻️ DailyChatSyncService - conversa de $dateKey restaurada sob demanda (${messages.length} mensagens)');
      return true;
    } catch (e) {
      print('⚠️ DailyChatSyncService - Erro ao restaurar chat de $dateKey: $e');
      return false;
    }
  }

  /// Agenda um upload do chat diário (debounced). Chamado após cada save local.
  void scheduleSync({String? dateKey}) {
    if (_token == null || _userId == null) {
      print(
          '[DAILY_CHAT_SYNC] schedule_sync_skip date=$dateKey reason=missing_auth');
      return;
    }
    if (dateKey != null && _isDateKey(dateKey)) {
      _pendingDateKeys.add(dateKey);
    }
    _hasPending = true;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), _syncToServer);
    print(
        '[DAILY_CHAT_SYNC] schedule_sync date=$dateKey pendingDates=${_pendingDateKeys.length}');
  }

  Future<void> syncPendingIfNeeded() async {
    if (!_hasPending) return;
    _debounce?.cancel();
    _debounce = null;
    await _syncToServer();
  }

  Future<void> syncDeletedDate(String dateKey) async {
    final token = _token;
    if (token == null || _userId == null || !_isDateKey(dateKey)) {
      return;
    }

    try {
      await _appStateService.syncAppState(
        token: token,
        nutritionChatByDate: {
          dateKey: {'messages': <Map<String, dynamic>>[]},
        },
        nutritionChatDateKey: dateKey,
      );
      _pendingDateKeys.remove(dateKey);
      _hasPending = _pendingDateKeys.isNotEmpty;
      print(
          '✅ DailyChatSyncService - chat diário de $dateKey removido do servidor');
    } catch (e) {
      print('⚠️ DailyChatSyncService - Erro ao remover chat de $dateKey: $e');
    }
  }

  Future<void> _syncToServer() async {
    final token = _token;
    if (_isSyncing || token == null || _userId == null || !_hasPending) {
      return;
    }

    _isSyncing = true;
    try {
      final syncDateKeys = Set<String>.from(_pendingDateKeys);
      final snapshot = syncDateKeys.isEmpty
          ? await buildSnapshot()
          : await buildSnapshotForDates(syncDateKeys);
      if (snapshot.isEmpty) {
        _hasPending = false;
        _pendingDateKeys.clear();
        return;
      }
      await _appStateService.syncAppState(
        token: token,
        nutritionChatByDate: snapshot,
        nutritionChatDateKey:
            syncDateKeys.length == 1 ? syncDateKeys.single : null,
      );
      if (syncDateKeys.isEmpty) {
        _pendingDateKeys.clear();
      } else {
        _pendingDateKeys.removeAll(syncDateKeys);
      }
      _hasPending = _pendingDateKeys.isNotEmpty;
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
  Future<Map<String, dynamic>> buildSnapshot() async {
    return _buildSnapshotWhere((key) => key.startsWith(_chatKeyPrefix));
  }

  Future<Map<String, dynamic>> buildSnapshotForDates(
    Iterable<String> dateKeys,
  ) async {
    final allowedDates = dateKeys.where(_isDateKey).toSet();
    if (allowedDates.isEmpty) return const <String, dynamic>{};
    return _buildSnapshotWhere((key) {
      if (!key.startsWith(_chatKeyPrefix)) return false;
      final match = _dateSuffix.firstMatch(key);
      final dateKey = match?.group(1);
      return dateKey != null && allowedDates.contains(dateKey);
    });
  }

  Future<Map<String, dynamic>> buildGuestSnapshot() async {
    return _buildSnapshotWhere(
        (key) => key.startsWith('${_chatKeyPrefix}guest_'));
  }

  Future<void> clearGuestChats() async {
    final keys = await _storage.getAllKeys();
    for (final key
        in keys.where((k) => k.startsWith('${_chatKeyPrefix}guest_'))) {
      await _storage.removeData(key);
    }
  }

  Future<Map<String, dynamic>> _buildSnapshotWhere(
    bool Function(String key) includeKey,
  ) async {
    final keys = await _storage.getAllKeys();
    final chatKeys = keys.where(includeKey);

    final result = <String, dynamic>{};
    for (final key in chatKeys) {
      final match = _dateSuffix.firstMatch(key);
      final dateKey = match?.group(1);
      if (dateKey == null) continue;

      final data = await _storage.getData(key);
      final day = _readChatDay(data);
      if (day == null || (!day.hasMessages && !day.isDeleted)) continue;

      final existing = result[dateKey];
      final existingDay = existing is Map
          ? _readChatDay(existing.cast<String, dynamic>())
          : null;
      if (existingDay != null && _compareChatDays(existingDay, day) >= 0) {
        continue;
      }
      result[dateKey] = _serializeChatDay(day);
    }
    return result;
  }

  bool _isDateKey(String value) {
    return RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value);
  }

  _ChatDay? _readChatDay(Map<String, dynamic>? data) {
    if (data == null) return null;

    final rawMessages = data['messages'];
    if (rawMessages is! List) return null;

    final messages = List<dynamic>.from(rawMessages);
    final updatedAt = _readDate(data['updatedAt']) ??
        _readDate(data['deletedAt']) ??
        _latestMessageTimestamp(messages);
    final isDeleted = data['deleted'] == true ||
        (messages.isEmpty && data['deletedAt'] != null);

    return _ChatDay(
      messages: messages,
      updatedAt: updatedAt,
      isDeleted: isDeleted,
    );
  }

  Map<String, dynamic> _serializeChatDay(_ChatDay day) {
    final updatedAt = day.updatedAt?.toUtc().toIso8601String();
    return {
      'messages': day.messages,
      if (updatedAt != null) 'updatedAt': updatedAt,
      if (day.isDeleted) ...{
        'deleted': true,
        'deletedAt': updatedAt ?? DateTime.now().toUtc().toIso8601String(),
      },
    };
  }

  int _compareChatDays(_ChatDay a, _ChatDay b) {
    final aUpdated = a.updatedAt;
    final bUpdated = b.updatedAt;
    if (aUpdated != null && bUpdated != null) {
      final byTime = aUpdated.compareTo(bUpdated);
      if (byTime != 0) return byTime;
    } else if (aUpdated != null) {
      return 1;
    } else if (bUpdated != null) {
      return -1;
    }

    final byCount = a.messages.length.compareTo(b.messages.length);
    if (byCount != 0) return byCount;

    if (a.isDeleted == b.isDeleted) return 0;
    return a.isDeleted ? 1 : -1;
  }

  DateTime? _latestMessageTimestamp(List<dynamic> messages) {
    DateTime? latest;
    for (final message in messages) {
      if (message is! Map) continue;
      final timestamp = _readDate(message['timestamp']);
      if (timestamp == null) continue;
      if (latest == null || timestamp.isAfter(latest)) {
        latest = timestamp;
      }
    }
    return latest;
  }

  DateTime? _readDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is! String || value.trim().isEmpty) return null;
    return DateTime.tryParse(value.trim());
  }
}

class _ChatDay {
  final List<dynamic> messages;
  final DateTime? updatedAt;
  final bool isDeleted;

  const _ChatDay({
    required this.messages,
    required this.updatedAt,
    required this.isDeleted,
  });

  bool get hasMessages => messages.isNotEmpty;
}
