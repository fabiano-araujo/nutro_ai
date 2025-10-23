class Message {
  String content;
  final Sender sender;
  final DateTime timestamp;

  Message({
    required this.content,
    required this.sender,
    required this.timestamp,
  });
}

enum Sender {
  user,
  ai,
}
