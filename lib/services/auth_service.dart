import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_model.dart';
import 'api_service.dart';

class AuthService with ChangeNotifier {
  User? _currentUser;
  String? _token;
  bool _isLoading = false;
  String? _errorMessage; // Para armazenar mensagens de erro
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  User? get currentUser => _currentUser;
  String? get token => _token;
  bool get isAuthenticated => _currentUser != null && _token != null;
  bool get isLoading => _isLoading;
  String? get errorMessage =>
      _errorMessage; // Getter para acessar mensagem de erro

  // Inicializar o serviço e verificar se há um token salvo
  Future<void> initialize() async {
    _setLoading(true);
    _errorMessage = null; // Limpar mensagens de erro anteriores
    try {
      print('[AuthService] Inicializando serviço de autenticação');

      // Verificar se há dados salvos no armazenamento seguro
      final savedToken = await _storage.read(key: 'auth_token');
      final savedUserJson = await _storage.read(key: 'user_data');

      print('[AuthService] Token salvo: ${savedToken != null ? 'Sim' : 'Não'}');
      print(
          '[AuthService] Dados de usuário salvos: ${savedUserJson != null ? 'Sim' : 'Não'}');

      if (savedToken != null && savedUserJson != null) {
        // Carregar os dados do usuário salvos
        final userData = jsonDecode(savedUserJson);
        _currentUser = User.fromJson(userData);
        _token = savedToken;

        print(
            '[AuthService] Dados de sessão restaurados para: ${_currentUser!.name}');

        // Não é mais necessário validar token em background
        // Uma vez que o login é feito, o token é válido enquanto o usuário estiver logado
      } else {
        print(
            '[AuthService] Nenhum token ou usuário encontrado no armazenamento');
      }
    } catch (e) {
      _errorMessage = 'Erro ao inicializar: ${e.toString().split('\n')[0]}';
      print('[AuthService] Erro ao inicializar autenticação: $e');
      await logout(); // Limpar dados em caso de erro
    } finally {
      _setLoading(false);
    }
  }

