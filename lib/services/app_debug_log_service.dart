import 'dart:convert';

import 'package:flutter/foundation.dart';

class AppDebugLogEntry {
  const AppDebugLogEntry({
    required this.timestamp,
    required this.tag,
    required this.event,
    required this.message,
  });

  final DateTime timestamp;
  final String tag;
  final String event;
  final String message;
}

class AppDebugLogService {
  static final ValueNotifier<List<AppDebugLogEntry>> entries =
      ValueNotifier<List<AppDebugLogEntry>>(const []);

  static bool get isEnabled {
    if (!kIsWeb) {
      return false;
    }
    final query = Uri.base.queryParameters;
    return query.containsKey('qa') || query['debugLogs'] == '1';
  }

  static void add(
    String tag,
    String event, [
    Map<String, dynamic> data = const {},
  ]) {
    final payload = data.isEmpty ? '' : ' ${_safeEncode(data)}';
    final line = '[$tag] $event$payload';
    debugPrint(line);

    if (!isEnabled) {
      return;
    }

    final current = entries.value;
    final next = [
      ...current,
      AppDebugLogEntry(
        timestamp: DateTime.now(),
        tag: tag,
        event: event,
        message: line,
      ),
    ];
    entries.value = next.length <= 200 ? next : next.sublist(next.length - 200);
  }

  static void clear() {
    entries.value = const [];
  }

  static String _safeEncode(Map<String, dynamic> data) {
    try {
      return jsonEncode(data.map(
        (key, value) => MapEntry(key, _safeValue(value)),
      ));
    } catch (error) {
      return '{"logEncodeError":"$error"}';
    }
  }

  static dynamic _safeValue(dynamic value) {
    if (value is String) {
      return value.length <= 700 ? value : '${value.substring(0, 700)}...';
    }
    if (value is num || value is bool || value == null) {
      return value;
    }
    if (value is Map) {
      return value.map(
        (key, item) => MapEntry(key.toString(), _safeValue(item)),
      );
    }
    if (value is Iterable) {
      return value.take(30).map(_safeValue).toList();
    }
    return value.toString();
  }
}
