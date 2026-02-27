import 'dart:convert';
import 'package:http/http.dart' as http;
import '../util/app_constants.dart';

/// Modelo de usuário simplificado
class SimpleUser {
  final int id;
  final String name;
  final String? photo;
  final String? username;

  SimpleUser({
    required this.id,
    required this.name,
    this.photo,
    this.username,
  });

  factory SimpleUser.fromJson(Map<String, dynamic> json) {
    return SimpleUser(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      photo: json['photo'],
      username: json['username'],
    );
  }
}

/// Modelo de FriendStreak
class FriendStreak {
  final int id;
  final int currentStreak;
  final int bestStreak;
  final bool user1CheckedIn;
  final bool user2CheckedIn;

  FriendStreak({
    required this.id,
    required this.currentStreak,
    required this.bestStreak,
    required this.user1CheckedIn,
    required this.user2CheckedIn,
  });

  factory FriendStreak.fromJson(Map<String, dynamic> json) {
    return FriendStreak(
      id: json['id'] ?? 0,
      currentStreak: json['currentStreak'] ?? 0,
      bestStreak: json['bestStreak'] ?? 0,
      user1CheckedIn: json['user1CheckedIn'] ?? false,
      user2CheckedIn: json['user2CheckedIn'] ?? false,
    );
  }
}

/// Modelo de amigo
class Friend {
  final int friendshipId;
  final SimpleUser friend;
  final FriendStreak? friendStreak;
  final DateTime since;

  Friend({
    required this.friendshipId,
    required this.friend,
    this.friendStreak,
    required this.since,
  });

  factory Friend.fromJson(Map<String, dynamic> json) {
    return Friend(
      friendshipId: json['friendshipId'] ?? 0,
      friend: SimpleUser.fromJson(json['friend'] ?? {}),
      friendStreak: json['friendStreak'] != null
          ? FriendStreak.fromJson(json['friendStreak'])
          : null,
      since: DateTime.parse(json['since'] ?? DateTime.now().toIso8601String()),
    );
  }
}

/// Modelo de pedido de amizade
class FriendRequest {
  final int id;
  final SimpleUser user;
  final DateTime createdAt;

