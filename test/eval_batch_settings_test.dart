import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:final_thesis_ui/services/eval_batch_service.dart';

/// The batch evaluator reads a clips.json that also carries each clip's
/// reference transcript. Handing that reference to Whisper as an
/// `initialPrompt` would bias the decoder toward the exact words it is
/// about to be scored against, so every WER it produced would be
/// meaningless. These tests pin that it cannot happen by accident.
void main() {
  String jsonOf(List<Map<String, dynamic>> rows) => jsonEncode(rows);

  group('isClipFile', () {
    test('accepts clips the fetcher writes', () {
      expect(EvalBatchService.isClipFile('fsc_0000.wav'), isTrue);
      expect(EvalBatchService.isClipFile('sung_tagalog_1.wav'), isTrue);
      expect(EvalBatchService.isClipFile('FLEURS_0001.WAV'), isTrue);
    });

    test('skips the fetcher\'s staging file', () {
      // An interrupted fetch leaves this behind, and transcribing it
      // would add a row no reference can match.
      expect(EvalBatchService.isClipFile('_tmp_fsc.wav'), isFalse);
    });

    test('skips non-audio siblings', () {
      expect(EvalBatchService.isClipFile('clips.json'), isFalse);
      expect(EvalBatchService.isClipFile('hypotheses.json'), isFalse);
      expect(EvalBatchService.isClipFile('notes.txt'), isFalse);
    });
  });

  group('parseClipSettings', () {
    test('reads lang and prompt, keyed by clip id', () {
      final settings = EvalBatchService.parseClipSettings(jsonOf([
        {'id': 'fsc_0000', 'lang': 'tl'},
        {'id': 'fallen_01', 'lang': 'en', 'prompt': 'what if I told you'},
      ]));

      expect(settings.keys, containsAll(['fsc_0000', 'fallen_01']));
      expect(settings['fsc_0000']!.lang, 'tl');
      expect(settings['fsc_0000']!.prompt, isNull);
      expect(settings['fallen_01']!.lang, 'en');
      expect(settings['fallen_01']!.prompt, 'what if I told you');
    });

    test('never turns a reference into a prompt', () {
      final settings = EvalBatchService.parseClipSettings(jsonOf([
        {
          'id': 'fsc_0000',
          'lang': 'tl',
          'reference': 'nasa iyo na ang lahat',
          'hypothesis': '',
        },
      ]));

      // The one thing that must hold: the answer key stays out of the
      // decoder.
      expect(settings['fsc_0000']!.prompt, isNull);
    });

    test('a reference does not become a prompt even alongside one', () {
      final settings = EvalBatchService.parseClipSettings(jsonOf([
        {
          'id': 'c1',
          'reference': 'the answer key',
          'prompt': 'the biasing text',
        },
      ]));

      expect(settings['c1']!.prompt, 'the biasing text');
      expect(settings['c1']!.prompt, isNot(contains('answer key')));
    });

    test('empty strings are treated as absent, not as a blank prompt', () {
      final settings = EvalBatchService.parseClipSettings(jsonOf([
        {'id': 'c1', 'lang': '', 'prompt': ''},
      ]));

      // An empty prompt would otherwise be reported as `prompted: true`
      // and wrongly flag an unprompted run as a separate condition.
      expect(settings['c1']!.lang, isNull);
      expect(settings['c1']!.prompt, isNull);
    });

    test('rows without a usable id are skipped', () {
      final settings = EvalBatchService.parseClipSettings(jsonOf([
        {'lang': 'tl'},
        {'id': '', 'lang': 'tl'},
        {'id': 42, 'lang': 'tl'},
        {'id': 'ok', 'lang': 'tl'},
      ]));

      expect(settings.keys, ['ok']);
    });

    test('malformed input falls back to defaults instead of throwing', () {
      // The batch should still run on its defaults; refusing to measure
      // anything because of a stray file is worse.
      expect(EvalBatchService.parseClipSettings('not json'), isEmpty);
      expect(EvalBatchService.parseClipSettings(''), isEmpty);
      expect(EvalBatchService.parseClipSettings('{"not": "a list"}'), isEmpty);
      expect(EvalBatchService.parseClipSettings('[1, 2, 3]'), isEmpty);
    });

    test('wrongly typed lang and prompt are ignored, not coerced', () {
      final settings = EvalBatchService.parseClipSettings(jsonOf([
        {'id': 'c1', 'lang': 5, 'prompt': ['a', 'b']},
      ]));

      expect(settings['c1']!.lang, isNull);
      expect(settings['c1']!.prompt, isNull);
    });

    test('the fetcher\'s own output parses', () {
      // Shape written by backend/fetch_eval_datasets.py.
      final settings = EvalBatchService.parseClipSettings(jsonOf([
        {
          'id': 'fsc_0000',
          'category': 'spoken_tagalog',
          'audio': 'fsc_0000.wav',
          'reference': 'ang pangarap ko ay nagmula sa iyo',
          'hypothesis': '',
          'lang': 'tl',
          'source': 'sapinsapin/filipinospeechcorpus (MIT)',
          'speaker_id': '01',
          'speech_type': 'read',
          'duration': 2.41,
          'notes': 'studio recorded; speaker held out for eval',
        },
        {
          'id': 'sung_tagalog_1',
          'category': 'sung_tagalog',
          'audio': 'sung_tagalog_1.wav',
          'reference': '',
          'hypothesis': '',
          'lang': 'tl',
          'source': 'record yourself',
        },
      ]));

      expect(settings.length, 2);
      expect(settings['fsc_0000']!.lang, 'tl');
      expect(settings['fsc_0000']!.prompt, isNull);
      expect(settings['sung_tagalog_1']!.prompt, isNull);
    });
  });
}
