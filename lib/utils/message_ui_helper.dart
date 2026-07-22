import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:math' as math;
import '../theme/app_theme.dart';
import '../utils/message_formatter.dart';
import '../screens/image_viewer_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Classe utilitária para construir elementos de UI relacionados a mensagens
class MessageUIHelper {
  static Widget _buildFormattedMessageText(
    String message, {
    required TextStyle style,
    required bool isDarkMode,
    required bool absorbPointer,
  }) {
    final formattedText = MessageFormatter.buildFormattedText(
      message,
      style: style,
      isDarkMode: isDarkMode,
    );

    if (!absorbPointer) return formattedText;

    return AbsorbPointer(
      child: formattedText,
    );
  }

  /// Constrói o indicador de digitação (três pontos animados)
  static Widget buildTypingIndicator({Color? color}) {
    return _AnimatedTypingIndicator(
      color: color ?? AppTheme.primaryColor,
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
                    .withValues(alpha: animationController.value * 0.7 + 0.3),
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
                    color: AppTheme.errorColor.withValues(
                        alpha: 0.5 - (animationController.value * 0.2)),
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
    required ValueChanged<Offset> onLongPress,
    Uint8List? imageBytes,
    double bottomSpacing = 8,
  }) {
    final double safeBottomSpacing = bottomSpacing < 0 ? 0 : bottomSpacing;

    // Verificar se o tema é escuro ou claro
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Widget para o conteúdo da mensagem
    Widget messageContent;

    if (isStreaming && message.isEmpty) {
      // Mostrar indicador de digitação
      messageContent = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          buildTypingIndicator(color: Theme.of(context).colorScheme.primary),
        ],
      );
    } else if (imageBytes != null) {
      // Mostrar imagem com o texto abaixo
      final hasCaption = message.trim().isNotEmpty;
      messageContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ImageViewerScreen(imageBytes: imageBytes),
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                imageBytes,
                width: 200,
                height: 150,
                fit: BoxFit.cover,
              ),
            ),
          ),
          if (hasCaption) ...[
            SizedBox(height: 8),
            _buildFormattedMessageText(
              message,
              style: TextStyle(
                color: isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
                fontSize: 16,
              ),
              isDarkMode: isDarkMode,
              absorbPointer: isUser,
            ),
          ],
        ],
      );
    } else {
      // Usar o formatador para mensagens de texto
      messageContent = _buildFormattedMessageText(
        message,
        style: TextStyle(
          color: isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
          fontSize: 16,
        ),
        isDarkMode: isDarkMode,
        absorbPointer: isUser,
      );
    }

    // Mensagem do usuário: balão cinza arredondado, alinhado à direita.
    // Quando é só imagem (sem texto), exibe a imagem sem o balão.
    if (isUser) {
      final bool imageOnly = imageBytes != null && message.trim().isEmpty;
      return GestureDetector(
        onLongPressStart: (details) => onLongPress(details.globalPosition),
        child: Align(
          alignment: Alignment.centerRight,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            child: Container(
              margin: EdgeInsets.only(bottom: safeBottomSpacing, left: 48),
              padding: imageOnly
                  ? EdgeInsets.zero
                  : EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: imageOnly
                  ? null
                  : BoxDecoration(
                      color: isDarkMode
                          ? AppTheme.darkUserMessageColor
                          : const Color(0xFFEFEFEF),
                      borderRadius: BorderRadius.circular(18),
                    ),
              child: DefaultTextStyle.merge(
                style: TextStyle(
                  color: isDarkMode ? Colors.white : AppTheme.textPrimaryColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
                child: messageContent,
              ),
            ),
          ),
        ),
      );
    }

    // Mensagem da IA: sem balão, estilo ChatGPT
    final errorBackgroundColor =
        isDarkMode ? Color(0xFF3B2532) : Color(0xFFFFF0F0);

    return GestureDetector(
      onLongPressStart: (details) => onLongPress(details.globalPosition),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: EdgeInsets.only(bottom: safeBottomSpacing),
          decoration: isError
              ? BoxDecoration(
                  color: errorBackgroundColor,
                  borderRadius: BorderRadius.circular(12),
                )
              : null,
          child: Container(
            width: double.infinity,
            padding: isError
                ? EdgeInsets.all(12)
                : EdgeInsets.symmetric(vertical: 4),
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

class _AnimatedTypingIndicator extends StatefulWidget {
  final Color color;

  const _AnimatedTypingIndicator({required this.color});

  @override
  State<_AnimatedTypingIndicator> createState() =>
      _AnimatedTypingIndicatorState();
}

class _AnimatedTypingIndicatorState extends State<_AnimatedTypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (index) {
                final phase = (_controller.value - (index * 0.18)) % 1.0;
                final wave = math.max(0.0, math.sin(phase * math.pi * 2));
                return Transform.translate(
                  key: ValueKey('typing_indicator_dot_$index'),
                  offset: Offset(0, -5 * wave),
                  child: Transform.scale(
                    scale: 0.9 + (0.25 * wave),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      height: 9,
                      width: 9,
                      decoration: BoxDecoration(
                        color: widget.color.withValues(
                          alpha: 0.45 + (0.55 * wave),
                        ),
                        shape: BoxShape.circle,
                        boxShadow: wave > 0.2
                            ? [
                                BoxShadow(
                                  color: widget.color.withValues(
                                    alpha: 0.22 * wave,
                                  ),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}
