import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/app_integrity_service.dart';
import 'services/diet_generation_background_service.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';
import 'screens/main_navigation.dart';
import 'screens/subscription_screen.dart';
import 'screens/essay_history_screen.dart';
import 'screens/new_essay_screen.dart';
import 'services/storage_service.dart';
import 'services/auth_service.dart';
import 'services/purchase_service.dart';
import 'services/ad_manager.dart';
import 'services/ad_settings_service.dart';
import 'i18n/app_localizations.dart';
import 'i18n/language_controller.dart';
import 'providers/credit_provider.dart';
import 'providers/essay_provider.dart';
import 'providers/daily_meals_provider.dart';
import 'providers/meal_types_provider.dart';
import 'providers/nutrition_goals_provider.dart';
import 'providers/food_history_provider.dart';
import 'providers/diet_plan_provider.dart';
import 'providers/free_chat_provider.dart';
import 'providers/streak_provider.dart';
import 'providers/friends_provider.dart';
import 'providers/challenges_provider.dart';
import 'providers/feed_provider.dart';
import 'providers/activity_tracking_provider.dart';

// Chave global para acessar o navigator de qualquer lugar do app
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Inicializa as plataformas WebView
  _initializeWebView();

  await _initializeFirebaseServices();

  // Inicializar serviços de anúncios apenas em plataformas não web
  if (!kIsWeb) {
    // Inicializar o SDK do Google Mobile Ads
    await MobileAds.instance.initialize();
    // Inicializar o gerenciador de anúncios
    await AdManager().initialize();

    // Incrementar contagem de abertura do app
    final adSettingsService = AdSettingsService();
    await adSettingsService.incrementAppOpenCount();
  }

  // Inicializar o StorageService e carregar as configurações antes de iniciar o app
  final storageService = StorageService();
  final settings = await storageService.getSettings();
  final savedTheme = settings['theme'] ?? 'system';

  print('Tema carregado ao iniciar o app: $savedTheme');

  runApp(MyApp(initialTheme: savedTheme));
}

Future<void> _initializeFirebaseServices() async {
  try {
    if (kIsWeb && !_hasWebFirebaseConfig) {
      print(
          '[Main] Firebase web config ausente; Firebase/App Check web nao foi inicializado.');
      return;
    }

    await Firebase.initializeApp(
      options: kIsWeb ? _webFirebaseOptions : null,
    );
    await AppIntegrityService.activateAppCheck();

    if (!kIsWeb) {
      await NotificationService().initialize();
      await DietGenerationBackgroundService.initialize();
    }

    print('[Main] Firebase initialized');
  } catch (e) {
    print('[Main] Error initializing Firebase: $e');
  }
}

const String _firebaseWebApiKey = String.fromEnvironment(
  'FIREBASE_WEB_API_KEY',
  defaultValue: '',
);
const String _firebaseWebAppId = String.fromEnvironment(
  'FIREBASE_WEB_APP_ID',
  defaultValue: '',
);
const String _firebaseWebMessagingSenderId = String.fromEnvironment(
  'FIREBASE_WEB_MESSAGING_SENDER_ID',
  defaultValue: '',
);
const String _firebaseWebProjectId = String.fromEnvironment(
  'FIREBASE_WEB_PROJECT_ID',
  defaultValue: '',
);
const String _firebaseWebAuthDomain = String.fromEnvironment(
  'FIREBASE_WEB_AUTH_DOMAIN',
  defaultValue: '',
);
const String _firebaseWebStorageBucket = String.fromEnvironment(
  'FIREBASE_WEB_STORAGE_BUCKET',
  defaultValue: '',
);

bool get _hasWebFirebaseConfig =>
    _firebaseWebApiKey.isNotEmpty &&
    _firebaseWebAppId.isNotEmpty &&
    _firebaseWebMessagingSenderId.isNotEmpty &&
    _firebaseWebProjectId.isNotEmpty;

FirebaseOptions get _webFirebaseOptions => FirebaseOptions(
      apiKey: _firebaseWebApiKey,
      appId: _firebaseWebAppId,
      messagingSenderId: _firebaseWebMessagingSenderId,
      projectId: _firebaseWebProjectId,
      authDomain:
          _firebaseWebAuthDomain.isEmpty ? null : _firebaseWebAuthDomain,
      storageBucket:
          _firebaseWebStorageBucket.isEmpty ? null : _firebaseWebStorageBucket,
    );

