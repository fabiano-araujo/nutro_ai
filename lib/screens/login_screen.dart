import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../i18n/app_localizations_extension.dart';
import 'email_login_screen.dart';
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
      duration: const Duration(milliseconds: 700),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.1, 0.7, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.12),
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
    if (_isLoading) {
      return;
    }

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
        final errorMsg = _localizedGoogleLoginError(authService.errorMessage);

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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr.translate('server_connection_error')),
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

  String _localizedGoogleLoginError(String? error) {
    final normalized = error?.toLowerCase() ?? '';
    if (normalized.contains('cancel')) {
      return context.tr.translate('login_cancelled');
    }
    if (normalized.contains('conectar') ||
        normalized.contains('connection') ||
        normalized.contains('network')) {
      return context.tr.translate('server_connection_error');
    }
    return context.tr.translate('google_login_failed');
  }

  Future<void> _openEmailLogin() async {
    if (_isLoading) {
      return;
    }

    final loginSucceeded = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => const EmailLoginScreen(),
      ),
    );

    if (!mounted || loginSucceeded != true) {
      return;
    }

    if (widget.popOnSuccess) {
      _closeAfterSuccessfulLogin();
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
        isDarkMode ? AppTheme.darkMutedTextColor : AppTheme.textSecondaryColor;
    final primaryColor =
        isDarkMode ? AppTheme.primaryColorDarkMode : AppTheme.primaryColor;
    final onPrimary = AppTheme.onColor(primaryColor);
    final surfaceColor =
        isDarkMode ? AppTheme.darkComponentColor : const Color(0xFFF3F7F7);
    final borderColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

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
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minHeight: constraints.maxHeight),
                      child: Center(
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: SlideTransition(
                            position: _slideAnimation,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 420),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _LoginMark(
                                    primaryColor: primaryColor,
                                    isDarkMode: isDarkMode,
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    context.tr.translate('app_title'),
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w700,
                                      color: textPrimary,
                                      height: 1.15,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    context.tr
                                        .translate('login_welcome_description'),
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      color: textSecondary,
                                      height: 1.45,
                                    ),
                                  ),
                                  const SizedBox(height: 36),
                                  _SocialButton(
                                    onPressed:
                                        _isLoading ? null : _handleGoogleLogin,
                                    isLoading: _isLoading,
                                    icon: Container(
                                      width: 28,
                                      height: 28,
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: const _GoogleGMark(size: 16),
                                    ),
                                    label: context.tr
                                        .translate('sign_in_with_google'),
                                    backgroundColor: primaryColor,
                                    borderColor: primaryColor,
                                    textColor: onPrimary,
                                  ),
                                  const SizedBox(height: 12),
                                  _SocialButton(
                                    onPressed:
                                        _isLoading ? null : _openEmailLogin,
                                    icon: Icon(
                                      Icons.mail_outline_rounded,
                                      size: 20,
                                      color: textPrimary,
                                    ),
                                    label: context.tr
                                        .translate('sign_in_with_email_short'),
                                    backgroundColor: surfaceColor,
                                    borderColor: borderColor,
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
  }) {
    final isProfileTab = widget.onOpenDrawer != null;
    final title = context.tr.translate(
      isProfileTab ? 'profile' : 'login_title',
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            if (widget.onOpenDrawer != null)
              IconButton(
                icon: Icon(Icons.menu_rounded, color: textColor),
                onPressed: widget.onOpenDrawer,
                tooltip: context.tr.translate('menu'),
              )
            else if (canPop)
              IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: textColor),
                onPressed: () => Navigator.of(context).maybePop(),
                tooltip: context.tr.translate('back'),
              )
            else
              const SizedBox(width: 48),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.settings_rounded, color: textColor),
              tooltip: context.tr.translate('settings_title'),
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
    );
  }
}

class _LoginMark extends StatelessWidget {
  final Color primaryColor;
  final bool isDarkMode;

  const _LoginMark({
    required this.primaryColor,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.darkCardColor : Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: isDarkMode ? 0.22 : 0.16),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/logo.png',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Icon(
              Icons.restaurant_menu_rounded,
              size: 36,
              color: primaryColor,
            );
          },
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget icon;
  final String label;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final bool isLoading;

  const _SocialButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
    this.isLoading = false,
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
          disabledBackgroundColor: backgroundColor.withValues(alpha: 0.72),
          side: BorderSide(color: borderColor, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: isLoading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: textColor,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  icon,
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
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

class _GoogleGMark extends StatelessWidget {
  final double size;

  const _GoogleGMark({this.size = 18});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: const CustomPaint(painter: _GoogleGPainter()),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  const _GoogleGPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.20;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -0.22, 1.25, false, paint);
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 0.95, 1.35, false, paint);
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, 2.28, 0.95, false, paint);
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, 3.25, 1.85, false, paint);

    canvas.drawRect(
      Rect.fromLTWH(
        size.width / 2,
        (size.height - stroke) / 2,
        size.width / 2 - stroke * 0.18,
        stroke,
      ),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
