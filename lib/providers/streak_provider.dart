import 'package:flutter/material.dart';
import '../services/streak_service.dart';

/// Provider para gerenciar streaks do usuário
class StreakProvider extends ChangeNotifier {
  UserStreak? _streak;
  bool _isLoading = false;
  String? _error;
  String? _token;
  int _sessionRevision = 0;
  Future<bool>? _checkInInFlight;
  String? _checkInDateKey;
  Future<bool>? _freezeActivationInFlight;
  Future<void>? _loadInFlight;
  final List<StreakCheckInEvent> _pendingCelebrationEvents = [];

  UserStreak? get streak => _streak;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasStreak => _streak != null;

  // Getters convenientes
  int get registrationStreak => _streak?.registrationStreak ?? 0;
  int get proteinStreak => _streak?.proteinStreak ?? 0;
  int get goalStreak => _streak?.goalStreak ?? 0;
  int get freezesAvailable => _streak?.freezesAvailable ?? 0;
  bool get isFreezeActive => _streak?.isFreezeActive ?? false;
  bool get isStreakInDanger => _streak?.isStreakInDanger ?? false;
  int get bestOverallStreak => _streak?.bestOverallStreak ?? 0;
  int get primaryStreak => registrationStreak;
  bool get hasPendingCelebration => _pendingCelebrationEvents.isNotEmpty;
  StreakCheckInEvent? get nextCelebrationEvent =>
      _pendingCelebrationEvents.isEmpty
          ? null
          : _pendingCelebrationEvents.first;

  /// Configura o token de autenticação
  void setToken(String token) {
    if (_token == token) return;
    _sessionRevision++;
    _token = token;
    _pendingCelebrationEvents.clear();
    loadStreak();
  }

  /// Limpa os dados de auth
  void clearAuth() {
    _sessionRevision++;
    _token = null;
    _streak = null;
    _error = null;
    _checkInInFlight = null;
    _checkInDateKey = null;
    _freezeActivationInFlight = null;
    _loadInFlight = null;
    _pendingCelebrationEvents.clear();
    notifyListeners();
  }

  /// Carrega os streaks do servidor
  Future<void> loadStreak() async {
    if (_token == null) return;

    final existing = _loadInFlight;
    if (existing != null) {
      await existing;
      return;
    }

    final operation = _loadStreak();
    _loadInFlight = operation;
    try {
      await operation;
    } finally {
      if (identical(_loadInFlight, operation)) {
        _loadInFlight = null;
      }
    }
  }

  Future<void> _loadStreak() async {
    if (_token == null) return;

    final token = _token!;
    final revision = _sessionRevision;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await StreakService.getMyStreak(token: token);
      if (revision != _sessionRevision || token != _token) return;
      if (result != null) {
        _streak = result.streak;
        _enqueueCelebration(result.pendingEvent);
        _error = null;
      } else {
        _error = 'Não foi possível carregar a sequência';
      }
    } catch (e) {
      _error = 'Erro ao carregar streaks: $e';
      print('[StreakProvider] $_error');
    } finally {
      if (revision == _sessionRevision && token == _token) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Realiza check-in
  Future<bool> performCheckIn({DateTime? localDate}) async {
    if (_token == null) return false;

    final requestedDate = localDate ?? DateTime.now();
    final requestedDateKey = _formatDateKey(requestedDate);

    final existing = _checkInInFlight;
    if (existing != null) {
      if (_checkInDateKey == requestedDateKey) return existing;
      await existing;
      return performCheckIn(localDate: requestedDate);
    }

    final operation = _performCheckIn(requestedDate);
    _checkInInFlight = operation;
    _checkInDateKey = requestedDateKey;
    try {
      return await operation;
    } finally {
      if (identical(_checkInInFlight, operation)) {
        _checkInInFlight = null;
        _checkInDateKey = null;
      }
    }
  }

  Future<bool> _performCheckIn(DateTime localDate) async {
    final loading = _loadInFlight;
    if (loading != null) await loading;

    final token = _token;
    if (token == null) return false;
    final revision = _sessionRevision;

    _isLoading = true;
    notifyListeners();

    try {
      final result = await StreakService.performCheckIn(
        token: token,
        localDate: localDate,
      );
      if (revision != _sessionRevision || token != _token) return false;
      if (result != null) {
        _streak = result.streak;
        _enqueueCelebration(result.event);
        _error = null;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _error = 'Erro ao fazer check-in: $e';
      print('[StreakProvider] $_error');
      return false;
    } finally {
      if (revision == _sessionRevision && token == _token) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void _enqueueCelebration(StreakCheckInEvent? event) {
    if (event == null || event.id <= 0 || event.currentStreak <= 0) return;
    if (_pendingCelebrationEvents.any((queued) => queued.id == event.id)) {
      return;
    }
    _pendingCelebrationEvents.add(event);
    _pendingCelebrationEvents.sort((a, b) {
      final byDate = a.checkInDate.compareTo(b.checkInDate);
      return byDate != 0 ? byDate : a.id.compareTo(b.id);
    });
  }

  /// Remove o evento da fila local assim que a tela termina. O ACK no servidor
  /// é tentado em seguida; se a rede falhar, ele volta numa futura sessão.
  Future<bool> completeCelebration(int eventId) async {
    _pendingCelebrationEvents.removeWhere((event) => event.id == eventId);
    notifyListeners();
    final token = _token;
    if (token == null) return false;
    final acknowledged = await StreakService.acknowledgeEvent(
      token: token,
      eventId: eventId,
    );
    if (acknowledged && token == _token) {
      await loadStreak();
    }
    return acknowledged;
  }

  /// Ativa o freeze
  Future<bool> activateFreeze() async {
    if (_token == null) return false;
    if (freezesAvailable <= 0) return false;

    final existing = _freezeActivationInFlight;
    if (existing != null) return existing;

    final operation = _activateFreeze();
    _freezeActivationInFlight = operation;
    try {
      return await operation;
    } finally {
      if (identical(_freezeActivationInFlight, operation)) {
        _freezeActivationInFlight = null;
      }
    }
  }

  Future<bool> _activateFreeze() async {
    if (_token == null || freezesAvailable <= 0) return false;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await StreakService.activateFreeze(token: _token!);
      if (result.streak != null) {
        _streak = result.streak;
        _error = null;
        notifyListeners();
        return true;
      }
      final failureError = result.error;
      print('[StreakProvider] activateFreeze failed: $failureError');
      // Recarrega para alinhar estado local com servidor.
      await loadStreak();
      // loadStreak limpa _error em caso de sucesso; reaplica a mensagem real.
      _error = failureError;
      return false;
    } catch (e) {
      _error = 'Erro ao ativar freeze: $e';
      print('[StreakProvider] $_error');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Força recarregamento do streak
  Future<void> refresh() async {
    await loadStreak();
  }

  static String _formatDateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}
