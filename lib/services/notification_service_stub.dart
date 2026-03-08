Future<void> firebaseMessagingBackgroundHandler(dynamic message) async {}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  String? get fcmToken => null;
  bool get isInitialized => false;

  Future<void> initialize() async {}

  void setAuthToken(String? token) {}

  Future<bool> registerTokenWithBackend(String authToken) async => false;

  Future<void> unregisterTokenFromBackend(String authToken) async {}

  Future<String?> getToken() async => null;
}
