import 'package:flutter/material.dart';

/// Notifier para controle de mensagens em streaming
/// Permite atualizar o conteúdo de uma mensagem em tempo real
/// e notificar os widgets interessados sobre mudanças no estado
class MessageNotifier extends ChangeNotifier {
  String _message = '';
  String _displayMessage = '';
  bool _isStreaming = true;
  bool _isError = false;

  /// Obtém o conteúdo atual da mensagem
  String get message => _message;

  /// Obtém o conteúdo que deve ser exibido na UI.
  String get displayMessage => _displayMessage;

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
  void updateMessage(String newContent, {String? displayContent}) {
    final nextDisplay = displayContent ?? newContent;

    if (_message == newContent && _displayMessage == nextDisplay) {
      return;
    }

    _message = newContent;
    _displayMessage = nextDisplay;
    notifyListeners();
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
      _displayMessage = errorMessage;
    } else if (error && _message.isEmpty) {
      _message = "Ocorreu um erro ao processar sua solicitação.";
      _displayMessage = _message;
    }
    notifyListeners();
  }
}
