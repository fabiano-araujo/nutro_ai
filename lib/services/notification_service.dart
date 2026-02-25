import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import '../util/app_constants.dart';

/// Handler de mensagens em background - deve ser top-level
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('[NotificationService] Background message: ${message.messageId}');
  print('[NotificationService] Title: ${message.notification?.title}');
  print('[NotificationService] Body: ${message.notification?.body}');
}

/// Service para gerenciar notificacoes push via Firebase Cloud Messaging
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  String? _fcmToken;
  String? _authToken;
  bool _isInitialized = false;

  String? get fcmToken => _fcmToken;
  bool get isInitialized => _isInitialized;

  /// Inicializa o servico de notificacoes
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Solicitar permissao
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      print('[NotificationService] Permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // Obter token FCM
        _fcmToken = await _messaging.getToken();
        print('[NotificationService] FCM Token: $_fcmToken');

        // Escutar refresh de token
        _messaging.onTokenRefresh.listen(_handleTokenRefresh);

        // Configurar handlers de mensagens
        _setupMessageHandlers();

        _isInitialized = true;
      } else {
        print('[NotificationService] Notifications not authorized');
      }
    } catch (e) {
      print('[NotificationService] Error initializing: $e');
    }
  }

  /// Configura handlers para diferentes estados do app
  void _setupMessageHandlers() {
    // Mensagens em foreground
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Quando app eh aberto via notificacao (estado terminado)
    FirebaseMessaging.instance.getInitialMessage().then(_handleInitialMessage);

    // Quando app eh aberto via notificacao (estado background)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
  }

  /// Trata mensagens em foreground
  void _handleForegroundMessage(RemoteMessage message) {
    print('[NotificationService] Foreground message received');
    print('[NotificationService] Title: ${message.notification?.title}');
    print('[NotificationService] Body: ${message.notification?.body}');
    print('[NotificationService] Data: ${message.data}');

    // TODO: Mostrar notificacao in-app ou snackbar
    // O Firebase Messaging nao mostra notificacao automaticamente em foreground
  }

  /// Trata quando app eh aberto via notificacao (estado terminado)
  void _handleInitialMessage(RemoteMessage? message) {
    if (message != null) {
      print('[NotificationService] Initial message: ${message.data}');
      _navigateFromNotification(message.data);
    }
  }

  /// Trata quando app eh aberto via notificacao (estado background)
  void _handleMessageOpenedApp(RemoteMessage message) {
    print('[NotificationService] Message opened app: ${message.data}');
    _navigateFromNotification(message.data);
  }

  /// Navega baseado nos dados da notificacao
  void _navigateFromNotification(Map<String, dynamic> data) {
    final type = data['type'];
    final screen = data['screen'];

    print('[NotificationService] Navigate to: $screen (type: $type)');
    // TODO: Implementar navegacao usando navigatorKey global
    // Por exemplo:
    // if (type == 'friend_request') {
    //   navigatorKey.currentState?.pushNamed('/social');
    // }
  }

  /// Trata refresh de token
  void _handleTokenRefresh(String newToken) async {
    print('[NotificationService] Token refreshed');
    _fcmToken = newToken;

    // Re-registrar com backend se autenticado
    if (_authToken != null) {
      await registerTokenWithBackend(_authToken!);
    }
  }

  /// Define o token de autenticacao
  void setAuthToken(String? token) {
    _authToken = token;
  }

  /// Registra token FCM no backend
  Future<bool> registerTokenWithBackend(String authToken) async {
    if (_fcmToken == null) {
      print('[NotificationService] No FCM token to register');
      return false;
    }

    try {
      final response = await http.post(
        Uri.parse('${AppConstants.API_BASE_URL}/fcm/register'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'token': _fcmToken,
          'platform': Platform.isIOS ? 'ios' : 'android',
        }),
      );

      if (response.statusCode == 200) {
        print('[NotificationService] Token registered with backend');
        _authToken = authToken;
        return true;
      } else {
        print('[NotificationService] Failed to register token: ${response.statusCode}');
        print('[NotificationService] Response: ${response.body}');
        return false;
      }
    } catch (e) {
      print('[NotificationService] Error registering token: $e');
      return false;
    }
  }

  /// Remove registro do token FCM no backend (logout)
  Future<void> unregisterTokenFromBackend(String authToken) async {
    if (_fcmToken == null) return;

    try {
      final response = await http.post(
        Uri.parse('${AppConstants.API_BASE_URL}/fcm/unregister'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'token': _fcmToken,
        }),
      );

      if (response.statusCode == 200) {
        print('[NotificationService] Token unregistered from backend');
      } else {
        print('[NotificationService] Failed to unregister token: ${response.statusCode}');
      }
    } catch (e) {
      print('[NotificationService] Error unregistering token: $e');
    }

    _authToken = null;
  }

  /// Obtem o token FCM atual (pode ser null se nao inicializado)
  Future<String?> getToken() async {
    if (_fcmToken == null) {
      _fcmToken = await _messaging.getToken();
    }
    return _fcmToken;
  }
}
