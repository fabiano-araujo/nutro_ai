import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../services/diet_generation_background_service.dart';

class ProfileShapePreviewProvider extends ChangeNotifier {
  static const Duration _jobPollInterval = Duration(seconds: 3);
  static const Duration _jobWaitTimeout = Duration(minutes: 8);

  ProfileShapeGenerationBackgroundTask? _activeJob;
  bool _isGenerating = false;
  bool _isPolling = false;
  String? _generatedImageUrl;
  String? _error;
  Map<String, dynamic>? _pendingCredits;
  late final Future<void> _loadFuture;

  ProfileShapePreviewProvider() {
    _loadFuture = _loadActiveJob();
  }

  bool get isGenerating => _isGenerating || _activeJob != null;
  bool get hasActiveProfileShapeGenerationJob => _activeJob != null;
  String? get activeProfileShapeGenerationJobId => _activeJob?.taskId;
  String? get generatedImageUrl => _generatedImageUrl;
  String? get error => _error;

  Future<void> ensureLoaded() => _loadFuture;

  static String storageKey(int userId) =>
      'profile_shape_preview_url_user_$userId';

  Map<String, dynamic>? takePendingCredits() {
    final credits = _pendingCredits;
    _pendingCredits = null;
    return credits;
  }

  Future<Map<String, dynamic>?> startGeneration({
    required int userId,
    required String token,
    required Uint8List imageBytes,
    required String languageCode,
  }) async {
    await ensureLoaded();

    if (_activeJob != null) {
      return _resumeActiveProfileShapeJob();
    }

    _isGenerating = true;
    _error = null;
    notifyListeners();

    try {
      final imageBase64 = 'data:image/jpeg;base64,${base64Encode(imageBytes)}';

      if (kIsWeb) {
        final data = await ApiService.generateProfileShapePreview(
          token: token,
          imageBytes: imageBytes,
          language: languageCode,
        );
        await _finishGenerationData(userId: userId, data: data);
        return data;
      }

      final job = await ProfileShapeGenerationBackgroundService.startGeneration(
        userId: userId.toString(),
        imageBase64: imageBase64,
        languageCode: languageCode,
      );
      _activeJob = job;
      notifyListeners();

      return _resumeActiveProfileShapeJob();
    } catch (e) {
      _isGenerating = false;
      _error = _formatError(e);
      notifyListeners();
      return null;
    }
  }

  Future<void> refreshActiveProfileShapeGenerationJob() async {
    await ensureLoaded();

    ProfileShapeGenerationBackgroundTask? latestJob;
    try {
      latestJob =
          await ProfileShapeGenerationBackgroundService.readActiveTask();
    } catch (e) {
      debugPrint('Erro ao atualizar geração de shape: $e');
      return;
    }

    if (latestJob == null) {
      final hadActiveJob = _activeJob != null;
      _activeJob = null;
      if (hadActiveJob) {
        _isGenerating = false;
        notifyListeners();
      }
      return;
    }

    _activeJob = latestJob;
    if (latestJob.isTerminal) {
      await _handleTerminalJob(latestJob);
    } else {
      unawaited(_resumeActiveProfileShapeJob());
    }
  }

  Future<void> stopActiveGeneration() async {
    _activeJob = null;
    _isGenerating = false;
    await ProfileShapeGenerationBackgroundService.stopActiveGeneration();
    notifyListeners();
  }

  Future<void> clearAll() async {
    _activeJob = null;
    _isGenerating = false;
    _error = null;
    _generatedImageUrl = null;
    _pendingCredits = null;
    await ProfileShapeGenerationBackgroundService.stopActiveGeneration();
    notifyListeners();
  }

