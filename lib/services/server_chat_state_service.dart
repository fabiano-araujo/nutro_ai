import 'dart:convert';

import 'package:http/http.dart' as http;

import '../util/app_constants.dart';

class ServerChatStateService {
  static final Uri _chatStateUri =
      Uri.parse('${AppConstants.API_BASE_URL}/ai/chat-state');
  static final Uri _chatCommandUri =
      Uri.parse('${AppConstants.API_BASE_URL}/ai/chat-command');

  Future<Map<String, dynamic>> fetchState({
    required String token,
  }) async {
    final response = await http.get(
      _chatStateUri,
      headers: _headers(token),
    );

    return _decodeResponse(
      response,
      fallbackMessage: 'Falha ao buscar o estado do chat no servidor',
    );
  }

  Future<Map<String, dynamic>> executeCommand({
    required String token,
    required String commandName,
    Map<String, dynamic> arguments = const {},
  }) async {
    final response = await http.post(
      _chatCommandUri,
      headers: _headers(token),
      body: jsonEncode({
        'commandName': commandName,
        'arguments': arguments,
      }),
    );

    return _decodeResponse(
      response,
      fallbackMessage: 'Falha ao executar o comando do chat no servidor',
    );
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
