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

class StreakCheckInEvent {
  final int id;
  final DateTime checkInDate;
  final int previousStreak;
  final int currentStreak;
  final DateTime? protectedMissedDate;
  final int freezesUsed;
  final int freezesRecovered;
  final int freezesEarned;
  final int freezesBefore;
  final int freezesAfter;

  const StreakCheckInEvent({
    required this.id,
    required this.checkInDate,
    required this.previousStreak,
    required this.currentStreak,
    required this.protectedMissedDate,
    required this.freezesUsed,
    required this.freezesRecovered,
    required this.freezesEarned,
    required this.freezesBefore,
    required this.freezesAfter,
  });

  bool get freezeRecovered => freezesRecovered > 0;

  factory StreakCheckInEvent.fromJson(Map<String, dynamic> json) {
    return StreakCheckInEvent(
      id: (json['id'] as num?)?.toInt() ?? 0,
      checkInDate: DateTime.parse(json['checkInDate'].toString()),
      previousStreak: (json['previousStreak'] as num?)?.toInt() ?? 0,
      currentStreak: (json['currentStreak'] as num?)?.toInt() ?? 1,
      protectedMissedDate: json['protectedMissedDate'] == null
          ? null
          : DateTime.parse(json['protectedMissedDate'].toString()),
      freezesUsed: (json['freezesUsed'] as num?)?.toInt() ?? 0,
      freezesRecovered: (json['freezesRecovered'] as num?)?.toInt() ?? 0,
      freezesEarned: (json['freezesEarned'] as num?)?.toInt() ?? 0,
      freezesBefore: (json['freezesBefore'] as num?)?.toInt() ?? 0,
      freezesAfter: (json['freezesAfter'] as num?)?.toInt() ?? 0,
    );
  }
}

class StreakLoadResult {
  final UserStreak streak;
  final StreakCheckInEvent? pendingEvent;

  const StreakLoadResult({required this.streak, this.pendingEvent});
}

class StreakCheckInResult {
  final UserStreak streak;
  final StreakCheckInEvent? event;
  final bool didAdvance;

  const StreakCheckInResult({
    required this.streak,
    this.event,
    required this.didAdvance,
  });
}

/// Service para operações de streak
class StreakService {
  static const String baseUrl = AppConstants.API_BASE_URL;

  /// Buscar meus streaks
  static Future<StreakLoadResult?> getMyStreak({required String token}) async {
    try {
      final localDate = _formatDate(DateTime.now());
      final response = await http.get(
        Uri.parse('$baseUrl/streak/me?localDate=$localDate'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final pendingJson = data['pendingEvent'];
          return StreakLoadResult(
            streak: UserStreak.fromJson(data['data']),
            pendingEvent: pendingJson is Map
                ? StreakCheckInEvent.fromJson(
                    pendingJson.cast<String, dynamic>(),
                  )
                : null,
          );
        }
      }

      return null;
    } catch (e) {
      print('[StreakService] Erro ao buscar streak: $e');
      return null;
    }
  }

  /// Realizar check-in
  static Future<StreakCheckInResult?> performCheckIn({
    required String token,
    DateTime? localDate,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/streak/checkin'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, dynamic>{
          'localDate': _formatDate(localDate ?? DateTime.now()),
          'timeZoneOffsetMinutes':
              (localDate ?? DateTime.now()).timeZoneOffset.inMinutes,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final eventJson = data['event'];
          return StreakCheckInResult(
            streak: UserStreak.fromJson(data['data']),
            event: eventJson is Map
                ? StreakCheckInEvent.fromJson(
                    eventJson.cast<String, dynamic>(),
                  )
                : null,
            didAdvance: data['didAdvance'] == true,
          );
        }
      }

      return null;
    } catch (e) {
      print('[StreakService] Erro ao fazer check-in: $e');
      return null;
    }
  }

  static Future<bool> acknowledgeEvent({
    required String token,
    required int eventId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/streak/events/$eventId/ack'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, dynamic>{}),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('[StreakService] Erro ao confirmar evento $eventId: $e');
      return false;
    }
  }

  static String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  /// Ativar freeze
  static Future<({UserStreak? streak, String? error})> activateFreeze({
    required String token,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/streak/freeze'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, dynamic>{}),
      );

      print(
        '[StreakService] activateFreeze status=${response.statusCode} body=${response.body}',
      );

      Map<String, dynamic>? data;
      try {
        data = jsonDecode(response.body) as Map<String, dynamic>?;
      } catch (_) {
        data = null;
      }

      if (response.statusCode == 200 &&
          data != null &&
          data['success'] == true &&
          data['data'] != null) {
        return (
          streak: UserStreak.fromJson(data['data']),
          error: null,
        );
      }

      final serverError = (data?['error'] ?? data?['message'])?.toString();
      return (
        streak: null,
        error: serverError ?? 'HTTP ${response.statusCode}',
      );
    } catch (e) {
      print('[StreakService] Erro ao ativar freeze: $e');
      return (streak: null, error: e.toString());
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
