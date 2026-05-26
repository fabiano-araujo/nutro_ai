import '../models/user_model.dart';

const String dietBenchmarkAllowedEmail = 'fabiano.araujo2056@gmail.com';

bool canAccessDietBenchmark(User? user) {
  if (user == null) {
    return false;
  }

  return user.email.trim().toLowerCase() == dietBenchmarkAllowedEmail;
}
