import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'nutrition_assistant_screen.dart';
import 'profile_screen.dart';
import 'login_screen.dart';
import 'personalized_diet_screen.dart';
import 'food_search_screen.dart';
import 'unified_search_screen.dart';
import 'free_chat_screen.dart';
import 'social_hub_screen.dart';
import '../services/rate_app_service.dart';
import '../services/auth_service.dart';
import '../services/user_app_state_service.dart';
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
import '../providers/meal_types_provider.dart';
import '../providers/food_history_provider.dart';
import '../models/user_model.dart';
import '../theme/app_theme.dart';

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
  String? _configuredAuthKey;
  final UserAppStateService _appStateService = UserAppStateService();

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
    if (authService.isLoading) {
      return;
    }

    final streakProvider = context.read<StreakProvider>();
    final friendsProvider = context.read<FriendsProvider>();
    final challengesProvider = context.read<ChallengesProvider>();
    final feedProvider = context.read<FeedProvider>();
    final creditProvider = context.read<CreditProvider>();
    final dietPlanProvider = context.read<DietPlanProvider>();
    final nutritionGoalsProvider = context.read<NutritionGoalsProvider>();
    final freeChatProvider = context.read<FreeChatProvider>();
    final mealTypesProvider = context.read<MealTypesProvider>();
    final foodHistoryProvider = context.read<FoodHistoryProvider>();

    if (authService.isAuthenticated && authService.currentUser != null) {
      final userId = authService.currentUser!.id.toString();
      final token = authService.token ?? '';
      if (token.isNotEmpty) {
        final authKey = '$userId:$token';
        if (_configuredAuthKey == authKey) {
          return;
        }
        _configuredAuthKey = authKey;

        print('[🔄 AUTH_DATA] ========== LOGIN DETECTADO ==========');
        print('[🔄 AUTH_DATA] UserId: $userId');
        print('[🔄 AUTH_DATA] Configurando providers...');

        dailyMealsProvider.setAuth(userId, token);
        print('[🔄 AUTH_DATA] ✅ DailyMealsProvider configurado');

        streakProvider.setToken(token);
        print('[🔄 AUTH_DATA] ✅ StreakProvider configurado');

        // Auto check-in de streak após sync de refeições do dia atual.
        // O backend só aceita check-in quando há UserDailySummary com calorias > 0,
        // então disparar logo após o sync garante a sincronização das duas pontas.
        dailyMealsProvider.onTodaySynced = () {
          streakProvider.performCheckIn();
        };

        friendsProvider.setToken(token);
        print('[🔄 AUTH_DATA] ✅ FriendsProvider configurado');

        challengesProvider.setToken(token);
        print('[🔄 AUTH_DATA] ✅ ChallengesProvider configurado');

        feedProvider.setToken(token);
        print('[🔄 AUTH_DATA] ✅ FeedProvider configurado');

        // Configurar auth para DietPlanProvider (carrega dietas do servidor)
        dietPlanProvider.setAuth(token, authService.currentUser!.id);
        print('[🔄 AUTH_DATA] ✅ DietPlanProvider configurado');

        nutritionGoalsProvider.setAuth(token, authService.currentUser!.id);
        freeChatProvider.setAuth(token, authService.currentUser!.id);

        // Carregar estado do usuário em uma única solicitação: perfil/créditos,
        // metas nutricionais e conversas livres.
        _loadAppStateFromServer(
          token,
          authService.currentUser!.id,
          authService,
          creditProvider,
          dietPlanProvider,
          nutritionGoalsProvider,
          freeChatProvider,
          mealTypesProvider,
          foodHistoryProvider,
        );

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
      _configuredAuthKey = null;
      print('[🔄 AUTH_DATA] ========== LOGOUT DETECTADO ==========');
      print('[🔄 AUTH_DATA] Limpando auth de todos os providers...');

      dailyMealsProvider.clearAuth();
      dailyMealsProvider.onTodaySynced = null;
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

      nutritionGoalsProvider.clearAuth();
      nutritionGoalsProvider.clearAllData();
      print('[🔄 AUTH_DATA] ✅ NutritionGoalsProvider limpo');

      freeChatProvider.clearAuth();
      mealTypesProvider.clearAuth();
      foodHistoryProvider.clearAuth();

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

  /// Carrega dados do usuário do servidor em uma única chamada.
  Future<void> _loadAppStateFromServer(
    String token,
    int userId,
    AuthService authService,
    CreditProvider creditProvider,
    DietPlanProvider dietPlanProvider,
    NutritionGoalsProvider nutritionGoalsProvider,
    FreeChatProvider freeChatProvider,
    MealTypesProvider mealTypesProvider,
    FoodHistoryProvider foodHistoryProvider,
  ) async {
    try {
      print('[MainNavigation] Carregando app-state do usuário do servidor...');
      final appState = await _appStateService.fetchAppState(token: token);

      final userData = (appState['user'] as Map?)?.cast<String, dynamic>();
      if (userData != null) {
        await authService.updateUserLocally(User.fromJson(userData));
      }

      // Atualizar créditos do servidor
      if (appState.containsKey('credits')) {
        await creditProvider.updateCreditsFromServer(appState);
        print('[MainNavigation] Créditos atualizados do servidor');
      }

      await nutritionGoalsProvider.setAuth(
        token,
        userId,
        appState: appState,
      );

      await freeChatProvider.setAuth(
        token,
        userId,
        serverConversations:
            (appState['freeChatConversations'] as List<dynamic>?) ??
                const <dynamic>[],
      );

      final dietPreferences = (appState['dietGenerationPreferences'] as Map?)
          ?.cast<String, dynamic>();
      if (dietPreferences != null && dietPreferences.isNotEmpty) {
        await dietPlanProvider.applyServerPreferencesSnapshot(dietPreferences);
      }

      await mealTypesProvider.setAuth(
        token,
        userId,
        serverMealTypes:
            (appState['mealTypes'] as List<dynamic>?) ?? const <dynamic>[],
      );

      await foodHistoryProvider.setAuth(
        token,
        userId,
        serverFoodHistory:
            (appState['foodHistory'] as Map?)?.cast<String, dynamic>(),
      );
    } catch (e) {
      print('[MainNavigation] Erro ao carregar app-state do servidor: $e');
      await nutritionGoalsProvider.setAuth(token, userId);
      await freeChatProvider.setAuth(token, userId);
      await mealTypesProvider.setAuth(token, userId);
      await foodHistoryProvider.setAuth(token, userId);
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
          backgroundColor: isDarkMode
              ? AppTheme.darkBackgroundColor
              : Theme.of(context).scaffoldBackgroundColor,
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
      backgroundColor: isDarkMode ? const Color(0xFF171717) : Colors.white,
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
                          color: isDarkMode ? Colors.white : Colors.black87,
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
                            color: isDarkMode ? Colors.white70 : Colors.black54,
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
                      color: isDarkMode ? Colors.white54 : Colors.black54,
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
                              color: isDarkMode ? Colors.white38 : Colors.grey,
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
                          final isSelected = _currentMode == 'free_chat' &&
                              _currentFreeChatId == chat.id;
                          return InkWell(
                            onTap: () => _openFreeChat(chat.id, chat.title),
                            onLongPress: () => _showDeleteConfirmation(
                                chat.id, chat.title, freeChatProvider),
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
                          color: isDarkMode ? Colors.black : Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Conversa livre',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.black : Colors.white,
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
          color: isDarkMode ? const Color(0xFF212121) : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(color: Theme.of(context).primaryColor, width: 1.5)
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
