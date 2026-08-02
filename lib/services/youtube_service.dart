import 'dart:ui' show Locale;

import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../i18n/app_localizations.dart';
import '../services/ai_service.dart';

class YouTubeService {
  // Cliente YouTube Explode
  static final YoutubeExplode _yt = YoutubeExplode();
  static final AIService _aiService = AIService(); // Instância do AIService

  static AppLocalizations _localizations(String languageCode) {
    final normalized = languageCode.trim().replaceAll('-', '_');
    final parts = normalized.split('_');
    final language = parts.first.toLowerCase();
    final country = parts.length > 1 ? parts[1].toUpperCase() : null;
    final locale = AppLocalizations.supportedLocales.firstWhere(
      (candidate) =>
          candidate.languageCode == language &&
          (country == null || candidate.countryCode == country),
      orElse: () => const Locale('pt', 'BR'),
    );
    return AppLocalizations(locale);
  }

  // Função para extrair o ID do vídeo de uma URL do YouTube
  static String extractVideoId(String url) {
    // Padrões de URL do YouTube:
    // - https://www.youtube.com/watch?v=VIDEO_ID
    // - https://youtu.be/VIDEO_ID
    // - https://youtube.com/shorts/VIDEO_ID

    RegExp regExp1 = RegExp(
        r'(?:youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/shorts\/)([^&\n?#]+)');
    Match? match = regExp1.firstMatch(url);

    if (match != null && match.groupCount >= 1) {
      return match.group(1)!;
    }

    // Se não conseguiu extrair, pode ser que a URL esteja em um formato diferente ou inválido
    return "";
  }

  // Função para obter a transcrição do vídeo usando YouTube Explode
  static Future<String> getTranscription(
    String videoId, {
    required String languageCode,
  }) async {
    try {
      // Verifica se a transcrição está em cache
      final prefs = await SharedPreferences.getInstance();
      final normalizedLanguage = languageCode
          .trim()
          .replaceAll('_', '-')
          .split('-')
          .first
          .toLowerCase();
      final cacheKey = 'transcript_${videoId}_$normalizedLanguage';
      final cachedTranscript = prefs.getString(cacheKey);

      if (cachedTranscript != null) {
        return cachedTranscript;
      }

      // Obtém a lista de legendas disponíveis
      final trackList = await _yt.videos.closedCaptions.getManifest(videoId);

      // Não inventa conteúdo quando o vídeo não fornece legendas.
      if (trackList.tracks.isEmpty) {
        return '';
      }

      // Prefere o idioma atual, depois inglês e por fim a primeira faixa.
      ClosedCaptionTrackInfo track;
      final preferredTracks = trackList.tracks.where((track) =>
          track.language.code.toLowerCase().startsWith(normalizedLanguage));
      if (preferredTracks.isEmpty) {
        final enTracks = trackList.tracks.where(
            (track) => track.language.code.toLowerCase().startsWith('en'));
        if (enTracks.isEmpty) {
          track = trackList.tracks.first;
        } else {
          track = enTracks.first;
        }
      } else {
        track = preferredTracks.first;
      }

      // Obtém as legendas
      final captionTrack = await _yt.videos.closedCaptions.get(track);

      // Converte as legendas em texto
      final transcriptBuilder = StringBuffer();

      for (final caption in captionTrack.captions) {
        transcriptBuilder.writeln(caption.text);
      }

      final transcript = transcriptBuilder.toString();

      // Armazena a transcrição em cache
      await prefs.setString(cacheKey, transcript);

      return transcript;
    } catch (e) {
      print('Erro ao obter transcrição do YouTube: $e');
      return '';
    }
  }

  // Método completo para obter informações do vídeo e transcrição (sem chamar a IA)
  static Future<Map<String, dynamic>> getVideoInfo(
    String url, {
    required String languageCode,
  }) async {
    try {
      // Extrai o ID do vídeo da URL
      final videoId = extractVideoId(url);
      if (videoId.isEmpty) {
        return {
          'success': false,
          'error': 'invalid_video_url',
        };
      }

      // Obtém informações básicas do vídeo
      final videoInfo = await _getBasicVideoInfo(
        videoId,
        languageCode: languageCode,
      );

      // Obtém a transcrição do vídeo
      final transcript = await getTranscription(
        videoId,
        languageCode: languageCode,
      );
      if (transcript.isEmpty) {
        return {
          'success': false,
          'error': 'transcript_unavailable',
          'videoInfo': videoInfo,
        };
      }

      // Retorna os dados do vídeo e transcrição sem gerar resumo
      return {
        'success': true,
        'videoInfo': videoInfo,
        'transcript': transcript,
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'video_processing_failed',
      };
    }
  }

