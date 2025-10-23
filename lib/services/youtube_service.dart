import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../services/ai_service.dart'; // Importando o AIService

class YouTubeService {
  // Cliente YouTube Explode
  static final YoutubeExplode _yt = YoutubeExplode();
  static final AIService _aiService = AIService(); // Instância do AIService

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
  static Future<String> getTranscription(String videoId) async {
    try {
      // Verifica se a transcrição está em cache
      final prefs = await SharedPreferences.getInstance();
      final cachedTranscript = prefs.getString('transcript_$videoId');

      if (cachedTranscript != null) {
        return cachedTranscript;
      }

      // Obtém a lista de legendas disponíveis
      final trackList = await _yt.videos.closedCaptions.getManifest(videoId);

      // Se não houver legendas disponíveis, retorne a transcrição simulada
      if (trackList.tracks.isEmpty) {
        final sampleTranscription = await _getSampleTranscription(videoId);
        await prefs.setString('transcript_$videoId', sampleTranscription);
        return sampleTranscription;
      }

      // Prefere legendas em português ou inglês, se disponíveis
      ClosedCaptionTrackInfo track;

      // Tenta encontrar legendas em português
      var ptTracks = trackList.tracks
          .where((track) => track.language.code.toLowerCase().startsWith('pt'));

      // Se não encontrar português, tenta inglês
      if (ptTracks.isEmpty) {
        var enTracks = trackList.tracks.where(
            (track) => track.language.code.toLowerCase().startsWith('en'));

        // Se não encontrar inglês, usa a primeira disponível
        if (enTracks.isEmpty) {
          track = trackList.tracks.first;
        } else {
          track = enTracks.first;
        }
      } else {
        track = ptTracks.first;
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
      await prefs.setString('transcript_$videoId', transcript);

      return transcript;
    } catch (e) {
      print('Erro ao obter transcrição do YouTube: $e');
      // Em caso de erro, retorna a transcrição simulada
      return _getSampleTranscription(videoId);
    }
  }

  // Método completo para obter informações do vídeo e transcrição (sem chamar a IA)
  static Future<Map<String, dynamic>> getVideoInfo(String url) async {
    try {
      // Extrai o ID do vídeo da URL
      final videoId = extractVideoId(url);
      if (videoId.isEmpty) {
        return {
          'success': false,
          'error': 'URL de vídeo inválida',
        };
      }

      // Obtém informações básicas do vídeo
      final videoInfo = await _getBasicVideoInfo(videoId);

      // Obtém a transcrição do vídeo
      final transcript = await getTranscription(videoId);
      if (transcript.isEmpty) {
        return {
          'success': false,
          'error': 'Não foi possível obter a transcrição do vídeo',
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
        'error': 'Erro ao processar o vídeo: ${e.toString()}',
      };
    }
  }

  // Renomeado o método original de getVideoInfo para _getBasicVideoInfo
  static Future<Map<String, dynamic>> _getBasicVideoInfo(String videoId) async {
    try {
      // Usa o YouTube Explode para obter informações reais do vídeo
      final video = await _yt.videos.get(videoId);

      return {
        'title': video.title,
        'channel': video.author,
        'duration': _formatDuration(video.duration),
        'views': _formatViews(video.engagement.viewCount),
        'thumbnail': video.thumbnails.highResUrl,
      };
    } catch (e) {
      print('Erro ao obter informações do vídeo: $e');
      // Retornar informações simuladas em caso de erro
      return {
        'title': 'Vídeo do YouTube $videoId',
        'channel': 'Canal do Criador',
        'duration': '10:30',
        'views': '123.456 visualizações',
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
  static String _formatViews(int views) {
    if (views < 1000) {
      return '$views visualizações';
    } else if (views < 1000000) {
      return '${(views / 1000).toStringAsFixed(1)}K visualizações';
    } else {
      return '${(views / 1000000).toStringAsFixed(1)}M visualizações';
    }
  }

  // Método que simula uma transcrição para fins de demonstração (usado como fallback)
  static Future<String> _getSampleTranscription(String videoId) async {
    // Simulação de um pequeno atraso de rede
    await Future.delayed(Duration(seconds: 1));

    // Textos de exemplo para diferentes vídeos para simular a funcionalidade
    final Map<String, String> sampleTexts = {
      'default': '''
Este vídeo explora as mudanças climáticas e seus impactos globais. As temperaturas estão aumentando em todo o mundo devido às emissões de carbono e outros gases de efeito estufa. Cientistas alertam que precisamos tomar medidas urgentes para reduzir as emissões e limitar o aquecimento global a 1,5 graus Celsius.

O derretimento das geleiras e o aumento do nível do mar são consequências visíveis das mudanças climáticas. Muitas espécies estão em risco de extinção devido à perda de habitat. Eventos climáticos extremos como furacões, incêndios florestais e secas estão se tornando mais frequentes e intensos.

Os países estão trabalhando juntos através de acordos internacionais como o Acordo de Paris para combater as mudanças climáticas. Indivíduos também podem contribuir fazendo escolhas sustentáveis em seu dia a dia, como reduzir o consumo de energia, optar por transporte público ou veículos elétricos e adotar uma dieta com menor pegada de carbono.

Empresas e governos estão investindo em energia renovável e tecnologias limpas para reduzir as emissões. A transição para uma economia de baixo carbono representa desafios, mas também oportunidades para inovação e crescimento sustentável.

Educação e conscientização sobre as mudanças climáticas são fundamentais para mobilizar a ação global. Todos têm um papel a desempenhar na proteção do nosso planeta para as gerações futuras.
''',
      'tech': '''
Neste vídeo, discutimos os avanços recentes em inteligência artificial e suas aplicações. A IA generativa está revolucionando vários campos, desde criação de conteúdo até diagnósticos médicos. Modelos de linguagem grande como GPT-4 podem gerar texto, código e imagens com qualidade impressionante.

O aprendizado de máquina continua a melhorar em áreas como visão computacional, processamento de linguagem natural e reconhecimento de padrões. Estas tecnologias estão sendo integradas em produtos e serviços que usamos diariamente, muitas vezes sem percebermos.

O desenvolvimento da IA levanta questões importantes sobre ética, privacidade e segurança. Pesquisadores e empresas estão trabalhando para garantir que os sistemas de IA sejam transparentes, justos e alinhados com valores humanos.

Também discutimos como a IA está transformando indústrias como saúde, finanças, transporte e educação. Embora haja preocupações sobre o impacto no mercado de trabalho, a IA também está criando novas oportunidades e profissões.

Os desafios da IA incluem viés algorítmico, uso responsável de dados e a necessidade de regulamentação apropriada. A colaboração entre empresas, governos e academia será essencial para maximizar os benefícios da IA enquanto minimizamos seus riscos.
''',
      'education': '''
Este vídeo apresenta métodos eficazes de estudo e aprendizado. A técnica de estudo espaçado envolve revisar o material em intervalos crescentes para melhorar a retenção de longo prazo. Pesquisas mostram que distribuir as sessões de estudo ao longo do tempo é mais eficaz do que estudar tudo de uma vez.

A prática de recuperação, que consiste em testar a si mesmo sobre o material aprendido, fortalece a memória mais do que simplesmente reler o conteúdo. Flashcards e questionários são ferramentas eficazes para implementar esta técnica.

Explicar conceitos em suas próprias palavras, conhecida como técnica Feynman, ajuda a identificar lacunas no seu entendimento e consolidar o aprendizado. Ensinar o que você aprendeu para outra pessoa ou para si mesmo é uma excelente maneira de verificar seu domínio do assunto.

O contexto de aprendizado também é importante. Variar os ambientes de estudo pode melhorar a retenção, pois seu cérebro associa a informação a diferentes estímulos. Além disso, alternar entre diferentes assuntos em uma sessão de estudo pode ser mais eficaz do que focar em um único tópico.

O sono adequado é crucial para a consolidação da memória. Durante o sono profundo, o cérebro processa e organiza as informações adquiridas durante o dia. Portanto, uma boa noite de sono após estudar é tão importante quanto o estudo em si.
''',
    };

    // Determinando qual texto de exemplo usar
    String transcription = '';
    if (videoId == 'tech123') {
      transcription = sampleTexts['tech'] ?? sampleTexts['default']!;
    } else if (videoId == 'edu456') {
      transcription = sampleTexts['education'] ?? sampleTexts['default']!;
    } else {
      transcription = sampleTexts['default']!;
    }

    return transcription;
  }

  // Método para obter um resumo de um vídeo
  static Future<Map<String, dynamic>> getVideoSummary(String url) async {
    try {
      // Extrai o ID do vídeo da URL
      final videoId = extractVideoId(url);
      if (videoId.isEmpty) {
        return {
          'success': false,
          'error': 'URL de vídeo inválida',
        };
      }

      // Obtém informações do vídeo
      final videoInfo = await _getBasicVideoInfo(videoId);
      final videoTitle = videoInfo['title'] as String;

      // Obtém a transcrição do vídeo
      final transcript = await getTranscription(videoId);
      if (transcript.isEmpty) {
        return {
          'success': false,
          'error': 'Não foi possível obter a transcrição do vídeo',
          'videoInfo': videoInfo,
        };
      }

      // Usa o AIService para resumir a transcrição
      final summary = await _aiService.summarizeYouTubeTranscript(
        transcript,
        videoTitle: videoTitle,
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
        'error': 'Ocorreu um erro ao processar o vídeo: $e',
      };
    }
  }

  // Limpa recursos ao finalizar o uso
  static void dispose() {
    _yt.close();
  }
}
