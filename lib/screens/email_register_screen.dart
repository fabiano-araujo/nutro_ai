import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../i18n/app_localizations_extension.dart';
import '../services/api_service.dart';

class EmailRegisterScreen extends StatefulWidget {
  const EmailRegisterScreen({Key? key}) : super(key: key);

  @override
  State<EmailRegisterScreen> createState() => _EmailRegisterScreenState();
}

class _EmailRegisterScreenState extends State<EmailRegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _errorMessage = '';

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

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
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final name = _nameController.text.trim();
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      final data = await ApiService.registerWithEmail(
        name: name,
        email: email,
        senha: password,
      );

      if (data['success'] == true) {
        final authService = Provider.of<AuthService>(context, listen: false);
        final authUpdated =
            await authService.updateUserDataFromLoginResponse(data);

        if (!authUpdated || !authService.isAuthenticated) {
          if (mounted) {
            setState(() {
              _errorMessage = authService.errorMessage ??
                  data['message']?.toString() ??
                  context.tr.translate('server_connection_error');
            });
          }
          return;
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr.translate('registration_success')),
              backgroundColor: AppTheme.successColor,
            ),
          );

          Navigator.of(context).pop(true);
        }
      } else {
        setState(() {
          final errorDetail = (data['error']?.toString() ?? '').toLowerCase();
          final message = (data['message']?.toString() ?? '').toLowerCase();

          if (errorDetail.contains('email ja esta em uso') ||
              errorDetail.contains('email já está em uso') ||
              errorDetail.contains('email already') ||
              message.contains('email ja esta em uso') ||
              message.contains('email já está em uso') ||
              message.contains('email already')) {
            _errorMessage = context.tr.translate('email_already_in_use');
          } else {
            _errorMessage =
                data['message'] ?? context.tr.translate('registration_failed');
          }
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = context.tr.translate('server_connection_error');
      });
    } finally {
      if (mounted) {
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
    final bgColor =
        isDarkMode ? AppTheme.darkBackgroundColor : AppTheme.backgroundColor;
    final textPrimary =
        isDarkMode ? AppTheme.darkTextColor : AppTheme.textPrimaryColor;
    final textSecondary =
        isDarkMode ? const Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;
    final primaryColor =
        isDarkMode ? AppTheme.primaryColorDarkMode : AppTheme.primaryColor;
    final onPrimary = AppTheme.onColor(primaryColor);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildMinimalHeader(textColor: textPrimary),
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
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _buildRegisterMark(
                                      textColor: textPrimary,
                                      isDarkMode: isDarkMode,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      context.tr.translate('create_account'),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.getSoftTextColor(
                                          isDarkMode,
                                        ),
                                        height: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      context.tr.translate('register_subtitle'),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: textSecondary.withValues(
                                          alpha: 0.86,
                                        ),
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 28),
                                    if (_errorMessage.isNotEmpty) ...[
                                      _buildErrorMessage(),
                                      const SizedBox(height: 16),
                                    ],
                                    _FieldLabel(
                                      label: context.tr.translate('name'),
                                      color: textSecondary,
                                    ),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _nameController,
                                      keyboardType: TextInputType.name,
                                      textCapitalization:
                                          TextCapitalization.words,
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: textPrimary,
                                      ),
                                      decoration: _fieldDecoration(
                                        hintText: context.tr.translate('name'),
                                        icon: Icons.person_outline_rounded,
                                        isDarkMode: isDarkMode,
                                        textSecondary: textSecondary,
                                        primaryColor: primaryColor,
                                      ),
                                      validator: (value) {
                                        final name = value?.trim() ?? '';
                                        if (name.isEmpty) {
                                          return context.tr.translate(
                                            'please_enter_name',
                                          );
                                        }
                                        if (name.length < 2) {
                                          return context.tr.translate(
                                            'name_min_length',
                                          );
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    _FieldLabel(
                                      label: context.tr.translate('email'),
                                      color: textSecondary,
                                    ),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _emailController,
                                      keyboardType: TextInputType.emailAddress,
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: textPrimary,
                                      ),
                                      decoration: _fieldDecoration(
                                        hintText: 'exemplo@email.com',
                                        icon: Icons.email_outlined,
                                        isDarkMode: isDarkMode,
                                        textSecondary: textSecondary,
                                        primaryColor: primaryColor,
                                      ),
                                      validator: (value) {
                                        final email = value?.trim() ?? '';
                                        if (email.isEmpty) {
                                          return context.tr.translate(
                                            'please_enter_email',
                                          );
                                        }
                                        if (!RegExp(
                                          r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                        ).hasMatch(email)) {
                                          return context.tr.translate(
                                            'please_enter_valid_email',
                                          );
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    _FieldLabel(
                                      label: context.tr.translate('password'),
                                      color: textSecondary,
                                    ),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _passwordController,
                                      obscureText: _obscurePassword,
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: textPrimary,
                                      ),
                                      decoration: _fieldDecoration(
                                        hintText: '••••••••',
                                        icon: Icons.lock_outline_rounded,
                                        isDarkMode: isDarkMode,
                                        textSecondary: textSecondary,
                                        primaryColor: primaryColor,
                                      ).copyWith(
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_outlined
                                                : Icons.visibility_off_outlined,
                                            size: 20,
                                            color: textSecondary,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _obscurePassword =
                                                  !_obscurePassword;
                                            });
                                          },
                                        ),
                                      ),
                                      validator: (value) {
                                        final password = value?.trim() ?? '';
                                        if (password.isEmpty) {
                                          return context.tr.translate(
                                            'please_enter_password',
                                          );
                                        }
                                        if (password.length < 6) {
                                          return context.tr.translate(
                                            'password_min_length',
                                          );
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    _FieldLabel(
                                      label: context.tr.translate(
                                        'confirm_password',
                                      ),
                                      color: textSecondary,
                                    ),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _confirmPasswordController,
                                      obscureText: _obscureConfirmPassword,
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: textPrimary,
                                      ),
                                      decoration: _fieldDecoration(
                                        hintText: '••••••••',
                                        icon: Icons.lock_outline_rounded,
                                        isDarkMode: isDarkMode,
                                        textSecondary: textSecondary,
                                        primaryColor: primaryColor,
                                      ).copyWith(
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscureConfirmPassword
                                                ? Icons.visibility_outlined
                                                : Icons.visibility_off_outlined,
                                            size: 20,
                                            color: textSecondary,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _obscureConfirmPassword =
                                                  !_obscureConfirmPassword;
                                            });
                                          },
                                        ),
                                      ),
                                      validator: (value) {
                                        final confirmPassword =
                                            value?.trim() ?? '';
                                        if (confirmPassword.isEmpty) {
                                          return context.tr.translate(
                                            'please_confirm_password',
                                          );
                                        }
                                        if (confirmPassword !=
                                            _passwordController.text.trim()) {
                                          return context.tr.translate(
                                            'passwords_dont_match',
                                          );
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 24),
                                    _buildSubmitButton(
                                      primaryColor: primaryColor,
                                      onPrimary: onPrimary,
                                    ),
                                    const SizedBox(height: 22),
                                    _buildLoginLink(
                                      textSecondary: textSecondary,
                                      primaryColor: primaryColor,
                                    ),
                                  ],
                                ),
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

  Widget _buildMinimalHeader({required Color textColor}) {
    return SizedBox(
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: Icon(Icons.arrow_back, color: textColor),
              onPressed: () => Navigator.of(context).pop(),
              tooltip: context.tr.translate('back'),
            ),
          ),
          Center(
            child: Text(
              context.tr.translate('register_title'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterMark({
    required Color textColor,
    required bool isDarkMode,
  }) {
    return Center(
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: _surfaceColor(isDarkMode),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: _subtleBorderColor(isDarkMode)),
        ),
        child: Icon(
          Icons.person_add_alt_outlined,
          size: 23,
          color: textColor.withValues(alpha: 0.82),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String hintText,
    required IconData icon,
    required bool isDarkMode,
    required Color textSecondary,
    required Color primaryColor,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: _subtleBorderColor(isDarkMode)),
    );

    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: _surfaceColor(isDarkMode),
      prefixIcon: Icon(
        icon,
        size: 20,
        color: textSecondary,
      ),
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: primaryColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppTheme.errorColor, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppTheme.errorColor, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: TextStyle(
        color: textSecondary.withValues(alpha: 0.72),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.errorColor.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppTheme.errorColor,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.errorColor,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton({
    required Color primaryColor,
    required Color onPrimary,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: primaryColor,
              ),
            )
          : ElevatedButton(
              onPressed: _handleRegister,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: onPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      context.tr.translate('register_button'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: onPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.arrow_forward, size: 18, color: onPrimary),
                ],
              ),
            ),
    );
  }

  Widget _buildLoginLink({
    required Color textSecondary,
    required Color primaryColor,
  }) {
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        children: [
          Text(
            context.tr.translate('already_have_account'),
            style: TextStyle(
              fontSize: 13,
              color: textSecondary,
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              context.tr.translate('login_button'),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  final Color color;

  const _FieldLabel({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
  }
}
