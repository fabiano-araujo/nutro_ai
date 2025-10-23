import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:record/record.dart' as rec;

class AudioRecorder {
  final _audioRecorder = rec.AudioRecorder();
  final _audioPlayer = AssetsAudioPlayer();
  String? _recordedFilePath;
  bool _isRecording = false;
  bool _isPlaying = false;

  /// Initialize the recorder
  Future<void> init() async {
    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) {
      throw Exception('Microphone permission not granted');
    }
  }

  /// Start recording audio
  Future<void> startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final rec.AudioEncoder encoder;
        if (kIsWeb) {
          _recordedFilePath = '';
          encoder = rec.AudioEncoder.opus;
        } else {
          final dir = await getApplicationDocumentsDirectory();
          _recordedFilePath =
              '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
          encoder = rec.AudioEncoder.aacLc;
        }
        await _audioRecorder.start(
          rec.RecordConfig(encoder: encoder),
          path: _recordedFilePath!,
        );
        _isRecording = true;
      }
    } catch (e) {
      print('Error starting recording: $e');
      _isRecording = false;
    }
  }

  /// Stop recording audio
  Future<String?> stopRecording() async {
    try {
      if (_isRecording) {
        _recordedFilePath = await _audioRecorder.stop();
        _isRecording = false;
        return _recordedFilePath;
      }
      return null;
    } catch (e) {
      print('Error stopping recording: $e');
      _isRecording = false;
      return null;
    }
  }

  /// Play recorded audio
  Future<void> playRecording() async {
    if (_recordedFilePath != null && _recordedFilePath!.isNotEmpty) {
      try {
        if (kIsWeb) {
          await _audioPlayer.open(
            Audio.network(_recordedFilePath!),
            autoStart: true,
          );
        } else {
          await _audioPlayer.open(
            Audio.file(_recordedFilePath!),
            autoStart: true,
          );
        }
        _isPlaying = true;

        // Update playing status when audio completes
        _audioPlayer.playlistAudioFinished.listen((_) {
          _isPlaying = false;
        });
      } catch (e) {
        print('Error playing recording: $e');
        _isPlaying = false;
      }
    }
  }

  /// Stop playing audio
  Future<void> stopPlaying() async {
    try {
      await _audioPlayer.stop();
      _isPlaying = false;
    } catch (e) {
      print('Error stopping playback: $e');
    }
  }

  /// Delete recorded audio file
  Future<void> deleteRecording() async {
    if (_recordedFilePath != null) {
      if (!kIsWeb) {
        try {
          final file = File(_recordedFilePath!);
          if (await file.exists()) {
            await file.delete();
          }
          _recordedFilePath = null;
        } catch (e) {
          print('Error deleting recording: $e');
        }
      } else {
        _recordedFilePath = null;
      }
    }
  }

  /// Check if currently recording
  bool get isRecording => _isRecording;

  /// Check if currently playing
  bool get isPlaying => _isPlaying;

  /// Get the path of recorded file
  String? get recordedFilePath => _recordedFilePath;

  /// Dispose resources
  Future<void> dispose() async {
    await _audioPlayer.dispose();
    await _audioRecorder.dispose();
  }
}
