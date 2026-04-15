import 'dart:math' as math;

String sanitizeAudioTranscript(String transcript) {
  final normalized = normalizeTranscriptSpacing(transcript);
  if (normalized.isEmpty) {
    return '';
  }

  final words = _extractWords(normalized.toLowerCase());
  if (words.length < 8) {
    return normalized;
  }

  final repeatedRun = _findDominantRepeatedRun(words);
  if (repeatedRun == null) {
    return normalized;
  }

  final coverageRatio = repeatedRun.coverageWords / words.length;
  final isLikelyLoop = coverageRatio >= 0.6 &&
      (normalized.length >= 80 || repeatedRun.coverageWords >= 12);

  if (!isLikelyLoop) {
    return normalized;
  }

  final collapsed = repeatedRun.pattern.join(' ');
  if (collapsed.isEmpty) {
    return normalized;
  }

  final startsUppercase = RegExp(r'^[A-ZÀ-Ý]').hasMatch(normalized);
  if (!startsUppercase) {
    return collapsed;
  }

  return '${collapsed[0].toUpperCase()}${collapsed.substring(1)}';
}

String normalizeTranscriptSpacing(String text) {
  return text
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(',.', '.')
      .replaceAll(' ,', ',')
      .replaceAll(' .', '.')
      .replaceAll(' ?', '?')
      .replaceAll(' !', '!')
      .trim();
}

List<String> _extractWords(String text) {
  final matches = RegExp(r"[A-Za-zÀ-ÿ0-9']+").allMatches(text);
  return matches.map((match) => match.group(0)!).toList(growable: false);
}

_RepeatedRun? _findDominantRepeatedRun(List<String> words) {
  _RepeatedRun? best;
  final maxPatternSize = math.min(6, words.length ~/ 2);

  for (var start = 0; start < words.length; start++) {
    for (var patternSize = 1; patternSize <= maxPatternSize; patternSize++) {
      if (start + (patternSize * 2) > words.length) {
        break;
      }

      final pattern = words.sublist(start, start + patternSize);
      var repeats = 1;
      var cursor = start + patternSize;

      while (cursor + patternSize <= words.length &&
          _matchesPattern(words, cursor, pattern)) {
        repeats++;
        cursor += patternSize;
      }

      final minRepeats = patternSize == 1 ? 8 : 4;
      if (repeats < minRepeats) {
        continue;
      }

      final candidate = _RepeatedRun(
        pattern: pattern,
        repeats: repeats,
        coverageWords: repeats * patternSize,
      );

      if (best == null ||
          candidate.coverageWords > best.coverageWords ||
          (candidate.coverageWords == best.coverageWords &&
              candidate.repeats > best.repeats)) {
        best = candidate;
      }
    }
  }

  return best;
}

bool _matchesPattern(List<String> words, int start, List<String> pattern) {
  for (var index = 0; index < pattern.length; index++) {
    if (words[start + index] != pattern[index]) {
      return false;
    }
  }

  return true;
}

class _RepeatedRun {
  const _RepeatedRun({
    required this.pattern,
    required this.repeats,
    required this.coverageWords,
  });

  final List<String> pattern;
  final int repeats;
  final int coverageWords;
}
