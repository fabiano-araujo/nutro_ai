import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Teste de Imagem'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Imagem do logo:'),
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 120,
                  height: 120,
                  errorBuilder: (context, error, stackTrace) {
                    print('Erro ao carregar imagem: $error');
                    return Container(
                      width: 120,
                      height: 120,
                      color: Colors.red,
                      child: const Icon(Icons.error, size: 60, color: Colors.white),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              const Text('Caminho: assets/images/logo.png'),
            ],
          ),
        ),
      ),
    );
  }
}
