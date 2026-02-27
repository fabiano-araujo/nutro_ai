import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_recognition_error.dart';

import '../screens/ai_tutor_screen.dart'; // Import necessário para State<AITutorScreen>
import '../utils/ui_utils.dart'; // Para usar os diálogos/toasts

// Mixin para encapsular a lógica de reconhecimento de voz
mixin AITutorSpeechMixin on State<AITutorScreen> {
  // Variáveis para reconhecimento de voz
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  bool _isListening = false;
  String _recognizedText = '';
  double _speechConfidence = 0.0;

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
  int _retryCount = 0;

  // Variáveis adicionais para controle de sessão de reconhecimento
  int _maxRetries = 1; // Voltar para apenas uma tentativa
  bool _forceStop = false;
  int _noMatchCount = 0;
  Timer? _autoStopTimer;

  // Referências que o mixin precisa do State principal (serão acessadas via 'this')
  // Exemplo: this._messageController, this._animationController, etc.
  // Os métodos como _keepScreenOn também serão acessados via 'this'

  // Inicialização do reconhecimento de voz
  Future<void> initSpeechRecognition() async {
    print('🎤 AITutorSpeechMixin - Inicializando reconhecimento de voz');

    try {
      // Para dispositivos Android, verificar permissão antes de inicializar
      if (!kIsWeb && Platform.isAndroid) {
        final status = await Permission.microphone.status;
        if (status.isDenied) {
          print(
              '🎤 AITutorSpeechMixin - Permissão de microfone não concedida ainda');
        }
      }

      bool available = await _speechToText.initialize(
        onStatus: _onSpeechStatus,
        onError: _onSpeechError,
        debugLogging: false,
      );

      if (!available) {
        print(
            '❌ AITutorSpeechMixin - O reconhecimento de voz não está disponível neste dispositivo');
      } else {
        print(
            '✅ AITutorSpeechMixin - Reconhecimento de voz inicializado com sucesso');
      }
    } catch (e) {
      print(
          '❌ AITutorSpeechMixin - Erro ao inicializar o reconhecimento de voz: $e');
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
        print('🎤 AITutorSpeechMixin - Status "done" detectado, reiniciando escuta...');

        // Marcar como em recuperação para evitar múltiplos reinícios
        _isBusyRecovering = true;

        // Aguardar os recursos do OS serem liberados antes de reiniciar
        Future.delayed(Duration(milliseconds: 300), () async {
          if (mounted && !_forceStop) {
            try {
              // Reiniciar o reconhecimento preservando o texto atual
              await _speechToText.listen(
                onResult: _onSpeechResult,
                localeId: 'pt_BR',
                listenMode: stt.ListenMode.dictation,
                pauseFor: Duration(seconds: 30),
                cancelOnError: false,
                partialResults: true,
                listenFor: Duration(minutes: 5),
              );
              print('🎤 AITutorSpeechMixin - Escuta reiniciada com sucesso');
            } catch (e) {
              print('❌ AITutorSpeechMixin - Erro ao reiniciar escuta: $e');
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
              '🎤 AITutorSpeechMixin - Muitos erros de no_match, parando reconhecimento');
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
            '🎤 AITutorSpeechMixin - Erro busy detectado, parando reconhecimento');
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
      _autoStopTimer = Timer(Duration(minutes: 5), () {
        if (_isListening) {
          print('🎤 AITutorSpeechMixin - Auto-stop após timeout');
          if (mounted) {
            setState(() {
              _isListening = false;
              _forceStop = true;
            });
          }
          _speechToText.stop();
          print(
              '🎤 AITutorSpeechMixin - Reconhecimento parado. Botão de enviar visível.');
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
            _recognizedText = '';
            messageController.clear();
            _retryCount = 0;
          });
        }
      } else {
        // Armazenar o texto atual para garantir que não seja perdido
        final currentText = messageController.text;
        if (mounted) {
          setState(() {
            _recognizedText = currentText;
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
          listenMode: stt.ListenMode.dictation,
          pauseFor: Duration(seconds: 30), // Aumentado para aguardar mais antes de parar
          cancelOnError: false,
          partialResults: true,
          listenFor: Duration(minutes: 5), // Aumentado para permitir ditados mais longos
        );
      } else {
        await _speechToText.listen(
          onResult: _onSpeechResult,
          localeId: 'pt_BR',
          listenMode: stt.ListenMode.dictation,
          pauseFor: Duration(seconds: 3),
          cancelOnError: false,
          partialResults: true,
        );
      }

      print('🎤 AITutorSpeechMixin - Iniciou a escuta de voz' +
          (kIsWeb ? ' na web' : ' no ${Platform.operatingSystem}') +
          (preserveCurrentText ? ' (preservando texto anterior)' : '') +
          (lowLatencyMode ? ' (modo baixa latência)' : ''));
    } catch (e) {
      print(
          '❌ AITutorSpeechMixin - Erro ao iniciar o reconhecimento de voz: $e');
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
          _isListening = false;
          _forceStop = true;
        });
      }

      // Se estamos no Android, liberar recursos adicionais
      if (!kIsWeb && Platform.isAndroid) {
        // Desativa a flag que mantém a tela ligada
        keepScreenOn(false);
      }

      print('🎤 AITutorSpeechMixin - Reconhecimento de voz parado');
    } catch (e) {
      print('❌ AITutorSpeechMixin - Erro ao parar o reconhecimento: $e');
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

    if (result.finalResult) {
      // Resultado final do reconhecimento
      if (mounted) {
        setState(() {
          _speechConfidence = result.confidence;
          _recognizedText = result.recognizedWords;

          // Atualizar o texto do campo
          messageController.text = _recognizedText;

          // Se detectarmos texto válido e significativo, atualizamos a UI
          if (_validateSpeechResult(_recognizedText)) {
            _isListening = false;
            _forceStop = true;
          }
        });
      }
    } else {
      // Resultados intermediários
      if (mounted) {
        setState(() {
          _recognizedText = result.recognizedWords;
          messageController.text = _recognizedText;
        });
      }
    }
  }

  // Método para validar se o resultado do reconhecimento de voz é útil
  bool _validateSpeechResult(String text) {
    // Verificar se o texto reconhecido tem conteúdo significativo
    final trimmedText = text.trim();

    // Se o texto tiver mais de 5 caracteres, ou contiver alguma palavra significativa,
    // consideramos que é um resultado válido
    return trimmedText.length > 5 ||
        trimmedText.contains(' ') || // Pelo menos duas palavras
        trimmedText.toLowerCase().contains('sim') ||
        trimmedText.toLowerCase().contains('não') ||
        trimmedText.toLowerCase().contains('ok');
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
        _retryCount = 0;

        // Importante: Não limpar o texto reconhecido aqui

        // Esperar um breve momento para liberar recursos
        await Future.delayed(Duration(milliseconds: 300));

        print('📢 AITutorSpeechMixin - Recursos de áudio liberados');
      } catch (e) {
        print('⚠️ AITutorSpeechMixin - Erro ao liberar recursos: $e');
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
            '❌ AITutorSpeechMixin - Erro ao parar reconhecimento no dispose: $e');
      }
    }
  }
}
