import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart' as record;

import '../utils/blob_url_helper.dart' as blob_url_helper;

class RecordedAudioData {
  const RecordedAudioData({
    required this.bytes,
    required this.mimeType,
    required this.fileExtension,
  });

  final Uint8List bytes;
  final String mimeType;
  final String fileExtension;
}

class ChatAudioRecorder {
  record.AudioRecorder? _audioRecorder;

  String? _recordedFilePath;
  String _mimeType = 'audio/wav';
  String _fileExtension = 'wav';

  Future<void> init() async {
    _ensureRecorder();
  }

  Future<bool> hasPermission({bool request = true}) async {
    return _ensureRecorder().hasPermission(request: request);
  }

  Stream<double> amplitudeStream(
      {Duration interval = const Duration(milliseconds: 120)}) {
    if (_audioRecorder == null) {
      return const Stream<double>.empty();
    }

    return _audioRecorder!.onAmplitudeChanged(interval).map((amplitude) {
      if (amplitude.current.isNaN || amplitude.current.isInfinite) {
        return -45.0;
      }

      return amplitude.current;
    });
  }

  Future<void> startRecording() async {
    await _disposeRecorder();
    final recorder = _ensureRecorder();

    final hasPermission = await recorder.hasPermission();
    if (!hasPermission) {
      throw Exception('Microphone permission not granted');
    }

    _fileExtension = 'wav';
    _mimeType = 'audio/wav';
    if (kIsWeb) {
      _recordedFilePath = null;
    } else {
      final dir = await getTemporaryDirectory();
      _recordedFilePath =
          '${dir.path}/chat_audio_${DateTime.now().millisecondsSinceEpoch}.$_fileExtension';
    }

    await recorder.start(
      const record.RecordConfig(
        encoder: record.AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: _recordedFilePath ?? '',
    );
  }

  Future<RecordedAudioData?> stopRecording() async {
    final recorder = _audioRecorder;
    final activePath = _recordedFilePath;
    final returnedPath = await recorder?.stop();
    final resolvedPath = activePath ?? returnedPath;

    await _disposeRecorder();

    if (resolvedPath == null || resolvedPath.isEmpty) {
      return null;
    }

    Uint8List bytes;
    if (kIsWeb) {
      try {
        bytes = await blob_url_helper.readObjectUrlBytes(resolvedPath);
      } finally {
        blob_url_helper.revokeObjectUrl(resolvedPath);
      }
    } else {
      final file = File(resolvedPath);
      if (!await file.exists()) {
        return null;
      }

      bytes = await file.readAsBytes();
      await _deleteFileIfExists(resolvedPath);
    }

    _recordedFilePath = null;

    return RecordedAudioData(
      bytes: bytes,
      mimeType: _mimeType,
      fileExtension: _fileExtension,
    );
  }

  Future<void> cancelRecording() async {
    final activePath = _recordedFilePath;
    final recorder = _audioRecorder;

    if (recorder != null) {
      await recorder.cancel();
    }

    await _disposeRecorder();
    if (!kIsWeb) {
      await _deleteFileIfExists(activePath);
    }
    _recordedFilePath = null;
  }

  Future<void> dispose() async {
    await _disposeRecorder();
  }

  Future<void> _deleteFileIfExists(String? path) async {
    if (path == null || path.isEmpty) {
      return;
    }

    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  record.AudioRecorder _ensureRecorder() {
    return _audioRecorder ??= record.AudioRecorder();
  }

  Future<void> _disposeRecorder() async {
    final recorder = _audioRecorder;
    _audioRecorder = null;

    if (recorder != null) {
      await recorder.dispose();
    }
  }
}
