import 'dart:convert';

import 'package:http/http.dart' as http;

import '../util/app_constants.dart';

class UserAppStateService {
  static final Uri _appStateUri =
      Uri.parse('${AppConstants.API_BASE_URL}/user/app-state');

  Future<Map<String, dynamic>> fetchAppState({
    required String token,
    String? nutritionChatDateKey,
    bool lightweight = false,
  }) async {
    final query = <String, String>{
      ..._appStateUri.queryParameters,
      if (nutritionChatDateKey != null)
        'nutritionChatDate': nutritionChatDateKey,
      if (lightweight) 'lightweight': 'true',
    };
    final uri = query.isEmpty
        ? _appStateUri
        : _appStateUri.replace(queryParameters: query);

    final response = await http
        .get(
          uri,
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 12));

    return _decodeResponse(
      response,
      fallbackMessage: 'Falha ao buscar os dados do usuário',
    );
  }

  Future<Map<String, dynamic>> syncAppState({
    required String token,
    Map<String, dynamic>? goalSetup,
    Map<String, dynamic>? macroTargets,
    Map<String, dynamic>? dietGenerationPreferences,
    List<Map<String, dynamic>>? freeChatConversations,
    List<Map<String, dynamic>>? mealTypes,
    Map<String, dynamic>? foodHistory,
    Map<String, dynamic>? nutritionChatByDate,
    String? nutritionChatDateKey,
  }) async {
    final body = <String, dynamic>{
      if (goalSetup != null) 'goalSetup': goalSetup,
      if (macroTargets != null) 'macroTargets': macroTargets,
      if (dietGenerationPreferences != null)
        'dietGenerationPreferences': dietGenerationPreferences,
      if (freeChatConversations != null)
        'freeChatConversations': freeChatConversations,
      if (mealTypes != null) 'mealTypes': mealTypes,
      if (foodHistory != null) 'foodHistory': foodHistory,
      if (nutritionChatByDate != null)
        'nutritionChatByDate': nutritionChatByDate,
    };

    final response = await http
        .put(
          nutritionChatDateKey == null
              ? _appStateUri
              : _appStateUri.replace(queryParameters: {
                  ..._appStateUri.queryParameters,
                  'nutritionChatDate': nutritionChatDateKey,
                }),
          headers: _headers(token),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 12));

    return _decodeResponse(
      response,
      fallbackMessage: 'Falha ao sincronizar os dados do usuário',
    );
  }

  static String formatDateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

  Map<String, dynamic> _decodeResponse(
    http.Response response, {
    required String fallbackMessage,
  }) {
    final dynamic decoded =
        response.body.isEmpty ? const {} : jsonDecode(response.body);
    final json =
        decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = json['data'];
      if (data is Map<String, dynamic>) {
        return data;
      }
      return json;
    }

    final message = json['message']?.toString() ??
        json['error']?.toString() ??
        fallbackMessage;
    throw Exception(message);
  }
}
