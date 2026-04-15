import 'package:flutter/material.dart';
import '../services/challenge_service.dart';

/// Provider para gerenciar desafios
class ChallengesProvider extends ChangeNotifier {
  String? _token;
  bool _isLoading = false;
  String? _error;

  List<Challenge> _myChallenges = [];
  List<Challenge> _publicChallenges = [];
  Challenge? _selectedChallenge;
  List<LeaderboardItem> _leaderboard = [];

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Challenge> get myChallenges => _myChallenges;
  List<Challenge> get publicChallenges => _publicChallenges;
  Challenge? get selectedChallenge => _selectedChallenge;
  List<LeaderboardItem> get leaderboard => _leaderboard;
  bool get hasActiveChallenges => _myChallenges.isNotEmpty;
  List<Challenge> get previewChallenges => _myChallenges.take(3).toList();
  List<Challenge> get previewPublicChallenges => _publicChallenges.take(2).toList();
  int get activeChallengeCount => _myChallenges.length;
  int get publicChallengeCount => _publicChallenges.length;

  /// Configura o token
  void setToken(String token) {
    _token = token;
    loadOverview();
  }

  /// Limpa os dados
  void clearAuth() {
    _token = null;
    _myChallenges = [];
    _publicChallenges = [];
    _selectedChallenge = null;
    _leaderboard = [];
    notifyListeners();
  }

  /// Carregar meus desafios
  Future<void> loadMyChallenges() async {
    if (_token == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      _myChallenges = await ChallengeService.getMyChallenges(token: _token!);
      _error = null;
    } catch (e) {
      _error = 'Erro ao carregar desafios: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Carregar desafios públicos
  Future<void> loadPublicChallenges() async {
    if (_token == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      _publicChallenges = await ChallengeService.getPublicChallenges(token: _token!);
      _error = null;
    } catch (e) {
      _error = 'Erro ao carregar desafios públicos: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Carregar detalhes do desafio
  Future<void> loadChallengeDetails(int challengeId) async {
    if (_token == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      _selectedChallenge = await ChallengeService.getChallengeDetails(
        token: _token!,
        challengeId: challengeId,
      );
      await loadLeaderboard(challengeId);
      _error = null;
    } catch (e) {
      _error = 'Erro ao carregar detalhes: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Carregar ranking
  Future<void> loadLeaderboard(int challengeId) async {
    if (_token == null) return;

    _leaderboard = await ChallengeService.getLeaderboard(
      token: _token!,
      challengeId: challengeId,
    );
    notifyListeners();
  }

  /// Criar desafio
  Future<Challenge?> createChallenge({
    required String name,
    String? description,
    required String type,
    int durationDays = 7,
    int? targetDays,
    double? targetValue,
    int maxParticipants = 10,
  }) async {
    if (_token == null) return null;

    _isLoading = true;
    notifyListeners();

    try {
      final challenge = await ChallengeService.createChallenge(
        token: _token!,
        name: name,
        description: description,
        type: type,
        durationDays: durationDays,
        targetDays: targetDays,
        targetValue: targetValue,
        maxParticipants: maxParticipants,
      );

      if (challenge != null) {
        await loadOverview();
      }

      return challenge;
    } catch (e) {
      _error = 'Erro ao criar desafio: $e';
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Entrar no desafio
  Future<bool> joinChallenge(int challengeId) async {
    if (_token == null) return false;

    final success = await ChallengeService.joinChallenge(
      token: _token!,
      challengeId: challengeId,
    );

    if (success) {
      await loadOverview();
    }

    return success;
  }

  /// Entrar por código
  Future<bool> joinByCode(String code) async {
    if (_token == null) return false;

    final success = await ChallengeService.joinByCode(
      token: _token!,
      code: code,
    );

    if (success) {
      await loadOverview();
    }

    return success;
  }

  /// Sair do desafio
  Future<bool> leaveChallenge(int challengeId) async {
    if (_token == null) return false;

    final success = await ChallengeService.leaveChallenge(
      token: _token!,
      challengeId: challengeId,
    );

    if (success) {
      await loadOverview();
      _selectedChallenge = null;
    }

    return success;
  }

  /// Registrar progresso
  Future<DayPoints?> recordProgress({
    required int challengeId,
  }) async {
    if (_token == null) return null;

    final points = await ChallengeService.recordProgress(
      token: _token!,
      challengeId: challengeId,
    );

    if (points != null) {
      await loadOverview();
      await loadChallengeDetails(challengeId);
    }

    return points;
  }

  /// Limpar seleção
  void clearSelection() {
    _selectedChallenge = null;
    _leaderboard = [];
    notifyListeners();
  }

  /// Refresh
  Future<void> refresh() async {
    await loadOverview();
  }

  /// Carrega desafios para resumo e cards sociais
  Future<void> loadOverview() async {
    if (_token == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final results = await Future.wait([
        ChallengeService.getMyChallenges(token: _token!),
        ChallengeService.getPublicChallenges(token: _token!),
      ]);
      _myChallenges = results[0];
      _publicChallenges = results[1];
      _error = null;
    } catch (e) {
      _error = 'Erro ao carregar desafios: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
