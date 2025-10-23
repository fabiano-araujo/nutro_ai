import 'package:flutter/foundation.dart';
import '../models/essay_model.dart';
import '../services/progress_tracker_service.dart';
import '../services/analytics_service.dart';
import 'package:uuid/uuid.dart';

class EssayProvider with ChangeNotifier {
  List<Essay> _essays = [];
  Essay? _currentEssay;
  final ProgressTrackerService _progressTracker = ProgressTrackerService();

  List<Essay> get essays => _essays;
  Essay? get currentEssay => _currentEssay;

  // Obter todas as redações
  List<Essay> getEssays() {
    return _essays;
  }

  // Inicializar com alguns exemplos
  void initWithSamples() {
    if (_essays.isEmpty) {
      _essays = [
        Essay(
          id: const Uuid().v4(),
          title: 'Os desafios da educação no Brasil',
          text: 'Texto da redação sobre os desafios da educação no Brasil...',
          type: 'ENEM',
          date: DateTime(2025, 4, 25),
          score: 800,
          status: 'Corrigido',
          competenceScores: {
            'Competência 1': 160,
            'Competência 2': 180,
            'Competência 3': 160,
            'Competência 4': 160,
            'Competência 5': 140,
          },
        ),
        Essay(
          id: const Uuid().v4(),
          title: 'Consequências da desinformação na era digital',
          text: 'Texto da redação sobre consequências da desinformação...',
          type: 'Vestibular',
          date: DateTime(2025, 4, 20),
          score: 780,
          status: 'Corrigido',
        ),
        Essay(
          id: const Uuid().v4(),
          title: 'Sustentabilidade e consumo consciente',
          text:
              'Texto da redação sobre sustentabilidade e consumo consciente...',
          type: 'ENEM',
          date: DateTime(2025, 4, 15),
          score: 850,
          status: 'Corrigido',
        ),
        Essay(
          id: const Uuid().v4(),
          title: 'O papel da tecnologia na educação',
          text: 'Texto da redação sobre o papel da tecnologia na educação...',
          type: 'Vestibular',
          date: DateTime(2025, 4, 25),
          status: 'Em Análise',
        ),
        Essay(
          id: const Uuid().v4(),
          title: 'Desigualdade social no Brasil',
          text: 'Texto da redação sobre desigualdade social no Brasil...',
          type: 'ENEM',
          date: DateTime(2025, 4, 22),
          status: 'Rascunho',
        ),
      ];
      notifyListeners();
    }
  }

  // Obter uma redação pelo ID
  Essay? getEssayById(String id) {
    try {
      return _essays.firstWhere((essay) => essay.id == id);
    } catch (e) {
      return null;
    }
  }

  // Adicionar uma nova redação
  void addEssay(Essay essay) {
    _essays.add(essay);
    notifyListeners();
  }

  // Criar uma nova redação
  Essay createNewEssay({
    required String title,
    required String text,
    required String type,
  }) {
    final essay = Essay(
      id: const Uuid().v4(),
      title: title,
      text: text,
      type: type,
      date: DateTime.now(),
      status: 'Rascunho',
    );

    _essays.add(essay);
    
    // Log analytics
    AnalyticsService.logEssayCreated(essay);
    
    notifyListeners();
    return essay;
  }

  // Enviar para correção
  void submitForCorrection(String id) {
    int index = _essays.indexWhere((essay) => essay.id == id);
    if (index != -1) {
      final updatedEssay = _essays[index].copyWith(status: 'Em Análise');
      _essays[index] = updatedEssay;
      
      // Log analytics
      AnalyticsService.logEssaySubmitted(updatedEssay);
      
      notifyListeners();
    }
  }

  // Atualizar pontuação após correção
  void updateEssayScore(
      String id, int score, Map<String, int> competenceScores) async {
    int index = _essays.indexWhere((essay) => essay.id == id);
    if (index != -1) {
      final updatedEssay = _essays[index].copyWith(
        score: score,
        status: 'Corrigido',
        competenceScores: competenceScores,
      );
      _essays[index] = updatedEssay;
      
      // Log analytics
      AnalyticsService.logEssayCorrected(updatedEssay);
      
      // Adicionar ao progresso
      try {
        await _progressTracker.addProgressPoint(updatedEssay);
      } catch (e) {
        debugPrint('Erro ao adicionar progresso: $e');
      }
      
      notifyListeners();
    }
  }

  // Calcular média de pontuação das redações corrigidas
  int calculateAverageScore() {
    final correctedEssays =
        _essays.where((essay) => essay.status == 'Corrigido');
    if (correctedEssays.isEmpty) return 0;

    final totalScore =
        correctedEssays.fold(0, (sum, essay) => sum + essay.score);
    return (totalScore / correctedEssays.length).round();
  }

  // Definir redação atual para edição/visualização
  void setCurrentEssay(Essay essay) {
    _currentEssay = essay;
    notifyListeners();
  }

  // Limpar redação atual
  void clearCurrentEssay() {
    _currentEssay = null;
    notifyListeners();
  }
}
