import 'package:flutter/material.dart';
import '../screens/nutrition_search_screen.dart';

/// Exemplo de como integrar a NutritionSearchScreen no seu app
///
/// Para usar, basta navegar para esta tela:
/// ```dart
/// Navigator.push(
///   context,
///   MaterialPageRoute(builder: (context) => const NutritionSearchScreen()),
/// );
/// ```

class NutritionSearchExample extends StatelessWidget {
  const NutritionSearchExample({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exemplo - Pesquisa Nutricional'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.restaurant_menu,
                size: 80,
                color: Colors.green,
              ),
              const SizedBox(height: 24),
              const Text(
                'Sistema de WebView com JavaScript Injection',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Extraia informações nutricionais de páginas web de forma automática',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NutritionSearchScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.search),
                label: const Text('Abrir Pesquisa Nutricional'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 24),
              _buildFeatureItem(
                'WebView Integrado',
                'Carregue qualquer URL em um WebView nativo',
                Icons.web,
              ),
              const SizedBox(height: 12),
              _buildFeatureItem(
                'JavaScript Injection',
                'Execute scripts personalizados na página',
                Icons.code,
              ),
              const SizedBox(height: 12),
              _buildFeatureItem(
                'Extração de Dados',
                'Extraia conteúdo estruturado do DOM',
                Icons.download,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String title, String description, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.green),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
