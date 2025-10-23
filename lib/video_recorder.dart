import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoRecorder {
  VideoPlayerController? _videoController;
  String? _videoPath;

  /// Initialize video player for a specific file
  Future<void> initializePlayer(String filePath) async {
    _videoController?.dispose();
    _videoPath = filePath;
    _videoController = VideoPlayerController.file(File(filePath));
    await _videoController?.initialize();
  }

  /// Get preview widget for video
  Widget? getVideoPreview() {
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return null;
    }
    return AspectRatio(
      aspectRatio: _videoController!.value.aspectRatio,
      child: VideoPlayer(_videoController!),
    );
  }

  /// Play the video
  Future<void> play() async {
    await _videoController?.play();
  }

  /// Pause the video
  Future<void> pause() async {
    await _videoController?.pause();
  }

  /// Get the current video path
  String? get videoPath => _videoPath;

  /// Dispose resources
  Future<void> dispose() async {
    await _videoController?.dispose();
    _videoController = null;
  }
}
