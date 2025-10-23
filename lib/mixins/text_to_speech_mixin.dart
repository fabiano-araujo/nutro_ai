import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum TtsState { playing, stopped, paused, continued }

mixin TextToSpeechMixin<T extends StatefulWidget> on State<T> {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = false;
  bool _isInitialized = false;
  String? _currentLanguageCode;
  String? _currentVoice;
  TtsState _ttsState = TtsState.stopped;
  double _pitch = 1.0;
  double _rate = 0.5;
  double _volume = 1.0;
  List<Map<String, String>> _availableVoices = [];

  // Getters para o estado de fala
  bool get isSpeaking => _isSpeaking;
  List<Map<String, String>> get availableVoices => _availableVoices;
  String? get currentVoice => _currentVoice;
  double get pitch => _pitch;
  double get rate => _rate;
  double get volume => _volume;

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  @override
  void dispose() {
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

      // Definir volume e pitch iniciais
      await _flutterTts.setVolume(_volume);
      await _flutterTts.setPitch(_pitch);
      await _flutterTts.setSpeechRate(_rate);

      // Definir o idioma padrão com base no dispositivo
      await _setLanguage('pt-BR');

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

      // Filtrar vozes por idioma (preferir português)
      var ptVoices = _availableVoices
          .where((voice) =>
              voice['locale'] != null &&
              voice['locale']!.toLowerCase().startsWith('pt'))
          .toList();

      // Se não tiver vozes em português, usar todas as vozes
      var candidateVoices = ptVoices.isEmpty ? _availableVoices : ptVoices;

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
  Future<void> _setLanguage(String languageCode) async {
    if (!_isInitialized) return;

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
        // Caso não encontre, tenta usar o PT-BR
        if (languages is List && languages.contains('pt-BR')) {
          await _flutterTts.setLanguage('pt-BR');
          _currentLanguageCode = 'pt-BR';
        }
        // Fallback para o primeiro idioma disponível
        else if (languages is List && languages.isNotEmpty) {
          await _flutterTts.setLanguage(languages.first.toString());
          _currentLanguageCode = languages.first.toString();
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
      print('TTS não está inicializado ou não é suportado');
      return;
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
