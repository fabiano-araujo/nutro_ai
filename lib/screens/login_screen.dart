import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  Color _surfaceColor(bool isDarkMode) =>
      isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFFF3F3F3);
  Color _subtleBorderColor(bool isDarkMode) =>
      isDarkMode ? Colors.white12 : Colors.black12;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.1, 0.7, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.16),
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
    final textPrimary =
        isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;
    final textSecondary =
        isDarkMode ? const Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;
    final primaryColor =
        isDarkMode ? AppTheme.primaryColorDarkMode : AppTheme.primaryColor;
    final onPrimary = AppTheme.onColor(primaryColor);

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDarkMode ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDarkMode ? Brightness.dark : Brightness.light,
    ));

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildMinimalHeader(
              canPop: canPop,
              textColor: textPrimary,
              isDarkMode: isDarkMode,
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minHeight: constraints.maxHeight),
                      child: Center(
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: SlideTransition(
                            position: _slideAnimation,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 520),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  _buildLoginMark(
                                    primaryColor: primaryColor,
                                    textColor: textPrimary,
                                    isDarkMode: isDarkMode,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    context.tr.translate('app_title'),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w700,
                                      color:
                                          AppTheme.getSoftTextColor(isDarkMode),
                                      height: 1.15,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    context.tr.translate('welcome_description'),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 15,
                                      color:
                                          textSecondary.withValues(alpha: 0.9),
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 34),
                                  if (_isLoading)
                                    SizedBox(
                                      height: 52,
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
                                        size: 30,
                                        color: Colors.red,
                                      ),
                                      label: context.tr
                                          .translate('sign_in_with_google'),
                                      backgroundColor: primaryColor,
                                      borderColor: primaryColor,
                                      textColor: onPrimary,
                                    ),
                                  const SizedBox(height: 10),
                                  _SocialButton(
                                    onPressed: () async {
                                      final loginSucceeded =
                                          await Navigator.of(context)
                                              .push<bool>(
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
                                      size: 19,
                                      color: textPrimary,
                                    ),
                                    label: context.tr
                                        .translate('sign_in_with_email'),
                                    backgroundColor: _surfaceColor(isDarkMode),
                                    borderColor: _subtleBorderColor(isDarkMode),
                                    textColor: textPrimary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMinimalHeader({
    required bool canPop,
    required Color textColor,
    required bool isDarkMode,
  }) {
    return SizedBox(
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: widget.onOpenDrawer != null
                ? IconButton(
                    icon: Icon(Icons.menu, color: textColor),
                    onPressed: widget.onOpenDrawer,
                    tooltip: 'Menu',
                  )
                : canPop
                    ? IconButton(
                        icon: Icon(Icons.arrow_back, color: textColor),
                        onPressed: () => Navigator.of(context).maybePop(),
                        tooltip: context.tr.translate('back'),
                      )
                    : const SizedBox(width: 48),
          ),
          Center(
            child: Text(
              context.tr.translate('login_title'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CreditIndicator(),
                IconButton(
                  icon: Icon(Icons.card_giftcard, color: textColor),
                  tooltip: context.tr.translate('watch_ad_for_credits'),
                  onPressed: () => RewardAdDialog.show(context),
                ),
                IconButton(
                  icon: Icon(Icons.settings, color: textColor),
                  tooltip: context.tr.translate('settings'),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => SettingsScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginMark({
    required Color primaryColor,
    required Color textColor,
    required bool isDarkMode,
  }) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: _surfaceColor(isDarkMode),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: _subtleBorderColor(isDarkMode)),
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/logo.png',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Icon(
              Icons.restaurant_menu,
              size: 24,
              color: textColor.withValues(alpha: 0.82),
            );
          },
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget icon;
  final String label;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;

  const _SocialButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          side: BorderSide(color: borderColor, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
