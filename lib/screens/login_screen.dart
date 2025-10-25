import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../i18n/app_localizations_extension.dart';
import 'email_login_screen.dart';
import '../widgets/credit_indicator.dart';
import '../widgets/reward_ad_dialog.dart';
import 'settings_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleLogin() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);

      // Tentar fazer login com Google
      final success = await authService.signInWithGoogle();

      if (success && mounted) {
        // Não fechamos a tela - o Builder no IndexedStack vai detectar
        // a mudança no authService e mostrar automaticamente o ProfileScreen
        setState(() {
          // Forçar reconstrução da tela para refletir o novo estado
          _isLoading = false;
        });
      } else if (!success && mounted) {
        // Usar a mensagem de erro do serviço, se disponível
        final errorMsg = authService.errorMessage ??
            'Falha ao fazer login com Google. Tente novamente.';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );

        // Desativar o indicador de carregamento em caso de falha
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('[LoginScreen] Erro ao fazer login: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao conectar: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );

        // Desativar o indicador de carregamento em caso de erro
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isDarkMode = theme.brightness == Brightness.dark;

    // Obter o serviço de autenticação para verificar mensagens de erro
    final authService = Provider.of<AuthService>(context, listen: true);

    // Usar a mesma cor de fundo do AI Tutor Screen
    final Color currentScaffoldBackgroundColor =
        isDarkMode ? AppTheme.darkBackgroundColor : AppTheme.backgroundColor;

    return Scaffold(
      backgroundColor: currentScaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: currentScaffoldBackgroundColor,
        title: Text(context.tr.translate('login_title') ?? 'Login'),
        centerTitle: false,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: CreditIndicator(),
          ),
          IconButton(
            icon: const Icon(Icons.card_giftcard),
            tooltip: context.tr.translate('watch_ad_for_credits') ??
                'Assistir anúncio para ganhar créditos',
            onPressed: () {
              // Chamar o RewardAdDialog
              RewardAdDialog.show(context);
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: currentScaffoldBackgroundColor,
        child: SafeArea(
          child: SingleChildScrollView(
            child: SizedBox(
              height: size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom -
                  kToolbarHeight -
                  20, // Extra espaço para evitar conteúdo cortado
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: size.height * 0.03),
                  // Logo e título
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        children: [
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/images/logo.png',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Icons.error,
                                    size: 40,
                                    color: AppTheme.primaryColor,
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            context.tr.translate('app_title') ?? 'Nutro AI',
                            style: TextStyle(
                              color: isDarkMode
                                  ? Colors.white
                                  : AppTheme.textPrimaryColor,
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.tr.translate('app_subtitle') ??
                                'Seu assistente inteligente de nutrição',
                            style: TextStyle(
                              color: isDarkMode
                                  ? Colors.white70
                                  : AppTheme.textSecondaryColor,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 60),
                  // Card de login
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 24,
                      right: 24,
                      bottom: 40, // Aumentado o espaço inferior
                    ),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? AppTheme.darkCardColor
                                : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 20,
                                spreadRadius: 5,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                context.tr.translate('welcome') ?? 'Bem-vindo',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                context.tr.translate('welcome_description') ??
                                    'Entre com sua conta para acompanhar suas calorias e alcançar seus objetivos nutricionais',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDarkMode
                                      ? AppTheme.darkTextColor
                                      : Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 24),
                              _isLoading
                                  ? const CircularProgressIndicator()
                                  : ElevatedButton.icon(
                                      onPressed: _handleGoogleLogin,
                                      icon: const Icon(
                                        Icons.g_mobiledata,
                                        size: 28,
                                        color: Colors.red,
                                      ),
                                      label: Text(context.tr.translate(
                                              'sign_in_with_google') ??
                                          'Entrar com Google'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isDarkMode
                                            ? AppTheme.darkCardColor
                                            : Colors.white,
                                        foregroundColor: isDarkMode
                                            ? Colors.white
                                            : Colors.black87,
                                        minimumSize: const Size(
                                          double.infinity,
                                          50,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          side: BorderSide(
                                            color: isDarkMode
                                                ? Colors.grey.shade800
                                                : Colors.grey.shade300,
                                            width: 1,
                                          ),
                                        ),
                                        elevation: 1,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                          horizontal: 16,
                                        ),
                                      ),
                                    ),
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    height: 1,
                                    width: 70,
                                    color: isDarkMode
                                        ? Colors.grey.shade700
                                        : Colors.grey.shade300,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    child: Text(
                                      context.tr.translate('or') ?? 'ou',
                                      style: TextStyle(
                                        color: isDarkMode
                                            ? Colors.grey.shade400
                                            : Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    height: 1,
                                    width: 70,
                                    color: isDarkMode
                                        ? Colors.grey.shade700
                                        : Colors.grey.shade300,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const EmailLoginScreen(),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.email_outlined),
                                label: Text(context.tr
                                        .translate('sign_in_with_email') ??
                                    'Entrar com email e senha'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDarkMode
                                      ? AppTheme.darkCardColor
                                      : Colors.white,
                                  foregroundColor: isDarkMode
                                      ? Colors.white
                                      : Colors.black87,
                                  minimumSize: const Size(
                                    double.infinity,
                                    50,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: isDarkMode
                                          ? Colors.grey.shade800
                                          : Colors.grey.shade300,
                                      width: 1,
                                    ),
                                  ),
                                  elevation: 1,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
