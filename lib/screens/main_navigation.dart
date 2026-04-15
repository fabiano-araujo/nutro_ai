import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'nutrition_assistant_screen.dart';
import 'profile_screen.dart';
import 'login_screen.dart';
import 'personalized_diet_screen.dart';
import 'food_search_screen.dart';
import 'camera_scan_screen.dart';
import 'unified_search_screen.dart';
import 'free_chat_screen.dart';
import 'social_hub_screen.dart';
import '../services/rate_app_service.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../i18n/app_localizations_extension.dart';
import '../providers/free_chat_provider.dart';
import '../providers/daily_meals_provider.dart';
import '../providers/streak_provider.dart';
import '../providers/friends_provider.dart';
import '../providers/challenges_provider.dart';
import '../providers/feed_provider.dart';
import '../providers/credit_provider.dart';
import '../providers/diet_plan_provider.dart';
import '../providers/nutrition_goals_provider.dart';

// Controlador global para gerenciar a navegação entre abas
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

// Wrapper para a tela de perfil que decide qual tela mostrar
class ProfileTabWrapper extends StatelessWidget {
  final VoidCallback? onOpenDrawer;
  final VoidCallback? onOpenSocialHub;

  const ProfileTabWrapper({
    Key? key,
    this.onOpenDrawer,
    this.onOpenSocialHub,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        return authService.isAuthenticated
            ? ProfileScreen(
                onOpenDrawer: onOpenDrawer,
                onOpenSocialHub: onOpenSocialHub,
              )
            : LoginScreen(onOpenDrawer: onOpenDrawer);
      },
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({Key? key}) : super(key: key);

  @override
  _MainNavigationState createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Chave para reiniciar o NutritionAssistantScreen
  Key _nutritionAssistantKey = UniqueKey();

  // Modo atual: 'diary' para diário (com JSON/calendário), 'free_chat' para conversa livre
  String _currentMode = 'diary';

  // ID da conversa livre atual (null = nova conversa)
  String? _currentFreeChatId;

  // Índice da aba selecionada no BottomNavigationBar
  int _selectedIndex = 0;

  // Controle para evitar chamadas duplicadas de auth
  bool _authInitialized = false;

  @override
  void initState() {
    super.initState();

    // Configurar callback do controlador de navegação
    navigationController.tabChangeCallback = _onItemTapped;

    // Verificar se deve mostrar o diálogo de avaliação
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Aguardar um pouco para que o app seja carregado completamente
      Future.delayed(Duration(seconds: 2), () {
        RateAppService.promptForRating(context);
      });

      // Configurar sync de refeições com auth
      _setupMealsSyncAuth();
    });
  }

  /// Configura a sincronização de refeições com o servidor baseado no estado de auth
  void _setupMealsSyncAuth() {
    if (_authInitialized) return;
    _authInitialized = true;

    final authService = context.read<AuthService>();
    final dailyMealsProvider = context.read<DailyMealsProvider>();

    // Configurar auth inicial se já estiver logado
    _updateMealsProviderAuth(authService, dailyMealsProvider);

    // Escutar mudanças no estado de autenticação
    authService.addListener(() {
      _updateMealsProviderAuth(authService, dailyMealsProvider);
    });
  }

  /// Atualiza o DailyMealsProvider e providers sociais com as credenciais de auth
  void _updateMealsProviderAuth(
      AuthService authService, DailyMealsProvider dailyMealsProvider) {
    final streakProvider = context.read<StreakProvider>();
    final friendsProvider = context.read<FriendsProvider>();
    final challengesProvider = context.read<ChallengesProvider>();
    final feedProvider = context.read<FeedProvider>();
    final creditProvider = context.read<CreditProvider>();
    final dietPlanProvider = context.read<DietPlanProvider>();
    final nutritionGoalsProvider = context.read<NutritionGoalsProvider>();
    final freeChatProvider = context.read<FreeChatProvider>();

    if (authService.isAuthenticated && authService.currentUser != null) {
      final userId = authService.currentUser!.id.toString();
      final token = authService.token ?? '';
      if (token.isNotEmpty) {
        print('[🔄 AUTH_DATA] ========== LOGIN DETECTADO ==========');
        print('[🔄 AUTH_DATA] UserId: $userId');
        print('[🔄 AUTH_DATA] Configurando providers...');

        dailyMealsProvider.setAuth(userId, token);
        print('[🔄 AUTH_DATA] ✅ DailyMealsProvider configurado');

        streakProvider.setToken(token);
        print('[🔄 AUTH_DATA] ✅ StreakProvider configurado');

        friendsProvider.setToken(token);
        print('[🔄 AUTH_DATA] ✅ FriendsProvider configurado');

        challengesProvider.setToken(token);
        print('[🔄 AUTH_DATA] ✅ ChallengesProvider configurado');

        feedProvider.setToken(token);
        print('[🔄 AUTH_DATA] ✅ FeedProvider configurado');

        // Configurar auth para DietPlanProvider (carrega dietas do servidor)
        dietPlanProvider.setAuth(token, authService.currentUser!.id);
        print('[🔄 AUTH_DATA] ✅ DietPlanProvider configurado');

        // Recarregar conversas do FreeChatProvider (dados locais do usuário)
        print('[🔄 AUTH_DATA] Recarregando FreeChatProvider...');
        freeChatProvider.reloadConversations();
        print('[🔄 AUTH_DATA] ✅ FreeChatProvider recarregado');

        // Carregar créditos do servidor após login
        _loadUserDataFromServer(
            token, authService.currentUser!.id, creditProvider);

        // Forçar recriação do NutritionAssistantScreen para carregar dados do usuário
        print(
            '[🔄 AUTH_DATA] Forçando recriação do NutritionAssistantScreen para login...');
        setState(() {
          _nutritionAssistantKey = UniqueKey();
          _currentMode = 'diary';
          _currentFreeChatId = null;
        });
        print('[🔄 AUTH_DATA] ✅ NutritionAssistantScreen será recriado');

        print(
            '[🔄 AUTH_DATA] ========== LOGIN CONFIGURAÇÃO CONCLUÍDA ==========');
      }
    } else {
      print('[🔄 AUTH_DATA] ========== LOGOUT DETECTADO ==========');
      print('[🔄 AUTH_DATA] Limpando auth de todos os providers...');

      dailyMealsProvider.clearAuth();
      print('[🔄 AUTH_DATA] ✅ DailyMealsProvider limpo');

      streakProvider.clearAuth();
      print('[🔄 AUTH_DATA] ✅ StreakProvider limpo');

      friendsProvider.clearAuth();
      print('[🔄 AUTH_DATA] ✅ FriendsProvider limpo');

      challengesProvider.clearAuth();
      print('[🔄 AUTH_DATA] ✅ ChallengesProvider limpo');

      feedProvider.clearAuth();
      print('[🔄 AUTH_DATA] ✅ FeedProvider limpo');

      dietPlanProvider.clearAuth();
      print('[🔄 AUTH_DATA] ✅ DietPlanProvider limpo');

      nutritionGoalsProvider.clearAllData();
      print('[🔄 AUTH_DATA] ✅ NutritionGoalsProvider limpo');

      // Forçar recriação do NutritionAssistantScreen para limpar estado visual
      print('[🔄 AUTH_DATA] Forçando recriação do NutritionAssistantScreen...');
      setState(() {
        _nutritionAssistantKey = UniqueKey();
        _currentMode = 'diary';
        _currentFreeChatId = null;
      });
      print('[🔄 AUTH_DATA] ✅ NutritionAssistantScreen será recriado');

      print(
          '[🔄 AUTH_DATA] ========== LOGOUT AUTH LIMPEZA CONCLUÍDA ==========');
    }
  }

  /// Carrega dados do usuário do servidor (créditos, etc.)
  Future<void> _loadUserDataFromServer(
      String token, int userId, CreditProvider creditProvider) async {
    try {
      print('[MainNavigation] Carregando dados do usuário do servidor...');
      final userData = await ApiService.getUserData(token, userId);

      // Atualizar créditos do servidor
      if (userData.containsKey('credits')) {
        await creditProvider.updateCreditsFromServer(userData);
        print('[MainNavigation] Créditos atualizados do servidor');
      }
    } catch (e) {
      print('[MainNavigation] Erro ao carregar dados do servidor: $e');
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  void _openSocialOverview() {
    setState(() {
      _selectedIndex = 2;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      socialTabController.changeTab(0);
    });
  }

  void _startNewFreeChat() {
    Navigator.pop(context); // Fechar drawer
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const FreeChatScreen()),
    );
  }

  void _switchToDiary() {
    Navigator.pop(context); // Fechar drawer
    setState(() {
      _currentMode = 'diary';
      _currentFreeChatId = null;
      _nutritionAssistantKey = UniqueKey(); // Forçar recriação do widget
    });
  }

  void _openFreeChat(String chatId, String title) {
    Navigator.pop(context); // Fechar drawer
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => FreeChatScreen(freeChatId: chatId)),
    );
  }

  void _openFreeChatFromSearch(String chatId, String title) {
    // Chamada depois que a search screen já fez pop
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => FreeChatScreen(freeChatId: chatId)),
    );
  }

  void _openDiaryForDate(DateTime date) {
    // Muda pra diário e seta data selecionada
    final mealsProvider =
        Provider.of<DailyMealsProvider>(context, listen: false);
    mealsProvider.setSelectedDate(date);
    setState(() {
      _selectedIndex = 0;
      _currentMode = 'diary';
      _currentFreeChatId = null;
      _nutritionAssistantKey = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          // Se não está na aba inicial, voltar para ela
          setState(() {
            _selectedIndex = 0;
          });
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        drawer: _buildDrawer(isDarkMode),
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            // Aba 0: Início / Chat
            NutritionAssistantScreen(
              key: _nutritionAssistantKey,
              isFreeChat: _currentMode == 'free_chat',
              freeChatId: _currentFreeChatId,
              onOpenDrawer: _openDrawer,
            ),

            // Aba 1: Minha Dieta
            PersonalizedDietScreen(
              onOpenDrawer: _openDrawer,
              onSearchPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const FoodSearchScreen(),
                  ),
                );
              },
            ),

            // Aba 2: Social
            SocialHubScreen(onOpenDrawer: _openDrawer),

            // Aba 3: Perfil
            ProfileTabWrapper(
              onOpenDrawer: _openDrawer,
              onOpenSocialHub: _openSocialOverview,
            ),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          selectedItemColor: isDarkMode ? Colors.white : Colors.black,
          unselectedItemColor: isDarkMode ? Colors.grey[600] : Colors.grey[700],
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              activeIcon: Icon(Icons.chat_bubble),
              label: context.tr.translate('home'),
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.restaurant_menu_outlined),
              activeIcon: Icon(Icons.restaurant_menu),
              label: context.tr.translate('my_diet'),
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_outline),
              activeIcon: Icon(Icons.people),
              label: 'Social',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: context.tr.translate('profile'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(bool isDarkMode) {
    return Drawer(
      backgroundColor:
          isDarkMode ? const Color(0xFF171717) : Colors.white,
      child: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Nutro + search (sem avatar)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
                  child: Row(
                    children: [
                      Text(
                        'Nutro',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color:
                              isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? const Color(0xFF2A2A2A)
                              : const Color(0xFFEFEFEF),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.search,
                            size: 20,
                            color: isDarkMode
                                ? Colors.white70
                                : Colors.black54,
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => UnifiedSearchScreen(
                                  onOpenFreeChat: (id, title) =>
                                      _openFreeChatFromSearch(id, title),
                                  onOpenDiaryDate: (date) =>
                                      _openDiaryForDate(date),
                                ),
                              ),
                            );
                          },
                          tooltip: 'Buscar',
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),

                // Cards de acesso rápido: Diário + Conversa livre
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _drawerQuickCard(
                          icon: Icons.calendar_today,
                          label: context.tr.translate('diary'),
                          isDarkMode: isDarkMode,
                          isSelected: _currentMode == 'diary',
                          onTap: _switchToDiary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _drawerQuickCard(
                          icon: Icons.chat_bubble_outline,
                          label: 'Conversa livre',
                          isDarkMode: isDarkMode,
                          isSelected: _currentMode == 'free_chat' &&
                              _currentFreeChatId == null,
                          onTap: _startNewFreeChat,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Subtítulo Recentes (conversas livres)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: Text(
                    'Recentes',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode
                          ? Colors.white54
                          : Colors.black54,
                    ),
                  ),
                ),

                // Lista de conversas livres (estilo ChatGPT: título puro)
                Expanded(
                  child: Consumer<FreeChatProvider>(
                    builder: (context, freeChatProvider, child) {
                      final conversations = freeChatProvider.conversations;

                      if (conversations.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 8),
                          child: Text(
                            context.tr.translate('no_conversations'),
                            style: TextStyle(
                              color: isDarkMode
                                  ? Colors.white38
                                  : Colors.grey,
                              fontSize: 13,
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.only(bottom: 90),
                        itemCount: conversations.length,
                        itemBuilder: (context, index) {
                          final chat = conversations[index];
                          final isSelected =
                              _currentMode == 'free_chat' &&
                                  _currentFreeChatId == chat.id;
                          return InkWell(
                            onTap: () =>
                                _openFreeChat(chat.id, chat.title),
                            onLongPress: () =>
                                _showDeleteConfirmation(chat.id,
                                    chat.title, freeChatProvider),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                              color: isSelected
                                  ? Theme.of(context)
                                      .primaryColor
                                      .withValues(alpha: 0.12)
                                  : null,
                              child: Text(
                                chat.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDarkMode
                                      ? Colors.white
                                      : Colors.black87,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),

            // Botão flutuante "+ Chat" (nova conversa livre)
            Positioned(
              right: 16,
              bottom: 16,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(100),
                color: isDarkMode ? Colors.white : Colors.black,
                child: InkWell(
                  onTap: _startNewFreeChat,
                  borderRadius: BorderRadius.circular(100),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: isDarkMode
                              ? Colors.black
                              : Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Conversa livre',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode
                                ? Colors.black
                                : Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerQuickCard({
    required IconData icon,
    required String label,
    required bool isDarkMode,
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isDarkMode
              ? const Color(0xFF212121)
              : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(
                  color: Theme.of(context).primaryColor, width: 1.5)
              : null,
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isDarkMode
                    ? const Color(0xFF2A2A2A)
                    : const Color(0xFFE0E0E0),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 20,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return context.tr.translate('today');
    } else if (difference.inDays == 1) {
      return context.tr.translate('yesterday');
    } else if (difference.inDays < 7) {
      return '${difference.inDays} ${context.tr.translate('days_ago')}';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _showDeleteConfirmation(
      String chatId, String title, FreeChatProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr.translate('delete_conversation')),
        content: Text(context.tr
            .translate('delete_conversation_confirm')
            .replaceAll('{title}', title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr.translate('cancel')),
          ),
          TextButton(
            onPressed: () {
              provider.deleteConversation(chatId);
              Navigator.pop(context);

              // Se estava vendo essa conversa, voltar para dieta
              if (_currentFreeChatId == chatId) {
                setState(() {
                  _currentMode = 'diet';
                  _currentFreeChatId = null;
                  _nutritionAssistantKey = UniqueKey();
                });
              }
            },
            child: Text(
              context.tr.translate('delete'),
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
