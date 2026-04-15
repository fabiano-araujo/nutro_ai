import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../screens/nutrition_assistant_screen.dart';
import '../services/ai_service.dart';
import '../services/chat_audio_recorder.dart';
import '../utils/audio_transcript_sanitizer.dart';
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
  Timer? _recordingTicker;
  StreamSubscription<double>? _amplitudeSubscription;
  Duration _recordingDuration = Duration.zero;
  List<double> _waveformSamples = List<double>.filled(18, 0.18);

  bool get isListening => _isListening;
  bool get isTranscribingAudio => _isTranscribingAudio;
  String get recognizedText => _recognizedText;
  Duration get recordingDuration => _recordingDuration;
  List<double> get waveformSamples =>
      List<double>.unmodifiable(_waveformSamples);

  TextEditingController get messageController;
  AnimationController get animationController;
  void keepScreenOn(bool keepOn);
  void incrementAndroidUpdateCounter();
  int get androidUpdateCounter;

  Future<void> initSpeechRecognition() async {
    print('🎤 NutritionAssistantSpeechMixin - Inicializando captura de áudio');

    try {
      if (!kIsWeb && Platform.isAndroid) {
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
            _committedRecognizedText = normalizeTranscriptSpacing(currentText);
            _recognizedText = _committedRecognizedText;
          });
        }
      }

      if (!kIsWeb) {
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
      _startRecordingVisualizer();

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
      print('❌ NutritionAssistantSpeechMixin - Erro ao iniciar gravação de áudio: $e');
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
    _stopRecordingVisualizer();

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

      final deviceLanguageCode = _localeToSpeechLanguageTag(
        WidgetsBinding.instance.platformDispatcher.locale,
      );
      final appLanguageCode = _localeToSpeechLanguageTag(
        Localizations.localeOf(context),
      );

      final rawTranscription = await _aiService.processAudio(
        recordedAudio.bytes,
        mimeType: recordedAudio.mimeType,
        languageCode: deviceLanguageCode,
        appLanguageCode: appLanguageCode,
        contextHint: 'nutrition_chat',
        audioDurationMs: _recordingDuration.inMilliseconds,
      );
      final transcription = sanitizeAudioTranscript(rawTranscription);

      if (transcription != rawTranscription) {
        final rawPreview = rawTranscription.length > 120
            ? '${rawTranscription.substring(0, 120)}...'
            : rawTranscription;
        print(
            '⚠️ NutritionAssistantSpeechMixin - Transcrição repetitiva detectada e colapsada: "$rawPreview" -> "$transcription"');
      }

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
    final processedText = normalizeTranscriptSpacing(text);
    _recognizedText = processedText;
    messageController.value = messageController.value.copyWith(
      text: processedText,
      selection: TextSelection.collapsed(offset: processedText.length),
      composing: TextRange.empty,
    );
  }

  String _mergeRecognizedText(String baseText, String newText) {
    final normalizedBase = normalizeTranscriptSpacing(baseText);
    final normalizedNew = normalizeTranscriptSpacing(newText);

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

    return normalizeTranscriptSpacing('$normalizedBase $normalizedNew');
  }

  String _localeToSpeechLanguageTag(Locale locale) {
    final languageCode = locale.languageCode.trim();
    final countryCode = locale.countryCode?.trim();

    if (languageCode.isEmpty || languageCode.toLowerCase() == 'und') {
      return 'pt-BR';
    }

    if (countryCode == null || countryCode.isEmpty) {
      return languageCode;
    }

    return '$languageCode-${countryCode.toUpperCase()}';
  }

  Future<void> releaseAudioResources() async {
    _autoStopTimer?.cancel();
    _stopRecordingVisualizer();
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
    _stopRecordingVisualizer();
    keepScreenOn(false);
    if (_isListening) {
      unawaited(_audioRecorder.cancelRecording());
    }
    unawaited(_audioRecorder.dispose());
  }

  void _startRecordingVisualizer() {
    _recordingTicker?.cancel();
    _amplitudeSubscription?.cancel();
    _recordingDuration = Duration.zero;
    _waveformSamples = List<double>.filled(18, 0.18);

    _recordingTicker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _recordingDuration += const Duration(milliseconds: 100);
      if (mounted) {
        setState(() {});
      }
    });

    _amplitudeSubscription = _audioRecorder
        .amplitudeStream(interval: const Duration(milliseconds: 90))
        .listen(
      (amplitude) {
        final normalizedSample = _normalizeAmplitude(amplitude);
        _waveformSamples = [
          ..._waveformSamples.skip(1),
          normalizedSample,
        ];

        if (mounted) {
          setState(() {});
        }
      },
      onError: (error) {
        print(
            '⚠️ NutritionAssistantSpeechMixin - Erro ao ler amplitude do áudio: $error');
      },
    );
  }

  void _stopRecordingVisualizer() {
    _recordingTicker?.cancel();
    _recordingTicker = null;
    _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
    _recordingDuration = Duration.zero;
    _waveformSamples = List<double>.filled(18, 0.18);
  }

  double _normalizeAmplitude(double amplitude) {
    const minDb = -45.0;
    const maxDb = 0.0;
    final clamped = amplitude.clamp(minDb, maxDb);
    final normalized = (clamped - minDb) / (maxDb - minDb);

    return (0.18 + (normalized * 0.82)).clamp(0.18, 1.0);
  }
}
