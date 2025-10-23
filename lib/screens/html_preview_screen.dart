import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
// Importamos dart:html somente se estivermos na web
import 'dart:ui' as ui;
// Importação condicional para o ambiente web
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' if (dart.library.io) 'package:nutro_ai/utils/fake_html.dart'
    as html;

class HtmlPreviewScreen extends StatefulWidget {
  final String htmlContent;
  final String title;

  const HtmlPreviewScreen({
    Key? key,
    required this.htmlContent,
    this.title = 'Visualização HTML',
  }) : super(key: key);

  @override
  State<HtmlPreviewScreen> createState() => _HtmlPreviewScreenState();
}

class _HtmlPreviewScreenState extends State<HtmlPreviewScreen> {
  WebViewController? _controller;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  bool _showingSourceCode = false;

  @override
  void initState() {
    super.initState();

    if (!kIsWeb) {
      // Nos dispositivos nativos, tenta carregar o WebView
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initWebView();
      });
    } else {
      // No web, não podemos usar WebView diretamente como nos dispositivos nativos
      // Então vamos reduzir o tempo de carregamento
      Future.delayed(Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    // Limpa os recursos
    _controller = null;
    super.dispose();
  }

  Future<void> _initWebView() async {
    try {
      // Inicializa as plataformas específicas primeiro
      if (!kIsWeb && WebViewPlatform.instance == null) {
        if (Platform.isAndroid) {
          AndroidWebViewPlatform.registerWith();
        } else if (Platform.isIOS) {
          WebKitWebViewPlatform.registerWith();
        }
      }

      // Verifica se o WebView está disponível
      if (WebViewPlatform.instance == null) {
        // Se o WebView não estiver disponível, mostra o código fonte
        print('WebView não está disponível, mostrando o código fonte');
        setState(() {
          _hasError = true;
          _errorMessage = 'WebView não está disponível neste dispositivo';
          _isLoading = false;
          // Ativa o modo de visualização do código fonte
          Future.delayed(Duration(seconds: 1), () {
            if (mounted) {
              setState(() {
                _showingSourceCode = true;
              });
            }
          });
        });
        return;
      }

      // Prepara o HTML para garantir que tenha a estrutura completa
      String htmlToLoad = _prepareHtmlContent(widget.htmlContent);
      print(
          'HTML preparado para carregamento: ${htmlToLoad.substring(0, htmlToLoad.length > 100 ? 100 : htmlToLoad.length)}...');

      // Cria o controlador
      final controller = WebViewController();

      // Configura o modo JavaScript
      controller.setJavaScriptMode(JavaScriptMode.unrestricted);

      // Configura a delegate de navegação com timeout
      bool pageLoaded = false;
      controller.setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            print('WebView começou a carregar: $url');
          },
          onPageFinished: (String url) {
            print('WebView terminou de carregar: $url');

            // Quando a página termina de carregar, verifica se estamos no Android
            // e injeta o HTML diretamente se for uma página em branco
            if (Platform.isAndroid && url == 'about:blank') {
              print(
                  'Página em branco carregada, injetando HTML via JavaScript');
              _injectHtmlViaJavaScript(controller, htmlToLoad);
            }

            if (mounted) {
              setState(() {
                _isLoading = false;
                pageLoaded = true;
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            print(
                'Erro no WebView: ${error.description}, código: ${error.errorCode}');
            if (mounted) {
              setState(() {
                _hasError = true;
                _errorMessage = 'Erro ao carregar HTML: ${error.description}';
                _isLoading = false;

                // Se for um erro grave, já abre diretamente o visualizador de código
                if (error.errorCode == -6 || // ERROR_FAILED
                    error.errorCode == -10 || // ERROR_TIMEOUT
                    error.errorCode == -14) {
                  // ERROR_UNKNOWN
                  _showingSourceCode = true;
                }
              });
            }
          },
        ),
      );

      // Define configurações específicas para Android
      if (Platform.isAndroid) {
        final androidController =
            controller.platform as AndroidWebViewController;
        await androidController.setGeolocationEnabled(false);
        // O JavaScript já está habilitado pela configuração anterior
        await androidController.setMediaPlaybackRequiresUserGesture(false);
      }

      try {
        if (Platform.isAndroid) {
          // No Android, vamos carregar uma página em branco primeiro e depois injetar o HTML
          print('Android: carregando about:blank e depois injetando HTML');
          await controller.loadRequest(Uri.parse('about:blank'));
        } else {
          // Para iOS e outras plataformas
          print('Não-Android: carregando HTML diretamente');
          await controller.loadHtmlString(htmlToLoad);
        }

        // Define um timeout para garantir que a página seja carregada
        Future.delayed(Duration(seconds: 5), () {
          if (mounted && !pageLoaded && _controller != null) {
            print('Timeout ao carregar WebView, tentando injetar JavaScript');
            // Tenta injetar JavaScript para verificar se o WebView está funcionando
            _controller!.runJavaScript('''
              document.body.style.backgroundColor = "#FFFFFF";
              document.body.innerHTML += "<div style='padding: 20px; text-align: center;'>Carregado com sucesso</div>";
            ''').catchError((e) {
              print('Falha ao executar JavaScript: $e');
              if (mounted) {
                setState(() {
                  _hasError = true;
                  _errorMessage = 'Não foi possível renderizar o HTML';
                  _isLoading = false;
                  _showingSourceCode = true;
                });
              }
            });
          }
        });
      } catch (e) {
        print('Erro ao carregar HTML como string: $e');
        try {
          // Como fallback, tenta salvar em arquivo
          final directory = await getTemporaryDirectory();
          final path = '${directory.path}/preview.html';
          final file = File(path);
          await file.writeAsString(htmlToLoad);

          print('Carregando HTML do arquivo: $path');
          await controller.loadFile(path);
        } catch (e) {
          // Se falhar, mostra erro
          print('Erro ao carregar arquivo HTML: $e');
          if (mounted) {
            setState(() {
              _hasError = true;
              _errorMessage = 'Erro ao carregar HTML: $e';
              _isLoading = false;
              _showingSourceCode = true;
            });
          }
          return;
        }
      }

      if (mounted) {
        setState(() {
          _controller = controller;
        });
      }
    } catch (e) {
      print('Erro ao inicializar WebView: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Erro ao inicializar o visualizador: $e';
          _isLoading = false;
          _showingSourceCode = true;
        });
      }
    }
  }

  // Função para injetar HTML diretamente via JavaScript (útil em alguns casos Android)
  Future<void> _injectHtmlViaJavaScript(
      WebViewController controller, String html) async {
    try {
      // Escapa o HTML para evitar problemas com aspas
      final escapedHtml = html
          .replaceAll('\\', '\\\\')
          .replaceAll('\n', '\\n')
          .replaceAll('\r', '')
          .replaceAll('\'', '\\\'');

      // Injeta o HTML diretamente no documento
      await controller.runJavaScript('''
        document.open();
        document.write('$escapedHtml');
        document.close();
      ''');

      print('HTML injetado via JavaScript com sucesso');
    } catch (e) {
      print('Erro ao injetar HTML via JavaScript: $e');
    }
  }

  // Prepara o HTML para garantir que tenha estrutura completa para renderização adequada
  String _prepareHtmlContent(String html) {
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
      color: #333;
      background-color: white;
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

  void _toggleSourceCodeView() {
    setState(() {
      _showingSourceCode = !_showingSourceCode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_showingSourceCode ? 'Código Fonte HTML' : widget.title),
        actions: [
          if (_controller != null &&
              !_hasError &&
              !_showingSourceCode &&
              !kIsWeb)
            IconButton(
              icon: Icon(Icons.refresh),
              onPressed: () {
                setState(() {
                  _isLoading = true;
                });
                _controller?.reload();
              },
            ),
          IconButton(
            icon: Icon(_showingSourceCode ? Icons.visibility : Icons.code),
            onPressed: _toggleSourceCodeView,
            tooltip: _showingSourceCode ? 'Ver página' : 'Ver código fonte',
          ),
        ],
      ),
      body: _showingSourceCode
          ? _buildSourceCodeView()
          : kIsWeb
              ? _buildWebView()
              : Stack(
                  children: [
                    if (_hasError)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 48,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Não foi possível carregar a visualização HTML',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 8),
                              Text(
                                _errorMessage,
                                style: TextStyle(color: Colors.grey[700]),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ElevatedButton(
                                    onPressed: () {
                                      setState(() {
                                        _hasError = false;
                                        _isLoading = true;
                                      });
                                      _initWebView();
                                    },
                                    child: Text('Tentar novamente'),
                                  ),
                                  SizedBox(width: 16),
                                  OutlinedButton(
                                    onPressed: _toggleSourceCodeView,
                                    child: Text('Ver código fonte'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (_controller != null)
                      WebViewWidget(controller: _controller!)
                    else
                      Center(
                        child: Text('Preparando visualização...'),
                      ),
                    if (_isLoading && !_hasError)
                      Center(
                        child: CircularProgressIndicator(),
                      ),
                  ],
                ),
      bottomNavigationBar: _hasError && !_showingSourceCode
          ? Container(
              padding: EdgeInsets.all(16),
              color: Colors.amber[100],
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Como alternativa, você pode visualizar o código HTML diretamente:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        OutlinedButton.icon(
                          icon: Icon(Icons.content_copy),
                          label: Text('Copiar HTML'),
                          onPressed: () {
                            _copyHtmlToClipboard();
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }

  // Widget para exibir o HTML no ambiente web
  Widget _buildWebView() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(),
      );
    }

    // No navegador, usamos uma abordagem alternativa com um documento HTML renderizado
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (!_showingSourceCode) ...[
          Image.asset(
            'assets/images/html_icon.png',
            width: 80,
            height: 80,
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                Icons.html,
                size: 80,
                color: Theme.of(context).primaryColor,
              );
            },
          ),
          SizedBox(height: 20),
          Text(
            'Visualização de HTML no navegador',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Para visualizar este conteúdo HTML, utilize o botão abaixo para abrir em uma nova janela.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
              ),
            ),
          ),
          SizedBox(height: 30),
          ElevatedButton.icon(
            icon: Icon(Icons.open_in_new),
            label: Text('Abrir em nova janela'),
            onPressed: () => _openHtmlInNewTab(),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
          SizedBox(height: 20),
          TextButton.icon(
            icon: Icon(Icons.code),
            label: Text('Ver código fonte'),
            onPressed: _toggleSourceCodeView,
          ),
        ],
      ],
    );
  }

  // Função para abrir o HTML em uma nova aba (apenas para web)
  void _openHtmlInNewTab() {
    if (kIsWeb) {
      // Esta função só funcionará no ambiente web
      final htmlContent = _prepareHtmlContent(widget.htmlContent);
      final blob = html.Blob([htmlContent], 'text/html');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.window.open(url, '_blank');
      // Não precisamos liberar o URL aqui, pois a nova aba vai lidar com isso
    }
  }

  Widget _buildSourceCodeView() {
    // Formatação básica do HTML para melhor visualização
    String formattedHtml = widget.htmlContent;
    try {
      // Tenta aplicar indentação e formatação para melhorar a legibilidade
      formattedHtml = _formatHtmlCode(widget.htmlContent);
    } catch (e) {
      // Se falhar na formatação, usa o HTML original
      print('Erro ao formatar HTML: $e');
    }

    return Container(
      color: Colors.grey[900],
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Stack(
            children: [
              SingleChildScrollView(
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  child: SelectableText(
                    formattedHtml,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: Colors.green[300],
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 16,
                right: 16,
                child: FloatingActionButton(
                  onPressed: _copyHtmlToClipboard,
                  child: Icon(Icons.content_copy),
                  tooltip: 'Copiar código HTML',
                  mini: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Função para formatar o código HTML com indentação básica
  String _formatHtmlCode(String html) {
    // Se o HTML já tiver indentação, apenas retorna
    if (html.contains('\n') && RegExp(r'^\s+<').hasMatch(html)) {
      return html;
    }

    // Substitui as tags de fechamento e abertura para facilitar a divisão
    var formatted = html.replaceAllMapped(
      RegExp(r'<\/(\w+)>'),
      (match) => '\n</${match.group(1)}>',
    );

    formatted = formatted.replaceAllMapped(
      RegExp(r'<(\w+)([^>]*)>'),
      (match) => '\n<${match.group(1)}${match.group(2)}>',
    );

    // Remove múltiplas linhas em branco
    formatted = formatted.replaceAll(RegExp(r'\n\s*\n'), '\n');

    // Adiciona indentação
    var lines = formatted.split('\n');
    var indent = 0;
    var result = <String>[];

    for (var line in lines) {
      if (line.trim().isEmpty) continue;

      // Reduz indentação para tags de fechamento
      if (line.trim().startsWith('</')) {
        indent = (indent - 2).clamp(0, 100);
      }

      // Adiciona a linha com indentação
      result.add(' ' * indent + line.trim());

      // Aumenta indentação para tags de abertura (exceto self-closing)
      if (line.trim().startsWith('<') &&
          !line.trim().startsWith('</') &&
          !line.trim().endsWith('/>') &&
          !line.contains('</')) {
        indent += 2;
      }
    }

    return result.join('\n');
  }

  void _copyHtmlToClipboard() {
    Clipboard.setData(ClipboardData(text: widget.htmlContent));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Código HTML copiado para a área de transferência'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

// Para permitir ao Flutter usar elementos HTML
// Utilitário para verificar se estamos em ambiente web
bool get isWeb => kIsWeb;
