import 'package:flutter/material.dart';
import '../services/feed_service.dart';

/// Provider para gerenciar feed social
class FeedProvider extends ChangeNotifier {
  String? _token;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;

  List<FeedActivity> _activities = [];
  final Set<int> _hiddenActivityIds = {};
  int _currentPage = 1;
  bool _hasMore = true;

  // Getters
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get error => _error;
  List<FeedActivity> get activities => _activities;
  bool get hasMore => _hasMore;
  bool get isEmpty => _activities.isEmpty && !_isLoading;

  /// Configura o token
  void setToken(String token) {
    _token = token;
    loadFeed();
  }

  /// Limpa os dados
  void clearAuth() {
    _token = null;
    _activities = [];
    _hiddenActivityIds.clear();
    _currentPage = 1;
    _hasMore = true;
    notifyListeners();
  }

  /// Carrega o feed
  Future<void> loadFeed() async {
    if (_token == null) return;

    _isLoading = true;
    _currentPage = 1;
    notifyListeners();

    try {
      final loadedActivities = await FeedService.getFeed(
        token: _token!,
        page: 1,
      );
      _activities = loadedActivities
          .where((activity) => !_hiddenActivityIds.contains(activity.id))
          .toList();
      _hasMore = loadedActivities.length >= 20;
      _error = null;
    } catch (e) {
      _error = 'Erro ao carregar feed: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Carregar mais
  Future<void> loadMore() async {
    if (_token == null || _isLoadingMore || !_hasMore) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final nextPage = _currentPage + 1;
      final newActivities = await FeedService.getFeed(
        token: _token!,
        page: nextPage,
      );

      final visibleActivities = newActivities
          .where((activity) => !_hiddenActivityIds.contains(activity.id))
          .toList();

      if (newActivities.isNotEmpty) {
        _activities.addAll(visibleActivities);
        _currentPage = nextPage;
        _hasMore = newActivities.length >= 20;
      } else {
        _hasMore = false;
      }
    } catch (e) {
      _error = 'Erro ao carregar mais: $e';
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Adicionar reação
  Future<bool> addReaction(int activityId, String emoji) async {
    if (_token == null) return false;

    final success = await FeedService.addReaction(
      token: _token!,
      activityId: activityId,
      emoji: emoji,
    );

    if (success) {
      // Atualizar localmente
      final index = _activities.indexWhere((a) => a.id == activityId);
      if (index != -1) {
        final activity = _activities[index];
        final newReactionCounts =
            Map<String, int>.from(activity.reactionCounts);
        final newUserReacted = Map<String, bool>.from(activity.userReacted);

        // Remover reação anterior se existir
        newUserReacted.forEach((key, value) {
          if (value && key != emoji) {
            newReactionCounts[key] = (newReactionCounts[key] ?? 1) - 1;
            newUserReacted[key] = false;
          }
        });

        // Adicionar nova reação
        newReactionCounts[emoji] = (newReactionCounts[emoji] ?? 0) + 1;
        newUserReacted[emoji] = true;

        _activities[index] = FeedActivity(
          id: activity.id,
          user: activity.user,
          type: activity.type,
          data: activity.data,
          isPrivate: activity.isPrivate,
          createdAt: activity.createdAt,
          reactionCounts: newReactionCounts,
          userReacted: newUserReacted,
        );

        notifyListeners();
      }
    }

    return success;
  }

  /// Remover reação
  Future<bool> removeReaction(int activityId) async {
    if (_token == null) return false;

    final success = await FeedService.removeReaction(
      token: _token!,
      activityId: activityId,
    );

    if (success) {
      // Atualizar localmente
      final index = _activities.indexWhere((a) => a.id == activityId);
      if (index != -1) {
        final activity = _activities[index];
        final newReactionCounts =
            Map<String, int>.from(activity.reactionCounts);
        final newUserReacted = Map<String, bool>.from(activity.userReacted);

        // Remover todas as reações do usuário
        newUserReacted.forEach((key, value) {
          if (value) {
            newReactionCounts[key] = (newReactionCounts[key] ?? 1) - 1;
            newUserReacted[key] = false;
          }
        });

        _activities[index] = FeedActivity(
          id: activity.id,
          user: activity.user,
          type: activity.type,
          data: activity.data,
          isPrivate: activity.isPrivate,
          createdAt: activity.createdAt,
          reactionCounts: newReactionCounts,
          userReacted: newUserReacted,
        );

        notifyListeners();
      }
    }

    return success;
  }

  /// Toggle reação
  Future<void> toggleReaction(int activityId, String emoji) async {
    final activity = _activities.firstWhere(
      (a) => a.id == activityId,
      orElse: () => throw Exception('Activity not found'),
    );

    if (activity.hasReacted(emoji)) {
      await removeReaction(activityId);
    } else {
      await addReaction(activityId, emoji);
    }
  }

  void hideActivity(int activityId) {
    _hiddenActivityIds.add(activityId);
    _activities.removeWhere((activity) => activity.id == activityId);
    notifyListeners();
  }

  void removeActivitiesByUser(int userId) {
    _activities.removeWhere((activity) => activity.user.id == userId);
    notifyListeners();
  }

  Future<bool> deleteActivity(int activityId) async {
    if (_token == null) return false;

    final success = await FeedService.deleteActivity(
      token: _token!,
      activityId: activityId,
    );

    if (success) {
      _activities.removeWhere((activity) => activity.id == activityId);
      _hiddenActivityIds.remove(activityId);
      _error = null;
      notifyListeners();
      return true;
    }

    _error = 'Erro ao excluir publicação';
    notifyListeners();
    return false;
  }

  Future<bool> publishProfileShapePreview({
    required String afterImageUrl,
    String? beforeImageBase64,
    required String mode,
  }) async {
    if (_token == null) return false;

    final activity = await FeedService.publishProfileShapePreview(
      token: _token!,
      afterImageUrl: afterImageUrl,
      beforeImageBase64: beforeImageBase64,
      mode: mode,
    );

    if (activity == null) {
      _error = 'Erro ao publicar prévia no feed';
      notifyListeners();
      return false;
    }

    _activities.insert(0, activity);
    _error = null;
    notifyListeners();
    return true;
  }

  /// Refresh
  Future<void> refresh() async {
    await loadFeed();
  }
}