  Future<void> _loadActiveJob() async {
    try {
      final latestJob =
          await ProfileShapeGenerationBackgroundService.readActiveTask();
      if (latestJob == null) return;

      _activeJob = latestJob;
      if (latestJob.isTerminal) {
        await _handleTerminalJob(latestJob);
      } else {
        _isGenerating = true;
        unawaited(_resumeActiveProfileShapeJob());
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Erro ao carregar geração de shape: $e');
    }
  }

  Future<Map<String, dynamic>?> _resumeActiveProfileShapeJob() async {
    if (_isPolling || _activeJob == null) {
      return null;
    }

    final job = _activeJob!;
    _isPolling = true;
    _isGenerating = true;
    _error = null;
    notifyListeners();

    if (!kIsWeb) {
      await ProfileShapeGenerationBackgroundService.resumeActiveGeneration();
    }

    try {
      final completedJob = await _waitForProfileShapeJob(job);
      if (_activeJob?.taskId != job.taskId) {
        return null;
      }

      final data = completedJob.responseData;
      if (data == null) {
        throw Exception('A geração finalizou sem imagem.');
      }

      await _clearActiveJob(job.taskId);
      final parsedUserId = int.tryParse(completedJob.userId);
      if (parsedUserId != null) {
        await _finishGenerationData(userId: parsedUserId, data: data);
      } else {
        await _finishGenerationData(userId: null, data: data);
      }
      return data;
    } catch (e) {
      if (_activeJob?.taskId == job.taskId) {
        _isGenerating = false;
        _error = _formatError(e);
        await _clearActiveJob(job.taskId);
        notifyListeners();
      }
      return null;
    } finally {
      _isPolling = false;
    }
  }

  Future<ProfileShapeGenerationBackgroundTask> _waitForProfileShapeJob(
    ProfileShapeGenerationBackgroundTask job,
  ) async {
    final deadline = DateTime.now().add(_jobWaitTimeout);
    Object? lastPollingError;

    while (DateTime.now().isBefore(deadline)) {
      ProfileShapeGenerationBackgroundTask? latestJob;
      try {
        latestJob =
            await ProfileShapeGenerationBackgroundService.readActiveTask();
        lastPollingError = null;
      } catch (e) {
        lastPollingError = e;
        await Future.delayed(_jobPollInterval);
        continue;
      }

      if (latestJob == null) {
        throw Exception('Serviço de geração de shape não encontrado');
      }

      if (latestJob.taskId != job.taskId) {
        throw Exception('Há outra geração de shape em andamento');
      }

      if (latestJob.status ==
          ProfileShapeGenerationBackgroundTask.statusCompleted) {
        return latestJob;
      }

      if (latestJob.status ==
              ProfileShapeGenerationBackgroundTask.statusFailed ||
          latestJob.status ==
              ProfileShapeGenerationBackgroundTask.statusCancelled) {
        throw Exception(
          latestJob.error ??
              'Geração de shape finalizada com status ${latestJob.status}',
        );
      }

      if (_activeJob?.taskId == latestJob.taskId) {
        _activeJob = latestJob;
        notifyListeners();
      }

      await Future.delayed(_jobPollInterval);
    }

    throw Exception(
      lastPollingError != null
          ? 'Tempo limite ao consultar a geração do shape: $lastPollingError'
          : 'Tempo limite ao aguardar a geração do shape',
    );
  }

  Future<void> _handleTerminalJob(
    ProfileShapeGenerationBackgroundTask job,
  ) async {
    await _clearActiveJob(job.taskId);

    if (job.status == ProfileShapeGenerationBackgroundTask.statusCompleted &&
        job.responseData != null) {
      await _finishGenerationData(
        userId: int.tryParse(job.userId),
        data: job.responseData!,
      );
      return;
    } else if (job.status ==
            ProfileShapeGenerationBackgroundTask.statusFailed ||
        job.status == ProfileShapeGenerationBackgroundTask.statusCancelled) {
      _error = _formatError(job.error ?? 'Geração de shape cancelada');
    }

    _isGenerating = false;
    notifyListeners();
  }

  Future<void> _finishGenerationData({
    required int? userId,
    required Map<String, dynamic> data,
  }) async {
    final imageUrl = data['imageUrl']?.toString();
    if (imageUrl == null || imageUrl.trim().isEmpty) {
      throw Exception('Não foi possível localizar a imagem gerada.');
    }

    _generatedImageUrl = imageUrl;
    _pendingCredits = data['credits'] is Map
        ? Map<String, dynamic>.from(data['credits'] as Map)
        : null;
    _isGenerating = false;
    _error = null;

    if (userId != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(storageKey(userId), imageUrl);
    }

    notifyListeners();
  }

  Future<void> _clearActiveJob([String? jobId]) async {
    if (jobId != null && _activeJob?.taskId != jobId) {
      return;
    }

    _activeJob = null;
    await ProfileShapeGenerationBackgroundService.clearActiveTask();
  }

  String _formatError(Object error) {
    var message = error.toString().replaceFirst('Exception: ', '').trim();
    if (message.isEmpty) {
      message = 'Não foi possível gerar sua prévia agora.';
    }
    return message;
  }
}
