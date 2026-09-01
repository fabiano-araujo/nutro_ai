import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:provider/provider.dart';
import 'nutrition_assistant_screen.dart';
import 'daily_meals_screen.dart';
import 'profile_screen.dart';
import 'login_screen.dart';
import 'nutrition_goals_wizard_screen.dart';
import 'personalized_diet_screen.dart';
import 'diet_benchmark_screen.dart';
import 'food_search_screen.dart';
import 'unified_search_screen.dart';
import 'free_chat_screen.dart';
import 'social_hub_screen.dart';
import 'streak_screen.dart';
import 'streak_celebration_screen.dart';
import 'streak_widget_onboarding_screen.dart';
import '../services/rate_app_service.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/user_app_state_service.dart';
import '../services/daily_chat_sync_service.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../services/behavioral_reminder_planner.dart';
import '../services/streak_widget_service.dart';
import '../i18n/app_localizations_extension.dart';
import '../i18n/language_controller.dart';
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
import '../utils/meal_type_localization.dart';
import '../utils/streak_helper.dart';
import '../providers/food_history_provider.dart';
import '../providers/profile_shape_preview_provider.dart';
import '../models/user_model.dart';
import '../theme/app_theme.dart';
import '../utils/fabiano_access.dart';
import '../widgets/app_debug_log_overlay.dart';
import '../widgets/guest_local_data_prompt.dart';
import '../controllers/navigation_controller.dart';

export '../controllers/navigation_controller.dart';

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

