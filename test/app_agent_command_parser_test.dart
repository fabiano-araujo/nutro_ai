import 'package:flutter_test/flutter_test.dart';
import 'package:nutro_ai/services/app_agent_service.dart';

void main() {
  test('parses app_commands with root-level fields from the model', () {
    const response = '''
Para configurar seus objetivos, preciso validar os dados.

{"app_commands":[
  {"app_command":"update_goal_setup_profile","sex":"male","age":28,"weight_kg":85,"height_cm":181},
  {"app_command":"update_goal_setup_preferences","activity":"moderate","goal":"weight_gain"}
]}
[APP_UI_HINT_BEGIN]{"actions":["configure_goals_ui"]}[APP_UI_HINT_END]
''';

    final batch = AppAgentCommand.tryParseBatch(response);

    expect(batch, isNotNull);
    expect(batch!.commands, hasLength(2));

    expect(batch.commands[0].name, 'update_goal_setup_profile');
    expect(batch.commands[0].arguments, <String, dynamic>{
      'sex': 'male',
      'age': 28,
      'weightKg': 85.0,
      'heightCm': 181.0,
    });

    expect(batch.commands[1].name, 'update_goal_setup_preferences');
    expect(batch.commands[1].arguments, <String, dynamic>{
      'activityLevel': 'moderatelyActive',
      'fitnessGoal': 'gainWeight',
    });
  });

  test('parses skipPreferenceStep for optional diet generation review', () {
    const response = '''
{"app_commands":[
  {"name":"update_diet_generation_preferences","skipPreferenceStep":true},
  {"name":"generate_new_diet_plan","arguments":{}}
]}
''';

    final batch = AppAgentCommand.tryParseBatch(response);

    expect(batch, isNotNull);
    expect(batch!.commands, hasLength(2));
    expect(batch.commands[0].name, 'update_diet_generation_preferences');
    expect(batch.commands[0].arguments, <String, dynamic>{
      'skipPreferenceStep': true,
    });
    expect(batch.commands[1].name, 'generate_new_diet_plan');
    expect(batch.commands[1].arguments, isEmpty);
  });

  test('only keeps prior conversation for contextual short replies', () {
    expect(
      AppAgentService.shouldIncludeConversationContext('Pode seguir'),
      isTrue,
    );
    expect(
      AppAgentService.shouldIncludeConversationContext('Qualquer uma'),
      isTrue,
    );
    expect(
      AppAgentService.shouldIncludeConversationContext('Qual a minha idade?'),
      isFalse,
    );
    expect(
      AppAgentService.shouldIncludeConversationContext(
        'Sou homem, tenho 28 anos e quero ganhar peso lentamente.',
      ),
      isFalse,
    );
  });

  test('normalizes snake_case activity and slow gain goal variants', () {
    const response = '''
{"app_command":{"name":"update_goal_setup_preferences","arguments":{"activityLevel":"moderately_active","fitnessGoal":"slow_weight_gain"}}}
''';

    final command = AppAgentCommand.tryParse(response);

    expect(command, isNotNull);
    expect(command!.name, 'update_goal_setup_preferences');
    expect(command.arguments, <String, dynamic>{
      'activityLevel': 'moderatelyActive',
      'fitnessGoal': 'gainWeightSlowly',
    });
  });

  test('does not treat food json as an app command batch', () {
    const response = '''
{"mealType":"lunch","foods":[{"name":"carne","portion":"100 gramas","macros":{"calories":250,"protein":26,"carbohydrate":0,"fat":15}}]}
''';

    expect(AppAgentCommand.containsCommandCandidate(response), isFalse);
    expect(AppAgentCommand.tryParse(response), isNull);
    expect(AppAgentCommand.tryParseBatch(response), isNull);
  });

  test('does not treat nested foods arrays as top-level commands', () {
    const response = '''
Resposta da IA:
{"mealType":"breakfast","foods":[{"name":"pao","portion":"1 fatia","macros":{"calories":70,"protein":2.5,"carbohydrate":13,"fat":1}}]}
''';

    expect(AppAgentCommand.tryParseBatch(response), isNull);
  });
}
