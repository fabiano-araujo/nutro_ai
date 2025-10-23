import 'package:flutter/material.dart';

class PurchaseConfig {
  // Singleton
  static final PurchaseConfig _instance = PurchaseConfig._internal();

  factory PurchaseConfig() {
    return _instance;
  }

  PurchaseConfig._internal();

  // Limites para usuários não premium
  static const int freeDailyMessages = 10;
  static const int freeImageUploads = 3;
  static const int freeVideoAnalysis = 2;
  static const int freeFileAnalysis = 1;

  // Contadores de uso (resetta diariamente)
  DateTime _lastResetDate = DateTime.now();
  int _messageCount = 0;
  int _imageUploadCount = 0;
  int _videoAnalysisCount = 0;
  int _fileAnalysisCount = 0;

  // Verifica se os contadores devem ser resetados (novo dia)
  void _checkReset() {
    final now = DateTime.now();
    if (now.day != _lastResetDate.day ||
        now.month != _lastResetDate.month ||
        now.year != _lastResetDate.year) {
      _resetCounters();
      _lastResetDate = now;
    }
  }

  // Reseta todos os contadores
  void _resetCounters() {
    _messageCount = 0;
    _imageUploadCount = 0;
    _videoAnalysisCount = 0;
    _fileAnalysisCount = 0;
  }

  // Verifica se o usuário pode enviar mensagem
  bool canSendMessage(bool isPremium) {
    _checkReset();
    if (isPremium) return true;
    return _messageCount < freeDailyMessages;
  }

  // Incrementa contador de mensagens e retorna se teve sucesso
  bool incrementMessageCount(bool isPremium) {
    _checkReset();
    if (isPremium) return true;

    if (_messageCount < freeDailyMessages) {
      _messageCount++;
      return true;
    }
    return false;
  }

  // Verifica se o usuário pode fazer upload de imagem
  bool canUploadImage(bool isPremium) {
    _checkReset();
    if (isPremium) return true;
    return _imageUploadCount < freeImageUploads;
  }

  // Incrementa contador de uploads de imagem e retorna se teve sucesso
  bool incrementImageUploadCount(bool isPremium) {
    _checkReset();
    if (isPremium) return true;

    if (_imageUploadCount < freeImageUploads) {
      _imageUploadCount++;
      return true;
    }
    return false;
  }

  // Verifica se o usuário pode analisar vídeo
  bool canAnalyzeVideo(bool isPremium) {
    _checkReset();
    if (isPremium) return true;
    return _videoAnalysisCount < freeVideoAnalysis;
  }

  // Incrementa contador de análise de vídeo e retorna se teve sucesso
  bool incrementVideoAnalysisCount(bool isPremium) {
    _checkReset();
    if (isPremium) return true;

    if (_videoAnalysisCount < freeVideoAnalysis) {
      _videoAnalysisCount++;
      return true;
    }
    return false;
  }

  // Verifica se o usuário pode analisar arquivo
  bool canAnalyzeFile(bool isPremium) {
    _checkReset();
    if (isPremium) return true;
    return _fileAnalysisCount < freeFileAnalysis;
  }

  // Incrementa contador de análise de arquivo e retorna se teve sucesso
  bool incrementFileAnalysisCount(bool isPremium) {
    _checkReset();
    if (isPremium) return true;

    if (_fileAnalysisCount < freeFileAnalysis) {
      _fileAnalysisCount++;
      return true;
    }
    return false;
  }

  // Retorna mensagem explicando o limite atingido
  String getLimitMessage(BuildContext context, String resourceType) {
    switch (resourceType) {
      case 'message':
        return 'Você atingiu o limite diário de $freeDailyMessages mensagens. Assine o plano Premium para enviar mensagens ilimitadas.';
      case 'image':
        return 'Você atingiu o limite diário de $freeImageUploads uploads de imagem. Assine o plano Premium para uploads ilimitados.';
      case 'video':
        return 'Você atingiu o limite diário de $freeVideoAnalysis análises de vídeo. Assine o plano Premium para análises ilimitadas.';
      case 'file':
        return 'Você atingiu o limite diário de $freeFileAnalysis análises de arquivo. Assine o plano Premium para análises ilimitadas.';
      default:
        return 'Você atingiu o limite diário deste recurso. Assine o plano Premium para uso ilimitado.';
    }
  }

  // Retorna o número de usos restantes
  String getRemainingUsage(String resourceType) {
    switch (resourceType) {
      case 'message':
        return '${freeDailyMessages - _messageCount}/$freeDailyMessages restantes hoje';
      case 'image':
        return '${freeImageUploads - _imageUploadCount}/$freeImageUploads restantes hoje';
      case 'video':
        return '${freeVideoAnalysis - _videoAnalysisCount}/$freeVideoAnalysis restantes hoje';
      case 'file':
        return '${freeFileAnalysis - _fileAnalysisCount}/$freeFileAnalysis restantes hoje';
      default:
        return '';
    }
  }
}
