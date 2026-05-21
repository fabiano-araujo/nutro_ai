import 'package:flutter_test/flutter_test.dart';
import 'package:nutro_ai/models/user_model.dart';

void main() {
  test('User.fromJson tolerates missing username in auth response', () {
    final user = User.fromJson({
      'id': 42,
      'name': 'Fabiano',
      'email': 'fabiano@example.com',
      'username': null,
      'photo': null,
      'subscription': {
        'isPremium': false,
        'planType': 'free',
        'expirationDate': null,
      },
    });

    expect(user.id, 42);
    expect(user.name, 'Fabiano');
    expect(user.email, 'fabiano@example.com');
    expect(user.username, 'Fabiano');
    expect(user.subscription.isPremium, isFalse);
    expect(user.subscription.planType, 'free');
  });

  test('User.fromJson parses legacy string ids and subscription values', () {
    final user = User.fromJson({
      'id': '7',
      'name': 'Maria',
      'email': 'maria@example.com',
      'subscription': 'mensal',
    });

    expect(user.id, 7);
    expect(user.username, 'Maria');
    expect(user.subscription.isPremium, isTrue);
    expect(user.subscription.planType, 'mensal');
  });
}
