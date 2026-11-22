import 'package:flutter_test/flutter_test.dart';

import 'package:final_thesis_ui/core/ondevice_crepe_service.dart';

/// Windowed analysis is only legitimate if it produces exactly the frames a
/// full sweep would have produced, minus the ones no consumer reads. If it
/// shifted a timestamp, skipped a frame inside a window, or analysed one
/// twice, the pitch results would change — which is the one thing this
/// optimisation is not allowed to do.
void main() {
  const frameSize = 1024;
  const sampleRate = 16000;

  // 50 ms at 16 kHz, the hop both result paths pass.
  const hop = 800;

  int msToSample(int ms) => (ms * sampleRate / 1000).round();
  int sampleToMs(int s) => (s / sampleRate * 1000).round();

  // Static, so this needs no platform binding and no microphone: the
  // window math is arithmetic, and keeping it callable without
  // constructing the service is what makes it testable at all.
  List<int> full(int samples) =>
      OnDeviceCrepeService.framePositionsForTest(samples, hop, null);

  List<int> windowed(int samples, List<AnalysisWindow> w) =>
      OnDeviceCrepeService.framePositionsForTest(samples, hop, w);

  group('full sweep', () {
    test('starts at zero and steps by the hop', () {
      final p = full(frameSize + hop * 3);
      expect(p, [0, hop, hop * 2, hop * 3]);
    });

    test('never runs past the last complete frame', () {
      // A partial trailing frame has no 1024 samples to feed the model.
      final p = full(frameSize + hop * 2 + 10);
      expect(p.last + frameSize, lessThanOrEqualTo(frameSize + hop * 2 + 10));
    });

    test('a buffer shorter than one frame yields nothing', () {
      expect(full(frameSize - 1), isEmpty);
      expect(full(0), isEmpty);
    });
  });

  group('windowed', () {
    final samples = msToSample(10000); // 10 s of audio

    test('is a subset of the full sweep, on the same grid', () {
      final w = windowed(samples, [
        const AnalysisWindow(1000, 1500),
        const AnalysisWindow(4000, 4300),
      ]);
      final f = full(samples).toSet();

      expect(w, isNotEmpty);
      // Same grid: every windowed position is one a full sweep produces,
      // so timestamps are identical, not merely close.
      for (final p in w) {
        expect(f.contains(p), isTrue,
            reason: '$p is not on the full-sweep hop grid');
      }
      expect(w.length, lessThan(f.length));
    });

    test('covers every hop inside a window', () {
      final w = windowed(samples, [const AnalysisWindow(1000, 1500)]);
      final times = w.map(sampleToMs).toList();

      // The grid snaps back to the hop before the window start, so the
      // window is fully covered rather than clipped at its leading edge.
      expect(times.first, lessThanOrEqualTo(1000));
      expect(times.last, greaterThanOrEqualTo(1500));
      for (var i = 1; i < w.length; i++) {
        expect(w[i] - w[i - 1], hop, reason: 'gap inside a window');
      }
    });

    test('produces no duplicate positions when windows overlap', () {
      final w = windowed(samples, [
        const AnalysisWindow(1000, 2000),
        const AnalysisWindow(1500, 2500), // overlaps the first
        const AnalysisWindow(1800, 1900), // fully inside
      ]);
      expect(w.toSet().length, w.length, reason: 'a frame analysed twice');
      expect(w, orderedEquals(List.of(w)..sort()));
    });

    test('merged overlapping windows equal the union of them', () {
      final merged = windowed(samples, [
        const AnalysisWindow(1000, 2000),
        const AnalysisWindow(1500, 2500),
      ]);
      final single = windowed(samples, [const AnalysisWindow(1000, 2500)]);
      expect(merged, single);
    });

    test('adjacent windows do not drop the frame between them', () {
      final two = windowed(samples, [
        const AnalysisWindow(1000, 1500),
        const AnalysisWindow(1500, 2000),
      ]);
      final one = windowed(samples, [const AnalysisWindow(1000, 2000)]);
      expect(two, one);
    });

    test('an empty window list means analyse everything', () {
      // Not "analyse nothing" — a song with no ground truth must not
      // silently come back with zero pitch data.
      expect(windowed(samples, const []), full(samples));
    });

    test('windows beyond the recording are clamped, not an error', () {
      final w = windowed(samples, [
        AnalysisWindow(-5000, 200), // starts before the recording
        const AnalysisWindow(999000, 999500), // starts after it ends
      ]);
      expect(w.first, 0);
      for (final p in w) {
        expect(p + frameSize, lessThanOrEqualTo(samples));
      }
    });

    test('a reversed window is ignored rather than inverting the loop', () {
      final w = windowed(samples, [const AnalysisWindow(3000, 2000)]);
      expect(w, isEmpty);
    });
  });

  group('padded', () {
    test('widens both sides', () {
      const w = AnalysisWindow(1000, 1500);
      final p = w.padded(80);
      expect(p.startMs, 920);
      expect(p.endMs, 1580);
    });

    test('never pads below zero', () {
      const w = AnalysisWindow(30, 100);
      expect(w.padded(80).startMs, 0);
    });

    test('padding recovers the frames the nearest-frame fallback needs', () {
      final samples = msToSample(10000);
      const syllable = AnalysisWindow(2000, 2100);

      final tight = windowed(samples, [syllable]).map(sampleToMs).toList();
      final padded =
          windowed(samples, [syllable.padded(80)]).map(sampleToMs).toList();

      // The builders fall back to the nearest frame within 80ms of a
      // window when nothing landed inside it, so those frames have to
      // exist for the fallback to find.
      expect(padded.first, lessThan(tight.first));
      expect(padded.last, greaterThan(tight.last));
      expect(padded.length, greaterThan(tight.length));
    });
  });
}
