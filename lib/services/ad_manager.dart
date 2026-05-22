import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/material.dart';
import 'dart:async';

class AdManager {
  static final AdManager _instance = AdManager._internal();
  bool _initialized = false;

  // Flag global de Premium. PurchaseService deve setar via setPremiumStatus().
  // Quando true, todos os anúncios são suprimidos (exceto rewarded opt-in que o usuário pode pedir).
  static bool _isPremium = false;
  static bool get isPremium => _isPremium;
  static void setPremiumStatus(bool premium) {
    _isPremium = premium;
    debugPrint('AdManager: premium status atualizado para $premium');
  }

  // Verifica se ads não-rewarded devem ser bloqueados (web ou usuário premium).
  static bool get adsBlocked => kIsWeb || _isPremium;

  factory AdManager() {
    return _instance;
  }

  AdManager._internal();

  Future<void> initialize() async {
    // Se estiver executando na web, não inicialize os anúncios
    if (kIsWeb) {
      debugPrint('AdManager: Pulando inicialização no ambiente web');
      return;
    }

    if (_initialized) {
      debugPrint('AdManager: SDK já foi inicializado anteriormente');
      return;
    }

    try {
      debugPrint('AdManager: Iniciando SDK do MobileAds');
      final initStatus = await MobileAds.instance.initialize();

      // Registrar status de cada adaptador de anúncio
      initStatus.adapterStatuses.forEach((key, status) {
        debugPrint(
            'AdManager: Adaptador $key - ${status.state.name}, ${status.description}');
      });

      _initialized = true;
      debugPrint('AdManager: SDK inicializado com sucesso');

      // Habilitar RequestConfiguration em modo debug
      if (kDebugMode) {
        final deviceId = await _getDeviceId();
        debugPrint('AdManager: ID do dispositivo para teste: $deviceId');

        await MobileAds.instance.updateRequestConfiguration(
          RequestConfiguration(
            testDeviceIds: [deviceId],
          ),
        );
        debugPrint('AdManager: Dispositivo configurado para teste');
      }
    } catch (e) {
      debugPrint('AdManager: Erro na inicialização do SDK: $e');
      _initialized = false;
    }
  }

  // Método para obter o ID do dispositivo para testes
  Future<String> _getDeviceId() async {
    try {
      // No Android, podemos usar a classe DeviceInfo para obter o ID do dispositivo
      // Este é um exemplo simples, você pode substituir por uma implementação real
      return '7B08F8CB482AF2B3B7B080FEBBBFC6D0'; // Este é um ID de teste genérico
    } catch (e) {
      debugPrint('AdManager: Erro ao obter ID do dispositivo: $e');
      return '';
    }
  }

  // ===== Slots por placement (Nutro AI) =====
  // Para usar IDs novos por placement em produção. Em debug usa sempre IDs de teste do Google.

  static const String _testNativeId = 'ca-app-pub-3940256099942544/2247696110';
  static const String _testInterstitialId =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _testRewardedId =
      'ca-app-pub-3940256099942544/5224354917';

  // Native genérico (legado / tools_screen)
  static String get nativeAdUnitId {
    if (kDebugMode) return _testNativeId;
    return 'ca-app-pub-6353302591459951/8299335029';
  }

  // Native específico para resultados de busca de alimentos
  static String get nativeSearchAdUnitId {
    if (kDebugMode) return _testNativeId;
    return 'ca-app-pub-6353302591459951/2844891422';
  }

  // Native específico para estado vazio da Minha Dieta
  static String get nativeDietEmptyAdUnitId {
    if (kDebugMode) return _testNativeId;
    return 'ca-app-pub-6353302591459951/8299335029';
  }

  // Intersticial genérico (legado / sair do AI)
  static String get interstitialAdUnitId {
    if (kDebugMode) return _testInterstitialId;
    return 'ca-app-pub-6353302591459951/6161319900';
  }

  // Intersticial específico após registrar refeição
  static String get interstitialMealDoneAdUnitId {
    if (kDebugMode) return _testInterstitialId;
    return 'ca-app-pub-6353302591459951/6161319900';
  }

