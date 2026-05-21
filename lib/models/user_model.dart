class User {
  final int id;
  final String name;
  final String email;
  final String username;
  final Subscription subscription;
  final String? photo;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.username,
    required this.subscription,
    this.photo,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final name = json['name']?.toString() ?? '';
    final email = json['email']?.toString() ?? '';
    final rawUsername = json['username']?.toString().trim();
    final fallbackUsername = name.trim().isNotEmpty ? name : email;
    final rawSubscription = json['subscription'];

    return User(
      id: _parseId(json['id']),
      name: name,
      email: email,
      username: rawUsername != null && rawUsername.isNotEmpty
          ? rawUsername
          : fallbackUsername,
      subscription: Subscription.fromJson(
        rawSubscription is Map
            ? Map<String, dynamic>.from(rawSubscription)
            : {
                'isPremium': rawSubscription != null &&
                    rawSubscription.toString() != 'free',
                'planType': rawSubscription?.toString() ?? 'free',
                'expirationDate': null,
              },
      ),
      photo: json['photo']?.toString(),
    );
  }

  static int _parseId(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'username': username,
      'subscription': subscription.toJson(),
      'photo': photo,
    };
  }
}

class Subscription {
  final bool isPremium;
  final String planType;
  final DateTime? expirationDate;
  final int? remainingDays;

  Subscription({
    required this.isPremium,
    required this.planType,
    this.expirationDate,
    this.remainingDays,
  });

  factory Subscription.fromJson(Map<String, dynamic> json) {
    final planType = json['planType']?.toString() ?? 'free';

    return Subscription(
      isPremium: _parseBool(
        json['isPremium'],
        fallback: planType != 'free',
      ),
      planType: planType,
      expirationDate: _parseDate(json['expirationDate']),
      remainingDays: _parseInt(json['remainingDays']),
    );
  }

  static bool _parseBool(dynamic value, {bool fallback = false}) {
    if (value == null) return fallback;
    if (value is bool) return value;
    final normalized = value.toString().toLowerCase();
    if (normalized == 'true' || normalized == '1') return true;
    if (normalized == 'false' || normalized == '0') return false;
    return fallback;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  Map<String, dynamic> toJson() {
    return {
      'isPremium': isPremium,
      'planType': planType,
      'expirationDate': expirationDate?.toIso8601String(),
      'remainingDays': remainingDays,
    };
  }

  String get formattedExpirationDate {
    if (expirationDate == null) return 'N/A';

    final day = expirationDate!.day.toString().padLeft(2, '0');
    final month = expirationDate!.month.toString().padLeft(2, '0');
    final year = expirationDate!.year;

    return '$day/$month/$year';
  }

  String get planName {
    switch (planType) {
      case 'semanal':
        return 'Semanal';
      case 'mensal':
        return 'Mensal';
      case 'anual':
        return 'Anual';
      default:
        return 'Gratuito';
    }
  }
}
