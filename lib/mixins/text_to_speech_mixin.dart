import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TtsState { playing, stopped, paused, continued }

class TtsEngineOption {
  final String id;
  final String label;
  final bool isAvailable;
  final bool isPiper;
  final String? packageName;

  const TtsEngineOption({
    required this.id,
    required this.label,
    required this.isAvailable,
    required this.isPiper,
    this.packageName,
  });
}

mixin TextToSpeechMixin<T extends StatefulWidget> on State<T> {
  static const String _systemEngineId = 'system_default';
  static const String _ttsEnginePreferenceKey = 'tts_engine_preference';
  static const Set<String> _knownPiperEnginePackages = {
    'io.onyx.tts',
    'org.woheller69.ttsengine',
  };

  final FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = false;
  bool _isInitialized = false;
  String? _currentLanguageCode;
  String? _currentVoice;
  String? _currentEngineId = _systemEngineId;
  String? _defaultEnginePackageName;
  TtsState _ttsState = TtsState.stopped;
  double _pitch = 1.0;
  double _rate = 0.5;
  double _volume = 1.0;
  List<Map<String, String>> _availableVoices = [];
  List<TtsEngineOption> _availableTtsEngines = [];
  Timer? _ttsInitTimer;
  Future<void>? _ttsInitFuture;

  // Getters para o estado de fala
  bool get isSpeaking => _isSpeaking;
  List<Map<String, String>> get availableVoices => _availableVoices;
  List<TtsEngineOption> get availableTtsEngines => _availableTtsEngines;
  String? get currentVoice => _currentVoice;
  String? get currentEngineId => _currentEngineId;
  double get pitch => _pitch;
  double get rate => _rate;
  double get volume => _volume;

  @override
  void initState() {
    super.initState();
    _scheduleDeferredTtsInit();
  }

  @override
  void dispose() {
    _ttsInitTimer?.cancel();
    if (_isInitialized) {
      try {
        stopSpeech();
        _flutterTts.stop();
      } catch (e) {
        print('Error during TTS disposal: $e');
      }
    }
    super.dispose();
  }

  void _scheduleDeferredTtsInit() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isInitialized || _ttsInitFuture != null) return;
      _ttsInitTimer = Timer(const Duration(milliseconds: 9000), () {
        if (!mounted || _isInitialized) return;
        unawaited(_startTtsInitNow('deferred_after_first_frame'));
      });
    });
  }

  Future<void> _startTtsInitNow(String reason) {
    if (_isInitialized) {
      return Future<void>.value();
    }
    _ttsInitTimer?.cancel();
    final existing = _ttsInitFuture;
    if (existing != null) {
      return existing;
    }

    final stopwatch = Stopwatch()..start();
    print('[TTS_PERF] init_start reason=$reason');
    final future = _initTts().whenComplete(() {
      print(
          '[TTS_PERF] init_done reason=$reason elapsedMs=${stopwatch.elapsedMilliseconds} initialized=$_isInitialized voices=${_availableVoices.length} engines=${_availableTtsEngines.length}');
    });
    _ttsInitFuture = future;
    return future;
  }

  // Verifica se a plataforma atual é suportada
  bool _isPlatformSupported() {
    if (kIsWeb) {
      // Web ainda tem problemas com TTS em alguns navegadores
      return false;
    }

    if (Platform.isAndroid ||
        Platform.isIOS ||
        Platform.isMacOS ||
        Platform.isWindows) {
      return true;
    }

    return false;
  }

  // Inicializa o TTS com as configurações básicas
  Future<void> _initTts() async {
    if (!_isPlatformSupported()) {
      print('TTS não é suportado nesta plataforma');
      return;
    }

    try {
      await _flutterTts.setSharedInstance(true);

      // Configurar listeners de eventos
      _flutterTts.setStartHandler(() {
        if (mounted) {
          setState(() {
            _isSpeaking = true;
            _ttsState = TtsState.playing;
          });
        }
      });

      _flutterTts.setCompletionHandler(() {
        if (mounted) {
          setState(() {
            _isSpeaking = false;
            _ttsState = TtsState.stopped;
          });
        }
      });

      _flutterTts.setCancelHandler(() {
        if (mounted) {
          setState(() {
            _isSpeaking = false;
            _ttsState = TtsState.stopped;
          });
        }
      });

      _flutterTts.setErrorHandler((error) {
        print('TTS Error: $error');
        if (mounted) {
          setState(() {
            _isSpeaking = false;
            _ttsState = TtsState.stopped;
          });
        }
      });

      await _loadTtsEngines();
      await _restoreSavedTtsEngine();
      await _applyVoiceParameters();

      // Definir o idioma com base no idioma regional do dispositivo
      final deviceLocale = WidgetsBinding.instance.platformDispatcher.locale;
      final deviceLanguageTag =
          '${deviceLocale.languageCode}-${deviceLocale.countryCode}';
      await _setLanguage(deviceLanguageTag, allowBeforeInitialized: true);

      // Carregar as vozes disponíveis
      await _loadVoices();

      // Selecionar uma voz mais realista
      await _selectBestVoice();

      _isInitialized = true;
    } catch (e) {
      print('Falha ao inicializar TTS: $e');
      _isInitialized = false;
    }
  }

  Future<void> _loadTtsEngines() async {
    _availableTtsEngines = [];

    if (!Platform.isAndroid) {
      _currentEngineId = _systemEngineId;
      _availableTtsEngines = const [
        TtsEngineOption(
          id: _systemEngineId,
          label: 'Sistema',
          isAvailable: true,
          isPiper: false,
        ),
      ];
      return;
    }

    try {
      final defaultEngine = await _flutterTts.getDefaultEngine;
      _defaultEnginePackageName = defaultEngine?.toString();

      final enginesResult = await _flutterTts.getEngines;
      final engineIds = <String>[];
      if (enginesResult is List) {
        for (final engine in enginesResult) {
          final engineId = engine?.toString();
          if (engineId != null && engineId.isNotEmpty) {
            engineIds.add(engineId);
          }
        }
      }

      _availableTtsEngines.add(
        TtsEngineOption(
          id: _systemEngineId,
          label: _isGoogleTtsEngine(_defaultEnginePackageName)
              ? 'Sistema / Google TTS'
              : 'Sistema',
          isAvailable: true,
          isPiper: false,
          packageName: _defaultEnginePackageName,
        ),
      );

      final piperEngines = engineIds.where(_looksLikePiperEngine).toList();
      if (piperEngines.isEmpty) {
        _availableTtsEngines.add(
          const TtsEngineOption(
            id: 'piper_unavailable',
            label: 'Piper TTS',
            isAvailable: false,
            isPiper: true,
          ),
        );
      } else {
        for (final engineId in piperEngines) {
          _availableTtsEngines.add(
            TtsEngineOption(
              id: engineId,
              label: 'Piper TTS',
              isAvailable: true,
              isPiper: true,
              packageName: engineId,
            ),
          );
        }
      }
    } catch (e) {
      print('Erro ao carregar mecanismos de TTS: $e');
      _availableTtsEngines = const [
        TtsEngineOption(
          id: _systemEngineId,
          label: 'Sistema',
          isAvailable: true,
          isPiper: false,
        ),
      ];
    }
  }

  Future<void> _restoreSavedTtsEngine() async {
    if (!Platform.isAndroid) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedEngineId =
          prefs.getString(_ttsEnginePreferenceKey) ?? _systemEngineId;
      final engine = _findAvailableEngine(savedEngineId);

      if (engine == null) {
        _currentEngineId = _systemEngineId;
        return;
      }

      await _applyTtsEngine(engine);
    } catch (e) {
      print('Erro ao restaurar mecanismo de TTS: $e');
      _currentEngineId = _systemEngineId;
    }
  }

  TtsEngineOption? _findAvailableEngine(String engineId) {
    for (final engine in _availableTtsEngines) {
      if (engine.id == engineId && engine.isAvailable) {
        return engine;
      }
    }
    return null;
  }

  Future<void> _applyTtsEngine(TtsEngineOption engine) async {
    if (!Platform.isAndroid) {
      _currentEngineId = _systemEngineId;
      return;
    }

    final enginePackageName =
        engine.id == _systemEngineId ? _defaultEnginePackageName : engine.id;
    if (enginePackageName == null || enginePackageName.isEmpty) {
      _currentEngineId = _systemEngineId;
      return;
    }

    await _flutterTts.setEngine(enginePackageName);
    _currentEngineId = engine.id;
  }

  Future<void> _applyVoiceParameters() async {
    await _flutterTts.setVolume(_volume);
    await _flutterTts.setPitch(_pitch);
    await _flutterTts.setSpeechRate(_rate);
  }

  bool _looksLikePiperEngine(String engineId) {
    final normalized = engineId.toLowerCase();
    return normalized.contains('piper') ||
        normalized.contains('sherpa') ||
        normalized.contains('onnx') ||
        _knownPiperEnginePackages.contains(normalized);
  }

  bool _isGoogleTtsEngine(String? engineId) {
    return engineId?.toLowerCase() == 'com.google.android.tts';
  }

  // Carrega as vozes disponíveis
  Future<void> _loadVoices() async {
    try {
      var voices = await _flutterTts.getVoices;
      if (voices is List) {
        _availableVoices = [];

        for (var voice in voices) {
          // Extrair informações da voz
          if (voice is Map) {
            var voiceMap = <String, String>{};

            if (voice['name'] != null)
              voiceMap['name'] = voice['name'].toString();
            if (voice['locale'] != null)
              voiceMap['locale'] = voice['locale'].toString();

            // Android inclui detalhes adicionais
            if (voice['quality'] != null)
              voiceMap['quality'] = voice['quality'].toString();
            if (voice['isNetworkConnectionRequired'] != null)
              voiceMap['isNetworkRequired'] =
                  voice['isNetworkConnectionRequired'].toString();

            _availableVoices.add(voiceMap);
          }
        }

        print('Vozes disponíveis: ${_availableVoices.length}');

        // Listar algumas vozes para debug
        if (_availableVoices.length > 0) {
          print('Amostra de vozes:');
          for (int i = 0; i < min(5, _availableVoices.length); i++) {
            print('Voz $i: ${_availableVoices[i]}');
          }
        }
      }
    } catch (e) {
      print('Erro ao carregar vozes: $e');
    }
  }

  // Seleciona a melhor voz disponível (mais realista)
  Future<void> _selectBestVoice() async {
    try {
      // Se não tivermos vozes disponíveis, não há o que fazer
      if (_availableVoices.isEmpty) return;

      // Obter o idioma regional do dispositivo
      final deviceLocale = WidgetsBinding.instance.platformDispatcher.locale;
      final deviceLanguageTag =
          '${deviceLocale.languageCode}_${deviceLocale.countryCode}'
              .toLowerCase();
      final deviceLanguageTagAlt =
          '${deviceLocale.languageCode}-${deviceLocale.countryCode}'
              .toLowerCase();

      print('Idioma do dispositivo: $deviceLanguageTag');

      // Primeiro, tentar encontrar vozes que correspondam exatamente ao idioma regional do dispositivo
      var exactMatchVoices = _availableVoices
          .where((voice) =>
              voice['locale'] != null &&
              (voice['locale']!.toLowerCase() == deviceLanguageTag ||
                  voice['locale']!.toLowerCase() == deviceLanguageTagAlt ||
                  voice['locale']!.toLowerCase().replaceAll('-', '_') ==
                      deviceLanguageTag))
          .toList();

      // Se não encontrar correspondência exata, usar vozes do mesmo idioma base
      var ptVoices = _availableVoices
          .where((voice) =>
              voice['locale'] != null &&
              voice['locale']!
                  .toLowerCase()
                  .startsWith(deviceLocale.languageCode))
          .toList();

      // Priorizar correspondência exata, depois idioma base, depois todas as vozes
      var candidateVoices = exactMatchVoices.isNotEmpty
          ? exactMatchVoices
          : (ptVoices.isNotEmpty ? ptVoices : _availableVoices);

      // No Android, procurar vozes de alta qualidade
      if (Platform.isAndroid) {
        // Procurar por vozes de melhor qualidade
        var highQualityVoices = candidateVoices
            .where((voice) =>
                voice['quality'] != null &&
                (voice['quality'] == 'high' ||
                    voice['quality'] ==
                        '400' || // Alguns dispositivos usam números
                    voice['quality'] == '500'))
            .toList();

        if (highQualityVoices.isNotEmpty) {
          candidateVoices = highQualityVoices;
        }

        // Procurar por vozes neurais ou de rede (geralmente mais realistas)
        var neuralVoices = candidateVoices
            .where((voice) =>
                (voice['name'] != null &&
                    (voice['name']!.toLowerCase().contains('neural') ||
                        voice['name']!.toLowerCase().contains('wavenet') ||
                        voice['name']!.toLowerCase().contains('premium'))) ||
                (voice['isNetworkRequired'] != null &&
                    voice['isNetworkRequired'] == 'true'))
            .toList();

        if (neuralVoices.isNotEmpty) {
          candidateVoices = neuralVoices;
        }
      }

      // Em iOS e macOS, procurar por vozes específicas de melhor qualidade
      if (Platform.isIOS || Platform.isMacOS) {
        var enhancedVoices = candidateVoices
            .where((voice) =>
                voice['name'] != null &&
                (voice['name']!.toLowerCase().contains('enhanced') ||
                    voice['name']!.toLowerCase().contains('premium')))
            .toList();

        if (enhancedVoices.isNotEmpty) {
          candidateVoices = enhancedVoices;
        }
      }

      // Se temos candidatos, escolher o primeiro
      if (candidateVoices.isNotEmpty) {
        var selectedVoice = candidateVoices.first;
        if (selectedVoice['name'] != null) {
          Map<String, String> voiceParams = {
            "name": selectedVoice['name']!,
          };

          if (selectedVoice['locale'] != null) {
            voiceParams["locale"] = selectedVoice['locale']!;
          }

          await _flutterTts.setVoice(voiceParams);
          _currentVoice = selectedVoice['name'];
          print('Voz selecionada: ${selectedVoice['name']}');
        }
      }
    } catch (e) {
      print('Erro ao selecionar melhor voz: $e');
    }
  }

  // Método público para definir a voz
  Future<void> setVoice(String voiceName) async {
    if (!_isInitialized) return;

    try {
      // Encontrar a voz pelo nome
      var voiceData = _availableVoices.firstWhere(
        (voice) => voice['name'] == voiceName,
        orElse: () => <String, String>{},
      );

      if (voiceData.isEmpty) return;

      // Definir a voz
      Map<String, String> voiceParams = {
        "name": voiceName,
      };

      if (voiceData['locale'] != null) {
        voiceParams["locale"] = voiceData['locale']!;
      }

      await _flutterTts.setVoice(voiceParams);
      _currentVoice = voiceName;
      print('Voz alterada para: $voiceName');
    } catch (e) {
      print('Erro ao definir voz: $e');
    }
  }

  Future<void> setTtsEngine(String engineId) async {
    if (!_isInitialized || !_isPlatformSupported() || !Platform.isAndroid) {
      return;
    }

    final engine = _findAvailableEngine(engineId);
    if (engine == null) return;

    try {
      await stopSpeech();
      await _applyTtsEngine(engine);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_ttsEnginePreferenceKey, engine.id);

      await _applyVoiceParameters();
      final deviceLocale = WidgetsBinding.instance.platformDispatcher.locale;
      final deviceLanguageTag =
          '${deviceLocale.languageCode}-${deviceLocale.countryCode}';
      await _setLanguage(deviceLanguageTag);
      await _loadVoices();
      await _selectBestVoice();

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Erro ao definir mecanismo de TTS: $e');
    }
  }

  // Métodos para ajustar os parâmetros de voz
  Future<void> setPitch(double pitch) async {
    if (!_isInitialized) return;

    try {
      // Garantir que o pitch esteja entre 0.5 e 2.0
      pitch = pitch.clamp(0.5, 2.0);
      await _flutterTts.setPitch(pitch);
      _pitch = pitch;
    } catch (e) {
      print('Erro ao definir pitch: $e');
    }
  }

  Future<void> setRate(double rate) async {
    if (!_isInitialized) return;

    try {
      // Garantir que a taxa esteja entre 0.1 e 1.0
      rate = rate.clamp(0.1, 1.0);
      await _flutterTts.setSpeechRate(rate);
      _rate = rate;
    } catch (e) {
      print('Erro ao definir taxa de fala: $e');
    }
  }

  Future<void> setVolume(double volume) async {
    if (!_isInitialized) return;

    try {
      // Garantir que o volume esteja entre 0.0 e 1.0
      volume = volume.clamp(0.0, 1.0);
      await _flutterTts.setVolume(volume);
      _volume = volume;
    } catch (e) {
      print('Erro ao definir volume: $e');
    }
  }

  // Configura o idioma para a síntese de voz
  Future<void> _setLanguage(String languageCode,
      {bool allowBeforeInitialized = false}) async {
    if (!_isInitialized && !allowBeforeInitialized) return;

    try {
      // Verifica se o idioma é suportado
      var languages = await _flutterTts.getLanguages;

      // Encontrar a correspondência mais próxima
      String? matchedLanguage;
      if (languages is List) {
        // Tenta encontrar correspondência exata
        if (languages.contains(languageCode)) {
          matchedLanguage = languageCode;
        }
        // Tenta encontrar correspondência parcial
        else {
          final prefix = languageCode.split('-')[0].toLowerCase();
          for (final lang in languages) {
            if (lang.toString().toLowerCase().startsWith(prefix)) {
              matchedLanguage = lang.toString();
              break;
            }
          }
        }
      }

      // Se encontrou uma correspondência, define o idioma
      if (matchedLanguage != null) {
        await _flutterTts.setLanguage(matchedLanguage);
        _currentLanguageCode = matchedLanguage;
        print('TTS language set to: $_currentLanguageCode');
      } else {
        // Caso não encontre correspondência exata, tentar o idioma base do dispositivo
        final deviceLocale = WidgetsBinding.instance.platformDispatcher.locale;
        final baseLanguage = deviceLocale.languageCode;

        // Procurar qualquer idioma que comece com o código do idioma do dispositivo
        String? fallbackLanguage;
        if (languages is List) {
          for (final lang in languages) {
            if (lang
                .toString()
                .toLowerCase()
                .startsWith(baseLanguage.toLowerCase())) {
              fallbackLanguage = lang.toString();
              break;
            }
          }
        }

        if (fallbackLanguage != null) {
          await _flutterTts.setLanguage(fallbackLanguage);
          _currentLanguageCode = fallbackLanguage;
          print('TTS language fallback to: $_currentLanguageCode');
        }
        // Fallback para o primeiro idioma disponível
        else if (languages is List && languages.isNotEmpty) {
          await _flutterTts.setLanguage(languages.first.toString());
          _currentLanguageCode = languages.first.toString();
          print(
              'TTS language fallback to first available: $_currentLanguageCode');
        }
      }
    } catch (e) {
      print('Error setting TTS language: $e');
    }
  }

  // Método para falar o texto
  Future<void> speak(String text) async {
    if (text.isEmpty) return;

    if (!_isInitialized || !_isPlatformSupported()) {
      if (!_isPlatformSupported()) {
        print('TTS não está inicializado ou não é suportado');
        return;
      }
      await _startTtsInitNow('speak_requested');
      if (!_isInitialized) {
        print('TTS não está inicializado ou não é suportado');
        return;
      }
    }

    // Para a fala atual se estiver falando
    if (_isSpeaking) {
      await stopSpeech();
      return;
    }

    try {
      // No Android, a API de TTS tem limitações de tamanho
      if (Platform.isAndroid && text.length > 4000) {
        // Dividir o texto em partes menores (limitar a 4000 caracteres por parte)
        final chunks = _splitTextIntoChunks(text, 4000);
        for (var i = 0; i < chunks.length; i++) {
          // Se parou de falar (usuário cancelou), interrompe
          if (!_isSpeaking && i > 0) break;

          var result = await _flutterTts.speak(chunks[i]);
          if (result != 1) {
            // Problema ao falar
            print('TTS falhou ao falar o texto');
            break;
          }

          // Aguarda a conclusão antes de processar o próximo chunk
          await Future.delayed(Duration(milliseconds: 500));
        }
      } else {
        var result = await _flutterTts.speak(text);
        if (result != 1) {
          // Problema ao falar
          print('TTS falhou ao falar o texto, código: $result');
        }
      }
    } catch (e) {
      print('TTS Error: $e');
      // Atualiza o estado em caso de erro
      if (mounted) {
        setState(() {
          _isSpeaking = false;
        });
      }
    }
  }

  // Método para parar a fala (público)
  Future<void> stopSpeech() async {
    if (!_isInitialized || !_isPlatformSupported()) return;

    try {
      var result = await _flutterTts.stop();
      if (result == 1) {
        if (mounted) {
          setState(() {
            _isSpeaking = false;
            _ttsState = TtsState.stopped;
          });
        }
      }
    } catch (e) {
      print('Error stopping TTS: $e');
      // Garantir que o estado está consistente mesmo se houver erro
      if (mounted) {
        setState(() {
          _isSpeaking = false;
          _ttsState = TtsState.stopped;
        });
      }
    }
  }

  // Método para dividir o texto em partes menores
  List<String> _splitTextIntoChunks(String text, int maxChunkSize) {
    List<String> chunks = [];

    // Se o texto for menor que o tamanho máximo, retorne-o diretamente
    if (text.length <= maxChunkSize) {
      chunks.add(text);
      return chunks;
    }

    // Divide o texto por parágrafos ou frases para manter a coerência
    var sentences = text.split(RegExp(r'(?<=[\.\?\!])\s+'));
    String currentChunk = '';

    for (var sentence in sentences) {
      // Se a sentença atual + a próxima couberem no chunk atual
      if ((currentChunk + sentence).length <= maxChunkSize) {
        currentChunk += sentence + ' ';
      } else {
        // Se o chunk atual não estiver vazio, adicione-o à lista
        if (currentChunk.isNotEmpty) {
          chunks.add(currentChunk.trim());
        }

        // Se a sentença for maior que o tamanho máximo, divida-a
        if (sentence.length > maxChunkSize) {
          var parts = sentence.split(' ');
          currentChunk = '';

          for (var part in parts) {
            if ((currentChunk + part).length <= maxChunkSize) {
              currentChunk += part + ' ';
            } else {
              chunks.add(currentChunk.trim());
              currentChunk = part + ' ';
            }
          }
        } else {
          currentChunk = sentence + ' ';
        }
      }
    }

    // Adicionar o último chunk se não estiver vazio
    if (currentChunk.isNotEmpty) {
      chunks.add(currentChunk.trim());
    }

    return chunks;
  }

  // Método auxiliar para limitar valor mínimo entre dois números
  int min(int a, int b) {
    return a < b ? a : b;
  }
}
