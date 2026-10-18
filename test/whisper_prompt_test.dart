import 'package:flutter_test/flutter_test.dart';
import 'package:final_thesis_ui/core/lyric_alignment_service.dart'
    show promptFromForTest;

void main() {
  group('Whisper initial prompt', () {
    test('passes short lyrics through unchanged', () {
      expect(promptFromForTest("Nasa 'yo na ang lahat, minamahal kita"),
          "Nasa 'yo na ang lahat, minamahal kita");
    });

    test('collapses newlines and runs of whitespace', () {
      expect(promptFromForTest('line one\n\n  line   two\t\tline three'),
          'line one line two line three');
    });

    test('null and blank mean no prompt, matching whisper.cpp default', () {
      expect(promptFromForTest(null), isNull);
      expect(promptFromForTest(''), isNull);
      expect(promptFromForTest('   \n\t  '), isNull);
    });

    test('a long song is trimmed to the prompt budget', () {
      final long = List.filled(400, 'minamahal').join(' ');
      final out = promptFromForTest(long)!;
      expect(out.length, lessThanOrEqualTo(600));
      expect(long, startsWith(out));
    });

    test('trimming never cuts a word in half', () {
      // A half-word is nothing but noise to bias decoding on.
      final long = List.filled(400, 'minamahal').join(' ');
      final out = promptFromForTest(long)!;
      expect(out.endsWith('minamahal'), isTrue,
          reason: 'should end on a whole word');
      expect(out.trimRight(), out, reason: 'no trailing space');
    });

    test('a single word longer than the budget still yields something', () {
      final giant = 'a' * 900;
      final out = promptFromForTest(giant)!;
      expect(out.length, lessThanOrEqualTo(600));
      expect(out.isNotEmpty, isTrue);
    });
  });
}
