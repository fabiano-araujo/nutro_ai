import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../i18n/app_localizations_extension.dart';

class RateAppScreen extends StatefulWidget {
  const RateAppScreen({Key? key}) : super(key: key);

  @override
  _RateAppScreenState createState() => _RateAppScreenState();
}

class _RateAppScreenState extends State<RateAppScreen> with SingleTickerProviderStateMixin {
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
      // Aguardar um pouco para mostrar a animação antes de abrir a Play Store
      await Future.delayed(const Duration(milliseconds: 800));
      // ID do app na Play Store (substitua com o ID real do seu aplicativo)
      const appId = 'com.fabianoaraujo.studyai';
      final url = Uri.parse('https://play.google.com/store/apps/details?id=$appId');

      try {
        await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
        );
        // Fechar a tela de avaliação após abrir a loja
        if (mounted) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        print('Não foi possível abrir a Play Store: $e');
      }
    } else {
      // Para avaliações baixas, apenas mostramos uma mensagem de agradecimento
      // e deixamos o usuário voltar manualmente
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDarkMode ? Colors.purpleAccent : Colors.purple;
    final backgroundColor = isDarkMode ? AppTheme.darkBackgroundColor : Colors.white;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: backgroundColor,
          appBar: AppBar(
            backgroundColor: backgroundColor,
            elevation: 0,
            iconTheme: IconThemeData(
              color: isDarkMode ? Colors.white : Colors.black,
            ),
            leading: IconButton(
              icon: Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: ScaleTransition(
            scale: _scaleAnimation,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: _submitted ? _buildThankYouContent(isDarkMode, primaryColor) : _buildRatingContent(isDarkMode, primaryColor),
              ),
            ),
          ),
        );
      }
    );
  }

  Widget _buildRatingContent(bool isDarkMode, Color primaryColor) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(height: 20),
        Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: primaryColor.withOpacity(0.1),
          ),
          child: Icon(
            Icons.emoji_emotions,
            size: 80,
            color: primaryColor,
          ),
        ),
        SizedBox(height: 30),
        Text(
          context.tr.translate('enjoying_app'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        SizedBox(height: 10),
        Text(
          context.tr.translate('rate_app_description'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
          ),
        ),
        SizedBox(height: 40),
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
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
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
                        size: 48,
                      ),
                    );
                  },
                ),
              ),
            );
          }),
        ),
        SizedBox(height: 40),
        ElevatedButton(
          onPressed: _rating > 0 ? _submitRating : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            padding: EdgeInsets.symmetric(horizontal: 40, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            elevation: 1,
            shadowColor: primaryColor.withOpacity(0.5),
          ),
          child: Text(
            context.tr.translate('submit'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        SizedBox(height: 20),
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
        SizedBox(height: 20),
        AnimatedContainer(
          duration: Duration(milliseconds: 500),
          curve: Curves.elasticOut,
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: primaryColor.withOpacity(0.1),
          ),
          child: Icon(
            iconData,
            size: 80,
            color: primaryColor,
          ),
        ),
        SizedBox(height: 30),
        Text(
          titleText,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        SizedBox(height: 20),
        Text(
          messageText,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
          ),
        ),
        SizedBox(height: 40),
        if (_rating < 4)
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              padding: EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 1,
              shadowColor: primaryColor.withOpacity(0.5),
            ),
            child: Text(
              context.tr.translate('ok'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        SizedBox(height: 20),
      ],
    );
  }
}
