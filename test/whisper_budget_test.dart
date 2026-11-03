import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:final_thesis_ui/core/lyric_alignment_service.dart';
import 'package:final_thesis_ui/services/admin_media_service.dart';

/// How long one Whisper decode is allowed to take.
///
/// It was a flat 90 seconds. ggml-tiny runs at roughly 2–4x realtime on a
/// mid-range Android phone, so a three-to-four minute karaoke take lands
/// either side of that line: past it the decode was abandoned, the pass
/// returned null, and the result screen showed no words — with nothing on
/// screen separating "the model heard nothing" from "we stopped waiting".
/// Short takes were unaffected, which is exactly why it read as the model
/// being unreliable rather than as a timeout.
void main() {
  /// Bytes of 16 kHz mono PCM16 for [seconds] of audio.
  int bytesFor(double seconds) => (seconds * 16000 * 2).round();

  test('a short take still gets a generous floor', () {
    // A ten-second drill must not get a ten-second budget.
    expect(whisperTimeoutFor(bytesFor(10)).inSeconds, greaterThanOrEqualTo(90));
  });

  test('a whole song gets more than the old flat 90 seconds', () {
    // The case that was failing: a full karaoke take.
    for (final minutes in [3, 4, 5]) {
      final budget = whisperTimeoutFor(bytesFor(minutes * 60.0));
      expect(budget.inSeconds, greaterThan(90),
          reason: '$minutes-minute take');
      // And comfortably more than the audio itself, since the decode is
      // slower than realtime on the phones this has to run on.
      expect(budget.inSeconds, greaterThan(minutes * 60 * 2),
          reason: '$minutes-minute take needs headroom over 2x realtime');
    }
  });

  test('the budget grows with the recording', () {
    var previous = Duration.zero;
    for (final seconds in [30.0, 60.0, 120.0, 240.0]) {
      final budget = whisperTimeoutFor(bytesFor(seconds));
      expect(budget, greaterThanOrEqualTo(previous),
          reason: 'at ${seconds}s');
      previous = budget;
    }
  });

  test('it is still bounded, so a hung decode cannot wait forever', () {
    // An hour of audio should not buy an open-ended wait.
    expect(whisperTimeoutFor(bytesFor(3600)).inMinutes, lessThanOrEqualTo(20));
  });

  test('an empty recording does not produce a zero or negative budget', () {
    expect(whisperTimeoutFor(0).inSeconds, greaterThanOrEqualTo(90));
    expect(whisperTimeoutFor(44).inSeconds, greaterThanOrEqualTo(90));
  });

  group('picking the wrong ground-truth file in admin', () {
    // Both files the notebook writes end in .json, so the picker offers
    // both. Rejecting the wrong one is not enough — the admin has to be
    // told which one to pick instead.
    test('a words file is rejected by name, not by shape', () {
      final words = jsonEncode({
        'stem': 'Buwan - Juan Karlos',
        'source': 'MMS_FA forced alignment of the vocal stem',
        'words': [
          {'text': "Ako'y", 'start': 28.384, 'end': 28.844, 'score': 0.67},
        ],
      });
      expect(
        () => AdminMediaService.validateGroundTruthJson(words),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          allOf(contains('words.json'), contains('<song>.json')),
        )),
      );
    });

    test('the notes file is still accepted', () {
      final notes = jsonEncode({
        'data': [
          {'syllable': '', 'start': 0.67, 'end': 0.88, 'note': 'C4'},
        ],
      });
      expect(() => AdminMediaService.validateGroundTruthJson(notes),
          returnsNormally);
    });

    test('a file with neither key still gets the generic message', () {
      expect(
        () => AdminMediaService.validateGroundTruthJson('{"nope": 1}'),
        throwsA(isA<FormatException>()
            .having((e) => e.message, 'message', contains('data'))),
      );
    });
  });
}
