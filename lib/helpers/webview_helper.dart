import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Helper class para gerenciar instâncias do InAppWebViewController
class WebViewHelper {
  static InAppWebViewController? _controller;

  /// Define o controller do WebView
  static void setInAppWebViewController(InAppWebViewController controller) {
    _controller = controller;
  }

  /// Retorna o controller do WebView
  static InAppWebViewController? getInAppWebViewController() {
    return _controller;
  }

  /// Carrega uma URL no WebView
  static Future<void> loadUrl(String url) async {
    if (_controller != null) {
      await _controller!.loadUrl(
        urlRequest: URLRequest(url: WebUri(url)),
      );
    }
  }

  /// Verifica se o WebView está carregando
  static Future<bool> isLoading() async {
    if (_controller != null) {
      return await _controller!.isLoading();
    }
    return false;
  }

  /// Executa JavaScript no WebView
  static Future<dynamic> evaluateJavascript({required String source}) async {
    if (_controller != null) {
      return await _controller!.evaluateJavascript(source: source);
    }
    return null;
  }

  /// Limpa o controller
  static void clear() {
    _controller = null;
  }

  /// Configurações padrão do WebView
  static InAppWebViewSettings getDefaultSettings() {
    return InAppWebViewSettings(
      javaScriptEnabled: true,
      javaScriptCanOpenWindowsAutomatically: true,
      mediaPlaybackRequiresUserGesture: false,
      allowsInlineMediaPlayback: true,
      iframeAllow: "camera; microphone",
      iframeAllowFullscreen: true,
      useOnDownloadStart: true,
      useOnLoadResource: true,
      useShouldOverrideUrlLoading: true,
      clearCache: false,
      cacheEnabled: true,
      verticalScrollBarEnabled: true,
      horizontalScrollBarEnabled: true,
      supportZoom: true,
      builtInZoomControls: true,
      displayZoomControls: false,
      userAgent: "Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36",
    );
  }
}
