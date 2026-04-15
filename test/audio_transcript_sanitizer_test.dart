import 'package:flutter_test/flutter_test.dart';
import 'package:nutro_ai/utils/audio_transcript_sanitizer.dart';

void main() {
  test('colapsa loop patologico de transcricao repetida', () {
    final transcript = List.filled(18, 'eu quero').join(', ');

    expect(sanitizeAudioTranscript(transcript), 'eu quero');
  });

  test('colapsa loop mesmo quando a primeira ocorrencia vem colada', () {
    final transcript =
        'Euquero, ${List.filled(17, 'eu quero').join(', ')}';

    expect(sanitizeAudioTranscript(transcript), 'Eu quero');
  });

  test('mantem frase normal sem repeticao artificial', () {
    const transcript =
        'Eu quero montar uma dieta com mais proteina e menos ultraprocessados.';

    expect(sanitizeAudioTranscript(transcript), transcript);
  });

  test('normaliza espacos sem colapsar repeticoes curtas legitimas', () {
    const transcript = 'nao   nao   nao';

    expect(sanitizeAudioTranscript(transcript), 'nao nao nao');
  });
}
