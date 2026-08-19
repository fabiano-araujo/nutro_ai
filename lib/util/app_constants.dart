// Constantes da aplicação

/// URL base do servidor da API
class AppConstants {
  /// Modelo textual padrão usado pelo app e pelos fallbacks do servidor.
  static const String DEFAULT_AI_MODEL = 'deepseek/deepseek-v4-flash-0731';

  /// URL base do servidor da API principal
  static const String API_BASE_URL = "https://nutro-api.snapdark.com";
  // static const String API_BASE_URL = "http://192.168.102.86:3001";

  /// URL base do servidor da API de dieta
  static const String DIET_API_BASE_URL = API_BASE_URL;
  // static const String DIET_API_BASE_URL = "http://192.168.102.86:3000";
}
