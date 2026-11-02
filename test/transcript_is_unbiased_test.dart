import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The displayed transcript must be what the singer actually sang.
///
/// Whisper's `initialPrompt` biases decoding toward a given vocabulary.
/// While the recognized words were being aligned against the song's
/// lyrics, priming with those lyrics was the right trade: it fixed
/// spellings like "kita" being heard as "kata", and the alignment step
/// was what the output fed into.
///
/// It is now the wrong trade. The words are only displayed, never scored
/// or compared, so the one thing the panel is for is showing what came
/// out of the singer's mouth. A primed decode would print the expected
/// line to someone who mumbled or sang the wrong words, and nothing on
/// screen would tell that apart from a correct reading.
///
/// So this is a source-level test rather than a behavioural one: the
/// guarantee is that the production entry point *cannot* be handed a
/// reference, not merely that today's callers don't. A behavioural test
/// would need the native decoder, and would not catch a new call site.
void main() {
  late String service;

  setUpAll(() {
    service = File('lib/core/lyric_alignment_service.dart')
        .readAsStringSync();
  });

  String signatureOf(String fn) {
    final start = service.indexOf('Future<List<TranscribedWord>> $fn(');
    expect(start, isNot(-1), reason: '$fn is gone — has it been renamed?');
    final open = service.indexOf('{', start);
    final close = service.indexOf('}', open);
    return service.substring(start, close);
  }

  test('transcribeWords takes no expected or reference text', () {
    final sig = signatureOf('transcribeWords');
    expect(sig.contains('expectedText'), isFalse,
        reason: 'transcribeWords accepts expectedText again, so a caller '
            "can bias the decode toward lyrics the singer may not have "
            'sung. The transcript is displayed, not scored — it has to be '
            'what was actually heard.');
    expect(sig.contains('reference'), isFalse,
        reason: 'transcribeWords accepts a reference again');
  });

  test('no screen passes expected text into transcription', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      // The evaluation harness is the one legitimate caller: there, a
      // prompt is a variable being measured, not a decoration on a
      // transcript the user reads.
      if (entity.path.replaceAll(r'\', '/')
          .endsWith('services/eval_batch_service.dart')) {
        continue;
      }
      final text = entity.readAsStringSync();
      if (!text.contains('transcribeWords(')) continue;
      final call = text.substring(text.indexOf('transcribeWords('));
      final end = call.indexOf(');');
      if (end != -1 && call.substring(0, end).contains('expectedText')) {
        offenders.add(entity.path);
      }
    }
    expect(offenders, isEmpty,
        reason: 'these call transcribeWords with expectedText: '
            '${offenders.join(', ')}');
  });

  test('the prompt plumbing survives for measurement only', () {
    // Not a style preference: dropping initialPrompt altogether would
    // remove the ability to measure whether prompting helps at all, which
    // is a real experiment on a 43MB tiny model. It just must not be
    // reachable from the app's own path.
    expect(service.contains('initialPrompt: _promptFrom(expectedText)'),
        isTrue,
        reason: 'transcribeForEvaluation can no longer vary the prompt, '
            'so prompting cannot be measured');
    final evalSig = service.substring(
      service.indexOf('Future<WhisperPass?> transcribeForEvaluation('),
    );
    expect(evalSig.substring(0, evalSig.indexOf(';')).contains('expectedText'),
        isTrue,
        reason: 'transcribeForEvaluation lost its expectedText parameter');
  });
}