  // Rewarded para créditos
  static String get rewardedAdUnitId {
    if (kDebugMode) return _testRewardedId;
    return 'ca-app-pub-6353302591459951/1723381446';
  }

  static String get appId {
    return 'ca-app-pub-6353302591459951~4220489218';
  }

  // Método para verificar disponibilidade de anúncios
  static bool get isAvailable {
    return !kIsWeb; // Anúncios não estão disponíveis na web
  }

  // Criar um anúncio nativo (aceita adUnitId customizado por placement)
  static Future<NativeAd?> createNativeAd({
    required Function(Ad) onAdLoaded,
    required Function(Ad, LoadAdError) onAdFailedToLoad,
    String? adUnitId,
  }) async {
    // Web ou usuário premium → sem anúncios nativos
    if (adsBlocked) {
      debugPrint(
          'AdManager: Anúncios nativos suprimidos (web=$kIsWeb premium=$_isPremium)');
      return null;
    }

    final nativeAd = NativeAd(
      adUnitId: adUnitId ?? nativeAdUnitId,
      factoryId:
          'customNativeAd', // Usa o factory id que registramos no MainActivity
      listener: NativeAdListener(
        onAdLoaded: onAdLoaded,
        onAdFailedToLoad: onAdFailedToLoad,
      ),
      request: const AdRequest(),
      // Opções personalizadas que serão passadas para a factory nativa
      customOptions: {
        "buttonColor":
            0xFF8C65D3, // Cor roxa para o botão CTA, mesmo usado no Credit Indicator
      },
    );

    try {
      await nativeAd.load();
      return nativeAd;
    } catch (e) {
      debugPrint('Erro ao carregar anúncio nativo: $e');
      return null;
    }
  }

