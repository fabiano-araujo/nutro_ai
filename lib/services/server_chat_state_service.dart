import 'dart:convert';

import 'package:http/http.dart' as http;

import 'app_integrity_service.dart';
import 'app_debug_log_service.dart';
import '../util/app_constants.dart';

class ServerChatStateService {
  static final Uri _chatStateUri =
      Uri.parse('${AppConstants.API_BASE_URL}/ai/chat-state');
  static final Uri _chatCommandUri =
      Uri.parse('${AppConstants.API_BASE_URL}/ai/chat-command');

  Future<Map<String, dynamic>> fetchState({
    required String token,
  }) async {
    AppDebugLogService.add('APP_SERVER_CHAT_STATE', 'fetch_state_request', {
      'url': _chatStateUri.toString(),
    });
    final response = await http.get(
      _chatStateUri,
      headers: await _headers(token),
    );
    AppDebugLogService.add('APP_SERVER_CHAT_STATE', 'fetch_state_response', {
      'status': response.statusCode,
      'bodyPreview': _preview(response.body),
    });

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
    final requestBody = jsonEncode({
      'commandName': commandName,
      'arguments': arguments,
    });
    AppDebugLogService.add('APP_SERVER_CHAT_STATE', 'execute_command_request', {
      'url': _chatCommandUri.toString(),
      'bodyPreview': _preview(requestBody),
    });
    final response = await http.post(
      _chatCommandUri,
      headers: await _headers(token),
      body: requestBody,
    );
    AppDebugLogService.add(
        'APP_SERVER_CHAT_STATE', 'execute_command_response', {
      'status': response.statusCode,
      'bodyPreview': _preview(response.body),
    });

    return _decodeResponse(
      response,
      fallbackMessage: 'Falha ao executar o comando do chat no servidor',
    );
  }

  Future<Map<String, String>> _headers(String token) async => {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        ...await AppIntegrityService.appCheckHeaders(),
      };

  Map<String, dynamic> _decodeResponse(
    http.Response response, {
    required String fallbackMessage,
  }) {
    final dynamic decoded =
        response.body.isEmpty ? const {} : _decodeJsonBody(response.body);
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

  dynamic _decodeJsonBody(String body) {
    try {
      return jsonDecode(body);
    } catch (error) {
      AppDebugLogService.add('APP_SERVER_CHAT_STATE', 'parse_error', {
        'error': error.toString(),
        'bodyPreview': _preview(body),
      });
      rethrow;
    }
  }

  String _preview(String value, {int maxChars = 600}) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= maxChars) {
      return normalized;
    }
    return '${normalized.substring(0, maxChars)}...';
  }
}
