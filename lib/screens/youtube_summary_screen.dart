import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:provider/provider.dart';
import '../i18n/app_localizations.dart';
import '../i18n/app_localizations_extension.dart';
import '../services/youtube_service.dart';
import '../providers/credit_provider.dart';
import '../widgets/credit_indicator.dart';
import '../screens/ai_tutor_screen.dart';
import 'dart:convert';

class YoutubeSummaryScreen extends StatefulWidget {
  const YoutubeSummaryScreen({Key? key}) : super(key: key);

  @override
  State<YoutubeSummaryScreen> createState() => _YoutubeSummaryScreenState();
}

class _YoutubeSummaryScreenState extends State<YoutubeSummaryScreen> {
  final TextEditingController _urlController = TextEditingController();
  bool _isLoading = false;
  bool _isVideoInfoLoaded = false;
  bool _isLoadingTranscript = false;
  bool _isTranscriptReady = false;
  String _errorMessage = '';
  Map<String, dynamic>? _videoInfo;
  String _transcript = '';
  bool _showFullTranscript = false;
  bool _isPlayingVideo = false;
  YoutubePlayerController? _youtubeController;

  @override
  void dispose() {
    _urlController.dispose();
    _youtubeController?.dispose();
    super.dispose();
  }

  // Validar URL do YouTube
  bool _isValidYoutubeUrl(String url) {
    return url.isNotEmpty &&
        (url.contains('youtube.com') || url.contains('youtu.be'));
  }

