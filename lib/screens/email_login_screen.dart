import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../i18n/app_localizations_extension.dart';
import '../util/app_constants.dart';
import '../services/api_service.dart';
import 'email_register_screen.dart';

class EmailLoginScreen extends StatefulWidget {
  const EmailLoginScreen({Key? key}) : super(key: key);

  @override
  State<EmailLoginScreen> createState() => _EmailLoginScreenState();
}

class _EmailLoginScreenState extends State<EmailLoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String _errorMessage = '';

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
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
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleEmailLogin() async {
    // Validar o formulário
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      // Chamar API para login usando ApiService
      final data = await ApiService.authenticateWithEmail(
        email: email,
        senha: password,
      );

      if (data['success'] == true) {
        // Login bem-sucedido
        final authService = Provider.of<AuthService>(context, listen: false);

        // Atualizar o serviço de autenticação com os dados do usuário
        await authService.updateUserDataFromLoginResponse(data);

        if (mounted) {
          // Mostrar mensagem de sucesso
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.tr.translate('login_success') ??
                    'Login realizado com sucesso!',
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );

          // Aguardar um pouco para garantir que o AuthService foi atualizado
          await Future.delayed(Duration(milliseconds: 300));

          // O Builder no IndexedStack vai detectar automaticamente
          // a mudança no authService e mostrar o ProfileScreen
          // Apenas atualizamos o estado para refletir a mudança
          setState(() {
            _isLoading = false;
          });
        }
      } else {
        // Tratar erro de login
        setState(() {
          _errorMessage = data['message'] ??
              'Falha ao fazer login. Verifique suas credenciais.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage =
            'Erro ao conectar ao servidor. Tente novamente mais tarde.';
      });
      print('[EmailLoginScreen] Erro ao fazer login: $e');
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
    final size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr.translate('email_login_title') ?? 'Login com Email',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: false,
        scrolledUnderElevation: 0,
        backgroundColor: isDarkMode
            ? AppTheme.darkBackgroundColor
            : AppTheme.primaryColor.withOpacity(0.8),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDarkMode
                ? [
                    AppTheme.darkBackgroundColor,
                    AppTheme.darkCardColor,
                  ]
                : [
                    AppTheme.primaryColor.withOpacity(0.8),
                    AppTheme.primaryDarkColor,
                  ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 60),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: size.height * 0.05),
                    // Logo
                    Container(
                      width: 80,
                      height: 80,
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
                              Icons.email,
                              size: 40,
                              color: Colors.white,
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Título
                    Text(
                      context.tr.translate('enter_with_email') ??
                          'Entre com seu Email',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Subtítulo
                    Text(
                      context.tr.translate('access_account') ??
                          'Acesse sua conta para continuar',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Formulário
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color:
                            isDarkMode ? AppTheme.darkCardColor : Colors.white,
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
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_errorMessage.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 20),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.red.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      color: Colors.red,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _errorMessage,
                                        style: TextStyle(
                                          color: Colors.red,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // Campo de email
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                labelText:
                                    context.tr.translate('email') ?? 'Email',
                                prefixIcon: Icon(Icons.email_outlined),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: isDarkMode
                                        ? Colors.grey.shade800
                                        : Colors.grey.shade300,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return context.tr
                                          .translate('please_enter_email') ??
                                      'Por favor, insira seu email';
                                }
                                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                    .hasMatch(value)) {
                                  return context.tr.translate(
                                          'please_enter_valid_email') ??
                                      'Por favor, insira um email válido';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),

                            // Campo de senha
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText:
                                    context.tr.translate('password') ?? 'Senha',
                                prefixIcon: Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: isDarkMode
                                        ? Colors.grey.shade800
                                        : Colors.grey.shade300,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return context.tr
                                          .translate('please_enter_password') ??
                                      'Por favor, insira sua senha';
                                }
                                if (value.length < 6) {
                                  return context.tr
                                          .translate('password_min_length') ??
                                      'A senha deve ter pelo menos 6 caracteres';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),

                            // Link de esqueci a senha
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  // Implementar esqueci a senha
                                },
                                child: Text(
                                  context.tr.translate('forgot_password') ??
                                      'Esqueceu a senha?',
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Botão de login
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: _isLoading
                                  ? Center(child: CircularProgressIndicator())
                                  : ElevatedButton(
                                      onPressed: _handleEmailLogin,
                                      child: Text(
                                        context.tr.translate('login_button') ??
                                            'Entrar',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            theme.colorScheme.primary,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        elevation: 1,
                                      ),
                                    ),
                            ),

                            const SizedBox(height: 24),

                            // Link para cadastro
                            Container(
                              width: double.infinity,
                              margin: EdgeInsets.only(top: 8),
                              child: Column(
                                children: [
                                  Text(
                                    context.tr.translate('no_account') ??
                                        'Ainda não tem uma conta?',
                                    style: TextStyle(
                                      color: isDarkMode
                                          ? Colors.grey.shade400
                                          : Colors.grey.shade700,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              EmailRegisterScreen(),
                                        ),
                                      );
                                    },
                                    child: Text(
                                      context.tr.translate('sign_up') ??
                                          'Cadastre-se',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
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
    );
  }
}
