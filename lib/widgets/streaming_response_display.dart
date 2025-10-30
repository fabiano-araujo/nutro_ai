import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import 'dart:async';
import '../i18n/app_localizations_extension.dart';

class StreamingResponseDisplay extends StatefulWidget {
  final String response;
  final bool isLoading;
  final bool isError;
  final bool isCode;
  final String titleKey;

  const StreamingResponseDisplay({
    Key? key,
    required this.response,
    this.isLoading = false,
    this.isError = false,
    this.isCode = false,
    required this.titleKey,
  }) : super(key: key);

  @override
  _StreamingResponseDisplayState createState() =>
      _StreamingResponseDisplayState();
}

class _StreamingResponseDisplayState extends State<StreamingResponseDisplay>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void didUpdateWidget(StreamingResponseDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Se a resposta foi atualizada, role para o fim
    if (widget.response != oldWidget.response && widget.response.isNotEmpty) {
      // Use um pequeno atraso para garantir que a UI foi atualizada antes de rolar
      Timer(Duration(milliseconds: 50), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: Duration(milliseconds: 100),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (widget.isLoading && widget.response.isEmpty) {
      return _buildLoadingState(isDarkMode);
    }

    if (widget.isError) {
      return _buildErrorState(isDarkMode);
    }

    if (widget.response.isEmpty && !widget.isLoading) {
      return _buildEmptyState(isDarkMode);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr.translate(widget.titleKey),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey[850] : Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
              width: 1,
            ),
          ),
          child: widget.isLoading && widget.response.isEmpty
              ? Center(
                  child: SizedBox(
                    height: 100,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(context.tr.translate('processing_request')),
                      ],
                    ),
                  ),
                )
              : SelectableText(
                  widget.response,
                  style: TextStyle(
                    height: 1.5,
                    fontSize: 16,
                  ),
                ),
        ),
        SizedBox(height: 16),
        _buildActionButtons(context),
      ],
    );
  }

  Widget _buildLoadingState(bool isDarkMode) {
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
              'Processando...',
              style: AppTheme.bodyMedium.copyWith(
                color: isDarkMode
                    ? AppTheme.darkTextColor
                    : AppTheme.textPrimaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Gerando a melhor resposta para você',
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

  Widget _buildErrorState(bool isDarkMode) {
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
              'Algo deu errado',
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
              'Por favor, tente novamente ou verifique sua conexão',
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
              child: Text('Tentar Novamente'),
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

  Widget _buildEmptyState(bool isDarkMode) {
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
              Icons.text_fields,
              color: isDarkMode
                  ? AppTheme.darkTextColor.withOpacity(0.5)
                  : Colors.grey[400],
              size: 48,
            ),
            SizedBox(height: 24),
            Text(
              'Nenhuma resposta ainda',
              style: AppTheme.bodyMedium.copyWith(
                color: isDarkMode
                    ? AppTheme.darkTextColor
                    : AppTheme.textPrimaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Preencha o documento e clique em "Resumir" para ver os resultados aqui',
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
    if (widget.isCode) {
      return _buildCodeBlock(text, isDarkMode);
    }

    return SelectableText(
      text,
      style: AppTheme.bodyMedium.copyWith(
        color: isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor,
        height: 1.5,
      ),
    );
  }

  Widget _buildCodeBlock(String code, bool isDarkMode) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.black : Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: EdgeInsets.all(16),
      width: double.infinity,
      child: SelectableText(
        code,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 14,
          color: isDarkMode ? Colors.grey[300] : Colors.black87,
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _buildActionButton(
          context: context,
          icon: Icons.copy,
          tooltip: context.tr.translate('copy_to_clipboard'),
          onPressed: () => _copyToClipboard(context),
        ),
        SizedBox(width: 8),
        _buildActionButton(
          context: context,
          icon: Icons.download,
          tooltip: context.tr.translate('download_content'),
          onPressed: () {
            // Implementar download
            _showFeatureNotImplemented(context);
          },
        ),
        SizedBox(width: 8),
        _buildActionButton(
          context: context,
          icon: Icons.share,
          tooltip: context.tr.translate('share_content'),
          onPressed: () {
            // Implementar compartilhamento
            _showFeatureNotImplemented(context);
          },
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
        ),
      ),
    );
  }

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: widget.response));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr.translate('copied_to_clipboard')),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showFeatureNotImplemented(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr.translate('feature_not_implemented')),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: context.tr.translate('ok'),
          onPressed: () {},
        ),
      ),
    );
  }
}
