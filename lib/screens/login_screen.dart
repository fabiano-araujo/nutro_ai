import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../i18n/app_localizations_extension.dart';
import 'email_login_screen.dart';
import '../widgets/credit_indicator.dart';
import '../widgets/reward_ad_dialog.dart';
import 'settings_screen.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;
  final bool popOnSuccess;

  const LoginScreen({
    Key? key,
    this.onOpenDrawer,
    this.popOnSuccess = false,
  }) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isLoading = false;
  bool _didAutoCloseAfterLogin = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.1, 0.7, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.1, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _closeAfterSuccessfulLogin() {
    if (_didAutoCloseAfterLogin) {
      return;
    }

    _didAutoCloseAfterLogin = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      Navigator.of(context).maybePop(true);
    });
  }

  Future<void> _handleGoogleLogin() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);

      final success = await authService.signInWithGoogle();

      if (success && mounted) {
        setState(() {
          _isLoading = false;
        });

        if (widget.popOnSuccess) {
          _closeAfterSuccessfulLogin();
        }
      } else if (!success && mounted) {
        final errorMsg = authService.errorMessage ??
            'Falha ao fazer login com Google. Tente novamente.';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 4),
          ),
        );

        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao conectar: $e'),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 4),
          ),
        );

        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final canPop = Navigator.of(context).canPop();

    final authService = Provider.of<AuthService>(context, listen: true);

    if (widget.popOnSuccess &&
        authService.isAuthenticated &&
        !_didAutoCloseAfterLogin) {
      _closeAfterSuccessfulLogin();
    }

    final bgColor =
        isDarkMode ? AppTheme.darkBackgroundColor : AppTheme.backgroundColor;
    final cardColor = isDarkMode ? AppTheme.darkCardColor : Colors.white;
    final borderColor =
        isDarkMode ? AppTheme.darkBorderColor : AppTheme.dividerColor;
    final textPrimary =
        isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;
    final textSecondary =
        isDarkMode ? const Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;
    final primaryColor =
        isDarkMode ? AppTheme.primaryColorDarkMode : AppTheme.primaryColor;

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDarkMode ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDarkMode ? Brightness.dark : Brightness.light,
    ));

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        leading: widget.onOpenDrawer != null
            ? IconButton(
                icon: Icon(Icons.menu, color: textPrimary),
                onPressed: widget.onOpenDrawer,
                tooltip: 'Menu',
              )
            : canPop
                ? IconButton(
                    icon: Icon(Icons.arrow_back, color: textPrimary),
                    onPressed: () => Navigator.of(context).maybePop(),
                    tooltip: context.tr.translate('back'),
                  )
                : null,
        title: Text(
          context.tr.translate('login_title') ?? 'Login',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4.0),
            child: CreditIndicator(),
          ),
          IconButton(
            icon: Icon(Icons.card_giftcard, color: textPrimary),
            tooltip: context.tr.translate('watch_ad_for_credits') ??
                'Assistir anúncio para ganhar créditos',
            onPressed: () => RewardAdDialog.show(context),
          ),
          IconButton(
            icon: Icon(Icons.settings, color: textPrimary),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),

                  // Logo
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: borderColor, width: 1.5),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.restaurant,
                            size: 36,
                            color: primaryColor,
                          );
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // App title
                  Text(
                    context.tr.translate('app_title') ?? 'Nutro AI',
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                      letterSpacing: 0.5,
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Subtitle
                  Text(
                    context.tr.translate('app_subtitle') ??
                        'Seu assistente inteligente de nutrição',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: textSecondary,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Login card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor, width: 1),
                      boxShadow: isDarkMode
                          ? null
                          : [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          context.tr.translate('welcome') ?? 'Bem-vindo',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.tr.translate('welcome_description') ??
                              'Entre com sua conta para acompanhar suas calorias e alcançar seus objetivos nutricionais',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: textSecondary,
                            height: 1.5,
                          ),
                        ),

                        const SizedBox(height: 28),

                        // Google button
                        if (_isLoading)
                          SizedBox(
                            height: 50,
                            child: Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: primaryColor,
                              ),
                            ),
                          )
                        else
                          _SocialButton(
                            onPressed: _handleGoogleLogin,
                            icon: const Icon(
                              Icons.g_mobiledata,
                              size: 28,
                              color: Colors.red,
                            ),
                            label: context.tr.translate('sign_in_with_google') ??
                                'Entrar com Google',
                            borderColor: borderColor,
                            cardColor: cardColor,
                            textColor: textPrimary,
                          ),

                        const SizedBox(height: 16),

                        // Divider
                        Row(
                          children: [
                            Expanded(
                              child: Divider(color: borderColor, height: 1),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                context.tr.translate('or') ?? 'ou',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(color: borderColor, height: 1),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Email button
                        _SocialButton(
                          onPressed: () async {
                            final loginSucceeded =
                                await Navigator.of(context).push<bool>(
                              MaterialPageRoute(
                                builder: (context) =>
                                    const EmailLoginScreen(),
                              ),
                            );

                            if (!mounted || loginSucceeded != true) {
                              return;
                            }

                            if (widget.popOnSuccess) {
                              _closeAfterSuccessfulLogin();
                            }
                          },
                          icon: Icon(
                            Icons.email_outlined,
                            size: 20,
                            color: textPrimary,
                          ),
                          label: context.tr.translate('sign_in_with_email') ??
                              'Entrar com email e senha',
                          borderColor: borderColor,
                          cardColor: cardColor,
                          textColor: textPrimary,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget icon;
  final String label;
  final Color borderColor;
  final Color cardColor;
  final Color textColor;

  const _SocialButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.borderColor,
    required this.cardColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: cardColor,
          foregroundColor: textColor,
          side: BorderSide(color: borderColor, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 10),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
