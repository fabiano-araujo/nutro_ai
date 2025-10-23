import 'package:uuid/uuid.dart';

class StudyItem {
  final String id;
  final String title;
  final String content;
  final String response;
  final String type; // 'question', 'document', 'code', 'text', etc.
  final DateTime timestamp;
  
  StudyItem({
    String? id,
    required this.title,
    required this.content,
    required this.response,
    required this.type,
    DateTime? timestamp,
  }) : 
    this.id = id ?? const Uuid().v4(),
    this.timestamp = timestamp ?? DateTime.now();
  
  factory StudyItem.fromJson(Map<String, dynamic> json) {
    return StudyItem(
      id: json['id'],
      title: json['title'],
      content: json['content'],
      response: json['response'],
      type: json['type'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'response': response,
      'type': type,
      'timestamp': timestamp.toIso8601String(),
    };
  }
  
  // Create a copy of this item with updated properties
  StudyItem copyWith({
    String? title,
    String? content,
    String? response,
    String? type,
  }) {
    return StudyItem(
      id: this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      response: response ?? this.response,
      type: type ?? this.type,
      timestamp: this.timestamp,
    );
  }
}