// Função para inicializar o WebView baseado na plataforma
void _initializeWebView() {
  try {
    if (!kIsWeb) {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          AndroidWebViewPlatform.registerWith();
          break;
        case TargetPlatform.iOS:
          WebKitWebViewPlatform.registerWith();
          break;
        default:
          break;
      }
    }
  } catch (e) {
    print('Erro ao inicializar WebView: $e');
  }
}

class MyApp extends StatefulWidget {
  final String initialTheme;

  const MyApp({Key? key, this.initialTheme = 'system'}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final StorageService _storageService = StorageService();
  late ThemeMode _themeMode;
  final LanguageController _languageController = LanguageController();
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _themeMode = _getThemeMode(widget.initialTheme);
    _loadSettings();
    _initializeAuth();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await _storageService.getSettings();
      final savedTheme = settings['theme'] ?? 'system';

      setState(() {
        _themeMode = _getThemeMode(savedTheme);
      });

      print('Tema carregado na inicialização: $savedTheme');
    } catch (e) {
      print('Erro ao carregar configurações: $e');
      setState(() {
        _themeMode = ThemeMode.system;
      });
    }
  }

  Future<void> _initializeAuth() async {
    try {
      await _authService.initialize();
    } catch (e) {
      print('Erro ao inicializar autenticação ou buscar dados: $e');
    }
  }

  ThemeMode _getThemeMode(String theme) {
    switch (theme) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(_themeMode, (ThemeMode mode) async {
            setState(() {
              _themeMode = mode;
            });
            await _storageService
                .saveSettings({'theme': _themeModeToString(mode)});
          }),
        ),
        ChangeNotifierProvider.value(
          value: _languageController,
        ),
        ChangeNotifierProvider(
          create: (_) => CreditProvider(),
        ),
        ChangeNotifierProvider.value(
          value: _authService,
        ),
        ChangeNotifierProxyProvider<AuthService, PurchaseService>(
          create: (_) => PurchaseService(),
          update: (_, authService, purchaseService) {
            final service = purchaseService ?? PurchaseService();
            service.bindAuthService(authService);
            return service;
          },
        ),
        ChangeNotifierProvider(
          create: (_) => EssayProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => DailyMealsProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => ActivityTrackingProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => MealTypesProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => NutritionGoalsProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => FoodHistoryProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => DietPlanProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => FreeChatProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => StreakProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => FriendsProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => ChallengesProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => FeedProvider(),
        ),
      ],
      child: Consumer2<ThemeProvider, LanguageController>(
        builder: (context, themeProvider, languageController, _) {
          return MaterialApp(
            title: 'Nutro AI',
            navigatorKey: navigatorKey,
            theme: AppTheme.lightTheme.copyWith(
              navigationBarTheme: NavigationBarThemeData(
                indicatorColor: const Color(0xFF66BB9A).withValues(alpha: 0.2),
                labelTextStyle: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF66BB9A),
                    );
                  }
                  return null;
                }),
              ),
            ),
            darkTheme: AppTheme.darkTheme.copyWith(
              scaffoldBackgroundColor: AppTheme.darkBackgroundColor,
              cardColor: const Color(0xFF1E1D23),
              navigationBarTheme: NavigationBarThemeData(
                indicatorColor: const Color(0xFF66BB9A).withValues(alpha: 0.2),
                labelTextStyle: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF66BB9A),
                    );
                  }
                  return null;
                }),
              ),
            ),
            themeMode: themeProvider.themeMode,
            debugShowCheckedModeBanner: false,
            locale: languageController.currentLocale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            routes: {
              '/subscription': (context) => const SubscriptionScreen(),
              '/essay_history': (context) => const EssayHistoryScreen(),
              '/new_essay': (context) => const NewEssayScreen(),
            },
            home: MainNavigation(),
          );
        },
      ),
    );
  }

  String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode;
  final Function(ThemeMode) _onThemeChanged;

  ThemeProvider(this._themeMode, this._onThemeChanged);

  ThemeMode get themeMode => _themeMode;

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    _onThemeChanged(mode);
    notifyListeners();
  }
}
