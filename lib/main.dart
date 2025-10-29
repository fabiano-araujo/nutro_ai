import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
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

// Chave global para acessar o navigator de qualquer lugar do app
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Inicializa as plataformas WebView
  _initializeWebView();

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

// Função para inicializar o WebView baseado na plataforma
void _initializeWebView() {
  try {
    if (!kIsWeb) {
      if (Platform.isAndroid) {
        AndroidWebViewPlatform.registerWith();
      } else if (Platform.isIOS) {
        WebKitWebViewPlatform.registerWith();
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

      // Se o usuário estiver autenticado, buscar seus dados do servidor
      if (_authService.isAuthenticated) {
        print('Usuário autenticado, buscando dados do servidor...');
        // Buscar dados do usuário e atualizar status de assinatura
        final userData = await _authService.fetchUserDataAndUpdateStatus();

        if (userData != null) {
          print('Dados do usuário obtidos, atualizando créditos...');
          // Atualizar créditos usando o provider
          Future.delayed(Duration.zero, () {
            final creditProvider = Provider.of<CreditProvider>(
                navigatorKey.currentContext!,
                listen: false);
            creditProvider.updateCreditsFromServer(userData);
          });
        }
      }
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
        ChangeNotifierProvider(
          create: (_) => PurchaseService(),
        ),
        ChangeNotifierProvider(
          create: (_) => EssayProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => DailyMealsProvider(),
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
      ],
      child: Consumer2<ThemeProvider, LanguageController>(
        builder: (context, themeProvider, languageController, _) {
          return MaterialApp(
            title: 'Study Companion',
            navigatorKey: navigatorKey,
            theme: AppTheme.lightTheme.copyWith(
              navigationBarTheme: NavigationBarThemeData(
                indicatorColor: const Color(0xFF66BB9A).withOpacity(0.2),
                labelTextStyle: MaterialStateProperty.resolveWith((states) {
                  if (states.contains(MaterialState.selected)) {
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
                indicatorColor: const Color(0xFF66BB9A).withOpacity(0.2),
                labelTextStyle: MaterialStateProperty.resolveWith((states) {
                  if (states.contains(MaterialState.selected)) {
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
      default:
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
