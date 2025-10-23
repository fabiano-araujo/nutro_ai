import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/material.dart';
import 'dart:async';

class AdManager {
  static final AdManager _instance = AdManager._internal();
  bool _initialized = false;

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

  // ID do anúncio nativo
  static String get nativeAdUnitId {
    // ID de teste para desenvolvimento
    if (kDebugMode) {
      return 'ca-app-pub-3940256099942544/2247696110'; // ID de teste do Google
    }
    // ID real para produção
    return 'ca-app-pub-6353302591459951/8335045731';
  }

  // ID do anúncio intersticial
  static String get interstitialAdUnitId {
    // ID de teste para desenvolvimento
    if (kDebugMode) {
      return 'ca-app-pub-3940256099942544/1033173712'; // ID de teste do Google
    }
    // ID real para produção
    return 'ca-app-pub-6353302591459951/5148870966';
  }

  // ID do anúncio premiado
  static String get rewardedAdUnitId {
    // ID de teste para desenvolvimento
    if (kDebugMode) {
      return 'ca-app-pub-3940256099942544/5224354917'; // ID de teste do Google
    }
    // ID real para produção
    return 'ca-app-pub-6353302591459951/8253254879';
  }

  // ID do aplicativo no AdMob
  static String get appId {
    return 'ca-app-pub-6353302591459951~5409413771';
  }

  // Método para verificar disponibilidade de anúncios
  static bool get isAvailable {
    return !kIsWeb; // Anúncios não estão disponíveis na web
  }

  // Criar um anúncio nativo
  static Future<NativeAd?> createNativeAd({
    required Function(Ad) onAdLoaded,
    required Function(Ad, LoadAdError) onAdFailedToLoad,
  }) async {
    // Se estiver na web, retorne null
    if (kIsWeb) {
      debugPrint('AdManager: Anúncios nativos não suportados na web');
      return null;
    }

    final nativeAd = NativeAd(
      adUnitId: nativeAdUnitId,
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

  // Carregar anúncio intersticial
  static Future<InterstitialAd?> loadInterstitialAd({
    Function(InterstitialAd ad)? onAdLoaded,
    Function(LoadAdError error)? onAdFailedToLoad,
    Function(Ad ad)? onAdDismissed,
    Function(Ad ad, AdError error)? onAdFailedToShow,
  }) async {
    // Se estiver na web, retorne null
    if (kIsWeb) {
      debugPrint('AdManager: Anúncios intersticiais não suportados na web');
      return null;
    }

    InterstitialAd? interstitialAd;

    try {
      await InterstitialAd.load(
        adUnitId: interstitialAdUnitId,
        request: const AdRequest(
          nonPersonalizedAds: false,
          keywords: ['finance', 'money', 'budget'],
          contentUrl: 'https://flutter.dev',
          neighboringContentUrls: ['https://flutter.dev/widgets'],
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
}
