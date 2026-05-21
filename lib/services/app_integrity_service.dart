import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_app_check_platform_interface/firebase_app_check_platform_interface.dart'
    show WebProvider;
import 'package:flutter/foundation.dart';

class AppIntegrityService {
  static const String _headerName = 'X-Firebase-AppCheck';
  static const String _webRecaptchaSiteKey = String.fromEnvironment(
    'APP_CHECK_WEB_RECAPTCHA_SITE_KEY',
    defaultValue: '',
  );

  static bool _appCheckActivated = false;

  static Future<void> activateAppCheck() async {
    final webProvider = _buildWebProvider();

    if (kIsWeb && webProvider == null) {
      print(
          '[AppIntegrity] APP_CHECK_WEB_RECAPTCHA_SITE_KEY ausente; App Check web nao foi ativado.');
      return;
    }

    try {
      await FirebaseAppCheck.instance.activate(
        providerWeb: webProvider,
        providerAndroid: kDebugMode
            ? const AndroidDebugProvider()
            : const AndroidPlayIntegrityProvider(),
        providerApple: kDebugMode
            ? const AppleDebugProvider()
            : const AppleAppAttestWithDeviceCheckFallbackProvider(),
      );
      _appCheckActivated = true;
      print('[AppIntegrity] Firebase App Check ativado');
    } catch (e) {
      print('[AppIntegrity] Erro ao ativar Firebase App Check: $e');
    }
  }

  static Future<Map<String, String>> appCheckHeaders() async {
    if (!_appCheckActivated) {
      return const {};
    }

    try {
      final token = await FirebaseAppCheck.instance.getToken();
      if (token == null || token.isEmpty) {
        return const {};
      }

      return {_headerName: token};
    } on FirebaseException catch (e) {
      print('[AppIntegrity] Erro ao obter App Check token: ${e.code}');
      return const {};
    } catch (e) {
      print('[AppIntegrity] Erro ao obter App Check token: $e');
      return const {};
    }
  }

  static WebProvider? _buildWebProvider() {
    if (!kIsWeb) {
      return null;
    }

    if (kDebugMode) {
      return WebDebugProvider();
    }

    if (_webRecaptchaSiteKey.isEmpty) {
      return null;
    }

    return ReCaptchaV3Provider(_webRecaptchaSiteKey);
  }
}
