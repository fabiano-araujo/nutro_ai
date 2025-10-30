import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../i18n/app_localizations_extension.dart';
import 'message_notifier.dart';

class ResponseDisplay extends StatefulWidget {
  final String? response;
  final bool isLoading;
  final bool isError;
  final bool isCode;
  final MessageNotifier? notifier;

  const ResponseDisplay({
    Key? key,
    this.response,
    this.isLoading = false,
    this.isError = false,
    this.isCode = false,
    this.notifier,
  }) : super(key: key);

  @override
  _ResponseDisplayState createState() => _ResponseDisplayState();
}

class _ResponseDisplayState extends State<ResponseDisplay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  String? _streamingText;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 600),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));

    // Adiciona listener para o notificador se disponível
    if (widget.notifier != null) {
      widget.notifier!.addListener(_updateStreamingText);
    }

    if (widget.response != null && !widget.isLoading) {
      _animationController.forward();
    }
  }

  void _updateStreamingText() {
    if (mounted && widget.notifier != null) {
      setState(() {
        _streamingText = widget.notifier!.message;
      });
    }
  }

  @override
  void didUpdateWidget(ResponseDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Gerencia mudanças no notificador
    if (oldWidget.notifier != widget.notifier) {
      if (oldWidget.notifier != null) {
        oldWidget.notifier!.removeListener(_updateStreamingText);
      }
      if (widget.notifier != null) {
        widget.notifier!.addListener(_updateStreamingText);
      }
    }

    // Gerencia mudanças na resposta estática
    if (oldWidget.response != widget.response && widget.response != null) {
      _animationController.reset();
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    // Remove o listener ao destruir o widget
    if (widget.notifier != null) {
      widget.notifier!.removeListener(_updateStreamingText);
    }
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Se estiver carregando e tiver um notificador com streaming
    if (widget.isLoading && widget.notifier != null) {
      return _buildStreamingResponse(isDarkMode, context);
    }

    if (widget.isLoading) {
      return _buildLoadingState(isDarkMode, context);
    }

    if (widget.isError) {
      return _buildErrorState(isDarkMode, context);
    }

    if (widget.response == null || widget.response!.isEmpty) {
      return _buildEmptyState(isDarkMode, context);
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Card(
        elevation: 1,
        margin: EdgeInsets.symmetric(vertical: 8, horizontal: 0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: isDarkMode ? AppTheme.darkCardColor : Colors.white,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        color: AppTheme.primaryColor,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Text(
                        context.tr.translate('ai_response') ?? 'AI Response',
                        style: AppTheme.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDarkMode
                              ? AppTheme.darkTextColor
                              : AppTheme.textPrimaryColor,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.copy_outlined, size: 18),
                    onPressed: () {
                      Clipboard.setData(
                          ClipboardData(text: widget.response ?? ''));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(context.tr.translate('text_copied') ??
                                'Response copied to clipboard'),
                            duration: Duration(seconds: 1)),
                      );
                    },
                    tooltip: context.tr.translate('copy_to_clipboard') ??
                        'Copy to clipboard',
                    color: isDarkMode
                        ? AppTheme.darkTextColor.withOpacity(0.7)
                        : AppTheme.textSecondaryColor,
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                  ),
                ],
              ),
              Divider(height: 24),
              _buildFormattedResponse(widget.response!, isDarkMode),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStreamingResponse(bool isDarkMode, BuildContext context) {
    final texto = _streamingText ?? '';

    return Card(
      elevation: 1,
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDarkMode ? AppTheme.darkCardColor : Colors.white,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      color: AppTheme.primaryColor,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text(
                      context.tr.translate('ai_response') ?? 'AI Response',
                      style: AppTheme.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDarkMode
                            ? AppTheme.darkTextColor
                            : AppTheme.textPrimaryColor,
                      ),
                    ),
                    SizedBox(width: 8),
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Divider(height: 24),
            texto.isNotEmpty
                ? _buildFormattedResponse(texto, isDarkMode)
                : Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: _buildTypingIndicator(),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Row(
      children: List.generate(
        3,
        (index) => Container(
          margin: EdgeInsets.symmetric(horizontal: 2),
          height: 8,
          width: 8,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.5),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(bool isDarkMode, BuildContext context) {
    return Card(
      elevation: 1,
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDarkMode ? AppTheme.darkCardColor : Colors.white,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(40),
        child: Column(
          children: [
            SizedBox(height: 8),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              strokeWidth: 3,
            ),
            SizedBox(height: 24),
            Text(
              context.tr.translate('thinking') ?? 'Thinking...',
              style: AppTheme.bodyMedium.copyWith(
                color: isDarkMode
                    ? AppTheme.darkTextColor
                    : AppTheme.textPrimaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              context.tr.translate('generating_best_response') ??
                  'Generating the best response for you',
              style: AppTheme.bodySmall.copyWith(
                color: isDarkMode
                    ? AppTheme.darkTextColor.withOpacity(0.7)
                    : AppTheme.textSecondaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(bool isDarkMode, BuildContext context) {
    return Card(
      elevation: 1,
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      color: isDarkMode ? Color(0xFF2A2020) : Color(0xFFFEEDED),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.error_outline,
              color: AppTheme.errorColor,
              size: 40,
            ),
            SizedBox(height: 16),
            Text(
              context.tr.translate('something_went_wrong') ??
                  'Something went wrong',
              style: AppTheme.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: isDarkMode
                    ? AppTheme.darkTextColor
                    : AppTheme.textPrimaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              context.tr.translate('try_again_or_check_connection') ??
                  'Please try again or check your connection',
              style: AppTheme.bodySmall.copyWith(
                color: isDarkMode
                    ? AppTheme.darkTextColor.withOpacity(0.7)
                    : AppTheme.textSecondaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {},
              child: Text(context.tr.translate('try_again') ?? 'Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDarkMode, BuildContext context) {
    return Card(
      elevation: 1,
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(
              Icons.lightbulb_outline,
              color: AppTheme.warningColor,
              size: 40,
            ),
            SizedBox(height: 16),
            Text(
              context.tr.translate('no_response_yet') ?? 'No Response Yet',
              style: AppTheme.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: isDarkMode
                    ? AppTheme.darkTextColor
                    : AppTheme.textPrimaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              context.tr.translate('ask_question_or_upload') ??
                  'Ask a question or upload content to get started',
              style: AppTheme.bodySmall.copyWith(
                color: isDarkMode
                    ? AppTheme.darkTextColor.withOpacity(0.7)
                    : AppTheme.textSecondaryColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormattedResponse(String text, bool isDarkMode) {
    // Para conteúdo de código, exibimos diretamente como um bloco de código
    if (widget.isCode) {
      return Container(
        margin: EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isDarkMode ? Color(0xFF1E2433) : Color(0xFFF0F4F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDarkMode ? AppTheme.darkBorderColor : Color(0xFFE1E6F0),
            width: 1,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: SelectableText(
            text,
            style: AppTheme.bodySmall.copyWith(
              fontFamily: 'Courier New',
              color: isDarkMode ? Color(0xFFC3E88D) : Color(0xFF0D5302),
              height: 1.6,
            ),
          ),
        ),
      );
    }

    // Simple parsing for code blocks and bullet points
    final List<Widget> formattedParts = [];

    // Split by code blocks using triple backticks
    final parts = text.split(RegExp(r'```([\w]*)(\n|\r|\r\n)?'));

    bool isCodeBlock = false;
    String? language;

    for (int i = 0; i < parts.length; i++) {
      if (i % 2 == 0) {
        // Regular text
        // Process bullet points and numbered lists
        final paragraphs = parts[i].split('\n');
        for (final paragraph in paragraphs) {
          if (paragraph.trim().isEmpty) continue;

          // Check if it's a bullet point
          if (paragraph.trim().startsWith('- ') ||
              paragraph.trim().startsWith('* ')) {
            formattedParts.add(
              Padding(
                padding: EdgeInsets.only(left: 16, bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '•',
                      style: AppTheme.bodyMedium.copyWith(
                        color: isDarkMode
                            ? AppTheme.primaryLightColor
                            : AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        paragraph.trim().substring(2),
                        style: AppTheme.bodyMedium.copyWith(
                          color: isDarkMode
                              ? AppTheme.darkTextColor
                              : AppTheme.textPrimaryColor,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          // Check if it's a numbered list
          else if (RegExp(r'^\d+\.\s').hasMatch(paragraph.trim())) {
            final match =
                RegExp(r'^(\d+)\.\s(.*)').firstMatch(paragraph.trim());
            if (match != null) {
              formattedParts.add(
                Padding(
                  padding: EdgeInsets.only(left: 16, bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${match.group(1)}.',
                        style: AppTheme.bodyMedium.copyWith(
                          color: isDarkMode
                              ? AppTheme.primaryLightColor
                              : AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          match.group(2) ?? '',
                          style: AppTheme.bodyMedium.copyWith(
                            color: isDarkMode
                                ? AppTheme.darkTextColor
                                : AppTheme.textPrimaryColor,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
          }
          // Regular paragraph
          else {
            // Check if it's a header (starts with # or ##)
            if (paragraph.trim().startsWith('# ')) {
              formattedParts.add(
                Padding(
                  padding: EdgeInsets.only(bottom: 16, top: 8),
                  child: Text(
                    paragraph.trim().substring(2),
                    style: AppTheme.headingMedium.copyWith(
                      color: isDarkMode
                          ? AppTheme.darkTextColor
                          : AppTheme.textPrimaryColor,
                    ),
                  ),
                ),
              );
            } else if (paragraph.trim().startsWith('## ')) {
              formattedParts.add(
                Padding(
                  padding: EdgeInsets.only(bottom: 12, top: 8),
                  child: Text(
                    paragraph.trim().substring(3),
                    style: AppTheme.headingSmall.copyWith(
                      color: isDarkMode
                          ? AppTheme.darkTextColor
                          : AppTheme.textPrimaryColor,
                    ),
                  ),
                ),
              );
            } else {
              formattedParts.add(
                Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    paragraph,
                    style: AppTheme.bodyMedium.copyWith(
                      color: isDarkMode
                          ? AppTheme.darkTextColor
                          : AppTheme.textPrimaryColor,
                      height: 1.5,
                    ),
                  ),
                ),
              );
            }
          }
        }
      } else {
        // Code block
        // Get language if available
        language = i < parts.length ? parts[i].trim() : '';
        i++; // Skip the language part

        if (i < parts.length) {
          formattedParts.add(
            Container(
              margin: EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isDarkMode ? Color(0xFF1E2433) : Color(0xFFF0F4F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color:
                      isDarkMode ? AppTheme.darkBorderColor : Color(0xFFE1E6F0),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (language != null && language!.isNotEmpty)
                    Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(
                        language!,
                        style: AppTheme.captionText.copyWith(
                          color: isDarkMode
                              ? AppTheme.darkTextColor.withOpacity(0.7)
                              : AppTheme.textSecondaryColor,
                        ),
                      ),
                    ),
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: SelectableText(
                      parts[i],
                      style: AppTheme.bodySmall.copyWith(
                        fontFamily: 'Courier New',
                        color:
                            isDarkMode ? Color(0xFFC3E88D) : Color(0xFF0D5302),
                        height: 1.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      }
    }

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: formattedParts);
  }
}
