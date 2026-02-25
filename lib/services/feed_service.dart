import 'dart:convert';
import 'package:http/http.dart' as http;
import '../util/app_constants.dart';
import 'social_service.dart';

/// Modelo de atividade no feed
class FeedActivity {
  final int id;
  final SimpleUser user;
  final String type;
  final Map<String, dynamic>? data;
  final bool isPrivate;
  final DateTime createdAt;
  final Map<String, int> reactionCounts;
  final Map<String, bool> userReacted;

  FeedActivity({
    required this.id,
    required this.user,
    required this.type,
    this.data,
    required this.isPrivate,
    required this.createdAt,
    required this.reactionCounts,
    required this.userReacted,
  });

  factory FeedActivity.fromJson(Map<String, dynamic> json) {
    return FeedActivity(
      id: json['id'] ?? 0,
      user: SimpleUser.fromJson(json['user'] ?? {}),
      type: json['type'] ?? '',
      data: json['data'],
      isPrivate: json['isPrivate'] ?? false,
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      reactionCounts: Map<String, int>.from(json['reactionCounts'] ?? {}),
      userReacted: Map<String, bool>.from(json['userReacted'] ?? {}),
    );
  }

  /// Mensagem formatada
  String get message {
    if (data != null && data!['message'] != null) {
      return data!['message'];
    }

    switch (type) {
      case 'CHECKIN_PROTEIN':
        return 'Bateu a meta de proteína! 💪';
      case 'CHECKIN_GOAL':
        return 'Dentro da meta calórica! 🎯';
      case 'CHECKIN_OVER':
        return 'Registrou o dia';
      case 'STREAK_MILESTONE':
        return 'Alcançou um marco de streak! 🔥';
      case 'FRIEND_STREAK':
        return 'Duo streak! 🤝';
      case 'CHALLENGE_JOIN':
        return 'Entrou em um desafio! 🏆';
      case 'CHALLENGE_WIN':
        return 'Ganhou um desafio! 🥇';
      default:
        return 'Atividade';
    }
  }

  /// Emoji principal
  String get emoji {
    switch (type) {
      case 'CHECKIN_PROTEIN':
        return '💪';
      case 'CHECKIN_GOAL':
        return '🎯';
      case 'CHECKIN_OVER':
        return '📝';
      case 'STREAK_MILESTONE':
        return '🔥';
      case 'FRIEND_STREAK':
        return '🤝';
      case 'CHALLENGE_JOIN':
        return '🏆';
      case 'CHALLENGE_WIN':
        return '🥇';
      default:
        return '📋';
    }
  }

  /// Total de reações
  int get totalReactions {
    return reactionCounts.values.fold(0, (a, b) => a + b);
  }

  /// Verificar se usuário reagiu com emoji específico
  bool hasReacted(String emoji) {
    return userReacted[emoji] == true;
  }

  /// Qualquer reação do usuário
  bool get hasAnyReaction {
    return userReacted.values.any((v) => v);
  }
}

/// Service para feed
class FeedService {
  static const String baseUrl = AppConstants.API_BASE_URL;

  /// Emojis de reação disponíveis
  static const List<String> availableEmojis = ['👏', '🔥', '💪', '😅', '❤️', '🎉'];

  /// Buscar feed
  static Future<List<FeedActivity>> getFeed({
    required String token,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/feed?page=$page&limit=$limit'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return (data['data'] as List)
              .map((a) => FeedActivity.fromJson(a))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('[FeedService] Erro ao buscar feed: $e');
      return [];
    }
  }

  /// Adicionar reação
  static Future<bool> addReaction({
    required String token,
    required int activityId,
    required String emoji,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/feed/$activityId/react'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'emoji': emoji}),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('[FeedService] Erro ao reagir: $e');
      return false;
    }
  }

  /// Remover reação
  static Future<bool> removeReaction({
    required String token,
    required int activityId,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/feed/$activityId/react'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      print('[FeedService] Erro ao remover reação: $e');
      return false;
    }
  }
}
