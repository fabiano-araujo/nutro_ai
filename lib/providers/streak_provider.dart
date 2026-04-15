import 'package:flutter/material.dart';
import '../services/streak_service.dart';

/// Provider para gerenciar streaks do usuário
class StreakProvider extends ChangeNotifier {
  UserStreak? _streak;
  bool _isLoading = false;
  String? _error;
  String? _token;

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

  /// Configura o token de autenticação
  void setToken(String token) {
    _token = token;
    loadStreak();
  }

  /// Limpa os dados de auth
  void clearAuth() {
    _token = null;
    _streak = null;
    _error = null;
    notifyListeners();
  }

  /// Carrega os streaks do servidor
  Future<void> loadStreak() async {
    if (_token == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final streak = await StreakService.getMyStreak(token: _token!);
      _streak = streak;
      _error = null;
    } catch (e) {
      _error = 'Erro ao carregar streaks: $e';
      print('[StreakProvider] $_error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Realiza check-in
  Future<bool> performCheckIn() async {
    if (_token == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      final streak = await StreakService.performCheckIn(token: _token!);
      if (streak != null) {
        _streak = streak;
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
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Ativa o freeze
  Future<bool> activateFreeze() async {
    if (_token == null) return false;
    if (freezesAvailable <= 0) return false;

    _isLoading = true;
    notifyListeners();

    try {
      final streak = await StreakService.activateFreeze(token: _token!);
      if (streak != null) {
        _streak = streak;
        _error = null;
        notifyListeners();
        return true;
      }
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
}
