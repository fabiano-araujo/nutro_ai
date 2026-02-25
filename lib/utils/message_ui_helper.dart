import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:typed_data';
import '../theme/app_theme.dart';
import '../utils/code_detector.dart';
import '../utils/message_formatter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Classe utilitária para construir elementos de UI relacionados a mensagens
class MessageUIHelper {
  /// Constrói o indicador de digitação (três pontos animados)
  static Widget buildTypingIndicator() {
    return Row(
      children: List.generate(
        3,
        (index) => Container(
          margin: EdgeInsets.symmetric(horizontal: 2),
          height: 6,
          width: 6,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.5),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  /// Formata a timestamp da mensagem
  static String formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(Duration(days: 1));
    final dateToCheck =
        DateTime(timestamp.year, timestamp.month, timestamp.day);

    if (dateToCheck == today) {
      return 'Hoje ${_formatTime(timestamp)}';
    } else if (dateToCheck == yesterday) {
      return 'Ontem ${_formatTime(timestamp)}';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year} ${_formatTime(timestamp)}';
    }
  }

  /// Formata a hora da timestamp
  static String _formatTime(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }

  /// Constrói o ícone pulsante para a interface de gravação de voz
  static Widget buildPulsatingIcon(AnimationController animationController) {
    return AnimatedBuilder(
      animation: animationController,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Círculo interior que pulsa mais rápido
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.errorColor
                    .withOpacity(animationController.value * 0.7 + 0.3),
              ),
            ),
            // Círculo exterior para feedback adicional
            if (!kIsWeb && Platform.isAndroid)
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.transparent,
                  border: Border.all(
                    color: AppTheme.errorColor
                        .withOpacity(0.5 - (animationController.value * 0.2)),
                    width: 1.5,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// Constrói uma bolha de mensagem simples
  static Widget buildSimpleMessageBubble({
    required BuildContext context,
    required String message,
    required bool isUser,
    required bool isError,
    required bool isStreaming,
    required VoidCallback onLongPress,
    Uint8List? imageBytes,
    double bottomSpacing = 8,
  }) {
    final double safeBottomSpacing =
        bottomSpacing < 0 ? 0 : bottomSpacing;

    // Verificar se o tema é escuro ou claro
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Widget para o conteúdo da mensagem
    Widget messageContent;

    if (isStreaming && message.isEmpty) {
      // Mostrar indicador de digitação
      messageContent = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          buildTypingIndicator(), // Usar o método da própria classe
        ],
      );
    } else if (imageBytes != null) {
      // Mostrar imagem com o texto abaixo
      messageContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              imageBytes,
              width: 200,
              height: 150,
              fit: BoxFit.cover,
            ),
          ),
          SizedBox(height: 8),
          // Usar o formatador para o texto abaixo da imagem
          MessageFormatter.buildFormattedText(
            message,
            style: TextStyle(
              color: isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
              fontSize: 16,
            ),
            isDarkMode: isDarkMode,
          ),
        ],
      );
    } else {
      // Usar o formatador para mensagens de texto
      messageContent = MessageFormatter.buildFormattedText(
        message,
        style: TextStyle(
          color: isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
          fontSize: 16,
        ),
        isDarkMode: isDarkMode,
      );
    }

    // Mensagem do usuário: simples, sem card, alinhado à direita
    if (isUser) {
      return GestureDetector(
        onLongPress: onLongPress,
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            margin: EdgeInsets.only(bottom: safeBottomSpacing),
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: messageContent,
          ),
        ),
      );
    }

    // Mensagem da IA: card estilizado similar ao MealCard
    final backgroundColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;
    final errorBackgroundColor = isDarkMode ? Color(0xFF3B2532) : Color(0xFFFFF0F0);

    return GestureDetector(
      onLongPress: onLongPress,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Card(
          margin: EdgeInsets.only(bottom: safeBottomSpacing),
          elevation: 1.5,
          shadowColor: isDarkMode
              ? Colors.black.withValues(alpha: 0.3)
              : Colors.black.withValues(alpha: 0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: isError ? errorBackgroundColor : backgroundColor,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            child: messageContent,
          ),
        ),
      ),
    );
  }

  // Método para criar um botão de ação individual
  static Widget buildActionButton(IconData icon, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(icon, color: Colors.white70, size: 20),
      onPressed: onPressed,
      splashRadius: 20,
      constraints: BoxConstraints(),
      padding: EdgeInsets.all(8),
    );
  }
}