  FriendRequest({
    required this.id,
    required this.user,
    required this.createdAt,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> json, bool isReceived) {
    return FriendRequest(
      id: json['id'] ?? 0,
      user: SimpleUser.fromJson(
        isReceived ? json['requester'] ?? {} : json['addressee'] ?? {},
      ),
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}

/// Modelo de usuário buscado
class SearchedUser {
  final int id;
  final String name;
  final String? photo;
  final String? username;
  final String? friendshipStatus;
  final int? friendshipId;
  final bool isRequester;

  SearchedUser({
    required this.id,
    required this.name,
    this.photo,
    this.username,
    this.friendshipStatus,
    this.friendshipId,
    this.isRequester = false,
  });

  factory SearchedUser.fromJson(Map<String, dynamic> json) {
    return SearchedUser(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      photo: json['photo'],
      username: json['username'],
      friendshipStatus: json['friendshipStatus'],
      friendshipId: json['friendshipId'],
      isRequester: json['isRequester'] ?? false,
    );
  }
}

/// Modelo de Duo Streak
class DuoStreak {
  final int friendshipId;
  final SimpleUser friend;
  final FriendStreak? friendStreak;
  final bool myCheckIn;
  final bool friendCheckIn;

  DuoStreak({
    required this.friendshipId,
    required this.friend,
    this.friendStreak,
    required this.myCheckIn,
    required this.friendCheckIn,
  });

  factory DuoStreak.fromJson(Map<String, dynamic> json) {
    return DuoStreak(
      friendshipId: json['friendshipId'] ?? 0,
      friend: SimpleUser.fromJson(json['friend'] ?? {}),
      friendStreak: json['friendStreak'] != null
          ? FriendStreak.fromJson(json['friendStreak'])
          : null,
      myCheckIn: json['myCheckIn'] ?? false,
      friendCheckIn: json['friendCheckIn'] ?? false,
    );
  }
}

/// Modelo de Ping
class BuddyPing {
  final int id;
  final SimpleUser sender;
  final String? message;
  final bool seen;
  final DateTime createdAt;

  BuddyPing({
    required this.id,
    required this.sender,
    this.message,
    required this.seen,
    required this.createdAt,
  });

  factory BuddyPing.fromJson(Map<String, dynamic> json) {
    return BuddyPing(
      id: json['id'] ?? 0,
      sender: SimpleUser.fromJson(json['sender'] ?? {}),
      message: json['message'],
      seen: json['seen'] ?? false,
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}

/// Service para operações sociais (amigos, duo, ping)
class SocialService {
  static const String baseUrl = AppConstants.API_BASE_URL;

  // ========== AMIGOS ==========

  /// Listar amigos
  static Future<List<Friend>> getFriends({required String token}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/friends'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return (data['data'] as List)
              .map((f) => Friend.fromJson(f))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('[SocialService] Erro ao listar amigos: $e');
      return [];
    }
  }

  /// Pedidos pendentes
  static Future<Map<String, List<FriendRequest>>> getPendingRequests({
    required String token,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/friends/requests'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return {
            'received': (data['data']['received'] as List)
                .map((r) => FriendRequest.fromJson(r, true))
                .toList(),
            'sent': (data['data']['sent'] as List)
                .map((r) => FriendRequest.fromJson(r, false))
                .toList(),
          };
        }
      }
      return {'received': [], 'sent': []};
    } catch (e) {
      print('[SocialService] Erro ao listar pedidos: $e');
      return {'received': [], 'sent': []};
    }
  }

  /// Buscar usuários
  static Future<List<SearchedUser>> searchUsers({
    required String token,
    required String query,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/friends/search?q=$query'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return (data['data'] as List)
              .map((u) => SearchedUser.fromJson(u))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('[SocialService] Erro ao buscar usuários: $e');
      return [];
    }
  }

  /// Enviar pedido de amizade
  static Future<bool> sendFriendRequest({
    required String token,
    required int addresseeId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/friends/request'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'addresseeId': addresseeId}),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('[SocialService] Erro ao enviar pedido: $e');
      return false;
    }
  }

  /// Aceitar pedido
  static Future<bool> acceptFriendRequest({
    required String token,
    required int friendshipId,
  }) async {
    try {
      final url = '$baseUrl/friends/accept/$friendshipId';
      print('[SocialService] Accepting friend request: POST $url');
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('[SocialService] Accept response: ${response.statusCode} - ${response.body}');
      return response.statusCode == 200;
    } catch (e) {
      print('[SocialService] Erro ao aceitar pedido: $e');
      return false;
    }
  }

  /// Rejeitar pedido
  static Future<bool> rejectFriendRequest({
    required String token,
    required int friendshipId,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/friends/request/$friendshipId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      print('[SocialService] Erro ao rejeitar pedido: $e');
      return false;
    }
  }

  /// Remover amigo
  static Future<bool> removeFriend({
    required String token,
    required int friendshipId,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/friends/$friendshipId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      print('[SocialService] Erro ao remover amigo: $e');
      return false;
    }
  }

  // ========== DUO STREAK ==========

  /// Listar duo streaks
  static Future<List<DuoStreak>> getDuoStreaks({required String token}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/duo/all'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return (data['data'] as List)
              .map((d) => DuoStreak.fromJson(d))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('[SocialService] Erro ao listar duo streaks: $e');
      return [];
    }
  }

  /// Check-in no duo
  static Future<bool> duoCheckIn({
    required String token,
    required int friendshipId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/duo/$friendshipId/checkin'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      print('[SocialService] Erro no duo check-in: $e');
      return false;
    }
  }

  // ========== PING ==========

  /// Enviar ping
  static Future<bool> sendPing({
    required String token,
    required int receiverId,
    String? message,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/ping'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'receiverId': receiverId,
          'message': message,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('[SocialService] Erro ao enviar ping: $e');
      return false;
    }
  }

  /// Pings recebidos
  static Future<Map<String, dynamic>> getReceivedPings({
    required String token,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/ping/received'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return {
            'pings': (data['data']['pings'] as List)
                .map((p) => BuddyPing.fromJson(p))
                .toList(),
            'unseenCount': data['data']['unseenCount'] ?? 0,
          };
        }
      }
      return {'pings': <BuddyPing>[], 'unseenCount': 0};
    } catch (e) {
      print('[SocialService] Erro ao listar pings: $e');
      return {'pings': <BuddyPing>[], 'unseenCount': 0};
    }
  }

  /// Marcar ping como visto
  static Future<bool> markPingSeen({
    required String token,
    required int pingId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/ping/$pingId/seen'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      print('[SocialService] Erro ao marcar ping: $e');
      return false;
    }
  }
}
