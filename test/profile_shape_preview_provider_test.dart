import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nutro_ai/providers/profile_shape_preview_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('migra a última geração antiga sem apagar ao trocar a foto', () async {
    const userId = 42;
    const imageUrl = 'https://example.com/shape-antigo.jpg';
    const sourceImageBase64 = 'Zm90by1vcmlnaW5hbA==';
    SharedPreferences.setMockInitialValues({
      ProfileShapePreviewProvider.storageKey(userId): imageUrl,
      ProfileShapePreviewProvider.sourceImageStorageKey(userId):
          sourceImageBase64,
    });

    final provider = ProfileShapePreviewProvider();
    await provider.ensureLoaded();
    await provider.loadHistory(userId);

    expect(provider.generationHistory, hasLength(1));
    expect(provider.generationHistory.single.imageUrl, imageUrl);
    expect(
      provider.generationHistory.single.sourceImageBase64,
      sourceImageBase64,
    );

    await provider.clearGeneratedPreview(userId: userId);

    expect(provider.generatedImageUrl, isNull);
    expect(provider.generationHistory, hasLength(1));
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString(ProfileShapePreviewProvider.historyStorageKey(userId)),
      isNotNull,
    );
  });

  test('carrega todas as gerações da mais recente para a mais antiga',
      () async {
    const userId = 7;
    final storedHistory = [
      {
        'imageUrl': 'https://example.com/shape-antigo.jpg',
        'sourceImageBase64': 'YW50aWdh',
        'createdAt': '2026-01-01T10:00:00.000Z',
      },
      {
        'imageUrl': 'https://example.com/shape-novo.jpg',
        'sourceImageBase64': 'bm92YQ==',
        'createdAt': '2026-02-01T10:00:00.000Z',
      },
    ];
    SharedPreferences.setMockInitialValues({
      ProfileShapePreviewProvider.historyStorageKey(userId):
          jsonEncode(storedHistory),
    });

    final provider = ProfileShapePreviewProvider();
    await provider.ensureLoaded();
    await provider.loadHistory(userId);

    expect(provider.generationHistory, hasLength(2));
    expect(
      provider.generationHistory.map((entry) => entry.imageUrl),
      [
        'https://example.com/shape-novo.jpg',
        'https://example.com/shape-antigo.jpg',
      ],
    );
    expect(
      provider.generatedImageUrl,
      'https://example.com/shape-novo.jpg',
    );
  });
}
