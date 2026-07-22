class ManualActivityEntry {
  final String id;
  final String activityId;
  final String activityName;
  final DateTime date;
  final int durationMinutes;
  final int caloriesBurned;
  final DateTime createdAt;

  const ManualActivityEntry({
    required this.id,
    required this.activityId,
    required this.activityName,
    required this.date,
    required this.durationMinutes,
    required this.caloriesBurned,
    required this.createdAt,
  });

  factory ManualActivityEntry.fromJson(Map<String, dynamic> json) {
    return ManualActivityEntry(
      id: json['id']?.toString() ?? '',
      activityId: json['activityId']?.toString() ?? '',
      activityName: json['activityName']?.toString() ?? '',
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      durationMinutes: _readInt(json['durationMinutes']),
      caloriesBurned: _readInt(json['caloriesBurned']),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'activityId': activityId,
      'activityName': activityName,
      'date': _dateKey(date),
      'durationMinutes': durationMinutes,
      'caloriesBurned': caloriesBurned,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _dateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}

class CustomActivityDefinition {
  final String id;
  final String name;
  final double met;
  final DateTime createdAt;

  const CustomActivityDefinition({
    required this.id,
    required this.name,
    required this.met,
    required this.createdAt,
  });

  factory CustomActivityDefinition.fromJson(Map<String, dynamic> json) {
    return CustomActivityDefinition(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      met: _readDouble(json['met'], fallback: 6),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'met': met,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static double _readDouble(dynamic value, {required double fallback}) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }
}