  // Renomeado o método original de getVideoInfo para _getBasicVideoInfo
  static Future<Map<String, dynamic>> _getBasicVideoInfo(
    String videoId, {
    required String languageCode,
  }) async {
    try {
      // Usa o YouTube Explode para obter informações reais do vídeo
      final video = await _yt.videos.get(videoId);

      return {
        'title': video.title,
        'channel': video.author,
        'duration': _formatDuration(video.duration),
        'views': _formatViews(video.engagement.viewCount, languageCode),
        'thumbnail': video.thumbnails.highResUrl,
      };
    } catch (e) {
      print('Erro ao obter informações do vídeo: $e');
      final l10n = _localizations(languageCode);
      return {
        'title': l10n
            .translate('youtube_video_fallback_title')
            .replaceAll('{id}', videoId),
        'channel': l10n.translate('youtube_creator_channel'),
        'duration': '--:--',
        'views': '',
        'thumbnail': 'https://i.ytimg.com/vi/$videoId/maxresdefault.jpg',
      };
    }
  }

  // Formata a duração para exibição (HH:MM:SS)
  static String _formatDuration(Duration? duration) {
    if (duration == null) return '00:00';

    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));

    if (duration.inHours > 0) {
      return '${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds';
    } else {
      return '$twoDigitMinutes:$twoDigitSeconds';
    }
  }

  // Formata o número de visualizações para exibição
  static String _formatViews(int views, String languageCode) {
    final l10n = _localizations(languageCode);
    final locale = l10n.locale.toLanguageTag();
    final count = NumberFormat.compact(locale: locale).format(views);
    return l10n
        .translate(views == 1 ? 'youtube_views_one' : 'youtube_views_other')
        .replaceAll('{count}', count);
  }

  // Método para obter um resumo de um vídeo
  static Future<Map<String, dynamic>> getVideoSummary(
    String url, {
    required String languageCode,
  }) async {
    try {
      // Extrai o ID do vídeo da URL
      final videoId = extractVideoId(url);
      if (videoId.isEmpty) {
        return {
          'success': false,
          'error': 'invalid_video_url',
        };
      }

      // Obtém informações do vídeo
      final videoInfo = await _getBasicVideoInfo(
        videoId,
        languageCode: languageCode,
      );
      final videoTitle = videoInfo['title'] as String;

      // Obtém a transcrição do vídeo
      final transcript = await getTranscription(
        videoId,
        languageCode: languageCode,
      );
      if (transcript.isEmpty) {
        return {
          'success': false,
          'error': 'transcript_unavailable',
          'videoInfo': videoInfo,
        };
      }

      // Usa o AIService para resumir a transcrição
      final summary = await _aiService.summarizeYouTubeTranscript(
        transcript,
        videoTitle: videoTitle,
        languageCode: languageCode,
      );

      // Verifica se ocorreu algum erro
      if (summary.containsKey('error')) {
        return {
          'success': false,
          'error': summary['error'],
          'videoInfo': videoInfo,
          'transcript': transcript,
        };
      }

      // Retorna os dados do resumo junto com as informações do vídeo e transcrição completa
      return {
        'success': true,
        'videoInfo': videoInfo,
        'transcript': transcript,
        'summary': summary['summary'],
        'mainTopics': summary['main_topics'],
        'keywords': summary['keywords'],
        'assessment': summary['assessment'],
        'fullResponse': summary['full_response'],
      };
    } catch (e) {
      print('Erro ao obter resumo do vídeo: $e');
      return {
        'success': false,
        'error': 'video_processing_failed',
      };
    }
  }

  // Limpa recursos ao finalizar o uso
  static void dispose() {
    _yt.close();
  }
}
