import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/ad_manager.dart';
import '../services/ad_settings_service.dart';

class NativeAdWidget extends StatefulWidget {
  const NativeAdWidget({Key? key}) : super(key: key);

  @override
  _NativeAdWidgetState createState() => _NativeAdWidgetState();
}

class _NativeAdWidgetState extends State<NativeAdWidget> {
  NativeAd? _nativeAd;
  bool _isAdLoaded = false;
  bool _shouldShowAd = false;
  final AdSettingsService _adSettingsService = AdSettingsService();
  Timer? _adReloadTimer;

  @override
  void initState() {
    super.initState();
    _checkShouldShowAd();
  }

  @override
  void dispose() {
    _adReloadTimer?.cancel();
    AdManager.disposeAd(_nativeAd);
    super.dispose();
  }

  // Verifica se o anúncio deve ser exibido
  Future<void> _checkShouldShowAd() async {
    // Na web, nunca mostrar anúncios
    if (kIsWeb) {
      setState(() {
        _shouldShowAd = false;
      });
      return;
    }

    final shouldShow = await _adSettingsService.shouldShowNativeAd();

    if (shouldShow) {
      setState(() {
        _shouldShowAd = true;
      });
      _loadAd();
      _setupAdReloadTimer();
    }
  }

  // Configurar timer para recarregar o anúncio
  void _setupAdReloadTimer() {
    // Na web, não configurar timer
    if (kIsWeb) return;

    // Cancelar timer existente se houver
    _adReloadTimer?.cancel();

    // Criar um novo timer que verifica a cada 30 segundos
    // se deve recarregar o anúncio (para não esperar exatamente 1 minuto completo)
    _adReloadTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      final shouldReload = await _adSettingsService.shouldReloadAd();
      if (shouldReload) {
        _reloadAd();
      }
    });
  }

  // Recarregar o anúncio
  void _reloadAd() {
    // Na web, não fazer nada
    if (kIsWeb) return;

    if (mounted) {
      setState(() {
        _isAdLoaded = false;
      });

      AdManager.disposeAd(_nativeAd);
      _nativeAd = null;

      _loadAd();
    }
  }

  void _loadAd() async {
    // Na web, não carregar anúncios
    if (kIsWeb || !_shouldShowAd) return;

    AdManager.createNativeAd(
      onAdLoaded: (Ad ad) {
        if (mounted) {
          setState(() {
            _nativeAd = ad as NativeAd;
            _isAdLoaded = true;
          });

          // Salvar o timestamp da exibição do anúncio
          _adSettingsService.saveLastAdShownTime();
        }
      },
      onAdFailedToLoad: (Ad ad, LoadAdError error) {
        ad.dispose();
        debugPrint('Falha ao carregar anúncio nativo: $error');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Na web ou se não deve exibir o anúncio ou não está carregado
    if (kIsWeb || !_shouldShowAd || !_isAdLoaded || _nativeAd == null) {
      // Retornar um widget vazio para não ocupar espaço
      return const SizedBox.shrink();
    }

    // Widget customizado para NativeAd com layout personalizado
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(0),
      child: AdWidget(ad: _nativeAd!),
      constraints: BoxConstraints(
        minHeight:
            185, // Aumentamos o tamanho mínimo para acomodar o layout personalizado
        maxHeight: 185, // E o máximo também
      ),
    );
  }
}

// Para personalização avançada, utilize NativeAdView do google_mobile_ads (Android/iOS nativo)
// No Flutter, a personalização depende do template do AdMob configurado no painel do AdMob.
// Para layouts 100% customizados, é necessário usar plataformas nativas ou plugins de terceiros.
// O widget acima já suporta exibir imagem, logo, título, nome do anunciante e botão de ação se o template do AdMob estiver configurado para isso.
