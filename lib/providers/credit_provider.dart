import 'package:flutter/material.dart';
import '../models/credit_model.dart';
import '../services/storage_service.dart';

class CreditProvider extends ChangeNotifier {
  CreditModel _creditModel = CreditModel.initial();
  final StorageService _storageService = StorageService();

  CreditProvider() {
    _loadCredits();
  }

  int get creditsRemaining => _creditModel.creditsRemaining;

  Future<void> _loadCredits() async {
    try {
      final creditData = await _storageService.getCreditData();
      if (creditData != null) {
        _creditModel = CreditModel.fromJson(creditData);

        // Verificar se precisa resetar os créditos (novo dia)
        if (_creditModel.needsReset) {
          _resetCredits();
        }
      }
      notifyListeners();
    } catch (e) {
      print('Erro ao carregar créditos: $e');
    }
  }

  Future<void> _saveCredits() async {
    try {
      await _storageService.saveCreditData(_creditModel.toJson());
    } catch (e) {
      print('Erro ao salvar créditos: $e');
    }
  }

  void _resetCredits() {
    _creditModel = CreditModel(
      creditsRemaining: CreditModel.dailyCredits,
      lastResetDate: DateTime.now(),
    );
    _saveCredits();
    notifyListeners();
  }

  /// Consome créditos para uma mensagem de texto
  Future<bool> consumeTextMessageCredit() {
    return _consumeCredits(CreditModel.textMessageCost);
  }

  /// Consome créditos para análise de imagem
  Future<bool> consumeImageAnalysisCredit() {
    return _consumeCredits(CreditModel.imageAnalysisCost);
  }

  /// Consome créditos para análise de arquivo
  Future<bool> consumeFileAnalysisCredit() {
    return _consumeCredits(CreditModel.fileAnalysisCost);
  }

  /// Consome créditos para resumo de vídeo
  Future<bool> consumeVideoSummaryCredit() {
    return _consumeCredits(CreditModel.videoSummaryCost);
  }

  /// Consome a quantidade especificada de créditos
  /// Retorna true se há créditos suficientes, false caso contrário
  Future<bool> _consumeCredits(int amount) async {
    // Verificar se temos créditos suficientes
    if (_creditModel.creditsRemaining < amount) {
      return false;
    }

    // Atualizar o modelo com a quantidade reduzida
    _creditModel = _creditModel.copyWith(
      creditsRemaining: _creditModel.creditsRemaining - amount,
    );

    // Notificar os ouvintes e salvar
    notifyListeners();
    await _saveCredits();

    return true;
  }

  /// Adiciona créditos após assistir um anúncio premiado
  Future<void> addRewardedCredits(int amount) async {
    // Atualizar o modelo com a quantidade adicionada
    _creditModel = _creditModel.copyWith(
      creditsRemaining: _creditModel.creditsRemaining + amount,
    );

    // Notificar os ouvintes e salvar
    notifyListeners();
    await _saveCredits();
  }

  /// Atualiza os créditos com base nos dados recebidos do servidor
  Future<void> updateCreditsFromServer(Map<String, dynamic> userData) async {
    try {
      if (userData.containsKey('credits') && userData['credits'] != null) {
        final creditData = userData['credits'];

        if (creditData.containsKey('available') &&
            creditData['lastReset'] != null) {
          final int availableCredits = creditData['available'] as int;
          final String lastResetStr = creditData['lastReset'] as String;
          final DateTime lastReset = DateTime.parse(lastResetStr);

          print(
              'Atualizando créditos do usuário: $availableCredits (último reset: $lastReset)');

          // Criar um novo modelo de crédito com os dados do servidor
          _creditModel = CreditModel(
            creditsRemaining: availableCredits,
            lastResetDate: lastReset,
          );

          // Salvar os dados atualizados
          await _saveCredits();

          // Notificar os ouvintes
          notifyListeners();
          print('Créditos atualizados com sucesso do servidor');
        }
      }
    } catch (e) {
      print('Erro ao atualizar créditos do servidor: $e');
    }
  }
}
