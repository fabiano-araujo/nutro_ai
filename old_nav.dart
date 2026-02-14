import 'package:flutter/material.dart';
import 'tools_screen.dart';
import 'ai_tutor_screen.dart';
import '../theme/app_theme.dart';
import '../i18n/app_localizations_extension.dart';
import '../services/rate_app_service.dart';

// Controlador global para gerenciar a navegau00e7u00e3o entre abas
class NavigationController {
  static final NavigationController _instance =
      NavigationController._internal();

  factory NavigationController() {
    return _instance;
  }

  NavigationController._internal();

  Function(int)? tabChangeCallback;

  void changeTab(int index) {
    if (tabChangeCallback != null) {
      tabChangeCallback!(index);
    }
  }
}

final navigationController = NavigationController();

class MainNavigation extends StatefulWidget {
  const MainNavigation({Key? key}) : super(key: key);

  @override
  _MainNavigationState createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  int _previousIndex = 0;

  @override
  void initState() {
    super.initState();
    // Registrar callback para mudanu00e7a de aba
    navigationController.tabChangeCallback = (index) {
      // Verificar se o usuário está saindo da tela de AITutor (índice 0)
      // Esta verificação é crucial para saber quando mostrar o anúncio intersticial
      bool leavingAITutor = _currentIndex == 0 && index != 0;

      // Atualizar índices
      setState(() {
        _previousIndex = _currentIndex;
        _currentIndex = index;
      });

      // Se saiu da tela do AITutor, acionar o método para mostrar anúncio
      // Este é o ponto chave para simular o comportamento de deactivate()
      // que não é chamado automaticamente pelo IndexedStack
      if (leavingAITutor) {
        // Chamar o método estático para notificar AITutorScreen
        AITutorScreen.handleTabExit();
      }
    };

    // Verificar se deve mostrar o diu00e1logo de avaliau00e7u00e3o
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Aguardar um pouco para que o app seja carregado completamente
      Future.delayed(Duration(seconds: 2), () {
        RateAppService.promptForRating(context);
      });
    });
  }

  final List<Widget> _screens = [
    AITutorScreen(), // Chat com IA integrado diretamente - PRIMEIRA ABA
    ToolsScreen(), // Ferramentas (Tools) - Dark theme
  ];

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Definir cores para ícones selecionados e não selecionados
    final selectedIconColor = isDarkMode ? Colors.white : Colors.black;
    final unselectedIconColor =
        isDarkMode ? Colors.grey[600] : Colors.grey[700];

    return WillPopScope(
      onWillPop: () async {
        // Se não estiver na primeira aba (AI Tutor)
        if (_currentIndex != 0) {
          // Se estiver saindo da aba do AITutor para outra, acionar o método
          // Mesmo padrão de verificação usado no callback de mudança de aba
          bool leavingAITutor = _currentIndex == 0;

          // Voltar para a primeira aba
          setState(() {
            _previousIndex = _currentIndex;
            _currentIndex = 0;
          });

          // Se saiu da tela do AITutor, acionar o método para mostrar anúncio
          // Esta lógica garante que o anúncio também apareça quando o usuário
          // usa o botão de voltar para sair da aba AITutor
          if (leavingAITutor) {
            AITutorScreen.handleTabExit();
          }

          // Previne o comportamento padrão do botão voltar
          return false;
        }
        // Se já estiver na primeira aba, permite o comportamento padrão do botão voltar
        return true;
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            navigationController.changeTab(index);
          },
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          selectedItemColor: selectedIconColor,
          unselectedItemColor: unselectedIconColor,
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              activeIcon: Icon(Icons.chat_bubble),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.lightbulb_outline),
              activeIcon: Icon(Icons.lightbulb),
              label: '',
            ),
          ],
        ),
      ),
    );
  }
}
