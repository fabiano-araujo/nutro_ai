import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nutro_ai/services/enhanced_progress_tracker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('radar data keeps stable competency keys for UI localization', () async {
    SharedPreferences.setMockInitialValues({
      'enhanced_essay_progress_user-1': jsonEncode([
        {
          'essayId': 'essay-1',
          'date': '2026-07-24T12:00:00.000',
          'totalScore': 800,
          'competencyScores': {
            'competencia1': 120,
            'competencia2': 140,
            'competencia3': 160,
            'competencia4': 180,
            'competencia5': 200,
          },
          'essayType': 'enem',
        },
      ]),
    });

    final radarData =
        await EnhancedProgressTracker().generateRadarChartData('user-1');

    expect(
      radarData.keys,
      orderedEquals([
        'competencia1',
        'competencia2',
        'competencia3',
        'competencia4',
        'competencia5',
      ]),
    );
    expect(radarData.values, orderedEquals([120, 140, 160, 180, 200]));
  });
}
