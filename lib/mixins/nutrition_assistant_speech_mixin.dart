import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable, kIsWeb;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../screens/nutrition_assistant_screen.dart';
import '../services/ai_service.dart';
import '../services/chat_audio_recorder.dart';
import '../utils/audio_transcript_sanitizer.dart';
import '../utils/ui_utils.dart';

class AudioCaptureUiState {
  const AudioCaptureUiState({
    this.isListening = false,
    this.isTranscribingAudio = false,
  });

  final bool isListening;
  final bool isTranscribingAudio;
}

// Mixin para encapsular a lógica de gravação e transcrição de voz do chat
mixin NutritionAssistantSpeechMixin on State<NutritionAssistantScreen> {
  static const Duration _audioCaptureTimeout = Duration(minutes: 5);
  static const String _micPerfTag = '[MIC_PERF]';
  static const int _waveformSampleCount = 33;
  static const double _waveformIdleSample = 0.025;

  final ChatAudioRecorder _audioRecorder = ChatAudioRecorder();
  final AIService _aiService = AIService();

  bool _isListening = false;
  bool _isTranscribingAudio = false;
  String _recognizedText = '';
  String _committedRecognizedText = '';
  Timer? _autoStopTimer;
  Stopwatch? _recordingStopwatch;
  StreamSubscription<double>? _amplitudeSubscription;
  Future<void>? _startRecordingOperation;
  bool _isPreparingAudioCapture = false;
  bool _cancelPendingStart = false;
  bool _microphonePermissionReady = false;
  double _waveformVisualIntensity = _waveformIdleSample;
  double _waveformCenterImpulse = 0.0;
  double _waveformPulsePhase = 0.0;
  Duration _recordingDuration = Duration.zero;
  List<double> _waveformSamples =
      List<double>.filled(_waveformSampleCount, _waveformIdleSample);
  final ValueNotifier<AudioCaptureUiState> _audioCaptureUiStateNotifier =
      ValueNotifier<AudioCaptureUiState>(const AudioCaptureUiState());
  final ValueNotifier<List<double>> _waveformSamplesNotifier =
      ValueNotifier<List<double>>(
    List<double>.unmodifiable(
      List<double>.filled(_waveformSampleCount, _waveformIdleSample),
    ),
  );

  bool get isListening => _isListening;
  bool get isTranscribingAudio => _isTranscribingAudio;
  String get recognizedText => _recognizedText;
  Duration get recordingDuration => _recordingDuration;
  List<double> get waveformSamples =>
      List<double>.unmodifiable(_waveformSamples);
  ValueListenable<AudioCaptureUiState> get audioCaptureUiStateListenable =>
      _audioCaptureUiStateNotifier;
  ValueListenable<List<double>> get waveformSamplesListenable =>
      _waveformSamplesNotifier;

  TextEditingController get messageController;
  AnimationController get animationController;
  void keepScreenOn(bool keepOn);
  void incrementAndroidUpdateCounter();
  int get androidUpdateCounter;

  void _setAudioCaptureUiState({
    bool? isListening,
    bool? isTranscribingAudio,
  }) {
    final nextIsListening = isListening ?? _isListening;
    final nextIsTranscribingAudio = isTranscribingAudio ?? _isTranscribingAudio;

    if (_isListening == nextIsListening &&
        _isTranscribingAudio == nextIsTranscribingAudio) {
      return;
    }

    _isListening = nextIsListening;
    _isTranscribingAudio = nextIsTranscribingAudio;

    if (mounted) {
      _audioCaptureUiStateNotifier.value = AudioCaptureUiState(
        isListening: nextIsListening,
        isTranscribingAudio: nextIsTranscribingAudio,
      );
    }
  }

  Future<void> initSpeechRecognition() async {
    print('🎤 NutritionAssistantSpeechMixin - Inicializando captura de áudio');

    try {
      if (!kIsWeb && Platform.isAndroid) {
        final status = await Permission.microphone.status;
        _microphonePermissionReady = status.isGranted;
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

  void startListening({
    bool preserveCurrentText = false,
    bool lowLatencyMode = false,
    Stopwatch? performanceStopwatch,
  }) async {
    final perf = performanceStopwatch ?? (Stopwatch()..start());
    _logMicPerf(
      perf,
      'startListening_enter preserve=$preserveCurrentText lowLatency=$lowLatencyMode',
    );

    if (_isListening ||
        _isTranscribingAudio ||
        _isPreparingAudioCapture ||
        _startRecordingOperation != null) {
      _logMicPerf(
        perf,
        'startListening_ignored listening=$_isListening transcribing=$_isTranscribingAudio preparing=$_isPreparingAudioCapture pendingStart=${_startRecordingOperation != null}',
      );
      return;
    }

    try {
      _autoStopTimer?.cancel();
      _cancelPendingStart = false;
      _isPreparingAudioCapture = true;
      _logMicPerf(perf, 'state_preparing_set');

      if (!preserveCurrentText) {
        if (mounted) {
          _committedRecognizedText = '';
          _recognizedText = '';
          messageController.clear();
          _setAudioCaptureUiState(
            isListening: true,
            isTranscribingAudio: false,
          );
          _logMicPerf(perf, 'ui_state_listening_set');
        }
      } else {
        final currentText = messageController.text;
        if (mounted) {
          _committedRecognizedText = normalizeTranscriptSpacing(currentText);
          _recognizedText = _committedRecognizedText;
          _setAudioCaptureUiState(
            isListening: true,
            isTranscribingAudio: false,
          );
          _logMicPerf(perf, 'ui_state_listening_set');
        }
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _logMicPerf(perf, 'ui_frame_after_listening_state');
        }
      });

      _autoStopTimer = Timer(_audioCaptureTimeout, () {
        if (_isListening) {
          stopListening();
        }
      });

      animationController.duration = const Duration(milliseconds: 600);
      animationController.repeat(reverse: true);
      keepScreenOn(true);
      _startRecordingVisualizer(listenForAmplitude: false);
      _logMicPerf(perf, 'local_visualizer_started');

      _logMicPerf(perf, 'await_recording_ui_frame_start');
      await WidgetsBinding.instance.endOfFrame;
      _logMicPerf(perf, 'await_recording_ui_frame_done');

      if (_cancelPendingStart || !_isListening) {
        _logMicPerf(perf, 'cancelled_after_recording_ui_frame');
        _resetPendingRecordingUi();
        return;
      }

      final hasPermission = await _ensureMicrophonePermissionForRecording(perf);
      if (!hasPermission) {
        return;
      }

      if (_cancelPendingStart || !_isListening) {
        _logMicPerf(perf, 'cancelled_before_record_start');
        _resetPendingRecordingUi();
        return;
      }

      _logMicPerf(perf, 'record_start_call');
      final startOperation =
          _audioRecorder.startRecording(verifyPermission: false);
      _startRecordingOperation = startOperation;
      await startOperation;
      _logMicPerf(perf, 'record_start_completed');
      if (identical(_startRecordingOperation, startOperation)) {
        _startRecordingOperation = null;
      }
      _isPreparingAudioCapture = false;

      if (_cancelPendingStart || !_isListening) {
        _logMicPerf(perf, 'cancelled_after_record_start');
        await _audioRecorder.cancelRecording();
        _resetPendingRecordingUi();
        return;
      }

      _startAmplitudeVisualizer(perf);
      _logMicPerf(perf, 'amplitude_listener_started');

      print('🎤 NutritionAssistantSpeechMixin - Captura de áudio iniciada' +
          (preserveCurrentText ? ' (preservando texto anterior)' : '') +
          (lowLatencyMode ? ' (modo baixa latência)' : ''));
      _logMicPerf(perf, 'startListening_done');
    } catch (e) {
      _logMicPerf(perf, 'startListening_error $e');
      _startRecordingOperation = null;
      _isPreparingAudioCapture = false;
      _autoStopTimer?.cancel();
      _stopRecordingVisualizer();
      print(
          '❌ NutritionAssistantSpeechMixin - Erro ao iniciar gravação de áudio: $e');
      if (!_cancelPendingStart) {
        UIUtils.showSimpleToast(context, 'Erro ao iniciar a gravação de áudio');
      }
      keepScreenOn(false);
      _setAudioCaptureUiState(
        isListening: false,
        isTranscribingAudio: false,
      );
    }
  }

  Future<void> stopListening() async {
    _autoStopTimer?.cancel();
    final capturedDuration = _currentRecordingDuration();
    final pendingStart = _startRecordingOperation;
    final wasPreparingAudioCapture =
        _isPreparingAudioCapture && pendingStart == null;
    _cancelPendingStart = true;

    if (!_isListening && pendingStart == null) {
      return;
    }

    keepScreenOn(false);

    if (wasPreparingAudioCapture) {
      _isPreparingAudioCapture = false;
      _stopRecordingVisualizer();
      _setAudioCaptureUiState(
        isListening: false,
        isTranscribingAudio: false,
      );
      return;
    }

    _setAudioCaptureUiState(
      isListening: false,
      isTranscribingAudio: true,
    );
    _stopRecordingVisualizer();

    try {
      if (pendingStart != null) {
        await pendingStart;
        if (identical(_startRecordingOperation, pendingStart)) {
          _startRecordingOperation = null;
        }
      }

      final recordedAudio = await _audioRecorder.stopRecording();

      if (recordedAudio == null || recordedAudio.bytes.isEmpty) {
        UIUtils.showSimpleToast(context, 'Nenhum áudio foi capturado');
        _setAudioCaptureUiState(isTranscribingAudio: false);
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
        audioDurationMs: capturedDuration.inMilliseconds,
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
      _startRecordingOperation = null;
      _isPreparingAudioCapture = false;
      _cancelPendingStart = false;
      _setAudioCaptureUiState(isTranscribingAudio: false);
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
      final pendingStart = _startRecordingOperation;
      if (_isPreparingAudioCapture || pendingStart != null) {
        _cancelPendingStart = true;
      }
      if (pendingStart != null) {
        try {
          await pendingStart;
        } catch (_) {}
      }
      _startRecordingOperation = null;
      _isPreparingAudioCapture = false;
      _cancelPendingStart = false;

      if (_isListening || pendingStart != null) {
        await _audioRecorder.cancelRecording();
      }

      _setAudioCaptureUiState(
        isListening: false,
        isTranscribingAudio: false,
      );
    } catch (e) {
      print('⚠️ NutritionAssistantSpeechMixin - Erro ao liberar áudio: $e');
    }
  }

  void disposeSpeechResources() {
    _autoStopTimer?.cancel();
    _stopRecordingVisualizer();
    keepScreenOn(false);
    if (_isListening || _startRecordingOperation != null) {
      _cancelPendingStart = true;
      unawaited(_audioRecorder.cancelRecording());
    }
    _startRecordingOperation = null;
    _isPreparingAudioCapture = false;
    unawaited(_audioRecorder.dispose());
    _audioCaptureUiStateNotifier.dispose();
    _waveformSamplesNotifier.dispose();
  }

  void _startRecordingVisualizer({bool listenForAmplitude = true}) {
    _recordingStopwatch?.stop();
    _amplitudeSubscription?.cancel();
    _recordingDuration = Duration.zero;
    _recordingStopwatch = Stopwatch()..start();
    _waveformVisualIntensity = _waveformIdleSample;
    _waveformCenterImpulse = 0.0;
    _waveformPulsePhase = 0.0;
    _setWaveformSamples(_buildWaveformSamples(_waveformIdleSample));

    if (!listenForAmplitude) {
      return;
    }

    _startAmplitudeVisualizer();
  }

  void _startAmplitudeVisualizer([Stopwatch? performanceStopwatch]) {
    _amplitudeSubscription?.cancel();
    var loggedFirstAmplitude = false;
    _amplitudeSubscription = _audioRecorder
        .amplitudeStream(interval: const Duration(milliseconds: 58))
        .listen(
      (amplitude) {
        if (!loggedFirstAmplitude) {
          loggedFirstAmplitude = true;
          final perf = performanceStopwatch;
          if (perf != null) {
            _logMicPerf(perf, 'first_amplitude_sample');
          }
        }
        final rawIntensity = _normalizeAmplitude(amplitude);
        final voiceEnergy =
            ((rawIntensity - 0.18) / 0.82).clamp(0.0, 1.0).toDouble();
        final targetIntensity = voiceEnergy <= 0.0
            ? _waveformIdleSample
            : _waveformIdleSample + (voiceEnergy * 0.96);
        final risingDelta =
            (targetIntensity - _waveformVisualIntensity).clamp(0.0, 1.0);
        final smoothing = targetIntensity > _waveformVisualIntensity
            ? (voiceEnergy > 0.55 ? 0.90 : 0.70)
            : 0.52;
        _waveformVisualIntensity +=
            (targetIntensity - _waveformVisualIntensity) * smoothing;
        _waveformCenterImpulse = math.max(
          _waveformCenterImpulse * (voiceEnergy > 0.35 ? 0.60 : 0.38),
          math.max(
            risingDelta * 1.05 * voiceEnergy,
            math.pow(voiceEnergy, 1.35).toDouble() * 0.22,
          ),
        );
        _waveformPulsePhase =
            (_waveformPulsePhase + 0.14 + (voiceEnergy * 0.58)) % (math.pi * 2);

        if (voiceEnergy <= 0.02 && _waveformVisualIntensity <= 0.08) {
          _waveformVisualIntensity = _waveformIdleSample;
          _waveformCenterImpulse *= 0.25;
        }

        _setWaveformSamples(
          _buildWaveformSamples(
            _waveformVisualIntensity,
            centerImpulse: _waveformCenterImpulse,
            phase: _waveformPulsePhase,
          ),
        );
      },
      onError: (error) {
        print(
            '⚠️ NutritionAssistantSpeechMixin - Erro ao ler amplitude do áudio: $error');
      },
    );
  }

  void _stopRecordingVisualizer() {
    _recordingStopwatch?.stop();
    _recordingStopwatch = null;
    _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
    _recordingDuration = Duration.zero;
    _waveformVisualIntensity = _waveformIdleSample;
    _waveformCenterImpulse = 0.0;
    _waveformPulsePhase = 0.0;
    _setWaveformSamples(_buildWaveformSamples(_waveformIdleSample));
  }

  void _resetPendingRecordingUi() {
    _autoStopTimer?.cancel();
    _isPreparingAudioCapture = false;
    _cancelPendingStart = false;
    _startRecordingOperation = null;
    _stopRecordingVisualizer();
    keepScreenOn(false);
    _setAudioCaptureUiState(
      isListening: false,
      isTranscribingAudio: false,
    );
  }

  double _normalizeAmplitude(double amplitude) {
    const minDb = -58.0;
    const maxDb = -9.0;
    final clamped = amplitude.clamp(minDb, maxDb).toDouble();
    final normalized = (clamped - minDb) / (maxDb - minDb);
    final noiseReduced =
        ((normalized - 0.30) / 0.70).clamp(0.0, 1.0).toDouble();
    final boosted = math.pow(noiseReduced, 0.68).toDouble();

    return (_waveformIdleSample + (boosted * 0.96))
        .clamp(_waveformIdleSample, 1.0)
        .toDouble();
  }

  List<double> _buildWaveformSamples(
    double intensity, {
    double centerImpulse = 0.0,
    double phase = 0.0,
  }) {
    final clampedIntensity = intensity.clamp(0.0, 1.0).toDouble();
    final clampedImpulse = centerImpulse.clamp(0.0, 1.0).toDouble();
    final voiceAmount =
        ((clampedIntensity - _waveformIdleSample) / (1.0 - _waveformIdleSample))
            .clamp(0.0, 1.0)
            .toDouble();

    return List<double>.generate(_waveformSampleCount, (index) {
      final position = index / (_waveformSampleCount - 1);
      final distanceFromCenter =
          ((position - 0.5).abs() * 2).clamp(0.0, 1.0).toDouble();
      final centerBias =
          math.exp(-math.pow(distanceFromCenter / 0.72, 2).toDouble());
      final waveA = (math.sin((position * math.pi * 4.3) - phase) + 1.0) * 0.5;
      final waveB =
          (math.sin((position * math.pi * 7.1) + (phase * 1.35)) + 1.0) * 0.5;
      final waveC =
          (math.sin((position * math.pi * 2.0) + (phase * 0.72)) + 1.0) * 0.5;
      final travelingPeakCenter = 0.5 + (math.sin(phase * 0.82) * 0.28);
      final travelingPeak = math
          .exp(
              -math.pow((position - travelingPeakCenter) / 0.115, 2).toDouble())
          .toDouble();
      final sidePeak = math.max(
        math.exp(-math.pow((position - 0.25) / 0.105, 2).toDouble()),
        math.exp(-math.pow((position - 0.75) / 0.105, 2).toDouble()),
      );
      final centerSpikeWeight =
          math.exp(-math.pow(distanceFromCenter / 0.14, 2).toDouble());

      final movingWave =
          ((waveA * 0.42) + (waveB * 0.28) + (waveC * 0.18)).clamp(0.0, 1.0);
      final voiceShape = (0.16 +
              (centerBias * 0.36) +
              (movingWave * 0.34) +
              (travelingPeak * 0.30) +
              (sidePeak * movingWave * 0.22))
          .clamp(0.0, 1.35)
          .toDouble();

      final idleMotion = movingWave * (0.004 + (voiceAmount * 0.012));
      final liveWave = _waveformIdleSample +
          idleMotion +
          (voiceShape * voiceAmount * 0.82) +
          (centerSpikeWeight * clampedImpulse * 0.32);

      return liveWave.clamp(0.018, 1.0).toDouble();
    });
  }

  Duration _currentRecordingDuration() {
    final stopwatch = _recordingStopwatch;
    return stopwatch == null ? _recordingDuration : stopwatch.elapsed;
  }

  void _setWaveformSamples(List<double> samples) {
    final nextSamples = List<double>.unmodifiable(samples);
    _waveformSamples = nextSamples;
    if (mounted) {
      _waveformSamplesNotifier.value = nextSamples;
    }
  }

  Future<bool> _ensureMicrophonePermissionForRecording(Stopwatch perf) async {
    if (kIsWeb) {
      _logMicPerf(perf, 'permission_web_hasPermission_call');
      final granted = await _audioRecorder.hasPermission(request: true);
      _logMicPerf(perf, 'permission_web_hasPermission_done granted=$granted');
      if (!granted) {
        _resetPendingRecordingUi();
        UIUtils.showErrorDialog(context, 'Permissão do microfone negada');
      }
      return granted;
    }

    if (_microphonePermissionReady) {
      _logMicPerf(perf, 'permission_cached_granted');
      return true;
    }

    _logMicPerf(perf, 'permission_status_call');
    var status = await Permission.microphone.status;
    _logMicPerf(perf, 'permission_status_done status=$status');

    if (status.isGranted) {
      _microphonePermissionReady = true;
      return true;
    }

    if (status.isPermanentlyDenied) {
      _resetPendingRecordingUi();
      UIUtils.showPermissionDialog(context, permanentlyDenied: true);
      return false;
    }

    _logMicPerf(perf, 'permission_request_call');
    status = await Permission.microphone.request();
    _logMicPerf(perf, 'permission_request_done status=$status');

    if (status.isGranted) {
      _microphonePermissionReady = true;
      return true;
    }

    _resetPendingRecordingUi();
    if (status.isPermanentlyDenied) {
      UIUtils.showPermissionDialog(context, permanentlyDenied: true);
    } else {
      UIUtils.showPermissionDialog(context);
    }
    return false;
  }

  void _logMicPerf(Stopwatch stopwatch, String event) {
    debugPrint('$_micPerfTag ${stopwatch.elapsedMilliseconds}ms $event');
  }
}