  // Carregar anúncio intersticial (aceita adUnitId customizado por placement)
  static Future<InterstitialAd?> loadInterstitialAd({
    Function(InterstitialAd ad)? onAdLoaded,
    Function(LoadAdError error)? onAdFailedToLoad,
    Function(Ad ad)? onAdDismissed,
    Function(Ad ad, AdError error)? onAdFailedToShow,
    String? adUnitId,
  }) async {
    // Web ou usuário premium → sem intersticiais
    if (adsBlocked) {
      debugPrint(
          'AdManager: Anúncios intersticiais suprimidos (web=$kIsWeb premium=$_isPremium)');
      return null;
    }

    InterstitialAd? interstitialAd;

    try {
      await InterstitialAd.load(
        adUnitId: adUnitId ?? interstitialAdUnitId,
        request: const AdRequest(
          nonPersonalizedAds: false,
          keywords: ['nutrition', 'food', 'diet', 'health', 'fitness'],
        ),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            interstitialAd = ad;

            // Configurar callback para quando o anúncio for fechado
            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) {
                if (onAdDismissed != null) {
                  onAdDismissed(ad);
                }
                ad.dispose();
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                debugPrint('Falha ao mostrar anúncio: ${error.message}');
                if (onAdFailedToShow != null) {
                  onAdFailedToShow(ad, error);
                }
                ad.dispose();
              },
              onAdShowedFullScreenContent: (ad) {
                debugPrint('Anúncio intersticial exibido em tela cheia');
              },
              onAdImpression: (ad) {
                debugPrint('Impressão do anúncio intersticial registrada');
              },
            );

            // Garantir modo imersivo para o anúncio
            //ad.setImmersiveMode(true);

            debugPrint('Anúncio intersticial carregado com sucesso');
            if (onAdLoaded != null) {
              onAdLoaded(ad);
            }
          },
          onAdFailedToLoad: (error) {
            debugPrint(
                'Falha ao carregar anúncio intersticial: ${error.message}');
            if (onAdFailedToLoad != null) {
              onAdFailedToLoad(error);
            }
          },
        ),
      );

      return interstitialAd;
    } catch (e) {
      debugPrint('Erro ao solicitar carregamento do anúncio intersticial: $e');
      return null;
    }
  }

  // Carregar anúncio premiado
  static Future<RewardedAd?> loadRewardedAd({
    Function(RewardedAd ad)? onAdLoaded,
    Function(LoadAdError error)? onAdFailedToLoad,
    Function(Ad ad)? onAdDismissed,
    Function(Ad ad, AdError error)? onAdFailedToShow,
    Function(RewardItem reward)? onUserEarnedReward,
  }) async {
    // Se estiver na web, retorne null
    if (kIsWeb) {
      debugPrint('AdManager: Anúncios premiados não suportados na web');
      return null;
    }

    final completer = Completer<RewardedAd?>();
    RewardedAd? rewardedAd;

    try {
      debugPrint(
          'AdManager: Carregando anúncio premiado com ID: ${rewardedAdUnitId}');

      // Configurar dispositivos de teste
      if (kDebugMode) {
        // Em debug, configurar dispositivos de teste para evitar limitações
        await MobileAds.instance.updateRequestConfiguration(
          RequestConfiguration(
            testDeviceIds: [
              '7B08F8CB482AF2B3B7B080FEBBBFC6D0'
            ], // Use o ID exibido nos logs
          ),
        );
        debugPrint('AdManager: Configuração de teste aplicada');
      }

      // Usar um timeout para evitar esperar indefinidamente
      var timeoutOccurred = false;
      Timer(Duration(seconds: 30), () {
        if (!completer.isCompleted) {
          timeoutOccurred = true;
          debugPrint('AdManager: Timeout ao carregar anúncio premiado');
          completer.complete(null);
        }
      });

      RewardedAd.load(
        adUnitId: rewardedAdUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            if (timeoutOccurred) {
              ad.dispose();
              return;
            }

            rewardedAd = ad;
            debugPrint('AdManager: Anúncio premiado carregado com sucesso');

            // Configurar callback para quando o anúncio for fechado
            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) {
                debugPrint('AdManager: Anúncio premiado fechado pelo usuário');
                if (onAdDismissed != null) {
                  onAdDismissed(ad);
                }
                // Não faça dispose aqui, pois isso impede o callback de recompensa
                // ad.dispose();
              },
              onAdShowedFullScreenContent: (ad) {
                debugPrint('AdManager: Anúncio premiado exibido em tela cheia');
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                debugPrint(
                    'AdManager: Falha ao mostrar anúncio premiado: ${error.message}, código: ${error.code}');
                if (onAdFailedToShow != null) {
                  onAdFailedToShow(ad, error);
                }
                ad.dispose();
              },
              onAdImpression: (ad) {
                debugPrint(
                    'AdManager: Impressão do anúncio premiado registrada');
              },
            );

            // Garantir modo imersivo para o anúncio
            //ad.setImmersiveMode(true);

            if (onAdLoaded != null) {
              onAdLoaded(ad);
            }

            if (!completer.isCompleted) {
              completer.complete(ad);
            }
          },
          onAdFailedToLoad: (error) {
            debugPrint(
                'AdManager: Falha ao carregar anúncio premiado: ${error.message}, código: ${error.code}');
            if (onAdFailedToLoad != null) {
              onAdFailedToLoad(error);
            }

            if (!completer.isCompleted) {
              completer.complete(null);
            }
          },
        ),
      );

      return await completer.future;
    } catch (e) {
      debugPrint(
          'AdManager: Erro ao solicitar carregamento do anúncio premiado: $e');
      if (!completer.isCompleted) {
        completer.complete(null);
      }
      return null;
    }
  }

  // Método para descarte seguro de anúncios
  static void disposeAd(Ad? ad) {
    if (ad != null && !kIsWeb) {
      try {
        ad.dispose();
      } catch (e) {
        debugPrint('Erro ao descartar anúncio: $e');
      }
    }
  }

  // Adicionar uma função para exibir os anúncios corretamente em modo imersivo
  static Future<bool> showInterstitialAd(InterstitialAd ad) async {
    try {
      // Garantir modo imersivo antes de mostrar
      //ad.setImmersiveMode(true);

      final completer = Completer<bool>();
      ad.show().then((_) {
        completer.complete(true);
      }).catchError((error) {
        debugPrint('Erro ao mostrar anúncio intersticial: $error');
        completer.complete(false);
      });

      return await completer.future;
    } catch (e) {
      debugPrint('Exceção ao mostrar anúncio intersticial: $e');
      return false;
    }
  }

  static Future<bool> showRewardedAd(RewardedAd ad,
      {Function(RewardItem)? onUserEarnedReward}) async {
    try {
      // Garantir modo imersivo antes de mostrar
      //ad.setImmersiveMode(true);

      final completer = Completer<bool>();
      ad.show(onUserEarnedReward: (ad, reward) {
        if (onUserEarnedReward != null) {
          onUserEarnedReward(reward);
        }
        completer.complete(true);
      }).catchError((error) {
        debugPrint('Erro ao mostrar anúncio de recompensa: $error');
        completer.complete(false);
      });

      return await completer.future;
    } catch (e) {
      debugPrint('Exceção ao mostrar anúncio de recompensa: $e');
      return false;
    }
  }

  // ===== Intersticial após registrar refeição =====
  // A regra: só dispara após N refeições registradas e respeitando cooldown.
  // Pré-carrega na N-1 para que a exibição na N seja imediata.

  static int _mealsRegisteredCount = 0;
  static InterstitialAd? _mealDoneInterstitial;
  static bool _isLoadingMealDoneInterstitial = false;
  static DateTime? _lastMealInterstitialAt;

  static const int _mealsThreshold =
      3; // mostra a cada 3 refeições registradas
  static const Duration _mealInterstitialCooldown = Duration(minutes: 2);

  /// Chamado sempre que uma refeição é registrada. Conta + pré-carrega ad quando
  /// estiver próximo do threshold. NÃO mostra o ad — quem mostra é
  /// [maybeShowMealDoneInterstitial], chamado após o feedback de sucesso na UI.
  static void notifyMealRegistered() {
    if (adsBlocked) return;
    _mealsRegisteredCount++;
    // Pré-carrega 1 refeição antes do threshold para que a exibição seja imediata.
    if (_mealsRegisteredCount >= _mealsThreshold - 1 &&
        _mealDoneInterstitial == null &&
        !_isLoadingMealDoneInterstitial) {
      _preloadMealDoneInterstitial();
    }
  }

  static Future<void> _preloadMealDoneInterstitial() async {
    if (adsBlocked || _isLoadingMealDoneInterstitial) return;
    _isLoadingMealDoneInterstitial = true;
    final ad = await loadInterstitialAd(
      adUnitId: interstitialMealDoneAdUnitId,
      onAdDismissed: (_) {
        _mealDoneInterstitial = null;
      },
    );
    _mealDoneInterstitial = ad;
    _isLoadingMealDoneInterstitial = false;
  }

  /// Verifica se está na hora de mostrar o intersticial pós-refeição e, se
  /// estiver, mostra. Não bloqueia: retorna após disparar o show() (fire-and-
  /// forget). Idempotente — pode ser chamado em todo registro de refeição.
  static Future<void> maybeShowMealDoneInterstitial() async {
    if (adsBlocked) return;
    if (_mealsRegisteredCount < _mealsThreshold) return;

    // Cooldown — evita bombardear o usuário
    final now = DateTime.now();
    if (_lastMealInterstitialAt != null &&
        now.difference(_lastMealInterstitialAt!) < _mealInterstitialCooldown) {
      return;
    }

    final ad = _mealDoneInterstitial;
    if (ad == null) {
      // Ad ainda não está pronto — tenta carregar para a próxima oportunidade
      if (!_isLoadingMealDoneInterstitial) {
        unawaited(_preloadMealDoneInterstitial());
      }
      return;
    }

    _mealDoneInterstitial = null;
    _mealsRegisteredCount = 0;
    _lastMealInterstitialAt = now;

    try {
      await ad.show();
    } catch (e) {
      debugPrint('AdManager: falha ao mostrar intersticial meal-done: $e');
    }
  }
}
