import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:provider/provider.dart';
import 'nutrition_assistant_screen.dart';
import 'profile_screen.dart';
import 'login_screen.dart';
import 'nutrition_goals_wizard_screen.dart';
import 'personalized_diet_screen.dart';
import 'diet_benchmark_screen.dart';
import 'food_search_screen.dart';
import 'unified_search_screen.dart';
import 'free_chat_screen.dart';
import 'social_hub_screen.dart';
import '../services/rate_app_service.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/user_app_state_service.dart';
import '../services/daily_chat_sync_service.dart';
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
import '../providers/profile_shape_preview_provider.dart';
import '../models/user_model.dart';
import '../theme/app_theme.dart';
import '../utils/fabiano_access.dart';
import '../widgets/app_debug_log_overlay.dart';

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
  // Credenciais usadas apenas em modo desenvolvedor (kDebugMode) para
  // oferecer login automático ao abrir o app.
  static const String _devAutoLoginEmail = 'fabiano.araujo2056@gmail.com';
  static const String _devAutoLoginPassword = '12345678';

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Chave para reiniciar o NutritionAssistantScreen
  Key _nutritionAssistantKey = UniqueKey();

  // Modo atual: 'diary' para diário (com JSON/calendário), 'free_chat' para conversa livre
  String _currentMode = 'diary';

  // ID da conversa livre atual (null = nova conversa)
  String? _currentFreeChatId;

  // Índice da aba selecionada na NavigationBar
  int _selectedIndex = 0;

  // Controle para evitar chamadas duplicadas de auth
  bool _authInitialized = false;
  String? _configuredAuthKey;
  String? _initialGoalsPromptAuthKey;
  bool _isBootstrappingAuthenticatedAppState = false;
  bool _isResolvingGuestLocalData = false;
  _GuestLocalDataSnapshot? _pendingGuestLocalData;
  Map<String, dynamic> _latestAppState = const <String, dynamic>{};
  final UserAppStateService _appStateService = UserAppStateService();
  Stopwatch? _authBootstrapStopwatch;

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

      // Em modo desenvolvedor, oferecer login automático na conta de testes.
      _maybeOfferDevAutoLogin();
    });
  }

  void _logChatBootPerf(String event, [Map<String, Object?> data = const {}]) {
    final elapsedMs = _authBootstrapStopwatch?.elapsedMilliseconds ?? 0;
    final payload = data.isEmpty
        ? ''
        : ' ${data.entries.map((entry) => '${entry.key}=${entry.value}').join(' ')}';
    debugPrint('[CHAT_BOOT_PERF] main +${elapsedMs}ms $event$payload');
  }

  /// Em builds de debug (kDebugMode), pergunta se o desenvolvedor quer entrar
  /// automaticamente na conta de testes. Não faz nada em release nem quando já
  /// existe uma sessão autenticada.
  Future<void> _maybeOfferDevAutoLogin() async {
    if (!kDebugMode) return;

    final authService = context.read<AuthService>();

    // Aguarda a restauração de sessão (leitura do secure storage) concluir.
    var waitedMs = 0;
    while (authService.isLoading && waitedMs < 5000) {
      await Future.delayed(const Duration(milliseconds: 100));
      waitedMs += 100;
    }

    if (!mounted || authService.isAuthenticated) return;

    final shouldLogin = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Modo desenvolvedor'),
        content: Text(
          'Fazer login automático na conta $_devAutoLoginEmail?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Não'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Entrar'),
          ),
        ],
      ),
    );

    if (shouldLogin == true) {
      await _performDevAutoLogin(authService);
    }
  }

  Future<void> _performDevAutoLogin(AuthService authService) async {
    try {
      final data = await ApiService.authenticateWithEmail(
        email: _devAutoLoginEmail,
        senha: _devAutoLoginPassword,
      );

      final ok = data['success'] == true &&
          await authService.updateUserDataFromLoginResponse(data);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Login automático: $_devAutoLoginEmail'
                : 'Falha no login automático: ${data['message'] ?? 'erro desconhecido'}',
          ),
          backgroundColor: ok ? AppTheme.successColor : AppTheme.errorColor,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro no login automático: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
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
        _authBootstrapStopwatch = Stopwatch()..start();
        _logChatBootPerf('auth_bootstrap_start', {
          'userId': userId,
          'restoredSession': authService.authenticatedFromStoredSession,
        });
        _setAuthenticatedAppStateBootstrap(true);

        print('[🔄 AUTH_DATA] ========== LOGIN DETECTADO ==========');
        print('[🔄 AUTH_DATA] UserId: $userId');
        print('[🔄 AUTH_DATA] Configurando providers...');
        unawaited(_configureAuthenticatedProviders(
          authKey: authKey,
          token: token,
          userId: authService.currentUser!.id,
          restoredSession: authService.authenticatedFromStoredSession,
          authService: authService,
          dailyMealsProvider: dailyMealsProvider,
          streakProvider: streakProvider,
          friendsProvider: friendsProvider,
          challengesProvider: challengesProvider,
          feedProvider: feedProvider,
          creditProvider: creditProvider,
          dietPlanProvider: dietPlanProvider,
          nutritionGoalsProvider: nutritionGoalsProvider,
          freeChatProvider: freeChatProvider,
          mealTypesProvider: mealTypesProvider,
          foodHistoryProvider: foodHistoryProvider,
        ));

        print(
            '[🔄 AUTH_DATA] ========== LOGIN CONFIGURAÇÃO CONCLUÍDA ==========');
      }
    } else {
      _configuredAuthKey = null;
      _initialGoalsPromptAuthKey = null;
      _isBootstrappingAuthenticatedAppState = false;
      _authBootstrapStopwatch = null;
      _pendingGuestLocalData = null;
      _latestAppState = const <String, dynamic>{};
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

      unawaited(context.read<ProfileShapePreviewProvider>().clearAll());
      print('[🔄 AUTH_DATA] ✅ ProfileShapePreviewProvider limpo');

      nutritionGoalsProvider.clearAuth();
      nutritionGoalsProvider.clearAllData();
      print('[🔄 AUTH_DATA] ✅ NutritionGoalsProvider limpo');

      freeChatProvider.clearAuth();
      mealTypesProvider.clearAuth();
      foodHistoryProvider.clearAuth();
      DailyChatSyncService.instance.clearAuth();

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

  Future<void> _configureAuthenticatedProviders({
    required String authKey,
    required String token,
    required int userId,
    required bool restoredSession,
    required AuthService authService,
    required DailyMealsProvider dailyMealsProvider,
    required StreakProvider streakProvider,
    required FriendsProvider friendsProvider,
    required ChallengesProvider challengesProvider,
    required FeedProvider feedProvider,
    required CreditProvider creditProvider,
    required DietPlanProvider dietPlanProvider,
    required NutritionGoalsProvider nutritionGoalsProvider,
    required FreeChatProvider freeChatProvider,
    required MealTypesProvider mealTypesProvider,
    required FoodHistoryProvider foodHistoryProvider,
  }) async {
    final shouldOfferGuestDataPrompt = !restoredSession;
    _logChatBootPerf('configure_authenticated_providers_start', {
      'restoredSession': restoredSession,
      'offerGuestPrompt': shouldOfferGuestDataPrompt,
    });
    _GuestLocalDataSnapshot? guestSnapshot;
    if (shouldOfferGuestDataPrompt) {
      try {
        guestSnapshot = await _captureGuestLocalDataSnapshot(
          dailyMealsProvider: dailyMealsProvider,
          dietPlanProvider: dietPlanProvider,
          nutritionGoalsProvider: nutritionGoalsProvider,
          freeChatProvider: freeChatProvider,
          mealTypesProvider: mealTypesProvider,
          foodHistoryProvider: foodHistoryProvider,
        );
      } catch (e) {
        print(
            '[MainNavigation] Erro ao capturar dados locais de convidado: $e');
      }
    }

    if (!mounted ||
        _configuredAuthKey != authKey ||
        !authService.isAuthenticated ||
        authService.currentUser?.id != userId) {
      return;
    }

    final allowLocalAutoSync = !shouldOfferGuestDataPrompt;
    _logChatBootPerf('configure_authenticated_providers_ready', {
      'allowLocalAutoSync': allowLocalAutoSync,
      'hasGuestSnapshot': guestSnapshot?.hasData ?? false,
    });
    final mealsAuthFuture =
        dailyMealsProvider.setAuth(userId.toString(), token);
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

    final dietPlanAuthFuture = dietPlanProvider.setAuth(
      token,
      userId,
      syncPendingPreferencesOnAuth: allowLocalAutoSync,
    );
    print('[🔄 AUTH_DATA] ✅ DietPlanProvider configurado');

    // Carregar estado do usuário antes de recriar o diário. Assim o
    // NutritionAssistantScreen já nasce com chat diário e refeições do
    // servidor disponíveis no storage/provider.
    await _finishAuthenticatedSetup(
      authKey: authKey,
      token: token,
      userId: userId,
      allowLocalAutoSync: allowLocalAutoSync,
      guestSnapshot: guestSnapshot,
      mealsAuthFuture: mealsAuthFuture,
      dietPlanAuthFuture: dietPlanAuthFuture,
      authService: authService,
      creditProvider: creditProvider,
      dietPlanProvider: dietPlanProvider,
      nutritionGoalsProvider: nutritionGoalsProvider,
      freeChatProvider: freeChatProvider,
      mealTypesProvider: mealTypesProvider,
      foodHistoryProvider: foodHistoryProvider,
    );
  }

  Future<_GuestLocalDataSnapshot> _captureGuestLocalDataSnapshot({
    required DailyMealsProvider dailyMealsProvider,
    required DietPlanProvider dietPlanProvider,
    required NutritionGoalsProvider nutritionGoalsProvider,
    required FreeChatProvider freeChatProvider,
    required MealTypesProvider mealTypesProvider,
    required FoodHistoryProvider foodHistoryProvider,
  }) async {
    await Future.wait([
      dailyMealsProvider.ready,
      dietPlanProvider.ensureLoaded(),
      nutritionGoalsProvider.ensureLoaded(),
      freeChatProvider.ensureLoaded(),
      mealTypesProvider.ensureLoaded(),
      foodHistoryProvider.ensureLoaded(),
    ]);

    final freeChatConversations = freeChatProvider
        .getServerConversationsSnapshot()
        .where((conversation) =>
            conversation['messages'] is List &&
            (conversation['messages'] as List).isNotEmpty)
        .toList();
    final guestChatByDate =
        await DailyChatSyncService.instance.buildGuestSnapshot();

    return _GuestLocalDataSnapshot(
      goalSetup: nutritionGoalsProvider.hasConfiguredGoals
          ? nutritionGoalsProvider.getServerGoalSetupSnapshot()
          : null,
      macroTargets: nutritionGoalsProvider.hasConfiguredGoals
          ? nutritionGoalsProvider.getMacroSnapshot()
          : null,
      freeChatConversations: freeChatConversations,
      foodHistory: foodHistoryProvider.hasLocalData
          ? foodHistoryProvider.toServerPayload()
          : null,
      mealTypes: mealTypesProvider.hasCustomMealTypes
          ? mealTypesProvider.toServerPayload()
          : const <Map<String, dynamic>>[],
      dietGenerationPreferences: dietPlanProvider.hasLocalDietPreferences
          ? dietPlanProvider.dietPreferencesToServerPayload()
          : null,
      nutritionChatByDate: guestChatByDate,
      dailyMeals: dailyMealsProvider.getLocalSyncSnapshots(),
    );
  }

  Future<void> _finishAuthenticatedSetup({
    required String authKey,
    required String token,
    required int userId,
    required bool allowLocalAutoSync,
    required _GuestLocalDataSnapshot? guestSnapshot,
    required Future<void> mealsAuthFuture,
    required Future<void> dietPlanAuthFuture,
    required AuthService authService,
    required CreditProvider creditProvider,
    required DietPlanProvider dietPlanProvider,
    required NutritionGoalsProvider nutritionGoalsProvider,
    required FreeChatProvider freeChatProvider,
    required MealTypesProvider mealTypesProvider,
    required FoodHistoryProvider foodHistoryProvider,
  }) async {
    _logChatBootPerf('finish_authenticated_setup_wait_start');
    await Future.wait([
      mealsAuthFuture,
      dietPlanAuthFuture,
      _loadAppStateFromServer(
        token,
        userId,
        allowLocalAutoSync,
        authService,
        creditProvider,
        dietPlanProvider,
        nutritionGoalsProvider,
        freeChatProvider,
        mealTypesProvider,
        foodHistoryProvider,
      ),
    ]);
    _logChatBootPerf('finish_authenticated_setup_wait_done');

    if (!mounted ||
        _configuredAuthKey != authKey ||
        !authService.isAuthenticated ||
        authService.currentUser?.id != userId) {
      return;
    }

    context.read<DailyMealsProvider>().updateGoals(
          calories: nutritionGoalsProvider.caloriesGoal,
          protein: nutritionGoalsProvider.proteinGoal,
          carbs: nutritionGoalsProvider.carbsGoal,
          fats: nutritionGoalsProvider.fatGoal,
          fitnessGoal: nutritionGoalsProvider.fitnessGoal.name,
        );

    // Forçar recriação do NutritionAssistantScreen para carregar dados do usuário.
    print(
        '[🔄 AUTH_DATA] Forçando recriação do NutritionAssistantScreen após app-state...');
    _logChatBootPerf('chat_screen_recreate_start', {
      'hasGuestPrompt': guestSnapshot != null && guestSnapshot.hasData,
    });
    setState(() {
      _nutritionAssistantKey = UniqueKey();
      _currentMode = 'diary';
      _currentFreeChatId = null;
      _isBootstrappingAuthenticatedAppState = false;
      _pendingGuestLocalData =
          guestSnapshot != null && guestSnapshot.hasData ? guestSnapshot : null;
    });
    _logChatBootPerf('chat_screen_recreate_set_state_done');
    print('[🔄 AUTH_DATA] ✅ NutritionAssistantScreen será recriado');
  }

  void _setAuthenticatedAppStateBootstrap(bool value) {
    if (!mounted || _isBootstrappingAuthenticatedAppState == value) {
      return;
    }
    setState(() {
      _isBootstrappingAuthenticatedAppState = value;
    });
    _logChatBootPerf('set_initial_chat_bootstrap', {
      'value': value,
    });
  }

  bool _isInitialChatBootstrapPending(AuthService authService) {
    if (authService.isLoading || _isBootstrappingAuthenticatedAppState) {
      return true;
    }

    final user = authService.currentUser;
    final token = authService.token;
    if (authService.isAuthenticated &&
        user != null &&
        token != null &&
        token.isNotEmpty) {
      return _configuredAuthKey != '${user.id}:$token';
    }

    return false;
  }

  /// Carrega dados do usuário do servidor em uma única chamada.
  Future<void> _loadAppStateFromServer(
    String token,
    int userId,
    bool allowLocalAutoSync,
    AuthService authService,
    CreditProvider creditProvider,
    DietPlanProvider dietPlanProvider,
    NutritionGoalsProvider nutritionGoalsProvider,
    FreeChatProvider freeChatProvider,
    MealTypesProvider mealTypesProvider,
    FoodHistoryProvider foodHistoryProvider,
  ) async {
    final appStateStopwatch = Stopwatch()..start();
    try {
      print('[MainNavigation] Carregando app-state do usuário do servidor...');
      final selectedDate = context.read<DailyMealsProvider>().selectedDate;
      _logChatBootPerf('app_state_fetch_start', {
        'date': UserAppStateService.formatDateKey(selectedDate),
      });
      final appState = await _appStateService.fetchAppState(
        token: token,
        nutritionChatDateKey: UserAppStateService.formatDateKey(selectedDate),
      );
      _logChatBootPerf('app_state_fetch_done', {
        'elapsedMs': appStateStopwatch.elapsedMilliseconds,
        'freeChatCount':
            ((appState['freeChatConversations'] as List<dynamic>?) ?? const [])
                .length,
        'hasNutritionChat': appState['nutritionChatByDate'] is Map,
      });
      _latestAppState = appState;

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
        syncPendingOnAuth: allowLocalAutoSync,
        syncLocalIfServerEmpty: allowLocalAutoSync,
      );
      _logChatBootPerf('nutrition_goals_auth_done', {
        'elapsedMs': appStateStopwatch.elapsedMilliseconds,
      });

      await freeChatProvider.setAuth(
        token,
        userId,
        serverConversations:
            (appState['freeChatConversations'] as List<dynamic>?) ??
                const <dynamic>[],
        syncPendingOnAuth: allowLocalAutoSync,
        syncLocalIfServerEmpty: allowLocalAutoSync,
      );
      _logChatBootPerf('free_chat_auth_done', {
        'elapsedMs': appStateStopwatch.elapsedMilliseconds,
      });

      final dietPreferences = (appState['dietGenerationPreferences'] as Map?)
          ?.cast<String, dynamic>();
      await dietPlanProvider.applyServerPreferencesSnapshot(
        dietPreferences ?? const <String, dynamic>{},
        syncLocalIfServerEmpty: allowLocalAutoSync,
      );

      await mealTypesProvider.setAuth(
        token,
        userId,
        serverMealTypes:
            (appState['mealTypes'] as List<dynamic>?) ?? const <dynamic>[],
        syncPendingOnAuth: allowLocalAutoSync,
        syncLocalIfServerEmpty: allowLocalAutoSync,
      );
      _logChatBootPerf('meal_types_auth_done', {
        'elapsedMs': appStateStopwatch.elapsedMilliseconds,
      });

      await foodHistoryProvider.setAuth(
        token,
        userId,
        serverFoodHistory:
            (appState['foodHistory'] as Map?)?.cast<String, dynamic>(),
        syncPendingOnAuth: allowLocalAutoSync,
        syncLocalIfServerEmpty: allowLocalAutoSync,
      );
      _logChatBootPerf('food_history_auth_done', {
        'elapsedMs': appStateStopwatch.elapsedMilliseconds,
      });

      // Restaura o chat diário do AI Tutor vindo do servidor (sobrevive a
      // limpeza de dados/reinstalação/troca de aparelho) e habilita o upload.
      await DailyChatSyncService.instance.restoreFromServer(
        (appState['nutritionChatByDate'] as Map?)?.cast<String, dynamic>(),
        scope: 'user_$userId',
      );
      DailyChatSyncService.instance.setAuth(token, userId);
      _logChatBootPerf('app_state_apply_done', {
        'elapsedMs': appStateStopwatch.elapsedMilliseconds,
      });
    } catch (e) {
      print('[MainNavigation] Erro ao carregar app-state do servidor: $e');
      _logChatBootPerf('app_state_error', {
        'elapsedMs': appStateStopwatch.elapsedMilliseconds,
        'error': e.toString(),
      });
      _latestAppState = const <String, dynamic>{};
      await nutritionGoalsProvider.setAuth(
        token,
        userId,
        syncPendingOnAuth: allowLocalAutoSync,
        syncLocalIfServerEmpty: allowLocalAutoSync,
      );
      await freeChatProvider.setAuth(
        token,
        userId,
        syncPendingOnAuth: allowLocalAutoSync,
        syncLocalIfServerEmpty: allowLocalAutoSync,
      );
      await mealTypesProvider.setAuth(
        token,
        userId,
        syncPendingOnAuth: allowLocalAutoSync,
        syncLocalIfServerEmpty: allowLocalAutoSync,
      );
      await foodHistoryProvider.setAuth(
        token,
        userId,
        syncPendingOnAuth: allowLocalAutoSync,
        syncLocalIfServerEmpty: allowLocalAutoSync,
      );
      DailyChatSyncService.instance.setAuth(token, userId);
    }

    await _maybeOpenInitialGoalsWizard(
      token: token,
      userId: userId,
      nutritionGoalsProvider: nutritionGoalsProvider,
    );
  }

  Future<void> _maybeOpenInitialGoalsWizard({
    required String token,
    required int userId,
    required NutritionGoalsProvider nutritionGoalsProvider,
  }) async {
    if (!mounted) return;

    final authService = context.read<AuthService>();
    if (!authService.isAuthenticated ||
        authService.currentUser?.id != userId ||
        authService.token != token) {
      return;
    }

    final authKey = '$userId:$token';
    if (_initialGoalsPromptAuthKey == authKey) {
      return;
    }

    await nutritionGoalsProvider.ensureLoaded();
    if (!mounted || nutritionGoalsProvider.hasConfiguredGoals) {
      return;
    }

    _initialGoalsPromptAuthKey = authKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const NutritionGoalsWizardScreen(),
        ),
      );
    });
  }

  Future<void> _saveGuestLocalData() async {
    final snapshot = _pendingGuestLocalData;
    final authService = context.read<AuthService>();
    final token = authService.token;
    final userId = authService.currentUser?.id;
    if (snapshot == null || token == null || userId == null) return;

    setState(() {
      _isResolvingGuestLocalData = true;
    });

    try {
      final mergedFreeChat = snapshot.freeChatConversations.isEmpty
          ? null
          : _mergeFreeChatConversations(
              _mapListFromAppState(_latestAppState['freeChatConversations']),
              snapshot.freeChatConversations,
            );
      final mergedFoodHistory = snapshot.foodHistory == null
          ? null
          : _mergeFoodHistory(
              (_latestAppState['foodHistory'] as Map?)?.cast<String, dynamic>(),
              snapshot.foodHistory!,
            );
      final mergedDailyChat = snapshot.nutritionChatByDate.isEmpty
          ? null
          : _mergeNutritionChatByDate(
              (_latestAppState['nutritionChatByDate'] as Map?)
                  ?.cast<String, dynamic>(),
              snapshot.nutritionChatByDate,
            );

      final hasAppStatePayload = snapshot.goalSetup != null ||
          snapshot.dietGenerationPreferences != null ||
          snapshot.mealTypes.isNotEmpty ||
          mergedFreeChat != null ||
          mergedFoodHistory != null ||
          mergedDailyChat != null;

      if (hasAppStatePayload) {
        await _appStateService.syncAppState(
          token: token,
          goalSetup: snapshot.goalSetup,
          macroTargets: snapshot.macroTargets,
          dietGenerationPreferences: snapshot.dietGenerationPreferences,
          freeChatConversations: mergedFreeChat,
          mealTypes: snapshot.mealTypes.isEmpty ? null : snapshot.mealTypes,
          foodHistory: mergedFoodHistory,
          nutritionChatByDate: mergedDailyChat,
        );
      }

      if (snapshot.dailyMeals.isNotEmpty) {
        await context.read<DailyMealsProvider>().syncSnapshotsToServer(
              token,
              snapshot.dailyMeals,
            );
      }

      if (snapshot.goalSetup != null) {
        await context.read<NutritionGoalsProvider>().applyServerSnapshot(
              goalSetup: snapshot.goalSetup!,
              macroTargets: snapshot.macroTargets,
            );
      }
      if (mergedFreeChat != null) {
        await context
            .read<FreeChatProvider>()
            .applyServerConversations(mergedFreeChat);
      }
      if (mergedFoodHistory != null) {
        await context
            .read<FoodHistoryProvider>()
            .applyServerSnapshot(mergedFoodHistory);
      }
      if (snapshot.mealTypes.isNotEmpty) {
        await context
            .read<MealTypesProvider>()
            .applyServerSnapshot(snapshot.mealTypes);
      }
      if (snapshot.dietGenerationPreferences != null) {
        await context.read<DietPlanProvider>().applyServerPreferencesSnapshot(
              snapshot.dietGenerationPreferences!,
              syncLocalIfServerEmpty: false,
            );
      }
      if (mergedDailyChat != null) {
        await DailyChatSyncService.instance.restoreFromServer(
          mergedDailyChat,
          scope: 'user_$userId',
        );
      }

      await DailyChatSyncService.instance.clearGuestChats();

      if (!mounted) return;
      setState(() {
        _pendingGuestLocalData = null;
        _isResolvingGuestLocalData = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr.translate('guest_local_data_saved')),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (e) {
      print('[MainNavigation] Erro ao salvar dados locais na conta: $e');
      if (!mounted) return;
      setState(() {
        _isResolvingGuestLocalData = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr.translate('guest_local_data_save_failed')),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Future<void> _discardGuestLocalData() async {
    final authService = context.read<AuthService>();
    final token = authService.token;
    final userId = authService.currentUser?.id;

    setState(() {
      _isResolvingGuestLocalData = true;
    });

    try {
      await DailyChatSyncService.instance.clearGuestChats();
      if (token != null && userId != null) {
        final dailyMealsProvider = context.read<DailyMealsProvider>();
        await dailyMealsProvider.clearAllData();
        await dailyMealsProvider.setAuth(userId.toString(), token);
      }

      if (!mounted) return;
      setState(() {
        _pendingGuestLocalData = null;
        _isResolvingGuestLocalData = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr.translate('guest_local_data_discarded')),
        ),
      );
    } catch (e) {
      print('[MainNavigation] Erro ao descartar dados locais: $e');
      if (!mounted) return;
      setState(() {
        _isResolvingGuestLocalData = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(context.tr.translate('guest_local_data_discard_failed')),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  List<Map<String, dynamic>> _mapListFromAppState(dynamic value) {
    if (value is! List) return const <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList();
  }

  List<Map<String, dynamic>> _mergeFreeChatConversations(
    List<Map<String, dynamic>> serverConversations,
    List<Map<String, dynamic>> localConversations,
  ) {
    final mergedById = <String, Map<String, dynamic>>{};
    for (final conversation in [
      ...serverConversations,
      ...localConversations
    ]) {
      final id = conversation['id']?.toString();
      if (id == null || id.trim().isEmpty) continue;
      final current = mergedById[id];
      if (current == null ||
          _messageCount(conversation['messages']) >=
              _messageCount(current['messages'])) {
        mergedById[id] = Map<String, dynamic>.from(conversation);
      }
    }

    final merged = mergedById.values.toList();
    merged.sort((a, b) {
      final aDate = DateTime.tryParse(a['lastUpdated']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = DateTime.tryParse(b['lastUpdated']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return merged;
  }

  Map<String, dynamic> _mergeFoodHistory(
    Map<String, dynamic>? serverFoodHistory,
    Map<String, dynamic> localFoodHistory,
  ) {
    final server = serverFoodHistory ?? const <String, dynamic>{};
    final frequency = <String, int>{};
    for (final source in [server['frequency'], localFoodHistory['frequency']]) {
      if (source is! Map) continue;
      source.forEach((key, value) {
        final count =
            value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;
        if (count > 0) {
          frequency[key.toString()] = (frequency[key.toString()] ?? 0) + count;
        }
      });
    }

    return {
      'favorites':
          _mergeFoodList(server['favorites'], localFoodHistory['favorites']),
      'recents': _mergeFoodList(server['recents'], localFoodHistory['recents']),
      'frequency': frequency,
    };
  }

  List<Map<String, dynamic>> _mergeFoodList(dynamic server, dynamic local) {
    final mergedById = <String, Map<String, dynamic>>{};
    for (final source in [server, local]) {
      if (source is! List) continue;
      for (final item in source.whereType<Map>()) {
        final food = item.cast<String, dynamic>();
        final id = food['idFatsecret']?.toString() ??
            food['id']?.toString() ??
            food['name']?.toString().trim().toLowerCase();
        if (id == null || id.isEmpty) continue;
        mergedById[id] = food;
      }
    }
    return mergedById.values.toList();
  }

  Map<String, dynamic> _mergeNutritionChatByDate(
    Map<String, dynamic>? serverChat,
    Map<String, dynamic> localChat,
  ) {
    final merged = <String, dynamic>{};
    void addEntries(Map<String, dynamic>? source) {
      if (source == null) return;
      source.forEach((dateKey, value) {
        if (value is! Map) return;
        final incoming = value.cast<String, dynamic>();
        final existing = merged[dateKey];
        if (existing is Map &&
            _messageCount(existing['messages']) >=
                _messageCount(incoming['messages'])) {
          return;
        }
        merged[dateKey] = incoming;
      });
    }

    addEntries(serverChat);
    addEntries(localChat);
    return merged;
  }

  int _messageCount(dynamic messages) {
    return messages is List ? messages.length : 0;
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) {
      return;
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  void _openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  /// Fecha o drawer somente se ele estiver aberto. Em telas largas o painel
  /// lateral é persistente (não é um Drawer), então não há nada para fechar.
  void _closeDrawerIfOpen() {
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.pop(context);
    }
  }

  /// Breakpoint a partir do qual o app exibe o layout de tela larga
  /// (menu lateral sempre visível, sem barra de navegação inferior).
  static const double _wideLayoutBreakpoint = 900;

  void _openSocialOverview() {
    setState(() {
      _selectedIndex = 2;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      socialTabController.changeTab(0);
    });
  }

  void _startNewFreeChat() {
    _closeDrawerIfOpen();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const FreeChatScreen()),
    );
  }

  void _switchToDiary() {
    _closeDrawerIfOpen();
    setState(() {
      _currentMode = 'diary';
      _currentFreeChatId = null;
      _nutritionAssistantKey = UniqueKey(); // Forçar recriação do widget
    });
  }

  void _openFreeChat(String chatId, String title) {
    _closeDrawerIfOpen();
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

  void _openDietBenchmark() {
    _closeDrawerIfOpen();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DietBenchmarkScreen()),
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value:
          isDarkMode ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= _wideLayoutBreakpoint;

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
            child: isWide
                ? _buildWideLayout(isDarkMode)
                : _buildNarrowLayout(isDarkMode),
          );
        },
      ),
    );
  }

  /// Layout para celulares: Drawer + NavigationBar Material 3.
  Widget _buildNarrowLayout(bool isDarkMode) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(isDarkMode),
      body: Stack(
        children: [
          AppDebugLogOverlay(
            child: _buildTabStack(onOpenDrawer: _openDrawer),
          ),
          _buildGuestLocalDataPrompt(isWide: false),
        ],
      ),
      bottomNavigationBar: _buildNavigationBar(isDarkMode),
    );
  }

  Widget _buildGuestLocalDataPrompt({required bool isWide}) {
    final snapshot = _pendingGuestLocalData;
    if (snapshot == null || !snapshot.hasData) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDarkMode = theme.brightness == Brightness.dark;
    final labels = snapshot.summaryLabels(context);

    return Positioned(
      left: isWide ? 24 : 16,
      right: isWide ? null : 16,
      bottom: 16,
      child: SafeArea(
        top: false,
        child: Align(
          alignment: isWide ? Alignment.bottomLeft : Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Material(
              color: isDarkMode ? AppTheme.darkCardColor : Colors.white,
              elevation: 10,
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color:
                                AppTheme.primaryColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.cloud_upload_outlined,
                            color: AppTheme.primaryColor,
                            size: 21,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tr.translate('guest_local_data_title'),
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                context.tr
                                    .translate('guest_local_data_message'),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  height: 1.25,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (labels.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        labels.join(' • '),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: _isResolvingGuestLocalData
                              ? null
                              : _discardGuestLocalData,
                          icon: const Icon(Icons.close_rounded, size: 18),
                          label: Text(
                            context.tr
                                .translate('guest_local_data_discard_action'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: _isResolvingGuestLocalData
                              ? null
                              : _saveGuestLocalData,
                          icon: _isResolvingGuestLocalData
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.check_rounded, size: 18),
                          label: Text(
                            context.tr
                                .translate('guest_local_data_save_action'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Layout para tablets/desktop: painel lateral fixo (sem Drawer) e sem
  /// NavigationBar — os itens de navegação ficam no rodapé do painel.
  Widget _buildWideLayout(bool isDarkMode) {
    return Scaffold(
      key: _scaffoldKey,
      body: Row(
        children: [
          SizedBox(
            width: 304,
            child: Material(
              color: isDarkMode
                  ? AppTheme.darkBackgroundColor
                  : AppTheme.backgroundColor,
              child: _buildSidePanelBody(isDarkMode, isPersistent: true),
            ),
          ),
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: isDarkMode ? Colors.white12 : Colors.black12,
          ),
          Expanded(
            child: Stack(
              children: [
                AppDebugLogOverlay(
                  child: _buildTabStack(onOpenDrawer: null),
                ),
                _buildGuestLocalDataPrompt(isWide: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Constrói as abas sob demanda e mantém as telas já abertas vivas.
  /// Isso evita que uma troca na NavigationBar reconstrua chat, dieta,
  /// social e perfil no mesmo frame.
  Widget _buildTabStack({required VoidCallback? onOpenDrawer}) {
    final authService = context.watch<AuthService>();
    final isInitialChatBootstrapping =
        _isInitialChatBootstrapPending(authService);
    final usesDrawer = onOpenDrawer != null;

    return IndexedStack(
      index: _selectedIndex,
      children: List.generate(4, (index) {
        return _LazyNavigationTab(
          key: ValueKey('main_navigation_tab_$index'),
          isSelected: _selectedIndex == index,
          cacheKey: _tabCacheKey(
            index: index,
            usesDrawer: usesDrawer,
            isInitialChatBootstrapping: isInitialChatBootstrapping,
          ),
          builder: (context) => _buildTabScreen(
            index: index,
            onOpenDrawer: onOpenDrawer,
            isInitialChatBootstrapping: isInitialChatBootstrapping,
          ),
        );
      }),
    );
  }

  String _tabCacheKey({
    required int index,
    required bool usesDrawer,
    required bool isInitialChatBootstrapping,
  }) {
    if (index == 0) {
      return [
        'home',
        usesDrawer ? 'drawer' : 'wide',
        identityHashCode(_nutritionAssistantKey),
        _currentMode,
        _currentFreeChatId ?? '',
        isInitialChatBootstrapping,
      ].join('|');
    }

    return '$index|${usesDrawer ? 'drawer' : 'wide'}';
  }

  /// Em telas largas, [onOpenDrawer] é null para que as telas escondam o
  /// botão de menu hambúrguer.
  Widget _buildTabScreen({
    required int index,
    required VoidCallback? onOpenDrawer,
    required bool isInitialChatBootstrapping,
  }) {
    switch (index) {
      case 0:
        return NutritionAssistantScreen(
          key: _nutritionAssistantKey,
          isFreeChat: _currentMode == 'free_chat',
          freeChatId: _currentFreeChatId,
          isBootstrappingInitialChat: isInitialChatBootstrapping,
          onOpenDrawer: onOpenDrawer,
          onOpenMyDiet: () => _onItemTapped(1),
        );
      case 1:
        return PersonalizedDietScreen(
          onOpenDrawer: onOpenDrawer,
          onSearchPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const FoodSearchScreen(),
              ),
            );
          },
        );
      case 2:
        return SocialHubScreen(onOpenDrawer: onOpenDrawer);
      case 3:
        return ProfileTabWrapper(
          onOpenDrawer: onOpenDrawer,
          onOpenSocialHub: _openSocialOverview,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildNavigationBar(bool isDarkMode) {
    return NavigationBar(
      selectedIndex: _selectedIndex,
      onDestinationSelected: _onItemTapped,
      backgroundColor: isDarkMode
          ? AppTheme.darkBackgroundColor
          : Theme.of(context).scaffoldBackgroundColor,
      elevation: 0,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: context.tr.translate('home'),
        ),
        NavigationDestination(
          icon: Icon(Icons.ramen_dining_outlined),
          selectedIcon: Icon(Icons.ramen_dining),
          label: context.tr.translate('my_diet'),
        ),
        NavigationDestination(
          icon: Icon(Icons.group_outlined),
          selectedIcon: Icon(Icons.group),
          label: 'Social',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: context.tr.translate('profile'),
        ),
      ],
    );
  }

  Widget _buildDrawer(bool isDarkMode) {
    return Drawer(
      backgroundColor:
          isDarkMode ? AppTheme.darkBackgroundColor : AppTheme.backgroundColor,
      child: _buildSidePanelBody(isDarkMode, isPersistent: false),
    );
  }

  /// Conteúdo compartilhado entre o Drawer (mobile) e o painel lateral fixo
  /// (tablet/desktop). Quando [isPersistent] for `true`, o FAB redundante é
  /// omitido e os itens de navegação ficam fixos no rodapé do painel.
  Widget _buildSidePanelBody(bool isDarkMode, {required bool isPersistent}) {
    final authService = context.watch<AuthService>();
    final showDietBenchmark = canAccessDietBenchmark(authService.currentUser);

    return SafeArea(
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
                        color: isDarkMode
                            ? AppTheme.darkTextColor
                            : Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? AppTheme.darkComponentColor
                            : const Color(0xFFEFEFEF),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.search,
                          size: 20,
                          color: isDarkMode
                              ? AppTheme.darkTextColor.withValues(alpha: 0.72)
                              : Colors.black54,
                        ),
                        onPressed: () {
                          _closeDrawerIfOpen();
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

              if (showDietBenchmark)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: _drawerBenchmarkTile(isDarkMode),
                ),

              // Itens de navegação (apenas tela larga) — acima das conversas.
              if (isPersistent) ...[
                _buildSidePanelNavItems(isDarkMode),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: isDarkMode ? AppTheme.darkBorderColor : Colors.black12,
                ),
              ],

              // Subtítulo Recentes (conversas livres)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Text(
                  'Recentes',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode
                        ? AppTheme.darkMutedTextColor
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
                                ? AppTheme.darkDisabledTextColor
                                : Colors.grey,
                            fontSize: 13,
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: EdgeInsets.only(
                        bottom: isPersistent ? 8 : 90,
                      ),
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
                                    ? AppTheme.darkTextColor
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

          // Botão flutuante "+ Chat" — só aparece no Drawer (mobile).
          if (!isPersistent)
            Positioned(
              right: 16,
              bottom: 16,
              child: _buildNewChatFab(isDarkMode),
            ),
        ],
      ),
    );
  }

  Widget _drawerBenchmarkTile(bool isDarkMode) {
    return InkWell(
      onTap: _openDietBenchmark,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isDarkMode ? AppTheme.darkCardColor : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDarkMode ? AppTheme.darkBorderColor : Colors.black12,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.science_outlined,
              size: 20,
              color: isDarkMode ? AppTheme.darkTextColor : Colors.black87,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.tr.translate('diet_benchmark_nav'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDarkMode ? AppTheme.darkTextColor : Colors.black87,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: isDarkMode ? AppTheme.darkMutedTextColor : Colors.black45,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewChatFab(bool isDarkMode) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(100),
      color: isDarkMode ? AppTheme.primaryColorDarkMode : AppTheme.primaryColor,
      child: InkWell(
        onTap: _startNewFreeChat,
        borderRadius: BorderRadius.circular(100),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.edit_outlined,
                size: 18,
                color: AppTheme.onColor(
                  isDarkMode
                      ? AppTheme.primaryColorDarkMode
                      : AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Conversa livre',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.onColor(
                    isDarkMode
                        ? AppTheme.primaryColorDarkMode
                        : AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Itens de navegação (Início, Minha Dieta, Social, Perfil) exibidos no
  /// rodapé do painel lateral quando o layout é de tela larga.
  Widget _buildSidePanelNavItems(bool isDarkMode) {
    final items = <_SidePanelNavItem>[
      _SidePanelNavItem(
        icon: Icons.home_outlined,
        activeIcon: Icons.home,
        label: context.tr.translate('home'),
      ),
      _SidePanelNavItem(
        icon: Icons.ramen_dining_outlined,
        activeIcon: Icons.ramen_dining,
        label: context.tr.translate('my_diet'),
      ),
      _SidePanelNavItem(
        icon: Icons.group_outlined,
        activeIcon: Icons.group,
        label: 'Social',
      ),
      _SidePanelNavItem(
        icon: Icons.person_outline,
        activeIcon: Icons.person,
        label: context.tr.translate('profile'),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(items.length, (i) {
          final item = items[i];
          final selected = _selectedIndex == i;
          final selectedBg = isDarkMode
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06);
          final itemColor = isDarkMode
              ? (selected ? Colors.white : AppTheme.darkTextColor)
              : Colors.black87;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: InkWell(
              onTap: () => _onItemTapped(i),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? selectedBg : null,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      selected ? item.activeIcon : item.icon,
                      size: 20,
                      color: itemColor,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w500,
                          color: itemColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
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
          color: isDarkMode ? AppTheme.darkCardColor : const Color(0xFFF5F5F5),
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
                    ? AppTheme.darkComponentColor
                    : const Color(0xFFE0E0E0),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 20,
                color: isSelected
                    ? (isDarkMode
                        ? AppTheme.primaryColorDarkMode
                        : AppTheme.primaryColor)
                    : (isDarkMode ? AppTheme.darkTextColor : Colors.black87),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isSelected
                    ? (isDarkMode
                        ? AppTheme.primaryColorDarkMode
                        : AppTheme.primaryColor)
                    : (isDarkMode ? AppTheme.darkTextColor : Colors.black87),
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

class _GuestLocalDataSnapshot {
  final Map<String, dynamic>? goalSetup;
  final Map<String, dynamic>? macroTargets;
  final List<Map<String, dynamic>> freeChatConversations;
  final Map<String, dynamic>? foodHistory;
  final List<Map<String, dynamic>> mealTypes;
  final Map<String, dynamic>? dietGenerationPreferences;
  final Map<String, dynamic> nutritionChatByDate;
  final List<DailyMealsSyncSnapshot> dailyMeals;

  const _GuestLocalDataSnapshot({
    required this.goalSetup,
    required this.macroTargets,
    required this.freeChatConversations,
    required this.foodHistory,
    required this.mealTypes,
    required this.dietGenerationPreferences,
    required this.nutritionChatByDate,
    required this.dailyMeals,
  });

  bool get hasData =>
      goalSetup != null ||
      freeChatConversations.isNotEmpty ||
      foodHistory != null ||
      mealTypes.isNotEmpty ||
      dietGenerationPreferences != null ||
      nutritionChatByDate.isNotEmpty ||
      dailyMeals.isNotEmpty;

  List<String> summaryLabels(BuildContext context) {
    final labels = <String>[];
    if (goalSetup != null) {
      labels.add(context.tr.translate('guest_local_data_summary_goals'));
    }
    if (dailyMeals.isNotEmpty) {
      labels.add(context.tr.translate('guest_local_data_summary_meals'));
    }
    if (freeChatConversations.isNotEmpty || nutritionChatByDate.isNotEmpty) {
      labels.add(context.tr.translate('guest_local_data_summary_chats'));
    }
    if (foodHistory != null) {
      labels.add(context.tr.translate('guest_local_data_summary_foods'));
    }
    if (mealTypes.isNotEmpty || dietGenerationPreferences != null) {
      labels.add(context.tr.translate('guest_local_data_summary_preferences'));
    }
    return labels;
  }
}

class _SidePanelNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _SidePanelNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

typedef _NavigationTabBuilder = Widget Function(BuildContext context);

class _LazyNavigationTab extends StatefulWidget {
  final bool isSelected;
  final String cacheKey;
  final _NavigationTabBuilder builder;

  const _LazyNavigationTab({
    super.key,
    required this.isSelected,
    required this.cacheKey,
    required this.builder,
  });

  @override
  State<_LazyNavigationTab> createState() => _LazyNavigationTabState();
}

class _LazyNavigationTabState extends State<_LazyNavigationTab> {
  Widget? _child;
  String? _activeCacheKey;

  @override
  Widget build(BuildContext context) {
    if (widget.isSelected &&
        (_child == null || _activeCacheKey != widget.cacheKey)) {
      _child = widget.builder(context);
      _activeCacheKey = widget.cacheKey;
    }

    return _child ?? const SizedBox.shrink();
  }
}
