import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'webview_helper.dart';

/// Helper para extração de conteúdo de páginas web usando JavaScript injection
class ScraperHelper {
  static const String HANDLER_LISTENER = 'CONTENT_EXTRACTOR';

  InAppWebViewController? _controller;
  bool _isPageLoaded = false;
  Function(dynamic)? _currentCallback;
  Timer? _timeoutTimer;

  /// Callback chamado quando o JavaScript envia dados de volta
  void listenerWebView(List<dynamic> arguments) {
    debugPrint('ScraperHelper: Dados recebidos do JavaScript');

    if (_currentCallback != null && arguments.isNotEmpty) {
      _currentCallback!(arguments[0]);
      _currentCallback = null;
    }

    // Cancela o timeout se houver
    _timeoutTimer?.cancel();
  }

  /// Callback chamado quando o WebView é criado
  void onWebViewCreated(InAppWebViewController controller) {
    _controller = controller;
    WebViewHelper.setInAppWebViewController(controller);

    // Registra o handler para receber dados do JavaScript
    controller.addJavaScriptHandler(
      handlerName: HANDLER_LISTENER,
      callback: listenerWebView,
    );

    debugPrint('ScraperHelper: WebView criado e handler registrado');
  }

  /// Callback chamado quando a página termina de carregar
  void onLoadFinished(InAppWebViewController controller, WebUri? url) {
    _isPageLoaded = true;
    debugPrint('ScraperHelper: Página carregada - $url');
  }

  /// Callback chamado quando há erro no carregamento
  void onLoadError(InAppWebViewController controller, WebUri? url, int code, String message) {
    debugPrint('ScraperHelper: Erro ao carregar página - $message');
    _isPageLoaded = false;

    if (_currentCallback != null) {
      _currentCallback!(null);
      _currentCallback = null;
    }

    _timeoutTimer?.cancel();
  }

  /// Extrai conteúdo da página atual usando JavaScript
  Future<void> extractContent({
    required String script,
    required Function(dynamic) callback,
    int timeoutSeconds = 30,
  }) async {
    if (_controller == null) {
      debugPrint('ScraperHelper: Controller não inicializado');
      callback(null);
      return;
    }

    _currentCallback = callback;

    // Configura timeout
    _timeoutTimer = Timer(Duration(seconds: timeoutSeconds), () {
      debugPrint('ScraperHelper: Timeout ao extrair conteúdo');
      if (_currentCallback != null) {
        _currentCallback!(null);
        _currentCallback = null;
      }
    });

    try {
      // Aguarda a página carregar se ainda não carregou
      int attempts = 0;
      while (!_isPageLoaded && attempts < 20) {
        await Future.delayed(const Duration(milliseconds: 500));
        attempts++;
      }

      if (!_isPageLoaded) {
        debugPrint('ScraperHelper: Página não carregou a tempo');
        callback(null);
        _timeoutTimer?.cancel();
        return;
      }

      debugPrint('ScraperHelper: Injetando JavaScript...');
      await _controller!.evaluateJavascript(source: script);
    } catch (e) {
      debugPrint('ScraperHelper: Erro ao executar JavaScript - $e');
      callback(null);
      _timeoutTimer?.cancel();
    }
  }

  /// Carrega uma nova URL no WebView
  Future<void> loadUrl(String url) async {
    _isPageLoaded = false;
    await WebViewHelper.loadUrl(url);
  }

  /// Scripts JavaScript prontos para uso

  /// Extrai todo o texto visível da página
  static String getExtractTextScript() {
    return '''
      (function() {
        try {
          var text = document.body.innerText || document.body.textContent;
          window.flutter_inappwebview.callHandler('$HANDLER_LISTENER', text);
        } catch(e) {
          window.flutter_inappwebview.callHandler('$HANDLER_LISTENER', 'Erro: ' + e.message);
        }
      })();
    ''';
  }

  /// Extrai HTML completo da página
  static String getExtractHtmlScript() {
    return '''
      (function() {
        try {
          var html = document.documentElement.outerHTML;
          window.flutter_inappwebview.callHandler('$HANDLER_LISTENER', html);
        } catch(e) {
          window.flutter_inappwebview.callHandler('$HANDLER_LISTENER', 'Erro: ' + e.message);
        }
      })();
    ''';
  }

  /// Extrai conteúdo de um seletor específico
  static String getExtractBySelectorScript(String selector, {bool innerHTML = false}) {
    return '''
      (function() {
        try {
          var element = document.querySelector('$selector');
          if (element) {
            var content = ${innerHTML ? 'element.innerHTML' : 'element.textContent'};
            window.flutter_inappwebview.callHandler('$HANDLER_LISTENER', content);
          } else {
            window.flutter_inappwebview.callHandler('$HANDLER_LISTENER', null);
          }
        } catch(e) {
          window.flutter_inappwebview.callHandler('$HANDLER_LISTENER', 'Erro: ' + e.message);
        }
      })();
    ''';
  }

  /// Extrai dados estruturados de múltiplos seletores
  static String getExtractMultipleScript(Map<String, String> selectors) {
    final selectorsJson = selectors.entries.map((e) => '"${e.key}": "${e.value}"').join(', ');

    return '''
      (function() {
        try {
          var selectors = {$selectorsJson};
          var result = {};

          for (var key in selectors) {
            var element = document.querySelector(selectors[key]);
            result[key] = element ? element.textContent.trim() : null;
          }

          window.flutter_inappwebview.callHandler('$HANDLER_LISTENER', JSON.stringify(result));
        } catch(e) {
          window.flutter_inappwebview.callHandler('$HANDLER_LISTENER', 'Erro: ' + e.message);
        }
      })();
    ''';
  }

  /// Extrai informações nutricionais da página FatSecret
  static String getFatSecretNutritionalInfoScript() {
    return '''
      (function() {
        try {
          var result = {};

          // Extrai o nome do alimento
          var titleElement = document.querySelector('.heading_medium, h1, .food_name');
          result.nome = titleElement ? titleElement.textContent.trim() : 'N/A';

          // Extrai a porção
          var servingElement = document.querySelector('.serving_size, .serving');
          result.porcao = servingElement ? servingElement.textContent.trim() : 'N/A';

          // Extrai os valores nutricionais
          var nutritionFacts = {};
          var factElements = document.querySelectorAll('.fact, .nutrition_fact, tr');

          factElements.forEach(function(element) {
            var label = element.querySelector('.fact_label, .nutrient_label, td:first-child');
            var value = element.querySelector('.fact_value, .nutrient_value, td:last-child');

            if (label && value) {
              var labelText = label.textContent.trim();
              var valueText = value.textContent.trim();
              if (labelText && valueText) {
                nutritionFacts[labelText] = valueText;
              }
            }
          });

          result.valoresNutricionais = nutritionFacts;

          // Tenta extrair calorias especificamente
          var caloriesElement = document.querySelector('.calorie, .calories, [class*="calor"]');
          if (caloriesElement) {
            var caloriesText = caloriesElement.textContent.trim();
            var caloriesMatch = caloriesText.match(/\d+/);
            result.calorias = caloriesMatch ? caloriesMatch[0] : 'N/A';
          }

          window.flutter_inappwebview.callHandler('$HANDLER_LISTENER', JSON.stringify(result));
        } catch(e) {
          window.flutter_inappwebview.callHandler('$HANDLER_LISTENER', 'Erro: ' + e.message);
        }
      })();
    ''';
  }

  /// Limpa recursos
  void dispose() {
    _timeoutTimer?.cancel();
    _currentCallback = null;
    _controller = null;
  }
}
