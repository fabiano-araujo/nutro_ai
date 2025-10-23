import 'package:flutter/material.dart';

class CodeDetector {
  /// Verifica se o texto provavelmente contém código HTML.
  static bool isHtmlCode(String text) {
    // Limpa o texto para análise
    final cleanText = text.trim();

    // Verifica elementos HTML comuns
    final containsHtmlTags = RegExp(
            r'<\s*(!DOCTYPE|html|head|body|div|a|p|h1|h2|h3|h4|h5|h6|ul|ol|li|table|tr|td|form|input|script|link|meta|style|button|span|img|video|audio|source|canvas|iframe|section|article|header|footer|nav)\b[^>]*>')
        .hasMatch(cleanText);

    // Verifica comentários HTML
    final containsHtmlComment =
        cleanText.contains('<!--') && cleanText.contains('-->');

    // Verifica DOCTYPE
    final containsDocType =
        cleanText.contains('<!DOCTYPE') || cleanText.contains('<!doctype');

    // Verifica estrutura básica de HTML
    final containsHtmlStructure =
        cleanText.contains('<html') && cleanText.contains('</html>');

    // Verifica se tem tags de abertura e fechamento
    final hasPairedTags =
        RegExp(r'<([a-z]+)[^>]*>.*?</\1>', dotAll: true).hasMatch(cleanText);

    // Verifica se há blocos de código específicos para HTML
    final isInHtmlCodeBlock = cleanText.contains('```html') ||
        cleanText.contains('```HTML') ||
        cleanText.contains('<html>') ||
        cleanText.contains('</html>');

    // Verifica se contém atributos HTML comuns
    final containsHtmlAttributes =
        RegExp(r'(class|id|style|href|src)=["\' '][^\'"]*["\']')
            .hasMatch(cleanText);

    // Regras adicionais para identificar código HTML
    final looksLikeHTML = (containsHtmlTags && hasPairedTags) ||
        containsHtmlStructure ||
        containsDocType ||
        (containsHtmlAttributes && containsHtmlTags) ||
        isInHtmlCodeBlock;

    // Verifica padrões comuns de HTML
    return looksLikeHTML || containsHtmlComment;
  }

  /// Extrai o conteúdo HTML completo do texto
  static String extractHtmlContent(String text) {
    // Se o texto começar com backticks de código, vamos tentar extrair o código
    if (text.contains('```html') && text.contains('```')) {
      // Extrai o conteúdo entre os marcadores de código html
      final RegExp regExp =
          RegExp(r'```html\s*([\s\S]*?)\s*```', caseSensitive: false);
      final match = regExp.firstMatch(text);
      if (match != null && match.groupCount >= 1) {
        final extractedCode = match.group(1) ?? text;
        return _wrapHtmlIfNeeded(extractedCode);
      }
    }

    // Tenta extrair código sem o prefixo html
    if (text.contains('```') && text.contains('```')) {
      final RegExp simpleRegExp = RegExp(r'```\s*([\s\S]*?)\s*```');
      final simpleMatch = simpleRegExp.firstMatch(text);
      if (simpleMatch != null && simpleMatch.groupCount >= 1) {
        final extractedCode = simpleMatch.group(1) ?? text;
        // Verifica se o código extraído parece HTML
        if (isHtmlCode(extractedCode)) {
          return _wrapHtmlIfNeeded(extractedCode);
        }
      }
    }

    // Se o HTML não estiver em um bloco de código mas parece ter uma estrutura HTML completa
    if (text.contains('<html') && text.contains('</html>')) {
      final RegExp htmlRegExp =
          RegExp(r'<html.*?>([\s\S]*?)</html>', caseSensitive: false);
      final match = htmlRegExp.firstMatch(text);
      if (match != null) {
        // Retorna o documento HTML completo
        final int startIndex = text.indexOf('<html');
        final int endIndex = text.indexOf('</html>') + 7;
        if (startIndex >= 0 && endIndex > startIndex) {
          return text.substring(
              startIndex - (text.contains('<!DOCTYPE') ? 10 : 0), endIndex);
        }
      }
    }

    // Se o texto parece HTML mas não está em um formato reconhecível,
    // envolvemos em tags HTML básicas para garantir renderização adequada
    if (isHtmlCode(text)) {
      return _wrapHtmlIfNeeded(text);
    }

    return text;
  }

  /// Envolve o HTML em um documento completo se necessário
  static String _wrapHtmlIfNeeded(String html) {
    // Se já for um documento HTML completo, retorna-o
    if (html.trim().startsWith('<!DOCTYPE') ||
        html.trim().startsWith('<html')) {
      return html;
    }

    // Caso contrário, envolve o conteúdo em um documento HTML completo
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    body {
      font-family: Arial, sans-serif;
      line-height: 1.6;
      padding: 16px;
      margin: 0;
    }
    img, video, iframe {
      max-width: 100%;
      height: auto;
    }
    pre {
      white-space: pre-wrap;
      background-color: #f5f5f5;
      padding: 10px;
      border-radius: 5px;
      overflow-x: auto;
    }
    code {
      font-family: monospace;
      background-color: #f5f5f5;
      padding: 2px 4px;
      border-radius: 3px;
    }
    table {
      border-collapse: collapse;
      width: 100%;
      margin-bottom: 16px;
    }
    th, td {
      border: 1px solid #ddd;
      padding: 8px;
      text-align: left;
    }
    th {
      background-color: #f2f2f2;
    }
  </style>
</head>
<body>
$html
</body>
</html>
''';
  }

  /// Cria um ícone para visualizar o HTML
  static Widget buildHtmlViewIcon({
    required BuildContext context,
    required String htmlContent,
    required VoidCallback onTap,
    Color? color,
  }) {
    return IconButton(
      icon: Icon(
        Icons.visibility,
        color: color ?? Theme.of(context).primaryColor,
        size: 18,
      ),
      onPressed: onTap,
      tooltip: 'Visualizar HTML',
      constraints: BoxConstraints(),
      padding: EdgeInsets.zero,
    );
  }
}
