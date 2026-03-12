import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../screens/ai_tutor_screen.dart';
import '../services/ai_service.dart';
import '../services/chat_audio_recorder.dart';
import '../utils/ui_utils.dart';

// Mixin para encapsular a lógica de gravação e transcrição de voz do chat
mixin NutritionAssistantSpeechMixin on State<NutritionAssistantScreen> {
  static const Duration _audioCaptureTimeout = Duration(minutes: 5);

  final ChatAudioRecorder _audioRecorder = ChatAudioRecorder();
  final AIService _aiService = AIService();

  bool _isListening = false;
  bool _isTranscribingAudio = false;
  String _recognizedText = '';
  String _committedRecognizedText = '';
  Timer? _autoStopTimer;

  bool get isListening => _isListening;
  bool get isTranscribingAudio => _isTranscribingAudio;
  String get recognizedText => _recognizedText;

  TextEditingController get messageController;
  AnimationController get animationController;
  void keepScreenOn(bool keepOn);
  void incrementAndroidUpdateCounter();
  int get androidUpdateCounter;

  Future<void> initSpeechRecognition() async {
    print('🎤 NutritionAssistantSpeechMixin - Inicializando captura de áudio');

    if (kIsWeb) {
      print(
          '⚠️ NutritionAssistantSpeechMixin - Captura de áudio no servidor desabilitada na web');
      return;
    }

    try {
      if (Platform.isAndroid) {
        final status = await Permission.microphone.status;
        if (status.isDenied) {
          print(
              '🎤 NutritionAssistantSpeechMixin - Permissão de microfone ainda não concedida');
        }
      }

      await _audioRecorder.init();
      print(
          '✅ NutritionAssistantSpeechMixin - Captura de áudio inicializada com sucesso');
    } catch (e) {
      print(
          '❌ NutritionAssistantSpeechMixin - Erro ao inicializar captura de áudio: $e');
    }
  }

  void startListening(
      {bool preserveCurrentText = false, bool lowLatencyMode = false}) async {
    if (kIsWeb) {
      UIUtils.showSimpleToast(
          context, 'Gravação de áudio ainda não disponível na web');
      return;
    }

    try {
      _autoStopTimer?.cancel();

      if (!preserveCurrentText) {
        if (mounted) {
          setState(() {
            _committedRecognizedText = '';
            _recognizedText = '';
            messageController.clear();
          });
        }
      } else {
        final currentText = messageController.text;
        if (mounted) {
          setState(() {
            _committedRecognizedText = _preprocessRecognizedText(currentText);
            _recognizedText = _committedRecognizedText;
          });
        }
      }

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

      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        UIUtils.showErrorDialog(context, 'Permissão do microfone negada');
        return;
      }

      _autoStopTimer = Timer(_audioCaptureTimeout, () {
        if (_isListening) {
          stopListening();
        }
      });

      animationController.duration = const Duration(milliseconds: 600);
      animationController.repeat(reverse: true);
      keepScreenOn(true);

      await _audioRecorder.startRecording();

      if (mounted) {
        setState(() {
          _isListening = true;
          _isTranscribingAudio = false;
        });
      }

      print('🎤 NutritionAssistantSpeechMixin - Captura de áudio iniciada' +
          (preserveCurrentText ? ' (preservando texto anterior)' : '') +
          (lowLatencyMode ? ' (modo baixa latência)' : ''));
    } catch (e) {
      print(
          '❌ NutritionAssistantSpeechMixin - Erro ao iniciar gravação de áudio: $e');
      UIUtils.showSimpleToast(context, 'Erro ao iniciar a gravação de áudio');
      keepScreenOn(false);
      if (mounted) {
        setState(() {
          _isListening = false;
          _isTranscribingAudio = false;
        });
      }
    }
  }

  Future<void> stopListening() async {
    _autoStopTimer?.cancel();

    if (!_isListening) {
      return;
    }

    keepScreenOn(false);

    if (mounted) {
      setState(() {
        _isListening = false;
        _isTranscribingAudio = true;
      });
    }

    try {
      final recordedAudio = await _audioRecorder.stopRecording();

      if (recordedAudio == null || recordedAudio.bytes.isEmpty) {
        UIUtils.showSimpleToast(context, 'Nenhum áudio foi capturado');
        if (mounted) {
          setState(() {
            _isTranscribingAudio = false;
          });
        }
        return;
      }

      final locale = Localizations.localeOf(context);
      final languageCode =
          locale.toString().replaceAll('-', '_').trim().isEmpty
              ? 'pt_BR'
              : locale.toString().replaceAll('-', '_');

      final transcription = await _aiService.processAudio(
        recordedAudio.bytes,
        mimeType: recordedAudio.mimeType,
        languageCode: languageCode,
      );

      if (transcription.startsWith('Desculpe, ocorreu um erro')) {
        UIUtils.showSimpleToast(context, transcription);
      } else {
        _committedRecognizedText = _mergeRecognizedText(
          _committedRecognizedText,
          transcription,
        );
        _updateRecognizedText(_committedRecognizedText);
      }
    } catch (e) {
      print(
          '❌ NutritionAssistantSpeechMixin - Erro ao finalizar gravação/transcrição: $e');
      UIUtils.showSimpleToast(context, 'Erro ao transcrever o áudio');
    } finally {
      if (mounted) {
        setState(() {
          _isTranscribingAudio = false;
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

    return _preprocessRecognizedText('$normalizedBase $normalizedNew');
  }

  String _preprocessRecognizedText(String newText) {
    try {
      return newText
          .replaceAll(RegExp(r'\s+'), ' ')
          .replaceAll(',.', '.')
          .replaceAll(' ,', ',')
          .replaceAll(' .', '.')
          .replaceAll(' ?', '?')
          .replaceAll(' !', '!')
          .trim();
    } catch (e) {
      print('⚠️ Erro no processamento de texto transcrito: $e');
      return newText;
    }
  }

  Future<void> releaseAudioResources() async {
    _autoStopTimer?.cancel();
    keepScreenOn(false);

    try {
      if (_isListening) {
        await _audioRecorder.cancelRecording();
      }

      if (mounted) {
        setState(() {
          _isListening = false;
          _isTranscribingAudio = false;
        });
      }
    } catch (e) {
      print('⚠️ NutritionAssistantSpeechMixin - Erro ao liberar áudio: $e');
    }
  }

  void disposeSpeechResources() {
    _autoStopTimer?.cancel();
    keepScreenOn(false);
    if (_isListening) {
      _audioRecorder.cancelRecording();
    }
    _audioRecorder.dispose();
  }
}
