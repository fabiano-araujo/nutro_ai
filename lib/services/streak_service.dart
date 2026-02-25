import 'dart:convert';
import 'package:http/http.dart' as http;
import '../util/app_constants.dart';

/// Modelo de streak do usuário
class UserStreak {
  final int id;
  final int userId;

  // Streak de Registro
  final int registrationStreak;
  final DateTime? registrationLastDate;
  final int registrationBestStreak;

  // Streak de Proteína
  final int proteinStreak;
  final DateTime? proteinLastDate;
  final int proteinBestStreak;

  // Streak de Meta
  final int goalStreak;
  final DateTime? goalLastDate;
  final int goalBestStreak;

  // Freeze
  final int freezesAvailable;
  final DateTime? freezeActiveUntil;

  // Extras
  final int daysUntilStreakLoss;
  final bool isFreezeActive;

  UserStreak({
    required this.id,
    required this.userId,
    required this.registrationStreak,
    this.registrationLastDate,
    required this.registrationBestStreak,
    required this.proteinStreak,
    this.proteinLastDate,
    required this.proteinBestStreak,
    required this.goalStreak,
    this.goalLastDate,
    required this.goalBestStreak,
    required this.freezesAvailable,
    this.freezeActiveUntil,
    this.daysUntilStreakLoss = 0,
    this.isFreezeActive = false,
  });

  factory UserStreak.fromJson(Map<String, dynamic> json) {
    return UserStreak(
      id: json['id'] ?? 0,
      userId: json['userId'] ?? 0,
      registrationStreak: json['registrationStreak'] ?? 0,
      registrationLastDate: json['registrationLastDate'] != null
          ? DateTime.parse(json['registrationLastDate'])
          : null,
      registrationBestStreak: json['registrationBestStreak'] ?? 0,
      proteinStreak: json['proteinStreak'] ?? 0,
      proteinLastDate: json['proteinLastDate'] != null
          ? DateTime.parse(json['proteinLastDate'])
          : null,
      proteinBestStreak: json['proteinBestStreak'] ?? 0,
      goalStreak: json['goalStreak'] ?? 0,
      goalLastDate: json['goalLastDate'] != null
          ? DateTime.parse(json['goalLastDate'])
          : null,
      goalBestStreak: json['goalBestStreak'] ?? 0,
      freezesAvailable: json['freezesAvailable'] ?? 1,
      freezeActiveUntil: json['freezeActiveUntil'] != null
          ? DateTime.parse(json['freezeActiveUntil'])
          : null,
      daysUntilStreakLoss: json['daysUntilStreakLoss'] ?? 0,
      isFreezeActive: json['isFreezeActive'] ?? false,
    );
  }

  /// Retorna o melhor streak entre os 3 tipos
  int get bestOverallStreak {
    return [registrationBestStreak, proteinBestStreak, goalBestStreak]
        .reduce((a, b) => a > b ? a : b);
  }

  /// Verifica se o streak de registro está em perigo
  bool get isStreakInDanger => daysUntilStreakLoss == 1;
}

/// Service para operações de streak
class StreakService {
  static const String baseUrl = AppConstants.API_BASE_URL;

  /// Buscar meus streaks
  static Future<UserStreak?> getMyStreak({required String token}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/streak/me'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return UserStreak.fromJson(data['data']);
        }
      }

      return null;
    } catch (e) {
      print('[StreakService] Erro ao buscar streak: $e');
      return null;
    }
  }

  /// Realizar check-in
  static Future<UserStreak?> performCheckIn({required String token}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/streak/checkin'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return UserStreak.fromJson(data['data']);
        }
      }

      return null;
    } catch (e) {
      print('[StreakService] Erro ao fazer check-in: $e');
      return null;
    }
  }

  /// Ativar freeze
  static Future<UserStreak?> activateFreeze({required String token}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/streak/freeze'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return UserStreak.fromJson(data['data']);
        }
      }

      return null;
    } catch (e) {
      print('[StreakService] Erro ao ativar freeze: $e');
      return null;
    }
  }

  /// Buscar streak de outro usuário
  static Future<UserStreak?> getUserStreak({
    required String token,
    required int userId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/streak/user/$userId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return UserStreak.fromJson(data['data']);
        }
      }

      return null;
    } catch (e) {
      print('[StreakService] Erro ao buscar streak do usuário: $e');
      return null;
    }
  }
}
