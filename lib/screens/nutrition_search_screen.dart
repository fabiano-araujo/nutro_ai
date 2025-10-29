import 'dart:convert';
import 'package:flutter/material.dart';
import '../widgets/my_inapp_webview.dart';
import '../helpers/scraper_helper.dart';
import '../helpers/webview_helper.dart';

/// Tela de pesquisa de informações nutricionais com WebView
class NutritionSearchScreen extends StatefulWidget {
  const NutritionSearchScreen({Key? key}) : super(key: key);

  @override
  State<NutritionSearchScreen> createState() => _NutritionSearchScreenState();
}

class _NutritionSearchScreenState extends State<NutritionSearchScreen> {
  final ScraperHelper _scraperHelper = ScraperHelper();
  final TextEditingController _urlController = TextEditingController();

  String _currentUrl = 'https://mobile.fatsecret.com.br/calorias-nutri%C3%A7%C3%A3o/coca-cola/coca-cola-zero-(lata)/1-lata';
  Map<String, dynamic>? _extractedData;
  bool _isExtracting = false;
  bool _showWebView = true;

  @override
  void initState() {
    super.initState();
    _urlController.text = _currentUrl;
  }

  @override
  void dispose() {
    _scraperHelper.dispose();
    _urlController.dispose();
    super.dispose();
  }

  /// Extrai informações nutricionais da página atual
  void _extractNutritionalInfo() {
    setState(() {
      _isExtracting = true;
      _extractedData = null;
    });

    _scraperHelper.extractContent(
      script: ScraperHelper.getFatSecretNutritionalInfoScript(),
      callback: (result) {
        if (mounted) {
          setState(() {
            _isExtracting = false;

            if (result != null && result is String) {
              try {
                _extractedData = jsonDecode(result);
              } catch (e) {
                _extractedData = {'erro': result.toString()};
              }
            } else {
              _extractedData = {'erro': 'Nenhum dado foi extraído'};
            }
          });
        }
      },
      timeoutSeconds: 30,
    );
  }

  /// Carrega uma nova URL no WebView
  void _loadUrl() {
    final url = _urlController.text.trim();
    if (url.isNotEmpty) {
      setState(() {
        _currentUrl = url;
        _extractedData = null;
      });
      _scraperHelper.loadUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pesquisa Nutricional'),
        actions: [
          IconButton(
            icon: Icon(_showWebView ? Icons.visibility_off : Icons.visibility),
            onPressed: () {
              setState(() {
                _showWebView = !_showWebView;
              });
            },
            tooltip: _showWebView ? 'Ocultar WebView' : 'Mostrar WebView',
          ),
        ],
      ),
      body: Column(
        children: [
          // Área de busca
          _buildSearchSection(),

          // Botões de ação
          _buildActionButtons(),

          // Dados extraídos
          if (_extractedData != null) _buildExtractedDataSection(),

          // WebView
          if (_showWebView)
            Expanded(
              child: _buildWebViewSection(),
            ),
        ],
      ),
    );
  }

  /// Seção de busca
  Widget _buildSearchSection() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _urlController,
            decoration: InputDecoration(
              labelText: 'URL da página',
              hintText: 'Cole a URL aqui...',
              prefixIcon: const Icon(Icons.link),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _urlController.clear();
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            keyboardType: TextInputType.url,
            onSubmitted: (_) => _loadUrl(),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _loadUrl,
            icon: const Icon(Icons.search),
            label: const Text('Carregar URL'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Botões de ação
  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isExtracting ? null : _extractNutritionalInfo,
              icon: _isExtracting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.download),
              label: Text(_isExtracting ? 'Extraindo...' : 'Extrair Dados'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Seção de dados extraídos
  Widget _buildExtractedDataSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: const Icon(Icons.info_outline, color: Colors.blue),
        title: const Text(
          'Dados Extraídos',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildDataContent(),
          ),
        ],
      ),
    );
  }

  /// Conteúdo dos dados extraídos
  Widget _buildDataContent() {
    if (_extractedData!.containsKey('erro')) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _extractedData!['erro'].toString(),
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Nome do alimento
        if (_extractedData!.containsKey('nome'))
          _buildInfoCard(
            'Nome',
            _extractedData!['nome'].toString(),
            Icons.restaurant,
            Colors.blue,
          ),

        const SizedBox(height: 12),

        // Porção
        if (_extractedData!.containsKey('porcao'))
          _buildInfoCard(
            'Porção',
            _extractedData!['porcao'].toString(),
            Icons.scale,
            Colors.orange,
          ),

        const SizedBox(height: 12),

        // Calorias
        if (_extractedData!.containsKey('calorias'))
          _buildInfoCard(
            'Calorias',
            _extractedData!['calorias'].toString(),
            Icons.local_fire_department,
            Colors.red,
          ),

        const SizedBox(height: 12),

        // Valores nutricionais
        if (_extractedData!.containsKey('valoresNutricionais') &&
            _extractedData!['valoresNutricionais'] is Map)
          _buildNutritionalValues(
            _extractedData!['valoresNutricionais'] as Map<String, dynamic>,
          ),

        const SizedBox(height: 16),

        // Botão de copiar JSON
        OutlinedButton.icon(
          onPressed: () {
            // Implementar cópia para clipboard
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Dados copiados para área de transferência!'),
              ),
            );
          },
          icon: const Icon(Icons.copy),
          label: const Text('Copiar JSON'),
        ),
      ],
    );
  }

  /// Card de informação individual
  Widget _buildInfoCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: color.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Lista de valores nutricionais
  Widget _buildNutritionalValues(Map<String, dynamic> values) {
    if (values.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: Colors.green.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'Valores Nutricionais',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
          const Divider(),
          ...values.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    entry.key,
                    style: const TextStyle(fontSize: 14),
                  ),
                  Text(
                    entry.value.toString(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  /// Seção do WebView
  Widget _buildWebViewSection() {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
      ),
      child: MyInAppWebView(
        url: _currentUrl,
        onWebViewCreated: _scraperHelper.onWebViewCreated,
        onLoadStop: _scraperHelper.onLoadFinished,
        onReceivedError: _scraperHelper.onLoadError,
        showProgress: true,
        settings: WebViewHelper.getOptimizedSettings(),
      ),
    );
  }
}
