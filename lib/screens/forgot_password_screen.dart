import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../i18n/app_localizations_extension.dart';
import '../services/api_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String initialEmail;

  const ForgotPasswordScreen({
    Key? key,
    this.initialEmail = '',
  }) : super(key: key);

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  static const String _appIconAsset = 'assets/images/logo.png';

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  int _step = 0;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _errorMessage = '';

  Color _surfaceColor(bool isDarkMode) =>
      isDarkMode ? const Color(0xFF2A2A2A) : const Color(0xFFF3F3F3);
  Color _subtleBorderColor(bool isDarkMode) =>
      isDarkMode ? Colors.white12 : Colors.black12;

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.initialEmail;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitCurrentStep() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      if (_step == 0) {
        await _requestCode();
      } else if (_step == 1) {
        await _verifyCode();
      } else {
        await _resetPassword();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _requestCode() async {
    final data = await ApiService.requestPasswordReset(
      email: _emailController.text.trim(),
      lang: Localizations.localeOf(context).languageCode,
    );

    if (!mounted) {
      return;
    }

    if (data['success'] == false) {
      setState(() {
        _errorMessage = context.tr.translate('forgot_password_send_error');
      });
      return;
    }

    setState(() {
      _step = 1;
    });
  }

  Future<void> _verifyCode() async {
    final data = await ApiService.verifyPasswordResetCode(
      email: _emailController.text.trim(),
      code: _codeController.text.trim(),
    );

    if (!mounted) {
      return;
    }

    if (data['success'] != true || data['valid'] != true) {
      setState(() {
        _errorMessage = context.tr.translate('forgot_password_invalid_code');
      });
      return;
    }

    setState(() {
      _step = 2;
    });
  }

  Future<void> _resetPassword() async {
    final data = await ApiService.resetPassword(
      email: _emailController.text.trim(),
      code: _codeController.text.trim(),
      newPassword: _passwordController.text.trim(),
    );

    if (!mounted) {
      return;
    }

    if (data['success'] != true) {
      setState(() {
        _errorMessage = context.tr.translate('forgot_password_reset_error');
      });
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr.translate('forgot_password_success')),
        backgroundColor: AppTheme.successColor,
      ),
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final bgColor =
        isDarkMode ? AppTheme.darkBackgroundColor : AppTheme.backgroundColor;
    final textSecondary =
        isDarkMode ? const Color(0xFFAEB7CE) : AppTheme.textSecondaryColor;
    final titleColor = isDarkMode ? Colors.white : Colors.black;
    final fieldTextColor = isDarkMode ? Colors.white : Colors.black;
    final primaryColor =
        isDarkMode ? AppTheme.primaryColorDarkMode : AppTheme.primaryColor;
    final onPrimary = AppTheme.onColor(primaryColor);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(textColor: titleColor),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: _surfaceColor(isDarkMode),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _subtleBorderColor(isDarkMode),
                                ),
                              ),
                              child: ClipOval(
                                child: Image.asset(
                                  _appIconAsset,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _titleForStep(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: titleColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _subtitleForStep(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              color: textSecondary.withValues(alpha: 0.86),
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 28),
                          if (_errorMessage.isNotEmpty) ...[
                            _buildErrorMessage(),
                            const SizedBox(height: 16),
                          ],
                          if (_step == 0)
                            _buildEmailField(
                              isDarkMode: isDarkMode,
                              fieldTextColor: fieldTextColor,
                              textSecondary: textSecondary,
                              primaryColor: primaryColor,
                            ),
                          if (_step == 1)
                            _buildCodeField(
                              isDarkMode: isDarkMode,
                              fieldTextColor: fieldTextColor,
                              textSecondary: textSecondary,
                              primaryColor: primaryColor,
                            ),
                          if (_step == 2)
                            _buildPasswordFields(
                              isDarkMode: isDarkMode,
                              fieldTextColor: fieldTextColor,
                              textSecondary: textSecondary,
                              primaryColor: primaryColor,
                            ),
                          const SizedBox(height: 24),
                          SizedBox(
                            height: 52,
                            child: _isLoading
                                ? Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: primaryColor,
                                    ),
                                  )
                                : ElevatedButton(
                                    onPressed: _submitCurrentStep,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryColor,
                                      foregroundColor: onPrimary,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(100),
                                      ),
                                    ),
                                    child: Text(
                                      _buttonLabelForStep(),
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: onPrimary,
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
            ),
          ],
        ),
      ),
    );
  }

  String _titleForStep() {
    switch (_step) {
      case 1:
        return context.tr.translate('forgot_password_code_title');
      case 2:
        return context.tr.translate('forgot_password_new_title');
      default:
        return context.tr.translate('forgot_password_title');
    }
  }

  String _subtitleForStep() {
    switch (_step) {
      case 1:
        return context.tr.translate('forgot_password_code_subtitle');
      case 2:
        return context.tr.translate('forgot_password_new_subtitle');
      default:
        return context.tr.translate('forgot_password_subtitle');
    }
  }

  String _buttonLabelForStep() {
    switch (_step) {
      case 1:
        return context.tr.translate('forgot_password_verify_code');
      case 2:
        return context.tr.translate('forgot_password_save');
      default:
        return context.tr.translate('forgot_password_send_code');
    }
  }

  Widget _buildHeader({required Color textColor}) {
    return SizedBox(
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: Icon(Icons.arrow_back, color: textColor),
              onPressed: () {
                if (_step > 0) {
                  setState(() {
                    _errorMessage = '';
                    _step -= 1;
                  });
                  return;
                }
                Navigator.of(context).pop();
              },
              tooltip: context.tr.translate('back'),
            ),
          ),
          Center(
            child: Text(
              context.tr.translate('forgot_password_title'),
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

  Widget _buildEmailField({
    required bool isDarkMode,
    required Color fieldTextColor,
    required Color textSecondary,
    required Color primaryColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr.translate('email'),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: fieldTextColor,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: TextStyle(fontSize: 15, color: fieldTextColor),
          decoration: _fieldDecoration(
            hintText: context.tr.translate('email_example_hint'),
            icon: Icons.email_outlined,
            isDarkMode: isDarkMode,
            textSecondary: textSecondary,
            primaryColor: primaryColor,
          ),
          validator: (value) {
            final email = value?.trim() ?? '';
            if (email.isEmpty) {
              return context.tr.translate('please_enter_email');
            }
            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
              return context.tr.translate('please_enter_valid_email');
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildCodeField({
    required bool isDarkMode,
    required Color fieldTextColor,
    required Color textSecondary,
    required Color primaryColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr.translate('forgot_password_code_label'),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: fieldTextColor,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          maxLength: 4,
          style: TextStyle(
            fontSize: 22,
            letterSpacing: 8,
            fontWeight: FontWeight.w700,
            color: fieldTextColor,
          ),
          decoration: _fieldDecoration(
            hintText: '0000',
            icon: Icons.pin_outlined,
            isDarkMode: isDarkMode,
            textSecondary: textSecondary,
            primaryColor: primaryColor,
          ).copyWith(counterText: ''),
          validator: (value) {
            final code = value?.trim() ?? '';
            if (code.length != 4) {
              return context.tr.translate('forgot_password_code_invalid');
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPasswordFields({
    required bool isDarkMode,
    required Color fieldTextColor,
    required Color textSecondary,
    required Color primaryColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr.translate('password'),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: fieldTextColor,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          style: TextStyle(fontSize: 15, color: fieldTextColor),
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
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
          ),
          validator: (value) {
            final password = value?.trim() ?? '';
            if (password.isEmpty) {
              return context.tr.translate('please_enter_password');
            }
            if (password.length < 6) {
              return context.tr.translate('password_min_length');
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        Text(
          context.tr.translate('confirm_password'),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: fieldTextColor,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          style: TextStyle(fontSize: 15, color: fieldTextColor),
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
                  _obscureConfirmPassword = !_obscureConfirmPassword;
                });
              },
            ),
          ),
          validator: (value) {
            if ((value?.trim() ?? '') != _passwordController.text.trim()) {
              return context.tr.translate('passwords_dont_match');
            }
            return null;
          },
        ),
      ],
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
      prefixIcon: Icon(icon, size: 20, color: textSecondary),
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: primaryColor, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.72)),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.28)),
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
}
