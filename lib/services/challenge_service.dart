import 'dart:convert';
import 'package:http/http.dart' as http;
import '../util/app_constants.dart';
import 'social_service.dart';

/// Modelo de desafio
class Challenge {
  final int id;
  final int creatorId;
  final String name;
  final String? description;
  final String type;
  final int durationDays;
  final DateTime startDate;
  final DateTime endDate;
  final int maxParticipants;
  final String? joinCode;
  final bool isActive;
  final SimpleUser? creator;
  final int participantCount;
  final List<ChallengeParticipant>? participants;
  final MyParticipation? myParticipation;

  Challenge({
    required this.id,
    required this.creatorId,
    required this.name,
    this.description,
    required this.type,
    required this.durationDays,
    required this.startDate,
    required this.endDate,
    required this.maxParticipants,
    this.joinCode,
    required this.isActive,
    this.creator,
    this.participantCount = 0,
    this.participants,
    this.myParticipation,
  });

  factory Challenge.fromJson(Map<String, dynamic> json) {
    return Challenge(
      id: json['id'] ?? 0,
      creatorId: json['creatorId'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'],
      type: json['type'] ?? 'LOGGING_STREAK',
      durationDays: json['durationDays'] ?? 7,
      startDate: DateTime.parse(json['startDate'] ?? DateTime.now().toIso8601String()),
      endDate: DateTime.parse(json['endDate'] ?? DateTime.now().toIso8601String()),
      maxParticipants: json['maxParticipants'] ?? 10,
      joinCode: json['joinCode'],
      isActive: json['isActive'] ?? true,
      creator: json['creator'] != null ? SimpleUser.fromJson(json['creator']) : null,
      participantCount: json['participantCount'] ?? (json['participants'] as List?)?.length ?? 0,
      participants: json['participants'] != null
          ? (json['participants'] as List)
              .map((p) => ChallengeParticipant.fromJson(p))
              .toList()
          : null,
      myParticipation: json['myParticipation'] != null
          ? MyParticipation.fromJson(json['myParticipation'])
          : null,
    );
  }

  /// Dias restantes
  int get daysRemaining {
    final now = DateTime.now();
    return endDate.difference(now).inDays;
  }

  /// Tipo formatado
  String get typeFormatted {
    switch (type) {
      case 'LOGGING_STREAK':
        return 'Registrar Refeições';
      case 'PROTEIN_TARGET':
        return 'Bater Proteína';
      case 'CALORIE_DEFICIT':
        return 'Déficit Calórico';
      case 'FIBER_TARGET':
        return 'Meta de Fibra';
      default:
        return 'Personalizado';
    }
  }
}

/// Participante de desafio
class ChallengeParticipant {
  final int id;
  final SimpleUser user;
  final int totalPoints;
  final int currentStreak;
  final bool showMacros;

  ChallengeParticipant({
    required this.id,
    required this.user,
    required this.totalPoints,
    required this.currentStreak,
    required this.showMacros,
  });

  factory ChallengeParticipant.fromJson(Map<String, dynamic> json) {
    return ChallengeParticipant(
      id: json['id'] ?? 0,
      user: SimpleUser.fromJson(json['user'] ?? {}),
      totalPoints: json['totalPoints'] ?? 0,
      currentStreak: json['currentStreak'] ?? 0,
      showMacros: json['showMacros'] ?? true,
    );
  }
}

/// Minha participação
class MyParticipation {
  final int totalPoints;
  final int currentStreak;

  MyParticipation({
    required this.totalPoints,
    required this.currentStreak,
  });

  factory MyParticipation.fromJson(Map<String, dynamic> json) {
    return MyParticipation(
      totalPoints: json['totalPoints'] ?? 0,
      currentStreak: json['currentStreak'] ?? 0,
    );
  }
}

/// Ranking item
class LeaderboardItem {
  final int rank;
  final SimpleUser user;
  final int totalPoints;
  final int currentStreak;
  final bool showMacros;

  LeaderboardItem({
    required this.rank,
    required this.user,
    required this.totalPoints,
    required this.currentStreak,
    required this.showMacros,
  });

