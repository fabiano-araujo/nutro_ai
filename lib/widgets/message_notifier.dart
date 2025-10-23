import 'package:flutter/material.dart';

/// Notifier para controle de mensagens em streaming
/// Permite atualizar o conteúdo de uma mensagem em tempo real
/// e notificar os widgets interessados sobre mudanças no estado
class MessageNotifier extends ChangeNotifier {
  String _message = '';
  bool _isStreaming = true;
  bool _isError = false;

  /// Obtém o conteúdo atual da mensagem
  String get message => _message;

  /// Verifica se a mensagem está em modo streaming
  bool get isStreaming => _isStreaming;

  /// Verifica se ocorreu um erro durante o processamento da mensagem
  bool get isError => _isError;

  /// Verifica se a mensagem contém fórmulas matemáticas
  bool get containsFormulas {
    return _message.contains('\\') ||
        _message.contains('\$') ||
        _message.contains('\\frac') ||
        _message.contains('\\sqrt');
  }

  /// Atualiza o conteúdo da mensagem e notifica ouvintes
  void updateMessage(String newContent) {
    if (newContent.isNotEmpty) {
      _message = newContent;
      notifyListeners();
    }
  }

  /// Define o estado de streaming da mensagem
  void setStreaming(bool streaming) {
    _isStreaming = streaming;
    notifyListeners();
  }

  /// Define o estado de erro da mensagem, opcionalmente com uma mensagem de erro
  void setError(bool error, [String? errorMessage]) {
    _isError = error;
    if (errorMessage != null && errorMessage.isNotEmpty) {
      _message = errorMessage;
    } else if (error && _message.isEmpty) {
      _message = "Ocorreu um erro ao processar sua solicitação.";
    }
    notifyListeners();
  }
}