  // Login com Google
  Future<bool> signInWithGoogle() async {
    _setLoading(true);
    _errorMessage = null; // Limpar mensagens de erro anteriores

    try {
      print('[AuthService] Iniciando login com Google');

      // Iniciar o processo de login do Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        print('[AuthService] Usuário cancelou o login com Google');
        _errorMessage = 'Login cancelado pelo usuário';
        return false; // Usuário cancelou o login
      }

      print(
          '[AuthService] Usuário Google obtido: ${googleUser.displayName}, ${googleUser.email}');

      // Obter informações do usuário Google
      final userData = {
        'email': googleUser.email,
        'name': googleUser.displayName ?? 'Usuário Google',
        'googleId': googleUser.id,
        'picture': googleUser.photoUrl ?? '',
      };

      print('[AuthService] Enviando dados para API: $userData');

      // Enviar para a API para autenticação
      final response = await ApiService.authenticateWithGoogle(
        email: userData['email']!,
        name: userData['name']!,
        googleId: userData['googleId']!,
        picture: userData['picture']!,
      );

      print('[AuthService] Resposta da API: $response');

      if (response['success'] == true && response['token'] != null) {
        // Salvar os dados do usuário e token
        _currentUser = User.fromJson(response['user']);
        _token = response['token'];

        // Salvar o token e dados do usuário para uso futuro
        await _storage.write(key: 'auth_token', value: _token);
        await _storage.write(
          key: 'user_data',
          value: jsonEncode(_currentUser!.toJson()),
        );

        print(
            '[AuthService] Usuário autenticado e salvo: ${_currentUser!.name}');
        _errorMessage = null;
        notifyListeners();
        return true;
      } else {
        _errorMessage =
            response['message'] ?? 'Erro desconhecido na autenticação';
        print('[AuthService] Falha na autenticação: $_errorMessage');
        return false;
      }
    } catch (e) {
      _errorMessage = 'Erro ao conectar: ${e.toString().split('\n')[0]}';
      print('[AuthService] Erro no login com Google: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Atualizar o perfil do usuário atual
  Future<bool> refreshUserProfile() async {
    if (!isAuthenticated || _token == null) {
      print('[AuthService] Tentativa de atualizar perfil sem autenticação');
      return false;
    }

    try {
      print(
          '[AuthService] Atualizando perfil do usuário: ${_currentUser?.name}');

      final updatedUser = await ApiService.getUserProfile(_token!);

      if (updatedUser != null) {
        // Verificar se houve mudança real nos dados antes de notificar
        bool changed = jsonEncode(_currentUser?.toJson()) !=
            jsonEncode(updatedUser.toJson());

        if (changed) {
          // Atualizar usuário em memória
          _currentUser = updatedUser;

          // Salvar os dados atualizados
          await _storage.write(
            key: 'user_data',
            value: jsonEncode(_currentUser!.toJson()),
          );

          print(
              '[AuthService] Perfil do usuário atualizado: ${_currentUser!.name}');
          notifyListeners(); // Notificar APENAS se houver mudança
        } else {
          print('[AuthService] Perfil do usuário já estava atualizado.');
        }
        return true;
      } else {
        print(
            '[AuthService] Não foi possível obter dados atualizados do usuário');
        // Considerar tratar erro de sessão inválida aqui também
        if (_token != null) {
          _errorMessage = 'Sessão inválida. Faça login novamente.';
          notifyListeners(); // Notificar sobre o erro
        }
        return false;
      }
    } catch (e) {
      print('[AuthService] Erro ao atualizar perfil: $e');

      // Se o erro for claramente relacionado à autenticação (401/403)
      if (e.toString().contains('401') ||
          e.toString().contains('403') ||
          e.toString().contains('unauthorized') ||
          e.toString().contains('não autorizado')) {
        print('[AuthService] Erro de autorização detectado, realizando logout');
        _errorMessage = 'Sessão inválida. Faça login novamente.';
        notifyListeners(); // Notificar antes do logout
        await logout();
      }
      // Para outros erros (conexão, etc.), apenas reportar
      else {
        _errorMessage =
            'Erro ao atualizar perfil: ${e.toString().split('\n')[0]}';
        notifyListeners();
      }

      return false;
    }
  }

  // Método para logout
  Future<void> logout({bool silent = false}) async {
    _setLoading(true);
    try {
      print('[AuthService] Iniciando processo de logout (silent: $silent)');

      // Tentar fazer logout do Google, mas não falhar se não conseguir
      try {
        await _googleSignIn.signOut();
        print('[AuthService] Logout do Google realizado com sucesso');
      } catch (e) {
        print('[AuthService] Erro ao fazer logout do Google: $e');
        // Continuar mesmo com erro, pois precisamos limpar os dados locais
      }

      // Limpar dados salvos
      await _storage.delete(key: 'auth_token');
      await _storage.delete(key: 'user_data');
      print('[AuthService] Dados de autenticação removidos do armazenamento');

      // Limpar dados em memória
      _currentUser = null;
      _token = null;

      // Limpar mensagem de erro se o logout for silencioso
      if (silent) {
        _errorMessage = null;
      }

      print('[AuthService] Logout realizado com sucesso');
      notifyListeners();
    } catch (e) {
      print('[AuthService] Erro ao fazer logout: $e');

      // Mesmo com erro, garantir que os dados em memória sejam limpos
      _currentUser = null;
      _token = null;
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  // Método para atualizar o usuário localmente sem chamar API
  // Útil para atualizar dados após confirmação de pagamento
  Future<void> updateUserLocally(User updatedUser) async {
    if (!isAuthenticated) {
      print('[AuthService] Tentativa de atualizar usuário sem autenticação');
      return;
    }

    try {
      print(
          '[AuthService] Atualizando usuário localmente: ${updatedUser.name}');

      // Atualizar usuário em memória
      _currentUser = updatedUser;

      // Salvar os dados atualizados no armazenamento
      await _storage.write(
        key: 'user_data',
        value: jsonEncode(_currentUser!.toJson()),
      );

      print('[AuthService] Usuário atualizado localmente com sucesso');

      // Chamamos notifyListeners() aqui agora para garantir que os ouvintes sejam notificados
      // independentemente de quem chamou este método
      notifyListeners();
    } catch (e) {
      print('[AuthService] Erro ao atualizar usuário localmente: $e');
    }
  }

  // Método específico para atualizar assinatura premium
  // Usado quando um pagamento é confirmado
  Future<void> updateSubscriptionStatus({
    required bool isPremium,
    required String planType,
    DateTime? expirationDate,
    int? remainingDays,
  }) async {
    if (!isAuthenticated || _currentUser == null) {
      print(
          '[AuthService] Tentativa de atualizar assinatura sem usuário autenticado');
      return;
    }

    try {
      print(
          '[AuthService] Atualizando status de assinatura para isPremium=$isPremium, planType=$planType');

      // Criar nova assinatura com os dados atualizados
      final updatedSubscription = Subscription(
        isPremium: isPremium,
        planType: planType,
        expirationDate: expirationDate,
        remainingDays: remainingDays,
      );

      // Criar usuário atualizado mantendo os outros dados
      final updatedUser = User(
        id: _currentUser!.id,
        name: _currentUser!.name,
        email: _currentUser!.email,
        username: _currentUser!.username,
        photo: _currentUser!.photo,
        subscription: updatedSubscription,
      );

      // Chamar o método updateUserLocally que já cuida de salvar e notificar
      await updateUserLocally(updatedUser);

      // Forçar uma notificação adicional para garantir
      print('[AuthService] Notificando assinatura atualizada para Premium');
      Future.delayed(Duration.zero, () => notifyListeners());
    } catch (e) {
      print('[AuthService] Erro ao atualizar status de assinatura: $e');
    }
  }

  // Verificar a idade do token e limpar se for muito antigo (usado quando o app é reaberto)
  Future<bool> checkTokenAge() async {
    // Tokens são válidos enquanto o usuário estiver logado
    // Não é necessário verificar a idade do token
    return isAuthenticated;
  }

  // Método para buscar dados completos do usuário e atualizar o status de assinatura
  Future<Map<String, dynamic>?> fetchUserDataAndUpdateStatus() async {
    if (!isAuthenticated || _currentUser == null || _token == null) {
      print('[AuthService] Tentativa de buscar dados sem estar autenticado');
      return null;
    }

    try {
      print(
          '[AuthService] Buscando dados completos do usuário: ${_currentUser!.id}');

      // Buscar dados do usuário pelo ID
      final userData = await ApiService.getUserData(_token!, _currentUser!.id);

      print('[AuthService] Dados do usuário recebidos:');
      print('[AuthService] Subscription: ${userData['subscription']}');

      // Verificar se o campo subscription existe
      if (userData.containsKey('subscription')) {
        final String subscriptionType = userData['subscription'] as String;

        // Atualizar o status da assinatura com base no valor recebido
        final bool isPremium = subscriptionType != 'free';

        print(
            '[AuthService] Atualizando assinatura: isPremium=$isPremium, type=$subscriptionType');

        // Criar nova assinatura com os dados atualizados
        final updatedSubscription = Subscription(
          isPremium: isPremium,
          planType: subscriptionType,
          expirationDate: null, // Não temos essa informação na resposta
          remainingDays: null, // Não temos essa informação na resposta
        );

        // Criar usuário atualizado mantendo os outros dados
        final updatedUser = User(
          id: _currentUser!.id,
          name: _currentUser!.name,
          email: _currentUser!.email,
          username: _currentUser!.username,
          photo: _currentUser!.photo,
          subscription: updatedSubscription,
        );

        // Atualizar o usuário localmente
        await updateUserLocally(updatedUser);
        print('[AuthService] Status de assinatura atualizado com sucesso');
      }

      return userData;
    } catch (e) {
      print('[AuthService] Erro ao buscar dados do usuário: $e');
      return null;
    }
  }

  // Método para atualizar dados de usuário após login com email/senha
  Future<bool> updateUserDataFromLoginResponse(
      Map<String, dynamic> data) async {
    try {
      // Verificar se os dados contêm as informações necessárias
      if (data['success'] == true &&
          data['token'] != null &&
          data['user'] != null) {
        // Salvar os dados do usuário e token
        _currentUser = User.fromJson(data['user']);
        _token = data['token'];

        // Salvar o token e dados do usuário para uso futuro
        await _storage.write(key: 'auth_token', value: _token);
        await _storage.write(
          key: 'user_data',
          value: jsonEncode(_currentUser!.toJson()),
        );

        print(
            '[AuthService] Usuário autenticado via email: ${_currentUser!.name}');
        _errorMessage = null;
        notifyListeners();
        return true;
      } else {
        _errorMessage = data['message'] ?? 'Erro desconhecido na autenticação';
        print('[AuthService] Falha na autenticação com email: $_errorMessage');
        return false;
      }
    } catch (e) {
      _errorMessage = 'Erro ao processar dados: ${e.toString().split('\n')[0]}';
      print('[AuthService] Erro ao processar dados de login: $e');
      return false;
    }
  }

  // Atualizar estado de carregamento
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
