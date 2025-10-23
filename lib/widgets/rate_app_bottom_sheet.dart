import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../theme/app_theme.dart';
import '../i18n/app_localizations_extension.dart';
import '../services/rate_app_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class RateAppBottomSheet extends StatefulWidget {
  const RateAppBottomSheet({Key? key}) : super(key: key);

  // Método para mostrar o bottom sheet
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => const RateAppBottomSheet(),
    );
  }

  @override
  _RateAppBottomSheetState createState() => _RateAppBottomSheetState();
}

class _RateAppBottomSheetState extends State<RateAppBottomSheet>
    with SingleTickerProviderStateMixin {
  int _rating = 0;
  bool _submitted = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _submitRating() async {
    setState(() {
      _submitted = true;
    });

    if (_rating >= 4) {
      // Marcar que o usuário avaliou o app
      await RateAppService.markAsRated();
      // Buscar o applicationId conforme a plataforma
      String appId;
      if (kIsWeb) {
        appId = 'br.com.snapdark.apps.studyai';
      } else {
        final packageInfo = await PackageInfo.fromPlatform();
        appId = packageInfo.packageName;
      }
      final url =
          Uri.parse('https://play.google.com/store/apps/details?id=$appId');
      try {
        await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
        );
        // Fechar o bottom sheet após abrir a loja
        if (mounted) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        print('Não foi possível abrir a Play Store: $e');
      }
      return;
    }
    // Para avaliações baixas, apenas mostramos uma mensagem de agradecimento
    // e deixamos o usuário voltar manualmente
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final backgroundColor =
        isDarkMode ? AppTheme.darkBackgroundColor : Colors.white;

    // Obter a altura da tela para dimensionar o bottom sheet
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomSheetHeight = screenHeight * 0.6; // 60% da altura da tela

    return AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Container(
            height: bottomSheetHeight,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Column(
              children: [
                // Barra de arraste
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Botão fechar
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: IconButton(
                      icon: Icon(
                        Icons.close,
                        color: isDarkMode ? Colors.white : Colors.black54,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
                // Conteúdo principal
                Expanded(
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24.0, vertical: 8.0),
                        child: _submitted && _rating < 4
                            ? _buildThankYouContent(isDarkMode, primaryColor)
                            : _buildRatingContent(isDarkMode, primaryColor),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        });
  }

  Widget _buildRatingContent(bool isDarkMode, Color primaryColor) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: primaryColor.withOpacity(0.1),
          ),
          child: Icon(
            Icons.emoji_emotions,
            size: 60,
            color: primaryColor,
          ),
        ),
        SizedBox(height: 16),
        Text(
          context.tr.translate('enjoying_app'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        SizedBox(height: 8),
        Text(
          context.tr.translate('rate_app_description'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
          ),
        ),
        SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            final starValue = index + 1;
            final isSelected = starValue <= _rating;

            return GestureDetector(
              onTap: () {
                setState(() {
                  _rating = starValue;
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6.0),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(
                    begin: 1.0,
                    end: isSelected ? 1.2 : 1.0,
                  ),
                  duration: Duration(milliseconds: 200),
                  builder: (context, scale, child) {
                    return Transform.scale(
                      scale: scale,
                      child: Icon(
                        isSelected ? Icons.star : Icons.star_border,
                        color: isSelected ? Colors.amber : Colors.grey,
                        size: 36,
                      ),
                    );
                  },
                ),
              ),
            );
          }),
        ),
        SizedBox(height: 24),
        ElevatedButton(
          onPressed: _rating > 0 ? _submitRating : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            elevation: 5,
            shadowColor: primaryColor.withOpacity(0.5),
          ),
          child: Text(
            context.tr.translate('submit'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        SizedBox(height: 16),
      ],
    );
  }

  Widget _buildThankYouContent(bool isDarkMode, Color primaryColor) {
    String titleText;
    String messageText;
    IconData iconData;

    if (_rating >= 4) {
      titleText = context.tr.translate('thank_you_positive');
      messageText = context.tr.translate('redirection_message');
      iconData = Icons.celebration;
    } else {
      titleText = context.tr.translate('thank_you');
      messageText = context.tr.translate('feedback_message');
      iconData = Icons.thumb_up;
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AnimatedContainer(
          duration: Duration(milliseconds: 500),
          curve: Curves.elasticOut,
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: primaryColor.withOpacity(0.1),
          ),
          child: Icon(
            iconData,
            size: 60,
            color: primaryColor,
          ),
        ),
        SizedBox(height: 16),
        Text(
          titleText,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        SizedBox(height: 12),
        Text(
          messageText,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
          ),
        ),
        SizedBox(height: 24),
        if (_rating < 4)
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 5,
              shadowColor: primaryColor.withOpacity(0.5),
            ),
            child: Text(
              context.tr.translate('ok'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        SizedBox(height: 16),
      ],
    );
  }
}
