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
    return User(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      username: json['username'],
      subscription: Subscription.fromJson(
        json['subscription'] ??
            {'isPremium': false, 'planType': 'free', 'expirationDate': null},
      ),
      photo: json['photo'],
    );
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
    return Subscription(
      isPremium: json['isPremium'] ?? false,
      planType: json['planType'] ?? 'free',
      expirationDate: json['expirationDate'] != null
          ? DateTime.parse(json['expirationDate'])
          : null,
      remainingDays: json['remainingDays'],
    );
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
