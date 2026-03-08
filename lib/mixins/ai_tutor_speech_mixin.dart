import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';

import '../screens/ai_tutor_screen.dart'; // Import necessário para State<NutritionAssistantScreen>
import '../utils/ui_utils.dart'; // Para usar os diálogos/toasts

// Mixin para encapsular a lógica de reconhecimento de voz
mixin NutritionAssistantSpeechMixin on State<NutritionAssistantScreen> {
  static const Duration _speechPauseTimeout = Duration(seconds: 30);
  static const Duration _speechListenTimeout = Duration(minutes: 5);
  static const Duration _speechRestartDelay = Duration(milliseconds: 300);

  // Variáveis para reconhecimento de voz
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  bool _isListening = false;
  String _recognizedText = '';
  String _committedRecognizedText = '';
  String _activeRecognizedSegment = '';

  // Getters para acesso às variáveis privadas
  bool get isListening => _isListening;
  String get recognizedText => _recognizedText;

  // Métodos para acessar os controladores e métodos da classe principal
  // Estes métodos devem ser implementados na classe que usa este mixin
  TextEditingController get messageController;
  AnimationController get animationController;
  void keepScreenOn(bool keepOn);
  void incrementAndroidUpdateCounter();
  int get androidUpdateCounter;

  // Variáveis para controlar tentativas de recuperação
  bool _isBusyRecovering = false;

  // Variáveis adicionais para controle de sessão de reconhecimento
  bool _forceStop = false;
  int _noMatchCount = 0;
  Timer? _autoStopTimer;

  // Referências que o mixin precisa do State principal (serão acessadas via 'this')
  // Exemplo: this._messageController, this._animationController, etc.
  // Os métodos como _keepScreenOn também serão acessados via 'this'

  // Inicialização do reconhecimento de voz
  Future<void> initSpeechRecognition() async {
    print(
        '🎤 NutritionAssistantSpeechMixin - Inicializando reconhecimento de voz');

    try {
      // Para dispositivos Android, verificar permissão antes de inicializar
      if (!kIsWeb && Platform.isAndroid) {
        final status = await Permission.microphone.status;
        if (status.isDenied) {
          print(
              '🎤 NutritionAssistantSpeechMixin - Permissão de microfone não concedida ainda');
        }
      }

      bool available = await _speechToText.initialize(
        onStatus: _onSpeechStatus,
        onError: _onSpeechError,
        debugLogging: false,
      );

      if (!available) {
        print(
            '❌ NutritionAssistantSpeechMixin - O reconhecimento de voz não está disponível neste dispositivo');
      } else {
        print(
            '✅ NutritionAssistantSpeechMixin - Reconhecimento de voz inicializado com sucesso');
      }
    } catch (e) {
      print(
          '❌ NutritionAssistantSpeechMixin - Erro ao inicializar o reconhecimento de voz: $e');
    }
  }

  // Callback de status do reconhecimento
  void _onSpeechStatus(String status) {
    print('Status do reconhecimento de voz: $status');

    // Em dispositivos Android, implementar escuta contínua
    // O Android para automaticamente após ~5 segundos de silêncio (limitação do OS)
    // A solução é reiniciar o listener quando o status for "done"
    if (!kIsWeb && Platform.isAndroid) {
      if (status == 'done' &&
          _isListening &&
          !_isBusyRecovering &&
          !_forceStop) {
        print(
            '🎤 NutritionAssistantSpeechMixin - Status "done" detectado, reiniciando escuta...');

        // Marcar como em recuperação para evitar múltiplos reinícios
        _isBusyRecovering = true;

        // Aguardar os recursos do OS serem liberados antes de reiniciar
        Future.delayed(_speechRestartDelay, () async {
          if (mounted && !_forceStop) {
            try {
              // Reiniciar o reconhecimento preservando o texto atual
              await _speechToText.listen(
                onResult: _onSpeechResult,
                localeId: 'pt_BR',
                pauseFor: _speechPauseTimeout,
                listenFor: _speechListenTimeout,
                listenOptions: stt.SpeechListenOptions(
                  listenMode: stt.ListenMode.dictation,
                  cancelOnError: false,
                  partialResults: true,
                ),
              );
              print(
                  '🎤 NutritionAssistantSpeechMixin - Escuta reiniciada com sucesso');
            } catch (e) {
              print(
                  '❌ NutritionAssistantSpeechMixin - Erro ao reiniciar escuta: $e');
              if (mounted) {
                setState(() {
                  _isListening = false;
                });
              }
            } finally {
              _isBusyRecovering = false;
            }
          } else {
            _isBusyRecovering = false;
          }
        });

        return;
      }
    } else {
      // Para outros dispositivos que não Android
      if (status == 'done' && _isListening) {
        if (mounted) {
          setState(() {
            _isListening = false;
          });
        }
      }
    }
  }

  // Callback de erro do reconhecimento
  void _onSpeechError(dynamic errorNotification) {
    print('Erro no reconhecimento de voz: $errorNotification');

    // Em dispositivos Android, tratar erros específicos
    if (!kIsWeb && Platform.isAndroid) {
      // Contar erros de não reconhecimento
      if (errorNotification.errorMsg.contains('no_match')) {
        _noMatchCount++;

        // Se tivermos muitos erros de não reconhecimento consecutivos, forçar parada
        if (_noMatchCount >= 2) {
          print(
              '🎤 NutritionAssistantSpeechMixin - Muitos erros de no_match, parando reconhecimento');
          _forceStop = true;
          stopListening();
          return;
        }
      }

      if (errorNotification.errorMsg.contains('network')) {
        UIUtils.showErrorDialog(context,
            'Erro de rede no reconhecimento de voz. Verifique sua conexão.');
      } else if (errorNotification.errorMsg.contains('busy') &&
          !_isBusyRecovering &&
          !_forceStop) {
        // Forçar parada em caso de erro busy - não tentar recuperar
        print(
            '🎤 NutritionAssistantSpeechMixin - Erro busy detectado, parando reconhecimento');
        _forceStop = true;
        stopListening();
      }
    }
  }

  // Método para iniciar a escuta de voz
  void startListening(
      {bool preserveCurrentText = false, bool lowLatencyMode = false}) async {
    // Agora usando os getters definidos em vez de dynamic casting
    try {
      // Resetar variáveis de controle
      _forceStop = false;
      _noMatchCount = 0;

      // Cancelar qualquer timer anterior
      _autoStopTimer?.cancel();

      // Configurar timer para auto-parar depois de um tempo mesmo se não detectar fala
      // e mostrar o botão de enviar
      _autoStopTimer = Timer(_speechListenTimeout, () {
        if (_isListening) {
          print('🎤 NutritionAssistantSpeechMixin - Auto-stop após timeout');
          if (mounted) {
            setState(() {
              _isListening = false;
              _forceStop = true;
            });
          }
          _speechToText.stop();
          print(
              '🎤 NutritionAssistantSpeechMixin - Reconhecimento parado. Botão de enviar visível.');
        }
      });

      // Acelera a animação para feedback visual mais responsivo no Android
      if (!kIsWeb && Platform.isAndroid) {
        animationController.duration = Duration(milliseconds: 600);
        animationController.repeat(reverse: true);
      }

      // Se não estiver preservando o texto atual, limpe-o
      if (!preserveCurrentText) {
        if (mounted) {
          setState(() {
            _committedRecognizedText = '';
            _activeRecognizedSegment = '';
            _recognizedText = '';
            messageController.clear();
          });
        }
      } else {
        // Armazenar o texto atual para garantir que não seja perdido
        final currentText = messageController.text;
        if (mounted) {
          setState(() {
            _committedRecognizedText = _preprocessRecognizedText(currentText);
            _activeRecognizedSegment = '';
            _recognizedText = _committedRecognizedText;
          });
        }
      }

      if (!_speechToText.isAvailable) {
        await initSpeechRecognition();
      }

      if (!_speechToText.isAvailable) {
        UIUtils.showErrorDialog(
            context, 'Reconhecimento de voz não disponível');
        return;
      }

      // Verificar permissão de microfone - tratamento otimizado para Android
      if (!kIsWeb && Platform.isAndroid) {
        var status = await Permission.microphone.status;
        if (status.isDenied) {
          status = await Permission.microphone.request();
          if (status.isDenied) {
            UIUtils.showPermissionDialog(context);
            return;
          }
        } else if (status.isPermanentlyDenied) {
          UIUtils.showPermissionDialog(context, permanentlyDenied: true);
          return;
        }

        // Manter a tela ligada durante o reconhecimento (Android)
        keepScreenOn(true);
      } else {
        // Para outras plataformas
        var status = await Permission.microphone.request();
        if (status != PermissionStatus.granted) {
          UIUtils.showErrorDialog(context, 'Permissão do microfone negada');
          return;
        }
      }

      if (mounted) {
        setState(() {
          _isListening = true;
        });
      }

      // Configurações específicas para Android
      if (!kIsWeb && Platform.isAndroid) {
        await _speechToText.listen(
          onResult: _onSpeechResult,
          localeId: 'pt_BR',
          pauseFor: _speechPauseTimeout,
          listenFor: _speechListenTimeout,
          listenOptions: stt.SpeechListenOptions(
            listenMode: stt.ListenMode.dictation,
            cancelOnError: false,
            partialResults: true,
          ),
        );
      } else {
        await _speechToText.listen(
          onResult: _onSpeechResult,
          localeId: 'pt_BR',
          pauseFor: _speechPauseTimeout,
          listenFor: _speechListenTimeout,
          listenOptions: stt.SpeechListenOptions(
            listenMode: stt.ListenMode.dictation,
            cancelOnError: false,
            partialResults: true,
          ),
        );
      }

      print('🎤 NutritionAssistantSpeechMixin - Iniciou a escuta de voz' +
          (kIsWeb ? ' na web' : ' no ${Platform.operatingSystem}') +
          (preserveCurrentText ? ' (preservando texto anterior)' : '') +
          (lowLatencyMode ? ' (modo baixa latência)' : ''));
    } catch (e) {
      print(
          '❌ NutritionAssistantSpeechMixin - Erro ao iniciar o reconhecimento de voz: $e');
      UIUtils.showSimpleToast(
          context, 'Erro ao iniciar o reconhecimento de voz');
      if (mounted) {
        setState(() => _isListening = false);
      }
      _isBusyRecovering = false;
      _forceStop = false;
    }
  }

  // Método para parar o reconhecimento de voz
  void stopListening() {
    // Cancelar o timer de auto-stop se existir
    _autoStopTimer?.cancel();

    try {
      if (_speechToText.isListening) {
        _speechToText.stop();
      }

      if (mounted) {
        setState(() {
          _committedRecognizedText =
              _preprocessRecognizedText(messageController.text);
          _activeRecognizedSegment = '';
          _recognizedText = _committedRecognizedText;
          _isListening = false;
          _forceStop = true;
        });
      }

      // Se estamos no Android, liberar recursos adicionais
      if (!kIsWeb && Platform.isAndroid) {
        // Desativa a flag que mantém a tela ligada
        keepScreenOn(false);
      }

      print('🎤 NutritionAssistantSpeechMixin - Reconhecimento de voz parado');
    } catch (e) {
      print(
          '❌ NutritionAssistantSpeechMixin - Erro ao parar o reconhecimento: $e');
      if (mounted) {
        setState(() {
          _isListening = false;
        });
      }
    }
  }

  // Método para lidar com o resultado do reconhecimento
  void _onSpeechResult(SpeechRecognitionResult result) {
    // Resetar contador de erros no_match quando houver um resultado bem-sucedido
    _noMatchCount = 0;

    final recognizedWords = _preprocessRecognizedText(result.recognizedWords);

    if (result.finalResult) {
      if (mounted) {
        setState(() {
          _committedRecognizedText =
              _mergeRecognizedText(_committedRecognizedText, recognizedWords);
          _activeRecognizedSegment = '';
          _updateRecognizedText(_committedRecognizedText);
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _activeRecognizedSegment = recognizedWords;
          _updateRecognizedText(
            _mergeRecognizedText(
              _committedRecognizedText,
              _activeRecognizedSegment,
            ),
          );
        });
      }
    }
  }

  void _updateRecognizedText(String text) {
    final processedText = _preprocessRecognizedText(text);
    _recognizedText = processedText;
    messageController.value = messageController.value.copyWith(
      text: processedText,
      selection: TextSelection.collapsed(offset: processedText.length),
      composing: TextRange.empty,
    );
  }

  String _mergeRecognizedText(String baseText, String newText) {
    final normalizedBase = _preprocessRecognizedText(baseText);
    final normalizedNew = _preprocessRecognizedText(newText);

    if (normalizedBase.isEmpty) {
      return normalizedNew;
    }

    if (normalizedNew.isEmpty) {
      return normalizedBase;
    }

    if (normalizedBase == normalizedNew) {
      return normalizedBase;
    }

    if (normalizedNew.startsWith(normalizedBase)) {
      return normalizedNew;
    }

    if (normalizedBase.endsWith(normalizedNew)) {
      return normalizedBase;
    }

    final lowerBase = normalizedBase.toLowerCase();
    final lowerNew = normalizedNew.toLowerCase();
    final maxOverlap =
        lowerBase.length < lowerNew.length ? lowerBase.length : lowerNew.length;

    for (var overlap = maxOverlap; overlap > 0; overlap--) {
      if (lowerBase.substring(lowerBase.length - overlap) ==
          lowerNew.substring(0, overlap)) {
        return _preprocessRecognizedText(
          normalizedBase + normalizedNew.substring(overlap),
        );
      }
    }

    return _preprocessRecognizedText('$normalizedBase $normalizedNew');
  }

  // Método para pré-processar o texto reconhecido, otimizando performance no Android
  String _preprocessRecognizedText(String newText) {
    // No Android, apenas processar textos com conteúdo suficiente para prevenir overhead
    if (!kIsWeb && Platform.isAndroid && newText.length < 3) {
      return newText;
    }

    try {
      // Remover espaços duplos - comum em reconhecimento de voz Android
      String processed = newText.replaceAll(RegExp(r'\s+'), ' ').trim();

      // Normalizar certos caracteres ou correções comuns
      processed = processed
          .replaceAll(',.', '.') // Correção de vírgula seguida de ponto
          .replaceAll(' ,', ',') // Espaço antes de vírgula
          .replaceAll(' .', '.') // Espaço antes de ponto
          .replaceAll(' ?', '?') // Espaço antes de interrogação
          .replaceAll(' !', '!'); // Espaço antes de exclamação

      return processed;
    } catch (e) {
      // Em caso de erro no processamento, retornar o texto original
      print('⚠️ Erro no processamento de texto: $e');
      return newText;
    }
  }

  // Função para liberar recursos de áudio
  Future<void> releaseAudioResources() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        // Forçar parada do reconhecimento
        if (_speechToText.isListening) {
          await _speechToText.stop();
        }

        // Limpar flags
        _isListening = false;
        _isBusyRecovering = false;

        // Importante: Não limpar o texto reconhecido aqui

        // Esperar um breve momento para liberar recursos
        await Future.delayed(Duration(milliseconds: 300));

        print('📢 NutritionAssistantSpeechMixin - Recursos de áudio liberados');
      } catch (e) {
        print(
            '⚠️ NutritionAssistantSpeechMixin - Erro ao liberar recursos: $e');
      }
    }
  }

  // Método chamado no dispose do State principal
  void disposeSpeechResources() {
    _autoStopTimer?.cancel();
    if (_speechToText.isListening) {
      try {
        _speechToText.stop();
      } catch (e) {
        print(
            '❌ NutritionAssistantSpeechMixin - Erro ao parar reconhecimento no dispose: $e');
      }
    }
  }
}
