import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:final_thesis_ui/services/admin_media_service.dart';

void main() {
  group('validateGroundTruthJson', () {
    test('accepts a file shaped like the bundled ground truth', () {
      final valid = jsonEncode({
        'data': [
          {'syllable': 'nas', 'start': 15.665, 'end': 15.891, 'note': 'G3'},
          {'syllable': 'sa', 'start': 15.9, 'end': 16.1, 'note': 'A3'},
        ],
      });
      expect(() => AdminMediaService.validateGroundTruthJson(valid),
          returnsNormally);
    });

    test('accepts a file where only some entries are usable', () {
      // GroundTruthService skips unparseable rows rather than failing, so
      // validation must not be stricter than the loader.
      final partly = jsonEncode({
        'data': [
          {'syllable': 'x', 'note': 'not-a-note'},
          {'syllable': 'nas', 'start': 1.0, 'end': 1.5, 'note': 'G3'},
        ],
      });
      expect(() => AdminMediaService.validateGroundTruthJson(partly),
          returnsNormally);
    });

    test('rejects a file that is not JSON at all', () {
      expect(() => AdminMediaService.validateGroundTruthJson('not json {{'),
          throwsA(isA<FormatException>()));
    });

    test('rejects JSON that is not an object', () {
      expect(() => AdminMediaService.validateGroundTruthJson('[1, 2, 3]'),
          throwsA(isA<FormatException>()));
    });

    test('rejects an object with no data list', () {
      expect(
          () => AdminMediaService.validateGroundTruthJson(
              jsonEncode({'syllables': []})),
          throwsA(isA<FormatException>()));
    });

    test('rejects an empty data list', () {
      expect(
          () => AdminMediaService.validateGroundTruthJson(
              jsonEncode({'data': []})),
          throwsA(isA<FormatException>()));
    });

    test('rejects entries missing note or timings', () {
      final noTimes = jsonEncode({
        'data': [
          {'syllable': 'nas', 'note': 'G3'},
        ],
      });
      expect(() => AdminMediaService.validateGroundTruthJson(noTimes),
          throwsA(isA<FormatException>()));
    });

    test('rejects an entry whose end is not after its start', () {
      final backwards = jsonEncode({
        'data': [
          {'syllable': 'nas', 'start': 2.0, 'end': 1.0, 'note': 'G3'},
        ],
      });
      expect(() => AdminMediaService.validateGroundTruthJson(backwards),
          throwsA(isA<FormatException>()));
    });

    test('the error explains what was wrong', () {
      try {
        AdminMediaService.validateGroundTruthJson(jsonEncode({'data': []}));
        fail('should have thrown');
      } on FormatException catch (e) {
        expect(e.message, contains('data'));
      }
    });
  });

  group('lookups with an empty index', () {
    setUp(AdminMediaService.resetForTest);

    test('report nothing uploaded, so callers fall back to bundled assets', () {
      expect(AdminMediaService.audioPathFor('Nasa Iyo Na Ang Lahat'), isNull);
      expect(
          AdminMediaService.groundTruthPathFor('Nasa Iyo Na Ang Lahat'), isNull);
      expect(AdminMediaService.customSongs, isEmpty);
      expect(AdminMediaService.isCustomSong('Anything'), isFalse);
    });
  });
}