  // Inicializar o player do YouTube
  void _initializeYoutubePlayer(String videoId) {
    _youtubeController = YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: false,
        mute: false,
        captionLanguage: 'pt',
      ),
    );
  }

  // Processar a URL do vídeo
  Future<void> _processUrl() async {
    final url = _urlController.text.trim();

    if (url.isEmpty) {
      setState(() {
        _errorMessage = context.tr.translate('youtube_error_empty_url');
      });
      return;
    }

    if (!_isValidYoutubeUrl(url)) {
      setState(() {
        _errorMessage = context.tr.translate('youtube_error_invalid_url');
      });
      return;
    }

    // Reiniciar estados
    setState(() {
      _isLoading = true;
      _isVideoInfoLoaded = false;
      _isLoadingTranscript = false;
      _isTranscriptReady = false;
      _errorMessage = '';
      _videoInfo = null;
      _transcript = '';
      _isPlayingVideo = false;
      _showFullTranscript = false;
      if (_youtubeController != null) {
        _youtubeController!.dispose();
        _youtubeController = null;
      }
    });

    try {
      // Notificar o usuário
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr.translate('processing_url')),
          duration: const Duration(seconds: 2),
        ),
      );

      // Extrair o ID do vídeo
      final videoId = YouTubeService.extractVideoId(url);
      if (videoId.isNotEmpty) {
        _initializeYoutubePlayer(videoId);
      }

      // 1. Carregar informações básicas do vídeo primeiro
      // Obtemos as informações completas mas só mostramos as básicas inicialmente
      final videoInfo = await YouTubeService.getVideoInfo(url);

      // Atualizar a UI com as informações básicas do vídeo
      if (videoInfo['success'] == true) {
        setState(() {
          _videoInfo = videoInfo['videoInfo'];
          _isVideoInfoLoaded = true;
          _isLoadingTranscript = true; // Começamos a carregar a transcrição
        });

        // 2. Usar a transcrição já obtida
        final transcript = videoInfo['transcript'];

        // Atualizar a UI quando a transcrição estiver pronta
        setState(() {
          _transcript = transcript;
          _isLoadingTranscript = false;
          _isTranscriptReady = true;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = videoInfo['error'] ??
              context.tr.translate('youtube_error_generic');
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isLoadingTranscript = false;
        _errorMessage = e.toString();
      });
    }
  }

  // Alternar entre mostrar vídeo e informações
  void _toggleVideoPlayer() {
    setState(() {
      _isPlayingVideo = !_isPlayingVideo;
    });
  }

  // Alternar exibição da transcrição
  void _toggleTranscript() {
    setState(() {
      _showFullTranscript = !_showFullTranscript;
    });
  }

  // Copiar a transcrição para a área de transferência
  void _copyTranscript() {
    if (_transcript.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: _transcript));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr.translate('text_copied')),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // Navegar para a tela AI Tutor com as informações do vídeo
  void _navigateToAITutor() {
    if (_videoInfo != null && _transcript.isNotEmpty) {
      // Criar um prompt mais simples e direto que será processado pela AI
      final String directPrompt =
          '''Gere um resumo detalhado deste vídeo do YouTube:

TÍTULO: ${_videoInfo!['title']}
CANAL: ${_videoInfo!['channel']}
DURAÇÃO: ${_videoInfo!['duration']}
VISUALIZAÇÕES: ${_videoInfo!['views']}

TRANSCRIÇÃO:
$_transcript

Por favor, forneça:
1. Os principais tópicos abordados no vídeo (em formato de lista)
2. Um resumo detalhado do conteúdo
3. Uma avaliação da complexidade e profundidade do material''';

      // Criar objeto que o AI Tutor possa processar para mostrar o card
      Map<String, dynamic> toolData = {
        'userInput': _videoInfo!['title'],
        'fullPrompt':
            directPrompt, // Aqui incluímos o prompt com transcrição para a IA
        'toolName': 'YouTube Summary',
        'toolTab': 'Análise de Vídeo',
        'sourceType': 'youtube',
        'thumbnailUrl': _videoInfo!['thumbnail'], // URL da thumbnail
        'videoTitle': _videoInfo!['title'],
        'videoChannel': _videoInfo!['channel'],
        'videoDuration': _videoInfo!['duration'],
        'videoViews': _videoInfo!['views'],
        'hasTranscript': true,
        'transcript': _transcript,
      };

      // Converter para JSON
      final String jsonData = jsonEncode(toolData);

      // Navegar para a tela do AI Tutor com o prompt e metadados
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AITutorScreen(initialPrompt: jsonData),
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr.translate('youtube_summary')),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: CreditIndicator(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Campo de entrada da URL
              TextField(
                controller: _urlController,
                decoration: InputDecoration(
                  labelText: context.tr.translate('enter_youtube_url'),
                  hintText: 'https://www.youtube.com/watch?v=...',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.link),
                  suffixIcon: _urlController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _urlController.clear();
                              _errorMessage = '';
                            });
                          },
                        )
                      : null,
                ),
                onChanged: (value) {
                  setState(() {
                    _errorMessage = '';
                  });
                },
                onSubmitted: (_) => _isLoading ? null : _processUrl(),
              ),

              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    _errorMessage,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),

              const SizedBox(height: 16),

              // Botão de processar URL
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _processUrl,
                  icon: const Icon(Icons.play_arrow),
                  label: Text(context.tr.translate('process_video')),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Dica de uso
              Text(
                context.tr.translate('youtube_summary_tip'),
                style: Theme.of(context).textTheme.bodySmall,
              ),

              // Estado de carregamento das informações do vídeo
              if (_isLoading && !_isVideoInfoLoaded) ...[
                const SizedBox(height: 24),
                Center(
                  child: Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(context.tr.translate('processing_video')),
                    ],
                  ),
                ),
              ],

              // Exibir informações do vídeo quando disponíveis
              if (_isVideoInfoLoaded && _videoInfo != null) ...[
                const SizedBox(height: 24),

                // Player de vídeo ou miniatura
                if (_youtubeController != null) ...[
                  _isPlayingVideo
                      ? YoutubePlayer(
                          controller: _youtubeController!,
                          showVideoProgressIndicator: true,
                          onReady: () {
                            // O player está pronto
                          },
                        )
                      : GestureDetector(
                          onTap: _toggleVideoPlayer,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: double.infinity,
                                height: 200,
                                decoration: BoxDecoration(
                                  image: DecorationImage(
                                    image: NetworkImage(
                                      _videoInfo!['thumbnail'],
                                    ),
                                    fit: BoxFit.cover,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.play_arrow,
                                  color: Colors.white,
                                  size: 40,
                                ),
                              ),
                            ],
                          ),
                        ),
                  if (_isPlayingVideo) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _toggleVideoPlayer,
                      icon: const Icon(Icons.arrow_back),
                      label: Text(context.tr.translate('back_to_info')),
                    ),
                  ],
                ],

                if (!_isPlayingVideo) ...[
                  const SizedBox(height: 16),

                  // Informações do vídeo
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr.translate('video_info'),
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _videoInfo!['title'],
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.person, size: 16),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  _videoInfo!['channel'],
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.timer, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                _videoInfo!['duration'],
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(width: 16),
                              const Icon(Icons.visibility, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                _videoInfo!['views'],
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Indicador de carregamento da transcrição
                  if (_isLoadingTranscript) ...[
                    const SizedBox(height: 16),
                    Center(
                      child: Column(
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 8),
                          Text(context.tr.translate('loading_transcript')),
                        ],
                      ),
                    ),
                  ],

                  // Botão de transcrição (se estiver pronta)
                  if (_isTranscriptReady) ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _toggleTranscript,
                      icon: Icon(_showFullTranscript
                          ? Icons.unfold_less
                          : Icons.unfold_more),
                      label: Text(_showFullTranscript
                          ? context.tr.translate('hide_transcript')
                          : context.tr.translate('view_full_transcript')),
                    ),
                  ],

                  // Transcrição completa (visível apenas quando solicitado)
                  if (_isTranscriptReady && _showFullTranscript) ...[
                    const SizedBox(height: 16),
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  context.tr.translate('full_transcript'),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy),
                                  onPressed: _copyTranscript,
                                  tooltip: context.tr.translate('copy'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(_transcript),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Botão para ver resumo no AI Tutor (visível apenas quando a transcrição estiver pronta)
                  if (_isTranscriptReady) ...[
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _navigateToAITutor,
                        icon: const Icon(Icons.auto_awesome),
                        label: Text(
                            context.tr.translate('see_summary_in_ai_tutor')),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          backgroundColor:
                              Theme.of(context).colorScheme.secondary,
                          foregroundColor:
                              Theme.of(context).colorScheme.onSecondary,
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
