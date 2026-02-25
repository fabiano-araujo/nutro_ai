import 'package:flutter/material.dart';
import '../services/social_service.dart';

/// Provider para gerenciar amigos, duo streaks e pings
class FriendsProvider extends ChangeNotifier {
  String? _token;
  bool _isLoading = false;
  String? _error;

  List<Friend> _friends = [];
  List<FriendRequest> _receivedRequests = [];
  List<FriendRequest> _sentRequests = [];
  List<DuoStreak> _duoStreaks = [];
  List<BuddyPing> _pings = [];
  int _unseenPingsCount = 0;

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Friend> get friends => _friends;
  List<FriendRequest> get receivedRequests => _receivedRequests;
  List<FriendRequest> get sentRequests => _sentRequests;
  List<DuoStreak> get duoStreaks => _duoStreaks;
  List<BuddyPing> get pings => _pings;
  int get unseenPingsCount => _unseenPingsCount;
  bool get hasPendingRequests => _receivedRequests.isNotEmpty;

  /// Configura o token de autenticação
  void setToken(String token) {
    _token = token;
    loadAll();
  }

  /// Limpa os dados
  void clearAuth() {
    _token = null;
    _friends = [];
    _receivedRequests = [];
    _sentRequests = [];
    _duoStreaks = [];
    _pings = [];
    _unseenPingsCount = 0;
    notifyListeners();
  }

  /// Carrega todos os dados
  Future<void> loadAll() async {
    if (_token == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      await Future.wait([
        loadFriends(),
        loadRequests(),
        loadDuoStreaks(),
        loadPings(),
      ]);
    } catch (e) {
      _error = 'Erro ao carregar dados: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Carrega lista de amigos
  Future<void> loadFriends() async {
    if (_token == null) return;
    _friends = await SocialService.getFriends(token: _token!);
    notifyListeners();
  }

  /// Carrega pedidos pendentes
  Future<void> loadRequests() async {
    if (_token == null) return;
    final requests = await SocialService.getPendingRequests(token: _token!);
    _receivedRequests = requests['received'] ?? [];
    _sentRequests = requests['sent'] ?? [];
    notifyListeners();
  }

  /// Carrega duo streaks
  Future<void> loadDuoStreaks() async {
    if (_token == null) return;
    _duoStreaks = await SocialService.getDuoStreaks(token: _token!);
    notifyListeners();
  }

  /// Carrega pings
  Future<void> loadPings() async {
    if (_token == null) return;
    final result = await SocialService.getReceivedPings(token: _token!);
    _pings = (result['pings'] as List).cast<BuddyPing>();
    _unseenPingsCount = result['unseenCount'] ?? 0;
    notifyListeners();
  }

  /// Buscar usuários
  Future<List<SearchedUser>> searchUsers(String query) async {
    if (_token == null) return [];
    return await SocialService.searchUsers(token: _token!, query: query);
  }

  /// Enviar pedido de amizade
  Future<bool> sendFriendRequest(int addresseeId) async {
    if (_token == null) return false;
    final success = await SocialService.sendFriendRequest(
      token: _token!,
      addresseeId: addresseeId,
    );
    if (success) {
      await loadRequests();
    }
    return success;
  }

  /// Aceitar pedido
  Future<bool> acceptRequest(int friendshipId) async {
    if (_token == null) return false;
    final success = await SocialService.acceptFriendRequest(
      token: _token!,
      friendshipId: friendshipId,
    );
    if (success) {
      await loadAll();
    }
    return success;
  }

  /// Rejeitar pedido
  Future<bool> rejectRequest(int friendshipId) async {
    if (_token == null) return false;
    final success = await SocialService.rejectFriendRequest(
      token: _token!,
      friendshipId: friendshipId,
    );
    if (success) {
      await loadRequests();
    }
    return success;
  }

  /// Remover amigo
  Future<bool> removeFriend(int friendshipId) async {
    if (_token == null) return false;
    final success = await SocialService.removeFriend(
      token: _token!,
      friendshipId: friendshipId,
    );
    if (success) {
      await loadFriends();
    }
    return success;
  }

  /// Duo check-in
  Future<bool> duoCheckIn(int friendshipId) async {
    if (_token == null) return false;
    final success = await SocialService.duoCheckIn(
      token: _token!,
      friendshipId: friendshipId,
    );
    if (success) {
      await loadDuoStreaks();
    }
    return success;
  }

  /// Enviar ping
  Future<bool> sendPing(int receiverId, {String? message}) async {
    if (_token == null) return false;
    return await SocialService.sendPing(
      token: _token!,
      receiverId: receiverId,
      message: message,
    );
  }

  /// Marcar ping como visto
  Future<void> markPingSeen(int pingId) async {
    if (_token == null) return;
    await SocialService.markPingSeen(token: _token!, pingId: pingId);
    await loadPings();
  }

  /// Refresh
  Future<void> refresh() async {
    await loadAll();
  }
}
