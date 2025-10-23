import 'dart:async';

class EventService {
  static final EventService _instance = EventService._internal();

  factory EventService() {
    return _instance;
  }

  EventService._internal();

  // Stream controller para eventos de histórico
  final _historyStreamController = StreamController<bool>.broadcast();

  // Stream para ouvir atualizações do histórico
  Stream<bool> get historyStream => _historyStreamController.stream;

  // Método para notificar que o histórico foi atualizado
  void notifyHistoryUpdated() {
    _historyStreamController.add(true);
  }

  void dispose() {
    _historyStreamController.close();
  }
}
