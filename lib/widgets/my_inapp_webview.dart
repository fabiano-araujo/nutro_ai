import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../helpers/webview_helper.dart';

/// Widget WebView reutilizável com callbacks configuráveis
class MyInAppWebView extends StatefulWidget {
  final String url;
  final Function(InAppWebViewController)? onWebViewCreated;
  final Function(InAppWebViewController, WebUri?)? onLoadStart;
  final Function(InAppWebViewController, WebUri?)? onLoadStop;
  final Function(InAppWebViewController, WebUri?, int, String)? onReceivedError;
  final Function(InAppWebViewController, int)? onProgressChanged;
  final Function(InAppWebViewController, ConsoleMessage)? onConsoleMessage;
  final bool showProgress;
  final InAppWebViewSettings? settings;

  const MyInAppWebView({
    Key? key,
    required this.url,
    this.onWebViewCreated,
    this.onLoadStart,
    this.onLoadStop,
    this.onReceivedError,
    this.onProgressChanged,
    this.onConsoleMessage,
    this.showProgress = true,
    this.settings,
  }) : super(key: key);

  @override
  State<MyInAppWebView> createState() => _MyInAppWebViewState();
}

class _MyInAppWebViewState extends State<MyInAppWebView> {
  double _progress = 0;
  bool _isLoading = true;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        InAppWebView(
          initialUrlRequest: URLRequest(
            url: WebUri(widget.url),
          ),
          initialSettings: widget.settings ?? WebViewHelper.getDefaultSettings(),
          onWebViewCreated: (controller) {
            WebViewHelper.setInAppWebViewController(controller);
            widget.onWebViewCreated?.call(controller);
          },
          onLoadStart: (controller, url) {
            setState(() {
              _isLoading = true;
              _progress = 0;
            });
            widget.onLoadStart?.call(controller, url);
          },
          onLoadStop: (controller, url) {
            setState(() {
              _isLoading = false;
              _progress = 1.0;
            });
            widget.onLoadStop?.call(controller, url);
          },
          onReceivedError: (controller, request, error) {
            setState(() {
              _isLoading = false;
            });
            widget.onReceivedError?.call(
              controller,
              request.url,
              error.type.toNativeValue() ?? -1,
              error.description,
            );
          },
          onProgressChanged: (controller, progress) {
            setState(() {
              _progress = progress / 100;
            });
            widget.onProgressChanged?.call(controller, progress);
          },
          onConsoleMessage: (controller, consoleMessage) {
            // Debug: imprime mensagens do console do JavaScript
            debugPrint('WebView Console [${consoleMessage.messageLevel}]: ${consoleMessage.message}');
            widget.onConsoleMessage?.call(controller, consoleMessage);
          },
          onPermissionRequest: (controller, request) async {
            // Concede automaticamente permissões solicitadas pelo WebView
            return PermissionResponse(
              resources: request.resources,
              action: PermissionResponseAction.GRANT,
            );
          },
        ),
        if (widget.showProgress && _isLoading && _progress < 1.0)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              value: _progress,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor,
              ),
            ),
          ),
      ],
    );
  }
}