  factory LeaderboardItem.fromJson(Map<String, dynamic> json) {
    return LeaderboardItem(
      rank: json['rank'] ?? 0,
      user: SimpleUser.fromJson(json['user'] ?? {}),
      totalPoints: json['totalPoints'] ?? 0,
      currentStreak: json['currentStreak'] ?? 0,
      showMacros: json['showMacros'] ?? true,
    );
  }
}

/// Pontos do dia
class DayPoints {
  final int logged;
  final int protein;
  final int goal;
  final int streakBonus;
  final int total;

  DayPoints({
    required this.logged,
    required this.protein,
    required this.goal,
    required this.streakBonus,
    required this.total,
  });

  factory DayPoints.fromJson(Map<String, dynamic> json) {
    return DayPoints(
      logged: json['logged'] ?? 0,
      protein: json['protein'] ?? 0,
      goal: json['goal'] ?? 0,
      streakBonus: json['streakBonus'] ?? 0,
      total: json['total'] ?? 0,
    );
  }
}

/// Service para desafios
class ChallengeService {
  static const String baseUrl = AppConstants.API_BASE_URL;

  /// Listar meus desafios
  static Future<List<Challenge>> getMyChallenges({required String token}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/challenges'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return (data['data'] as List)
              .map((c) => Challenge.fromJson(c))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('[ChallengeService] Erro ao listar desafios: $e');
      return [];
    }
  }

  /// Desafios públicos
  static Future<List<Challenge>> getPublicChallenges({required String token}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/challenges/public'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return (data['data'] as List)
              .map((c) => Challenge.fromJson(c))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('[ChallengeService] Erro ao listar desafios públicos: $e');
      return [];
    }
  }

  /// Detalhes do desafio
  static Future<Challenge?> getChallengeDetails({
    required String token,
    required int challengeId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/challenges/$challengeId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return Challenge.fromJson(data['data']);
        }
      }
      return null;
    } catch (e) {
      print('[ChallengeService] Erro ao buscar detalhes: $e');
      return null;
    }
  }

  /// Criar desafio
  static Future<Challenge?> createChallenge({
    required String token,
    required String name,
    String? description,
    required String type,
    int durationDays = 7,
    int? targetDays,
    double? targetValue,
    int maxParticipants = 10,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/challenges'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'name': name,
          'description': description,
          'type': type,
          'durationDays': durationDays,
          'targetDays': targetDays,
          'targetValue': targetValue,
          'maxParticipants': maxParticipants,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return Challenge.fromJson(data['data']);
        }
      }
      return null;
    } catch (e) {
      print('[ChallengeService] Erro ao criar desafio: $e');
      return null;
    }
  }

  /// Entrar no desafio
  static Future<bool> joinChallenge({
    required String token,
    required int challengeId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/challenges/$challengeId/join'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      print('[ChallengeService] Erro ao entrar: $e');
      return false;
    }
  }

  /// Entrar por código
  static Future<bool> joinByCode({
    required String token,
    required String code,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/challenges/join/$code'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      print('[ChallengeService] Erro ao entrar por código: $e');
      return false;
    }
  }

  /// Sair do desafio
  static Future<bool> leaveChallenge({
    required String token,
    required int challengeId,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/challenges/$challengeId/leave'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      print('[ChallengeService] Erro ao sair: $e');
      return false;
    }
  }

  /// Ranking
  static Future<List<LeaderboardItem>> getLeaderboard({
    required String token,
    required int challengeId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/challenges/$challengeId/leaderboard'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return (data['data'] as List)
              .map((l) => LeaderboardItem.fromJson(l))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('[ChallengeService] Erro ao buscar ranking: $e');
      return [];
    }
  }

  /// Registrar progresso
  static Future<DayPoints?> recordProgress({
    required String token,
    required int challengeId,
    required bool logged,
    required bool hitProtein,
    required bool hitGoal,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/challenges/$challengeId/checkin'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'logged': logged,
          'hitProtein': hitProtein,
          'hitGoal': hitGoal,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return DayPoints.fromJson(data['data']);
        }
      }
      return null;
    } catch (e) {
      print('[ChallengeService] Erro ao registrar progresso: $e');
      return null;
    }
  }
}
