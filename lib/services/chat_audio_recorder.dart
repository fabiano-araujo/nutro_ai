import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart' as record;

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
  final record.AudioRecorder _audioRecorder = record.AudioRecorder();

  String? _recordedFilePath;
  String _mimeType = 'audio/m4a';
  String _fileExtension = 'm4a';

  Future<void> init() async {
    if (kIsWeb) {
      return;
    }

    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      throw Exception('Microphone permission not granted');
    }
  }

  Future<bool> hasPermission() async {
    if (kIsWeb) {
      return false;
    }

    return _audioRecorder.hasPermission();
  }

  Future<void> startRecording() async {
    if (kIsWeb) {
      throw UnsupportedError('Audio recording is not supported on web');
    }

    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      throw Exception('Microphone permission not granted');
    }

    final dir = await getTemporaryDirectory();
    _fileExtension = 'm4a';
    _mimeType = 'audio/m4a';
    _recordedFilePath =
        '${dir.path}/chat_audio_${DateTime.now().millisecondsSinceEpoch}.$_fileExtension';

    await _audioRecorder.start(
      const record.RecordConfig(
        encoder: record.AudioEncoder.aacLc,
        sampleRate: 16000,
        bitRate: 128000,
      ),
      path: _recordedFilePath!,
    );
  }

  Future<RecordedAudioData?> stopRecording() async {
    if (kIsWeb) {
      return null;
    }

    final path = await _audioRecorder.stop();
    final resolvedPath = path ?? _recordedFilePath;
    if (resolvedPath == null || resolvedPath.isEmpty) {
      return null;
    }

    final file = File(resolvedPath);
    if (!await file.exists()) {
      return null;
    }

    final bytes = await file.readAsBytes();
    await _deleteFileIfExists(resolvedPath);
    _recordedFilePath = null;

    return RecordedAudioData(
      bytes: bytes,
      mimeType: _mimeType,
      fileExtension: _fileExtension,
    );
  }

  Future<void> cancelRecording() async {
    if (kIsWeb) {
      return;
    }

    final path = await _audioRecorder.stop();
    await _deleteFileIfExists(path ?? _recordedFilePath);
    _recordedFilePath = null;
  }

  Future<void> dispose() async {
    if (!kIsWeb) {
      await _audioRecorder.dispose();
    }
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
}