class _MainNavigationState extends State<MainNavigation>
    with WidgetsBindingObserver {
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
  Map<String, List<Map<String, dynamic>>> _initialNutritionChatMessagesByDate =
      const <String, List<Map<String, dynamic>>>{};
  final UserAppStateService _appStateService = UserAppStateService();
  Stopwatch? _authBootstrapStopwatch;
  Timer? _behavioralNotificationDebounce;
  Timer? _behavioralDayRolloverTimer;
  Timer? _streakWidgetSyncDebounce;
  DailyMealsProvider? _notificationMealsProvider;
  MealTypesProvider? _notificationMealTypesProvider;
  StreakProvider? _notificationStreakProvider;
  LanguageController? _notificationLanguageController;
  bool _behavioralNotificationSyncRunning = false;
  bool _behavioralNotificationSyncRequested = false;
  bool _forceBehavioralNotificationSync = false;
  bool _refreshBehavioralNotificationTimeZone = false;
  int _behavioralNotificationSessionRevision = 0;
  StreamSubscription<void>? _streakWidgetOpenSubscription;
  int? _lastObservedMealAdditionVersion;
  String? _lastStreakWidgetSnapshotSignature;
  bool _streakWidgetIntroCheckRunning = false;
  bool _streakWidgetIntroVisible = false;
  bool _streakScreenOpeningFromWidget = false;
  bool _streakExperienceQueueRunning = false;
  bool _streakWidgetIntroPending = false;
  bool _waitingForStreakCheckInBeforeWidgetIntro = false;
  Timer? _streakExperienceRetryTimer;
  Timer? _streakWidgetIntroFallbackTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Configurar callback do controlador de navegação
    navigationController.tabChangeCallback = _onItemTapped;

    // Verificar se deve mostrar o diálogo de avaliação
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Aguardar um pouco para que o app seja carregado completamente
      Future.delayed(const Duration(seconds: 2), () {
        _promptForRatingWhenStreakExperienceIsIdle();
      });

      // Configurar sync de refeições com auth
      _setupMealsSyncAuth();

      // Reconciliar lembretes condicionais depois que os providers existem.
      _setupBehavioralNotifications();

      // Mantém o widget Android sincronizado e trata abertura pelo launcher.
      _setupStreakWidget();

      // Em modo desenvolvedor, oferecer login automático na conta de testes.
      _maybeOfferDevAutoLogin();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scheduleBehavioralNotificationSync(
        force: true,
        refreshTimeZone: true,
      );
      _scheduleStreakWidgetSync(force: true);
      unawaited(_refreshStreakAfterResume());
    }
  }

  void _setupBehavioralNotifications() {
    if (_notificationMealsProvider != null) return;

    _notificationMealsProvider = context.read<DailyMealsProvider>()
      ..addListener(_onBehavioralNotificationStateChanged);
    _notificationMealTypesProvider = context.read<MealTypesProvider>()
      ..addListener(_onBehavioralNotificationStateChanged);
    _notificationStreakProvider = context.read<StreakProvider>()
      ..addListener(_onBehavioralNotificationStateChanged);
    _notificationLanguageController = context.read<LanguageController>()
      ..addListener(_onBehavioralNotificationLanguageChanged);

    _scheduleBehavioralNotificationSync(force: true);
  }

  void _setupStreakWidget() {
    final mealsProvider = _notificationMealsProvider;
    if (mealsProvider == null) return;

    StreakWidgetService.initialize();
    _lastObservedMealAdditionVersion = mealsProvider.mealAdditionVersion;
    _streakWidgetOpenSubscription ??=
        StreakWidgetService.openStreakRequests.listen((_) {
      unawaited(_openStreakScreenFromWidget());
    });

    unawaited(
      mealsProvider.ready.then((_) {
        if (mounted) {
          _scheduleStreakWidgetSync(force: true);
        }
      }),
    );
    unawaited(
      StreakWidgetService.consumeInitialOpenRequest().then((shouldOpen) {
        if (shouldOpen && mounted) {
          unawaited(_openStreakScreenFromWidget());
        }
      }),
    );
  }

  void _scheduleStreakWidgetSync({bool force = false}) {
    if (!mounted || _notificationMealsProvider == null) return;
    if (force) {
      _lastStreakWidgetSnapshotSignature = null;
    }
    _streakWidgetSyncDebounce?.cancel();
    _streakWidgetSyncDebounce = Timer(
      const Duration(milliseconds: 180),
      _syncStreakWidget,
    );
  }

  Future<void> _syncStreakWidget() async {
    final mealsProvider = _notificationMealsProvider;
    final streakProvider = _notificationStreakProvider;
    if (mealsProvider == null || streakProvider == null) return;

    await mealsProvider.ready;
    if (!mounted) return;

    final now = DateTime.now();
    final nutrition = mealsProvider.getNutritionSnapshotForDate(now);
    final calories = (nutrition['calories'] as num?)?.round() ?? 0;
    final calorieGoal = (nutrition['calorieGoal'] as num?)?.round() ??
        mealsProvider.caloriesGoal;
    final streak = effectiveRegistrationStreak(
      streakProvider,
      mealsProvider,
    );
    final dateKey = _notificationDateKey(now);
    final signature = '$dateKey:$calories:$calorieGoal:$streak';
    if (_lastStreakWidgetSnapshotSignature == signature) return;
    _lastStreakWidgetSnapshotSignature = signature;

    await StreakWidgetService.update(
      StreakWidgetSnapshot(
        calories: calories,
        calorieGoal: calorieGoal,
        streak: streak,
        date: now,
      ),
    );
  }

  void _observeFirstStreakDay() {
    final mealsProvider = _notificationMealsProvider;
    if (mealsProvider == null) return;

    final version = mealsProvider.mealAdditionVersion;
    final previousVersion = _lastObservedMealAdditionVersion;
    _lastObservedMealAdditionVersion = version;
    final now = DateTime.now();
    if (!shouldOfferStreakWidgetIntro(
      previousMealAdditionVersion: previousVersion,
      mealAdditionVersion: version,
      lastMealAdditionDate: mealsProvider.lastMealAdditionDate,
      now: now,
      localRegistrationStreak: mealsProvider.getCurrentRegistrationStreak(),
    )) {
      return;
    }

    _streakWidgetIntroPending = true;
    final authService = context.read<AuthService>();
    if (authService.isAuthenticated) {
      _waitingForStreakCheckInBeforeWidgetIntro = true;
      _streakWidgetIntroFallbackTimer?.cancel();
      _streakWidgetIntroFallbackTimer = Timer(const Duration(seconds: 8), () {
        _waitingForStreakCheckInBeforeWidgetIntro = false;
        _scheduleStreakExperienceDrain();
      });
      return;
    }
    _scheduleStreakExperienceDrain();
  }

  void _scheduleStreakExperienceDrain({
    Duration delay = Duration.zero,
  }) {
    if (!mounted) return;
    _streakExperienceRetryTimer?.cancel();
    _streakExperienceRetryTimer = Timer(delay, () {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_drainStreakExperienceQueue());
      });
    });
  }

  Future<void> _drainStreakExperienceQueue() async {
    if (!mounted || _streakExperienceQueueRunning) return;

    final streakProvider = context.read<StreakProvider>();
    final event = streakProvider.nextCelebrationEvent;
    final canShowWidget =
        _streakWidgetIntroPending && !_waitingForStreakCheckInBeforeWidgetIntro;
    if (event == null && !canShowWidget) return;

    final routeIsCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    if (_isBootstrappingAuthenticatedAppState ||
        _pendingGuestLocalData != null) {
      return;
    }
    if (!routeIsCurrent) {
      _scheduleStreakExperienceDrain(
        delay: const Duration(milliseconds: 600),
      );
      return;
    }

    _streakExperienceQueueRunning = true;
    try {
      while (true) {
        if (!mounted) return;
        final nextEvent = streakProvider.nextCelebrationEvent;
        if (nextEvent != null) {
          await Navigator.of(context).push<int>(
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => StreakCelebrationScreen(
                event: StreakCelebrationEvent(
                  eventId: nextEvent.id,
                  currentStreak: nextEvent.currentStreak,
                  effectiveDate: nextEvent.checkInDate,
                  missedDates: [
                    if (nextEvent.protectedMissedDate != null)
                      nextEvent.protectedMissedDate!,
                  ],
                  freezeRecovered: nextEvent.freezeRecovered,
                  freezesAvailable: nextEvent.freezesAfter,
                ),
              ),
            ),
          );
          if (!mounted) return;
          await streakProvider.completeCelebration(nextEvent.id);
          continue;
        }

        if (_streakWidgetIntroPending &&
            !_waitingForStreakCheckInBeforeWidgetIntro) {
          _streakWidgetIntroPending = false;
          await _maybeShowStreakWidgetIntro();
        }
        break;
      }
    } finally {
      _streakExperienceQueueRunning = false;
    }
  }

  Future<void> _performStreakCheckInAfterDateSync(
    StreakProvider streakProvider,
    DateTime syncedDate,
  ) async {
    final now = DateTime.now();
    final todayOrdinal = DateTime.utc(now.year, now.month, now.day);
    final syncedOrdinal = DateTime.utc(
      syncedDate.year,
      syncedDate.month,
      syncedDate.day,
    );
    final daysAgo = todayOrdinal.difference(syncedOrdinal).inDays;

    // Hoje é o fluxo normal. Ontem também é aceito para uploads offline que
    // começaram antes da meia-noite. Datas mais antigas continuam sendo
    // apenas histórico e não avançam retroativamente a sequência.
    if (daysAgo < 0 || daysAgo > 1) return;

    try {
      await streakProvider.performCheckIn(localDate: syncedDate);
    } finally {
      if (daysAgo == 0) {
        _waitingForStreakCheckInBeforeWidgetIntro = false;
        _streakWidgetIntroFallbackTimer?.cancel();
      }
      _scheduleStreakExperienceDrain();
    }
  }

  Future<void> _refreshStreakAfterResume() async {
    if (!mounted) return;
    final authService = context.read<AuthService>();
    if (!authService.isAuthenticated) return;
    final streakProvider = context.read<StreakProvider>();
    final mealsProvider = context.read<DailyMealsProvider>();
    await streakProvider.refresh();
    await mealsProvider.ready;
    if (!mounted) return;
    await _recoverRecentStreakCheckIns(streakProvider, mealsProvider);
  }

  Future<void> _recoverRecentStreakCheckIns(
    StreakProvider streakProvider,
    DailyMealsProvider mealsProvider,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final recentDates = <DateTime>[
      DateTime(today.year, today.month, today.day - 1),
      today,
    ];

    for (final date in recentDates) {
      if (!mounted) return;
      if (mealsProvider.hasMealsOn(date)) {
        await _performStreakCheckInAfterDateSync(streakProvider, date);
      }
    }
    _scheduleStreakExperienceDrain();
  }

  Future<void> _promptForRatingWhenStreakExperienceIsIdle() async {
    if (!mounted) return;
    final streakProvider = context.read<StreakProvider>();
    if (_streakExperienceQueueRunning ||
        _streakWidgetIntroPending ||
        streakProvider.hasPendingCelebration ||
        _isBootstrappingAuthenticatedAppState ||
        _pendingGuestLocalData != null) {
      return;
    }
    await RateAppService.promptForRating(context);
  }

  Future<void> _maybeShowStreakWidgetIntro() async {
    if (_streakWidgetIntroCheckRunning || _streakWidgetIntroVisible) return;
    _streakWidgetIntroCheckRunning = true;
    try {
      if (!await StreakWidgetService.isSupported() ||
          await StreakWidgetService.isAdded()) {
        return;
      }

      if (!mounted) return;
      final authService = context.read<AuthService>();
      final scope = authService.currentUser?.id.toString() ?? 'guest';
      if (await StreakWidgetIntroStore.wasSeen(scope)) return;

      // Grava antes da navegação para que notificações de novas refeições não
      // empilhem o mesmo onboarding enquanto ele estiver aberto.
      await StreakWidgetIntroStore.markSeen(scope);
      if (!mounted) return;

      final mealsProvider = context.read<DailyMealsProvider>();
      final streakProvider = context.read<StreakProvider>();
      final now = DateTime.now();
      final nutrition = mealsProvider.getNutritionSnapshotForDate(now);
      _streakWidgetIntroVisible = true;
      await Navigator.of(context).push<StreakWidgetPinResult>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => StreakWidgetOnboardingScreen(
            calories: (nutrition['calories'] as num?)?.round() ?? 0,
            calorieGoal: (nutrition['calorieGoal'] as num?)?.round() ??
                mealsProvider.caloriesGoal,
            streak: effectiveRegistrationStreak(
              streakProvider,
              mealsProvider,
            ),
          ),
        ),
      );
      _scheduleStreakWidgetSync(force: true);
    } finally {
      _streakWidgetIntroVisible = false;
      _streakWidgetIntroCheckRunning = false;
    }
  }

  Future<void> _openStreakScreenFromWidget() async {
    if (!mounted || _streakScreenOpeningFromWidget) return;
    _streakScreenOpeningFromWidget = true;
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => const StreakScreen()),
      );
    } finally {
      _streakScreenOpeningFromWidget = false;
    }
  }

  void _onBehavioralNotificationStateChanged() {
    _scheduleBehavioralNotificationSync();
    _scheduleStreakWidgetSync();
    _observeFirstStreakDay();
    _scheduleStreakExperienceDrain();
  }

  void _onBehavioralNotificationLanguageChanged() {
    _scheduleBehavioralNotificationSync(force: true);
  }

  void _scheduleBehavioralNotificationSync({
    bool force = false,
    bool refreshTimeZone = false,
  }) {
    if (!mounted) return;
    _forceBehavioralNotificationSync |= force;
    _refreshBehavioralNotificationTimeZone |= refreshTimeZone;
    _behavioralNotificationDebounce?.cancel();
    _behavioralNotificationDebounce = Timer(
      const Duration(milliseconds: 350),
      _drainBehavioralNotificationSync,
    );
  }

  Future<void> _drainBehavioralNotificationSync() async {
    if (_behavioralNotificationSyncRunning) {
      _behavioralNotificationSyncRequested = true;
      return;
    }

    _behavioralNotificationSyncRunning = true;
    try {
      do {
        _behavioralNotificationSyncRequested = false;
        final force = _forceBehavioralNotificationSync;
        final refreshTimeZone = _refreshBehavioralNotificationTimeZone;
        _forceBehavioralNotificationSync = false;
        _refreshBehavioralNotificationTimeZone = false;
        await _syncBehavioralNotifications(
          force: force,
          refreshTimeZone: refreshTimeZone,
        );
      } while (_behavioralNotificationSyncRequested && mounted);
    } finally {
      _behavioralNotificationSyncRunning = false;
    }
  }

  Future<void> _syncBehavioralNotifications({
    required bool force,
    required bool refreshTimeZone,
  }) async {
    final sessionRevision = _behavioralNotificationSessionRevision;
    final mealsProvider = _notificationMealsProvider;
    final mealTypesProvider = _notificationMealTypesProvider;
    final streakProvider = _notificationStreakProvider;
    if (mealsProvider == null ||
        mealTypesProvider == null ||
        streakProvider == null) {
      return;
    }

    await Future.wait([
      mealsProvider.ready,
      mealTypesProvider.ensureLoaded(),
    ]);
    if (!mounted || sessionRevision != _behavioralNotificationSessionRevision) {
      return;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final entries = <BehavioralMealEntry>[];
    final daysWithMeals = <String>{};
    for (var daysAgo = 0;
        daysAgo <= BehavioralReminderPlanner.habitLookbackDays;
        daysAgo++) {
      final day = today.subtract(Duration(days: daysAgo));
      if (mealsProvider.hasMealsOn(day)) {
        daysWithMeals.add(_notificationDateKey(day));
      }
      for (final meal in mealsProvider.getMealsForDate(day)) {
        if (meal.foods.isEmpty) continue;
        entries.add(
          BehavioralMealEntry(
            recordedAt: DateTime(
              day.year,
              day.month,
              day.day,
              meal.dateTime.hour,
              meal.dateTime.minute,
              meal.dateTime.second,
            ),
            mealType: meal.type.name,
          ),
        );
      }
    }

    final hasMealsToday = mealsProvider.hasMealsOn(today);
    final localStreak = mealsProvider.getCurrentRegistrationStreak();
    final backendStreak = streakProvider.registrationStreak;
    final currentStreak =
        localStreak > backendStreak ? localStreak : backendStreak;
    var registrationLastDate = streakProvider.streak?.registrationLastDate;
    if (hasMealsToday) {
      registrationLastDate = today;
    } else if (registrationLastDate == null && currentStreak > 0) {
      registrationLastDate = today.subtract(const Duration(days: 1));
    }

    final reminderContext = BehavioralReminderContext(
      now: now,
      mealSlots: [
        for (final mealType in mealTypesProvider.mealTypes)
          BehavioralMealSlot(
            id: mealType.id,
            name: _localizedNotificationMealName(mealType),
            order: mealType.order,
            configuredTime: mealType.reminderTime,
          ),
      ],
      mealEntries: entries,
      daysWithMeals: daysWithMeals,
      hasMealsToday: hasMealsToday,
      currentRegistrationStreak: currentStreak,
      registrationLastDate: registrationLastDate,
      isStreakProtected: streakProvider.isFreezeActive,
    );
    _scheduleBehavioralDayRollover(now);

    try {
      if (sessionRevision != _behavioralNotificationSessionRevision) {
        return;
      }
      await NotificationService().syncBehavioralReminders(
        reminderContext,
        force: force,
        refreshTimeZone: refreshTimeZone,
      );
    } catch (e) {
      debugPrint('[MainNavigation] Erro ao reconciliar lembretes: $e');
    }
  }

  void _scheduleBehavioralDayRollover(DateTime now) {
    _behavioralDayRolloverTimer?.cancel();
    final nextDay = DateTime(now.year, now.month, now.day + 1, 0, 1);
    final delay = nextDay.difference(now);
    if (delay <= Duration.zero) return;
    _behavioralDayRolloverTimer = Timer(delay, () {
      _scheduleBehavioralNotificationSync(
        force: true,
        refreshTimeZone: true,
      );
      _scheduleStreakWidgetSync(force: true);
    });
  }

  String _localizedNotificationMealName(MealTypeConfig mealType) {
    return localizedMealTypeName(context.tr, mealType);
  }

  String _notificationDateKey(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _behavioralNotificationDebounce?.cancel();
    _behavioralDayRolloverTimer?.cancel();
    _streakWidgetSyncDebounce?.cancel();
    _streakExperienceRetryTimer?.cancel();
    _streakWidgetIntroFallbackTimer?.cancel();
    _streakWidgetOpenSubscription?.cancel();
    _notificationMealsProvider
        ?.removeListener(_onBehavioralNotificationStateChanged);
    _notificationMealTypesProvider
        ?.removeListener(_onBehavioralNotificationStateChanged);
    _notificationStreakProvider
        ?.removeListener(_onBehavioralNotificationStateChanged);
    _notificationLanguageController
        ?.removeListener(_onBehavioralNotificationLanguageChanged);
    if (navigationController.tabChangeCallback == _onItemTapped) {
      navigationController.tabChangeCallback = null;
    }
    super.dispose();
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
        title: Text(dialogContext.tr.translate('developer_mode')),
        content: Text(
          dialogContext.tr
              .translate('developer_auto_login_prompt')
              .replaceAll('{email}', _devAutoLoginEmail),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.tr.translate('no')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.tr.translate('login')),
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
                ? context.tr
                    .translate('developer_auto_login_success')
                    .replaceAll('{email}', _devAutoLoginEmail)
                : context.tr.translate('developer_auto_login_failed'),
          ),
          backgroundColor: ok ? AppTheme.successColor : AppTheme.errorColor,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr.translate('developer_auto_login_error')),
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
        _behavioralNotificationSessionRevision++;
        unawaited(
          NotificationService().clearBehavioralReminders(forgetContext: true),
        );
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
      _initialNutritionChatMessagesByDate =
          const <String, List<Map<String, dynamic>>>{};
      print('[🔄 AUTH_DATA] ========== LOGOUT DETECTADO ==========');
      print('[🔄 AUTH_DATA] Limpando auth de todos os providers...');

      dailyMealsProvider.clearAuth();
      dailyMealsProvider.onDateSynced = null;
      print('[🔄 AUTH_DATA] ✅ DailyMealsProvider limpo');

      streakProvider.clearAuth();
      _streakWidgetIntroPending = false;
      _waitingForStreakCheckInBeforeWidgetIntro = false;
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

      // Nao deixe alertas personalizados da conta anterior sobreviverem ao
      // logout. Novos registros como convidado voltam a gerar um plano novo.
      _behavioralNotificationSessionRevision++;
      _behavioralNotificationDebounce?.cancel();
      unawaited(
        NotificationService().clearBehavioralReminders(forgetContext: true),
      );

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
    if (allowLocalAutoSync) {
      DailyChatSyncService.instance.setAuth(token, userId);
      _logChatBootPerf('daily_chat_sync_auth_ready_early', {
        'userId': userId,
      });
    }
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
    // O backend só aceita check-in quando há alimento persistido no resumo,
    // então disparar logo após o sync garante a sincronização das duas pontas.
    dailyMealsProvider.onDateSynced = (syncedDate) {
      return _performStreakCheckInAfterDateSync(
        streakProvider,
        syncedDate,
      );
    };

    // Recupera a janela sync-concluído/check-in-pendente após um encerramento
    // inesperado do app. O endpoint é idempotente por usuário e data.
    unawaited(mealsAuthFuture.then((_) async {
      if (!mounted) return;
      await _recoverRecentStreakCheckIns(
        streakProvider,
        dailyMealsProvider,
      );
    }));

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

    // Carregar app-state antes de recriar o diário. As refeições e dietas
    // continuam aquecendo em background para não travar o chat inicial.
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
    _observeAuthenticatedProviderWarmup(
      mealsAuthFuture: mealsAuthFuture,
      dietPlanAuthFuture: dietPlanAuthFuture,
    );

    _logChatBootPerf('finish_authenticated_setup_app_state_wait_start');
    await _loadAppStateFromServer(
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
    );
    _logChatBootPerf('finish_authenticated_setup_app_state_wait_done');

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
    _scheduleStreakExperienceDrain();
    _logChatBootPerf('chat_screen_recreate_set_state_done');
    print('[🔄 AUTH_DATA] ✅ NutritionAssistantScreen será recriado');
  }

  void _observeAuthenticatedProviderWarmup({
    required Future<void> mealsAuthFuture,
    required Future<void> dietPlanAuthFuture,
  }) {
    Future<void> observe(String name, Future<void> future) async {
      final stopwatch = Stopwatch()..start();
      try {
        await future;
        _logChatBootPerf('auth_provider_warmup_done', {
          'provider': name,
          'elapsedMs': stopwatch.elapsedMilliseconds,
        });
      } catch (e) {
        print('[MainNavigation] Erro no warmup autenticado de $name: $e');
        _logChatBootPerf('auth_provider_warmup_error', {
          'provider': name,
          'elapsedMs': stopwatch.elapsedMilliseconds,
          'error': e.toString(),
        });
      }
    }

    unawaited(Future.wait([
      observe('daily_meals', mealsAuthFuture),
      observe('diet_plan', dietPlanAuthFuture),
    ]).then((_) {
      _logChatBootPerf('auth_provider_warmup_all_done');
    }));
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

  List<Map<String, dynamic>>? _initialDailyChatMessagesForCurrentDate() {
    final selectedDate = context.read<DailyMealsProvider>().selectedDate;
    final dateKey = UserAppStateService.formatDateKey(selectedDate);
    return _initialNutritionChatMessagesByDate[dateKey];
  }

  Future<void> _prepareInitialDailyChatMessages({
    required String scope,
    required String dateKey,
  }) async {
    final storageKey = 'nutrition_chat_${scope}_$dateKey';
    final rawDay = await StorageService().getData(storageKey);
    final messages = _normalizeInitialDailyChatMessages(rawDay);
    _initialNutritionChatMessagesByDate = {
      if (messages != null) dateKey: messages,
    };
  }

  List<Map<String, dynamic>>? _normalizeInitialDailyChatMessages(
    Map<String, dynamic>? rawDay,
  ) {
    if (rawDay == null) {
      return null;
    }
    if (rawDay['deleted'] == true) {
      return null;
    }

    final messages = rawDay['messages'];
    if (messages is! List || messages.isEmpty) {
      return null;
    }

    final normalized = messages
        .whereType<Map>()
        .map((message) => _normalizeInitialDailyChatMessage(message))
        .where((message) => !_isRestoredAssistantPlaceholder(message))
        .toList();
    return normalized.isEmpty ? null : normalized;
  }

  Map<String, dynamic> _normalizeInitialDailyChatMessage(Map message) {
    final normalized = <String, dynamic>{
      'isUser': message['isUser'] == true,
      'timestamp': _parseInitialDailyChatTimestamp(message['timestamp']) ??
          DateTime.now(),
    };

    if (message.containsKey('message')) {
      normalized['message'] = message['message'];
    }
    if (message['hasImage'] == true) {
      normalized['hasImage'] = true;
      if (message['imageMimeType'] != null) {
        normalized['imageMimeType'] = message['imageMimeType'];
      }
    }
    if (message['hadImage'] == true) {
      normalized['hadImage'] = true;
    }
    if (message['notifier'] != null) {
      normalized['notifier'] = message['notifier'];
    }
    // Historico restaurado nunca deve voltar em estado de streaming. Quando
    // uma geracao antiga ficou pendurada, mostrar isso como progresso trava a
    // percepcao da tela inicial.
    normalized['streaming'] = false;

    return normalized;
  }

  bool _isRestoredAssistantPlaceholder(Map<String, dynamic> message) {
    if (message['isUser'] == true) {
      return false;
    }

    final text = message['message'];
    final hasText = text is String && text.trim().isNotEmpty;
    final hasImage = message['hasImage'] == true || message['hadImage'] == true;
    return !hasText && !hasImage;
  }

  DateTime? _parseInitialDailyChatTimestamp(dynamic value) {
    if (value is DateTime) return value;
    if (value is! String || value.trim().isEmpty) return null;
    return DateTime.tryParse(value.trim());
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
    _initialNutritionChatMessagesByDate =
        const <String, List<Map<String, dynamic>>>{};
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
      await _prepareInitialDailyChatMessages(
        scope: 'user_$userId',
        dateKey: UserAppStateService.formatDateKey(selectedDate),
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
      _scheduleStreakExperienceDrain();
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
      _scheduleStreakExperienceDrain();
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
    if (index == 0) {
      final shouldResetDiary =
          _currentMode != 'diary' || _currentFreeChatId != null;
      if (_selectedIndex == 0 && !shouldResetDiary) {
        return;
      }
      setState(() {
        _selectedIndex = 0;
        if (shouldResetDiary) {
          _currentMode = 'diary';
          _currentFreeChatId = null;
          _nutritionAssistantKey = UniqueKey();
        }
      });
      navigationController.updateSelectedIndex(0);
      return;
    }

    if (_selectedIndex == index) {
      return;
    }

    setState(() {
      _selectedIndex = index;
    });
    navigationController.updateSelectedIndex(index);
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
  static const double _wideSidePanelWidth = 252;

  bool get _isWideLayout =>
      MediaQuery.sizeOf(context).width >= _wideLayoutBreakpoint;

  void _openSocialOverview() {
    setState(() {
      _selectedIndex = 3;
    });
    navigationController.updateSelectedIndex(3);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      socialTabController.changeTab(0);
    });
  }

  void _openUnifiedSearch() {
    _closeDrawerIfOpen();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UnifiedSearchScreen(
          onOpenFreeChat: (id, title) => _openFreeChatFromSearch(id, title),
          onOpenDiaryDate: (date) => _openDiaryForDate(date),
        ),
      ),
    );
  }

  void _startNewFreeChat() {
    if (_isWideLayout) {
      _openFreeChatInPlace();
      return;
    }
    _closeDrawerIfOpen();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const FreeChatScreen()),
    );
  }

  void _openFreeChatInPlace({String? chatId}) {
    final resolvedId = chatId ??
        context.read<FreeChatProvider>().createConversation(reuseEmpty: true);
    final alreadyOpen = _selectedIndex == 0 &&
        _currentMode == 'free_chat' &&
        _currentFreeChatId == resolvedId;
    if (alreadyOpen) {
      return;
    }

    setState(() {
      _selectedIndex = 0;
      _currentMode = 'free_chat';
      _currentFreeChatId = resolvedId;
      _nutritionAssistantKey = UniqueKey();
    });
    navigationController.updateSelectedIndex(0);
  }

  void _openFreeChat(String chatId, String title) {
    if (_isWideLayout) {
      _openFreeChatInPlace(chatId: chatId);
      return;
    }
    _closeDrawerIfOpen();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => FreeChatScreen(freeChatId: chatId)),
    );
  }

  void _openFreeChatFromSearch(String chatId, String title) {
    if (_isWideLayout) {
      _openFreeChatInPlace(chatId: chatId);
      return;
    }
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
    navigationController.updateSelectedIndex(0);
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
                navigationController.updateSelectedIndex(0);
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
    return Stack(
      children: [
        Positioned.fill(
          child: Scaffold(
            key: _scaffoldKey,
            drawer: _buildDrawer(isDarkMode),
            body: AppDebugLogOverlay(
              child: _buildTabStack(onOpenDrawer: _openDrawer),
            ),
            bottomNavigationBar: _buildNavigationBar(isDarkMode),
          ),
        ),
        _buildGuestLocalDataPrompt(isWide: false),
      ],
    );
  }

  Widget _buildGuestLocalDataPrompt({required bool isWide}) {
    final snapshot = _pendingGuestLocalData;
    if (snapshot == null || !snapshot.hasData) {
      return const SizedBox.shrink();
    }

    return GuestLocalDataPrompt(
      kinds: snapshot.kinds,
      isResolving: _isResolvingGuestLocalData,
      isWide: isWide,
      onSave: _saveGuestLocalData,
      onDiscard: _discardGuestLocalData,
    );
  }

  /// Layout para tablets/desktop: painel lateral fixo (sem Drawer) e sem
  /// NavigationBar — os itens de navegação ficam no rodapé do painel.
  Widget _buildWideLayout(bool isDarkMode) {
    return Stack(
      children: [
        Positioned.fill(
          child: Scaffold(
            key: _scaffoldKey,
            body: Row(
              children: [
                SizedBox(
                  width: _wideSidePanelWidth,
                  child: Material(
                    color: isDarkMode
                        ? AppTheme.darkBackgroundColor
                        : AppTheme.backgroundColor,
                    child: _buildSidePanelBody(isDarkMode, showNavItems: true),
                  ),
                ),
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: isDarkMode ? Colors.white12 : Colors.black12,
                ),
                Expanded(
                  child: AppDebugLogOverlay(
                    child: _buildTabStack(onOpenDrawer: null),
                  ),
                ),
              ],
            ),
          ),
        ),
        _buildGuestLocalDataPrompt(isWide: true),
      ],
    );
  }

  /// Constrói as abas sob demanda e mantém as telas já abertas vivas.
  /// Isso evita que uma troca na NavigationBar reconstrua chat, dieta,
  /// diário, social e perfil no mesmo frame.
  Widget _buildTabStack({required VoidCallback? onOpenDrawer}) {
    final authService = context.watch<AuthService>();
    final isInitialChatBootstrapping =
        _isInitialChatBootstrapPending(authService);
    final usesDrawer = onOpenDrawer != null;

    return IndexedStack(
      index: _selectedIndex,
      children: List.generate(5, (index) {
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
          initialMessages:
              _currentMode == 'diary' && !isInitialChatBootstrapping
                  ? _initialDailyChatMessagesForCurrentDate()
                  : null,
          onOpenDrawer: onOpenDrawer,
          onOpenMyDiet: () => _onItemTapped(2),
        );
      case 1:
        return const DailyMealsScreen(showBackButton: false);
      case 2:
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
      case 3:
        return SocialHubScreen(onOpenDrawer: onOpenDrawer);
      case 4:
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
      selectedIndex: _selectedIndex == 4 ? 3 : _selectedIndex,
      onDestinationSelected: (index) => _onItemTapped(index < 3 ? index : 4),
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
          icon: Icon(Icons.menu_book_outlined),
          selectedIcon: Icon(Icons.menu_book),
          label: context.tr.translate('diary'),
        ),
        NavigationDestination(
          icon: Icon(Icons.ramen_dining_outlined),
          selectedIcon: Icon(Icons.ramen_dining),
          label: context.tr.translate('my_diet'),
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
      child: _buildSidePanelBody(isDarkMode, showNavItems: false),
    );
  }

  /// Conteúdo compartilhado entre o Drawer (mobile) e o painel lateral fixo
  /// (tablet/desktop). No mobile a navegação fica na barra inferior, então
  /// os atalhos Início/Diário/Minha Dieta/Perfil não entram no drawer.
  Widget _buildSidePanelBody(bool isDarkMode, {bool showNavItems = true}) {
    final authService = context.watch<AuthService>();
    final showDietBenchmark = canAccessDietBenchmark(authService.currentUser);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 6, 10),
            child: Row(
              children: [
                Text(
                  'Nutro',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: isDarkMode ? AppTheme.darkTextColor : Colors.black87,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    Icons.search,
                    size: 20,
                    color: isDarkMode
                        ? AppTheme.darkTextColor.withValues(alpha: 0.72)
                        : Colors.black54,
                  ),
                  onPressed: _openUnifiedSearch,
                  tooltip: context.tr.translate('search'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: _buildNewChatButton(isDarkMode),
          ),
          if (showDietBenchmark)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: _drawerBenchmarkTile(isDarkMode),
            ),
          if (showNavItems) _buildSidePanelNavItems(isDarkMode),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 16, 6),
            child: Text(
              context.tr.translate('recent'),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
                color:
                    isDarkMode ? AppTheme.darkMutedTextColor : Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Consumer<FreeChatProvider>(
              builder: (context, freeChatProvider, child) {
                final conversations = freeChatProvider.conversations;

                if (conversations.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(18, 4, 16, 8),
                    child: Text(
                      context.tr.translate('no_conversations'),
                      style: TextStyle(
                        color: isDarkMode
                            ? AppTheme.darkDisabledTextColor
                            : Colors.grey,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                  itemCount: conversations.length,
                  itemBuilder: (context, index) {
                    final chat = conversations[index];
                    final isSelected = _currentMode == 'free_chat' &&
                        _currentFreeChatId == chat.id;
                    final selectedBg = isDarkMode
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06);
                    return InkWell(
                      onTap: () => _openFreeChat(chat.id, chat.title),
                      onLongPress: () => _showDeleteConfirmation(
                          chat.id, chat.title, freeChatProvider),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? selectedBg : null,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _localizedConversationTitle(chat.title),
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

  Widget _buildNewChatButton(bool isDarkMode) {
    final foreground = isDarkMode ? AppTheme.darkTextColor : Colors.black87;

    return Material(
      color: isDarkMode ? AppTheme.darkCardColor : const Color(0xFFF5F5F5),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: _startNewFreeChat,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              Icon(
                Icons.edit_outlined,
                size: 18,
                color: foreground,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.tr.translate('new_conversation'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: foreground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Itens de navegação (Início, Diário, Minha Dieta e Perfil).
  Widget _buildSidePanelNavItems(bool isDarkMode) {
    final items = <_SidePanelNavItem>[
      _SidePanelNavItem(
        icon: Icons.home_outlined,
        activeIcon: Icons.home,
        label: context.tr.translate('home'),
      ),
      _SidePanelNavItem(
        icon: Icons.menu_book_outlined,
        activeIcon: Icons.menu_book,
        label: context.tr.translate('diary'),
      ),
      _SidePanelNavItem(
        icon: Icons.ramen_dining_outlined,
        activeIcon: Icons.ramen_dining,
        label: context.tr.translate('my_diet'),
      ),
      _SidePanelNavItem(
        icon: Icons.person_outline,
        activeIcon: Icons.person,
        label: context.tr.translate('profile'),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(items.length, (i) {
          final item = items[i];
          // O índice 3 do IndexedStack é a aba Social, que fica oculta na
          // navegação principal; o quarto item visível aponta para o índice 4.
          final tabIndex = i < 3 ? i : 4;
          final selected = tabIndex == 0
              ? _selectedIndex == 0 && _currentMode == 'diary'
              : _selectedIndex == tabIndex;
          final selectedBg = isDarkMode
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06);
          final itemColor = isDarkMode
              ? (selected ? Colors.white : AppTheme.darkTextColor)
              : Colors.black87;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: InkWell(
              onTap: () {
                _closeDrawerIfOpen();
                _onItemTapped(tabIndex);
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: selected ? selectedBg : null,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      selected ? item.activeIcon : item.icon,
                      size: 19,
                      color: itemColor,
                    ),
                    const SizedBox(width: 12),
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

  void _showDeleteConfirmation(
      String chatId, String title, FreeChatProvider provider) {
    final localizedTitle = _localizedConversationTitle(title);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr.translate('delete_conversation')),
        content: Text(context.tr
            .translate('delete_conversation_confirm')
            .replaceAll('{title}', localizedTitle)),
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
                  _currentMode = 'diary';
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

  String _localizedConversationTitle(String title) {
    if (title.trim() == 'Nova conversa') {
      return context.tr.translate('new_conversation');
    }
    return title;
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

  List<GuestLocalDataKind> get kinds {
    final items = <GuestLocalDataKind>[];
    if (goalSetup != null) {
      items.add(GuestLocalDataKind.goals);
    }
    if (dailyMeals.isNotEmpty) {
      items.add(GuestLocalDataKind.meals);
    }
    if (freeChatConversations.isNotEmpty || nutritionChatByDate.isNotEmpty) {
      items.add(GuestLocalDataKind.chats);
    }
    if (foodHistory != null) {
      items.add(GuestLocalDataKind.foods);
    }
    if (mealTypes.isNotEmpty || dietGenerationPreferences != null) {
      items.add(GuestLocalDataKind.preferences);
    }
    return items;
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
