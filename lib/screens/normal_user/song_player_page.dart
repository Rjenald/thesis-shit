import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../../constants/app_colors.dart';
import '../../widgets/song_cover_art.dart';
import '../../core/audio_service.dart';
import '../../core/crepe_pitch_service.dart';
import '../../core/lyric_alignment_service.dart';
import '../../core/mixed_recording_service.dart';
import '../../core/note_utils.dart';
import '../../core/ondevice_crepe_service.dart';
import '../../core/pitch_detection_service.dart';
import '../../core/singing_segment_builder.dart';
import '../../core/web_audio_fix.dart';
import '../../widgets/pitch_graph.dart';
import '../../models/session_result.dart';
import '../../models/singing_segment.dart';
import '../../data/song_lyrics.dart';
import '../../services/ground_truth_service.dart';
import '../../services/lyrics_service.dart';
import '../../services/song_audio_service.dart';
import '../../services/song_catalog_service.dart';
import 'results_page.dart';

class SongPlayerPage extends StatefulWidget {
  final String songTitle;
  final String songArtist;
  final String songImage;

  const SongPlayerPage({
    super.key,
    required this.songTitle,
    required this.songArtist,
    this.songImage = '',
  });

  @override
  State<SongPlayerPage> createState() => _SongPlayerPageState();
}

class _SongPlayerPageState extends State<SongPlayerPage> {
  final AudioPlayer _player = AudioPlayer();
  PitchDetectionService? _micService;
  String _detectorLabel = '';

  // Live pitch graph — rolling cents-deviation history (null = no signal).
  static const int _centsHistoryMax = 90;
  final List<double?> _centsHistory = [];

  bool _isPlaying = false;
  bool _isRecording = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  // Playback speed (also slows/speeds pitch, like a tape — matches the
  // mixed recording export so the singer's voice stays in sync with it).
  static const List<double> _speedPresets = [0.7, 0.8, 0.9, 1.0, 1.1, 1.2];
  double _playbackSpeed = 1.0;

  List<LrcLine> _lyrics = [];
  bool _lyricsLoading = true;
  int _currentLyricIdx = -1;

  final List<double> _rawHz = [];
  final List<double> _rawCents = [];
  StreamSubscription<NoteResult?>? _micSub;

  // Voice recording
  StreamSubscription<List<int>>? _bytesSub;
  final List<int> _recordedPcm = [];
  Duration _recordStartPosition = Duration.zero;

  // Live scoring
  int _correctCount = 0;
  int _totalDetections = 0;

  // Pitch feedback
  String _pitchLabel = '';
  Color _pitchColor = Colors.transparent;
  IconData _pitchIcon = Icons.mic_none;

  // Scroll controller for lyrics auto-scroll
  final ScrollController _lyricsScrollCtrl = ScrollController();

  // High-frequency updates (position ticks ~several times/sec, pitch
  // results ~every 80ms) go through these instead of setState(), so only
  // the small widgets that actually need to redraw every tick do —
  // instead of rebuilding the whole page (lyrics list, header, controls)
  // on every single tick, which was the main source of jank/lag.
  final ValueNotifier<Duration> _positionNotifier = ValueNotifier(Duration.zero);
  final ValueNotifier<int> _scoreTick = ValueNotifier(0);

  // just_audio's positionStream reports the decoder's read position, which
  // runs ahead of what's actually audible once you account for output
  // buffering — worse on the emulator, but present on real devices too.
  // That made lyric highlighting fire before the matching word was heard,
  // on every song. This clock is _positionNotifier nudged back to line the
  // highlight up with what the singer actually hears; used only for lyric
  // sync, never for the progress bar/seek time, which must stay exact.
  static const Duration _lyricSyncOffset = Duration(milliseconds: 350);
  final ValueNotifier<Duration> _lyricPositionNotifier = ValueNotifier(Duration.zero);

  // ── Post-recording analysis pre-warming ───────────────────────────────────
  // The batch CREPE pass (target-vs-actual pitch, see _showResults) and
  // Whisper's lyric alignment both have a fixed one-time model-load cost.
  // Starting that here, while the song is loading/playing and well before
  // the user stops recording, moves it off the critical path — see
  // OnDeviceCrepeService._loadModelBytes / warmUpWhisperModel.
  final OnDeviceCrepeService _offlineCrepe = OnDeviceCrepeService();

  @override
  void initState() {
    super.initState();
    _initAudio();
    _loadLyrics();
    _offlineCrepe.preload().ignore();
    warmUpWhisperModel().ignore();
  }

  Future<void> _initAudio() async {
    final audio = SongAudioService.resolve(widget.songTitle);
    if (audio == null) {
      debugPrint('No audio URL for "${widget.songTitle}"');
      return;
    }
    try {
      // An admin-uploaded track lives on disk, not in the asset bundle.
      if (audio.isAsset) {
        await _player.setAsset(audio.path);
      } else {
        await _player.setFilePath(audio.path);
      }
      await _player.setVolume(1.0);
      _duration = _player.duration ?? Duration.zero;
      setState(() {});
    } catch (e) {
      debugPrint('Audio load failed: $e');
    }

    _player.positionStream.listen((pos) {
      if (!mounted) return;
      _position = pos;
      _positionNotifier.value = pos;
      final lyricPos = pos > _lyricSyncOffset ? pos - _lyricSyncOffset : Duration.zero;
      _lyricPositionNotifier.value = lyricPos;
      _updateLyricIndex(lyricPos);
    });
    _player.durationStream.listen((dur) {
      if (!mounted || dur == null) return;
      setState(() => _duration = dur);
    });
    _player.playerStateStream.listen((state) {
      if (!mounted) return;
      if (state.processingState == ProcessingState.completed) _onSongComplete();
      setState(() => _isPlaying = state.playing);
    });
  }

  Future<void> _loadLyrics() async {
    final local = LocalSongLyrics.getLyrics(widget.songTitle);
    if (local != null && local.isNotEmpty) {
      if (!mounted) return;
      setState(() { _lyrics = local; _lyricsLoading = false; });
      return;
    }
    try {
      final online = await LyricsService.fetchLyrics(
          title: widget.songTitle, artist: widget.songArtist);
      if (online.isNotEmpty && mounted) {
        setState(() { _lyrics = online; _lyricsLoading = false; });
        return;
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() => _lyricsLoading = false);
  }

  void _updateLyricIndex(Duration pos) {
    if (_lyrics.isEmpty) return;
    final ms = pos.inMilliseconds;
    int idx = -1;
    for (int i = 0; i < _lyrics.length; i++) {
      if (_lyrics[i].timestamp.inMilliseconds <= ms) {
        idx = i;
      } else {
        break;
      }
    }
    if (idx == -1 && _isPlaying && _lyrics.first.timestamp.inMilliseconds == 0) {
      idx = 0;
    }
    if (idx != _currentLyricIdx) {
      _currentLyricIdx = idx;
      if (mounted) setState(() {});
      _scrollToCurrentLyric();
    }
  }

  void _scrollToCurrentLyric() {
    if (_currentLyricIdx < 0 || !_lyricsScrollCtrl.hasClients) return;
    // Each lyric line is roughly 56px tall; center the current one
    final targetOffset = (_currentLyricIdx * 56.0) - 120.0;
    _lyricsScrollCtrl.animateTo(
      targetOffset.clamp(0.0, _lyricsScrollCtrl.position.maxScrollExtent),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  int _getHighlightedWordCount([Duration? at]) {
    if (_currentLyricIdx < 0 || _currentLyricIdx >= _lyrics.length) return 0;
    final pos = at ?? _lyricPositionNotifier.value;
    final lineStart = _lyrics[_currentLyricIdx].timestamp.inMilliseconds;
    final lineEnd = _currentLyricIdx + 1 < _lyrics.length
        ? _lyrics[_currentLyricIdx + 1].timestamp.inMilliseconds
        : lineStart + 5000;
    final dur = lineEnd - lineStart;
    if (dur <= 0) return 0;
    final elapsed = pos.inMilliseconds - lineStart;
    final progress = (elapsed / dur).clamp(0.0, 1.0);
    final words = _lyrics[_currentLyricIdx].text.split(' ');
    return (progress * words.length).ceil().clamp(0, words.length);
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> _toggleMic() async {
    _isRecording ? await _stopMic() : await _startMic();
  }

  Future<void> _startMic() async {
    // Detector priority: on-device CREPE (best — no network, matches the
    // thesis's on-device claim) -> network CREPE server, if reachable ->
    // local YIN (always works, no dependencies). Whichever one actually
    // starts becomes _micService; the rest are only tried on failure.
    bool ok = false;

    final onDeviceCrepe = OnDeviceCrepeService();
    if (await onDeviceCrepe.start()) {
      _micService = onDeviceCrepe;
      _detectorLabel = 'CREPE · on-device';
      ok = true;
    } else {
      onDeviceCrepe.dispose();

      final networkCrepe = CrepePitchService();
      if (await networkCrepe.start()) {
        _micService = networkCrepe;
        _detectorLabel = 'CREPE · server';
        ok = true;
      } else {
        networkCrepe.dispose();

        _micService = AudioService();
        if (await _micService!.start()) {
          _detectorLabel = 'YIN · offline';
          ok = true;
        } else {
          _micService?.dispose();
          _micService = null;
        }
      }
    }

    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission denied')));
      }
      return;
    }
    _recordStartPosition = _position;
    _recordedPcm.clear(); _correctCount = 0; _totalDetections = 0;
    _centsHistory.clear();

    _bytesSub = _micService!.rawBytes.listen((b) => _recordedPcm.addAll(b));

    _micSub = _micService!.results.listen((result) {
      if (!mounted) return;
      _rawHz.add(result?.frequency ?? 0);
      _rawCents.add(result?.cents ?? 0);

      final hasSignal = result != null && result.feedback != PitchFeedback.noSignal;
      _centsHistory.add(hasSignal ? result.cents : null);
      if (_centsHistory.length > _centsHistoryMax) {
        _centsHistory.removeAt(0);
      }

      if (hasSignal) {
        _totalDetections++;
        if (result.feedback == PitchFeedback.correct) {
          _correctCount++;
          final ac = result.cents.abs();
          if (ac <= 5) {
            _pitchLabel = 'PERFECT'; _pitchColor = const Color(0xFF4CAF50);
            _pitchIcon = Icons.star;
          } else if (ac <= 10) {
            _pitchLabel = 'GREAT'; _pitchColor = const Color(0xFF2196F3);
            _pitchIcon = Icons.check_circle;
          } else {
            _pitchLabel = 'GOOD'; _pitchColor = const Color(0xFFFF9800);
            _pitchIcon = Icons.thumb_up;
          }
        } else {
          _pitchLabel = 'MISS'; _pitchColor = const Color(0xFFF44336);
          _pitchIcon = Icons.close;
        }
      }
      _scoreTick.value++;
    });
    setState(() => _isRecording = true);

    // Web only: browsers can duck <audio> elements when getUserMedia() is
    // granted. Native platforms no longer need a workaround here now that
    // AudioService.start() configures the recorder to not steal audio focus
    // / interrupt the shared audio session (see audio_service.dart).
    await _player.setVolume(1.0);
    fixWebAudioDucking();
    if (!_player.playing) await _player.play();
  }

  Future<void> _stopMic() async {
    await _bytesSub?.cancel(); _bytesSub = null;
    await _micSub?.cancel(); _micSub = null;
    await _micService?.stop(); _micService?.dispose(); _micService = null;
    setState(() { _isRecording = false; _pitchLabel = ''; _pitchColor = Colors.transparent; });
  }

  Future<void> _onSongComplete() async {
    await _stopMic();
    if (!mounted) return;
    await _showResults();
  }

  Future<void> _showResults() async {
    if (_rawHz.isEmpty) { Navigator.pop(context); return; }
    Uint8List? wav = _recordedPcm.isNotEmpty ? _buildWav(_recordedPcm) : null;
    final micOnlyWav = wav;

    // The end of the RECORDED audio, not wherever song playback position
    // happens to be after _player.stop() — that stream's behavior around
    // stop() isn't something to depend on. Derived straight from how many
    // samples were actually captured, which is also exactly what the CREPE
    // pass below (and the lyric-line time filtering further down) uses, so
    // none of them can disagree with each other.
    const sampleRate = 16000;
    final recordedDurationMs =
        (_recordedPcm.length / 2 / sampleRate * 1000).round();
    final recordEndOffset =
        _recordStartPosition + Duration(milliseconds: recordedDurationMs);

    // Logged outside the `if (wav != null)` below, because that is exactly
    // the case worth seeing: with no captured PCM the whole ground-truth
    // pass is skipped and the result screen shows a score and drills but no
    // Pitch Timeline, while every other diagnostic here stays silent.
    // _rawHz comes from the live pitch stream and _recordedPcm from the raw
    // byte stream, so one can be full while the other is empty.
    debugPrint('Recording captured: pcmBytes=${_recordedPcm.length} '
        '(${recordedDurationMs}ms), liveReadings=${_rawHz.length}, '
        'detector=$_detectorLabel, '
        'start=$_recordStartPosition end=$recordEndOffset');
    if (_recordedPcm.isEmpty) {
      debugPrint('  !! no PCM captured — skipping ground-truth analysis, '
          'so there will be no Pitch Timeline for this take.');
    }

    List<SingingSegment> singingSegments = const [];
    // Mixing the backing track into the recording (ffmpeg, via
    // mixSongAndVoice) is the slowest of these three independent steps, but
    // it's only needed for the optional "Listen"/"My Voice" playback on the
    // results screen — not for anything scoring/analysis-related. Awaiting
    // it before navigating was adding its full duration to every wait,
    // for a feature the user might not even use that session. It's kicked
    // off here but deliberately NOT awaited below — ResultsPage gets the
    // mic-only WAV immediately and upgrades to this once it resolves.
    Future<Uint8List?>? pendingMixedAudio;

    if (wav != null) {
      _showMixingDialog();
      // The dialog blocks back-navigation (PopScope canPop: false) while
      // it's up, so if anything below throws or hangs without this
      // try/finally, the user would be stuck on it with no way out — this
      // guarantees it always gets dismissed, success or failure.
      try {
        // Ground truth is a small local JSON parse — check it first so the
        // batch CREPE pass below only runs when there's an actual target
        // melody to compare against (most songs don't have one yet).
        final groundTruth = await GroundTruthService.loadForSong(widget.songTitle);

        final audio = SongAudioService.resolve(widget.songTitle);
        pendingMixedAudio = audio != null
            ? mixSongAndVoice(
                songPath: audio.path,
                songIsAsset: audio.isAsset,
                songStartOffset: _recordStartPosition,
                micWavBytes: wav,
                playbackSpeed: _playbackSpeed,
              )
            : null;

        // Transcribe the clean mic-only audio with Whisper once — its
        // output feeds both the existing lyric-alignment card and (for
        // songs with a ground truth) the pitch segments' "what did I
        // actually sing" word — and, only if this song has a ground truth
        // melody, run batch CREPE pitch analysis over that same mic-only
        // audio for target-vs-actual pitch comparison. Independent work,
        // run concurrently; this is what the result screen actually needs
        // before it can show anything, so it's the only thing still
        // awaited here.
        final hasGroundTruth = groundTruth != null && groundTruth.isNotEmpty;
        debugPrint('Ground truth for "${widget.songTitle}": '
            '${groundTruth?.length ?? 'null'} syllables, hasGroundTruth=$hasGroundTruth, '
            'recordStartOffset=$_recordStartPosition, recordEndOffset=$recordEndOffset');

        // Whisper and CREPE are independent analyses — one throwing (a bad
        // model load, a native decode error, whatever) must not also take
        // down the other, since Future.wait rejects as soon as either
        // future does. Each is caught individually so a single failure
        // degrades gracefully (empty result for that one) instead of
        // silently discarding both, which previously made buildSingingSegments
        // never even run and the whole ground-truth UI look empty even
        // though nothing was actually wrong with the pitch analysis itself.
        // The lyrics are NOT handed to Whisper, even though this song's
        // are known. The transcript is only displayed — as the words we
        // heard — so biasing the decoder toward the expected text would
        // show those words to a singer who sang something else, and
        // nothing on screen would distinguish that from a correct
        // reading. Scoring comes from pitch and is unaffected.
        final transcribeFuture = transcribeWords(
          micOnlyWav!,
          // Per-song: forcing Tagalog on an English song degrades the whole
          // decode, and at least one catalogued song is sung in English.
          lang: SongCatalogService.languageFor(widget.songTitle),
        ).catchError((e, st) {
          debugPrint('Whisper transcription step failed: $e\n$st');
          return <TranscribedWord>[];
        });
        // Only the syllable windows are worth model time: the segment
        // builder reads frames inside a ground-truth syllable's window and
        // discards everything else, so a full sweep spent most of its
        // inference on frames nothing would ever look at. Padded by the
        // same tolerance the builder's nearest-frame fallback uses, so
        // narrowing the analysis cannot remove a frame it would have used.
        final analysisWindows = hasGroundTruth
            ? groundTruth
                .where((g) =>
                    g.endTime >= _recordStartPosition &&
                    g.startTime <= recordEndOffset)
                .map((g) => AnalysisWindow(
                      g.startTime.inMilliseconds -
                          _recordStartPosition.inMilliseconds,
                      g.endTime.inMilliseconds -
                          _recordStartPosition.inMilliseconds,
                    ).padded(kNearestFrameToleranceMs))
                .toList()
            : const <AnalysisWindow>[];

        final crepeFuture = hasGroundTruth
            ? _offlineCrepe
                .analyzeOffline(
                _pcmBytesToInt16(_recordedPcm),
                hopMs: 50,
                windows: analysisWindows,
              )
                .catchError((e, st) {
                debugPrint('CREPE analysis step failed: $e\n$st');
                return <PitchFrame>[];
              })
            : Future<List<PitchFrame>>.value(const <PitchFrame>[]);

        // Bounded so an unforeseen hang anywhere in this pipeline can never
        // leave the "Preparing the result..." dialog stuck up forever.
        final results = await Future.wait([transcribeFuture, crepeFuture])
            .timeout(const Duration(minutes: 2));
        final recognizedWords = results[0] as List<TranscribedWord>;
        final pitchFrames = results[1] as List<PitchFrame>;
        debugPrint('recognizedWords=${recognizedWords.length}, '
            'pitchFrames=${pitchFrames.length} '
            '(voiced=${pitchFrames.where((f) => f.hasSignal).length})');

        if (hasGroundTruth) {
          singingSegments = buildSingingSegments(
            groundTruth: groundTruth,
            pitchFrames: pitchFrames,
            recordStartOffset: _recordStartPosition,
            recordEndOffset: recordEndOffset,
            recognizedWords: recognizedWords,
          );
          debugPrint('singingSegments=${singingSegments.length} '
              '(noSignal=${singingSegments.where((s) => s.status == PitchFeedback.noSignal).length})');
        }
      } catch (e, st) {
        // Whatever failed, the recording itself is still fine to save and
        // show — just without alignment/pitch data. Silently losing the
        // whole result because one optional analysis step failed would be
        // worse than showing a partial one.
        debugPrint('Post-recording analysis failed: $e\n$st');
      } finally {
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
      }
    }

    if (!mounted) return;
    final session = SessionResult(
      songTitle: widget.songTitle, songArtist: widget.songArtist,
      songImage: widget.songImage, completedAt: DateTime.now(),
      lyricResults: _buildLyricResults(recordEndOffset), durationSeconds: _position.inSeconds,
      singingSegments: singingSegments,
    );
    Navigator.pushReplacement(context, MaterialPageRoute(
      builder: (_) => ResultsPage(
        session: session, recordedVoiceWav: wav,
        pendingMixedAudio: pendingMixedAudio),
    ));
  }

  void _showMixingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: AppColors.cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: const Padding(
            padding: EdgeInsets.all(24),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppColors.primaryCyan),
                SizedBox(width: 16),
                Flexible(
                  child: Text(
                    'Preparing the result...',
                    style: TextStyle(color: Colors.white, fontFamily: 'Roboto'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Maps each lyric LINE's own expected time window onto [_rawHz]/
  /// [_rawCents], skipping any line whose window falls entirely outside
  /// [recordEndOffset] — [_recordStartPosition, recordEndOffset] is what was
  /// actually recorded. The previous approach divided the whole recording
  /// into one bucket per lyric line in the FULL SONG regardless of how much
  /// of it was actually covered, so a short recording still "produced" a
  /// result for every line, including ones the user never reached, by
  /// stretching whatever little real data existed across all of them —
  /// which is how lines nobody sang ended up labeled with a pitch status.
  ///
  /// Readings have no individual timestamp, but the live pitch stream fires
  /// at a roughly steady cadence, so the actual recorded duration divided by
  /// the reading count is a reasonable estimate of time-per-reading for
  /// mapping a line's time window to an array-index range.
  List<LyricPitchData> _buildLyricResults(Duration recordEndOffset) {
    final total = _rawHz.length;
    if (total == 0) return [];

    if (_lyrics.isEmpty) {
      // No timed lyrics to match lines against — fall back to a generic
      // even split across the whole recording.
      const seg = 30;
      final sz = (total / seg).ceil();
      return List.generate(seg, (i) {
        final s = i * sz;
        final e = (s + sz).clamp(0, total);
        if (s >= total) return null;
        return LyricPitchData(
          lyricText: 'Segment ${i + 1}',
          pitchReadings: _rawHz.sublist(s, e),
          centsReadings: _rawCents.sublist(s, e),
        );
      }).whereType<LyricPitchData>().toList();
    }

    final recordedDurationMs =
        (recordEndOffset - _recordStartPosition).inMilliseconds;
    if (recordedDurationMs <= 0) return [];
    final msPerReading = recordedDurationMs / total;

    final results = <LyricPitchData>[];
    for (var i = 0; i < _lyrics.length; i++) {
      final lineStart = _lyrics[i].timestamp;
      final lineEnd = i + 1 < _lyrics.length
          ? _lyrics[i + 1].timestamp
          : lineStart + const Duration(seconds: 5);

      // Line's time window doesn't overlap the recorded window at all —
      // the user never reached (or had already passed) this line.
      if (lineEnd <= _recordStartPosition || lineStart >= recordEndOffset) {
        continue;
      }

      final startMs = (lineStart - _recordStartPosition)
          .inMilliseconds
          .clamp(0, recordedDurationMs);
      final endMs = (lineEnd - _recordStartPosition)
          .inMilliseconds
          .clamp(0, recordedDurationMs);
      final s = (startMs / msPerReading).round().clamp(0, total);
      final e = (endMs / msPerReading).round().clamp(s, total);
      if (s >= e) continue;

      results.add(LyricPitchData(
        lyricText: _lyrics[i].text,
        pitchReadings: _rawHz.sublist(s, e),
        centsReadings: _rawCents.sublist(s, e),
      ));
    }
    return results;
  }

  /// The mic's rawBytes stream (buffered into [_recordedPcm]) is raw PCM16LE
  /// bytes, one element per byte — CREPE's batch analysis needs actual int16
  /// sample values, so decode each little-endian pair.
  List<int> _pcmBytesToInt16(List<int> bytes) {
    final byteData = Uint8List.fromList(bytes).buffer.asByteData();
    final samples = <int>[];
    for (var i = 0; i + 1 < bytes.length; i += 2) {
      samples.add(byteData.getInt16(i, Endian.little));
    }
    return samples;
  }

  Uint8List _buildWav(List<int> pcm) {
    const sr = 16000; const ch = 1; const bps = 16;
    final br = sr * ch * bps ~/ 8; final ba = ch * bps ~/ 8; final n = pcm.length;
    final b = ByteData(44 + n);
    b.setUint8(0,0x52);b.setUint8(1,0x49);b.setUint8(2,0x46);b.setUint8(3,0x46);
    b.setUint32(4,36+n,Endian.little);
    b.setUint8(8,0x57);b.setUint8(9,0x41);b.setUint8(10,0x56);b.setUint8(11,0x45);
    b.setUint8(12,0x66);b.setUint8(13,0x6D);b.setUint8(14,0x74);b.setUint8(15,0x20);
    b.setUint32(16,16,Endian.little);b.setUint16(20,1,Endian.little);
    b.setUint16(22,ch,Endian.little);b.setUint32(24,sr,Endian.little);
    b.setUint32(28,br,Endian.little);b.setUint16(32,ba,Endian.little);
    b.setUint16(34,bps,Endian.little);
    b.setUint8(36,0x64);b.setUint8(37,0x61);b.setUint8(38,0x74);b.setUint8(39,0x61);
    b.setUint32(40,n,Endian.little);
    for(int i=0;i<n;i++) {
      b.setUint8(44+i,pcm[i]&0xFF);
    }
    return b.buffer.asUint8List();
  }

  double get _liveScore => _totalDetections > 0 ? (_correctCount / _totalDetections * 100) : 0;
  String _getRank(double s) {
    if(s>=95)return'S+';if(s>=90)return'S';if(s>=80)return'A';
    if(s>=65)return'B';if(s>=50)return'C';return'D';
  }
  Color _getRankColor(String r) {
    switch(r){case'S+':case'S':return const Color(0xFFFFD700);
    case'A':return const Color(0xFF4CAF50);case'B':return const Color(0xFF2196F3);
    case'C':return const Color(0xFFFF9800);default:return const Color(0xFFF44336);}
  }
  String _fmt(Duration d) {
    final m=d.inMinutes.toString().padLeft(2,'0');
    final s=(d.inSeconds%60).toString().padLeft(2,'0');return'$m:$s';
  }

  @override
  void dispose() {
    _player.dispose();
    _lyricsScrollCtrl.dispose();
    _positionNotifier.dispose();
    _lyricPositionNotifier.dispose();
    _scoreTick.dispose();
    _bytesSub?.cancel(); _micSub?.cancel(); _micService?.dispose();
    _offlineCrepe.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD — Spotify-style lyrics player
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            // Song image + info
            _buildSongInfo(),
            // Scrolling lyrics (main area)
            Expanded(child: _buildLyricsBody()),
            // Pitch + score bar
            if (_isRecording)
              ValueListenableBuilder<int>(
                valueListenable: _scoreTick,
                builder: (context, tick, child) => _buildBottomInfo(),
              ),
            // Progress + controls
            _buildProgressBar(),
            _buildControls(),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── HEADER ──
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 28),
            onPressed: () { _player.stop(); _stopMic(); Navigator.pop(context); },
          ),
          Expanded(
            child: Text(
              'NOW PLAYING',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                fontFamily: 'Roboto',
                letterSpacing: 1.5,
              ),
            ),
          ),
          if (_isRecording)
            Row(mainAxisSize: MainAxisSize.min, children: [
              if (_detectorLabel.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryCyan.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primaryCyan.withValues(alpha: 0.5)),
                  ),
                  child: Text(_detectorLabel,
                      style: const TextStyle(color: AppColors.primaryCyan, fontSize: 9, fontWeight: FontWeight.bold, fontFamily: 'Roboto', letterSpacing: 0.3)),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(10)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.fiber_manual_record, color: Colors.white, size: 8),
                  SizedBox(width: 3),
                  Text('REC', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Roboto')),
                ]),
              ),
            ])
          else
            const SizedBox(width: 40),
        ],
      ),
    );
  }

  // ── SONG INFO (album art + title like Spotify) ──
  Widget _buildSongInfo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
      child: Row(
        children: [
          // Album art
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: AppColors.cardBg,
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            // borderRadius 0: the parent Container already clips this
            // with its own rounded shape and antialiasing.
            child: SongCoverArt(
              image: widget.songImage,
              width: double.infinity,
              height: double.infinity,
              borderRadius: 0,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.songTitle,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'Roboto'),
                    overflow: TextOverflow.ellipsis, maxLines: 1),
                const SizedBox(height: 2),
                Text(widget.songArtist,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13, fontFamily: 'Roboto'),
                    overflow: TextOverflow.ellipsis, maxLines: 1),
              ],
            ),
          ),
        ],
      ),
    );
  }


  // ── LYRICS BODY — Spotify-style scrolling lyrics ──
  Widget _buildLyricsBody() {
    if (_lyricsLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryCyan));
    }
    if (_lyrics.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lyrics_outlined, color: Colors.white.withValues(alpha: 0.15), size: 64),
            const SizedBox(height: 16),
            Text('No lyrics available',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 16, fontFamily: 'Roboto')),
            const SizedBox(height: 6),
            Text('Sing along to the music!',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 13, fontFamily: 'Roboto')),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ShaderMask(
        shaderCallback: (bounds) => LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black,
            Colors.black,
            Colors.transparent,
          ],
          stops: const [0.0, 0.08, 0.92, 1.0],
        ).createShader(bounds),
        blendMode: BlendMode.dstIn,
        child: ListView.builder(
          controller: _lyricsScrollCtrl,
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
          itemCount: _lyrics.length,
          itemBuilder: (ctx, i) {
            final isCurrent = i == _currentLyricIdx;
            final isPast = _currentLyricIdx >= 0 && i < _currentLyricIdx;

            if (isCurrent) {
              return ValueListenableBuilder<Duration>(
                valueListenable: _lyricPositionNotifier,
                builder: (context, pos, _) =>
                    _buildCurrentLyricLine(i, _getHighlightedWordCount(pos)),
              );
            }

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                _lyrics[i].text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isPast
                      ? Colors.white.withValues(alpha: 0.25)
                      : Colors.white.withValues(alpha: 0.45),
                  fontSize: isPast ? 16 : 18,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Roboto',
                  height: 1.4,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Current lyric line — word-by-word highlight (green active, white upcoming)
  Widget _buildCurrentLyricLine(int lineIdx, int highlightCount) {
    final text = _lyrics[lineIdx].text;
    final words = text.split(' ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          children: words.asMap().entries.map((entry) {
            final i = entry.key;
            final word = entry.value;
            final isSung = i < highlightCount;
            final space = i < words.length - 1 ? ' ' : '';

            return TextSpan(
              text: '$word$space',
              style: TextStyle(
                color: isSung ? AppColors.primaryCyan : Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                fontFamily: 'Roboto',
                height: 1.4,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── BOTTOM INFO: Score + Pitch badge ──
  Widget _buildBottomInfo() {
    final score = _liveScore;
    final rank = _getRank(score);
    final rc = _getRankColor(rank);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${score.toStringAsFixed(0)}%',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Roboto')),
                    const SizedBox(width: 8),
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: rc.withValues(alpha: 0.15), shape: BoxShape.circle,
                        border: Border.all(color: rc, width: 2),
                      ),
                      child: Center(child: Text(rank,
                          style: TextStyle(color: rc, fontSize: rank.length > 1 ? 9 : 13,
                              fontWeight: FontWeight.w900, fontFamily: 'Roboto'))),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (_pitchLabel.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: _pitchColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _pitchColor.withValues(alpha: 0.5), width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_pitchIcon, color: _pitchColor, size: 14),
                      const SizedBox(width: 4),
                      Text(_pitchLabel,
                          style: TextStyle(color: _pitchColor, fontSize: 12,
                              fontWeight: FontWeight.w800, fontFamily: 'Roboto', letterSpacing: 1)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          PitchGraph(centsHistory: _centsHistory),
        ],
      ),
    );
  }

  // ── PROGRESS ──
  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: ValueListenableBuilder<Duration>(
        valueListenable: _positionNotifier,
        builder: (context, pos, _) {
          final p = _duration.inMilliseconds > 0
              ? (pos.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0) : 0.0;
          return Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: p, minHeight: 3,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1DB954)),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_fmt(pos), style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10, fontFamily: 'Roboto')),
                  _buildSpeedChip(),
                  Text(_fmt(_duration), style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10, fontFamily: 'Roboto')),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _cycleSpeed() async {
    final idx = _speedPresets.indexOf(_playbackSpeed);
    final next = _speedPresets[(idx + 1) % _speedPresets.length];
    setState(() => _playbackSpeed = next);
    await _player.setSpeed(next);
  }

  Widget _buildSpeedChip() {
    return GestureDetector(
      onTap: _cycleSpeed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: _playbackSpeed == 1.0
              ? Colors.white.withValues(alpha: 0.06)
              : AppColors.primaryCyan.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _playbackSpeed == 1.0
                ? Colors.white.withValues(alpha: 0.1)
                : AppColors.primaryCyan.withValues(alpha: 0.4),
          ),
        ),
        child: Text(
          '${_playbackSpeed.toStringAsFixed(1)}x',
          style: TextStyle(
            color: _playbackSpeed == 1.0 ? Colors.white.withValues(alpha: 0.5) : AppColors.primaryCyan,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            fontFamily: 'Roboto',
          ),
        ),
      ),
    );
  }

  // ── CONTROLS ──
  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ctrlBtn(icon: _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, onTap: _togglePlay, size: 28),
          // Mic button
          GestureDetector(
            onTap: _toggleMic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 58, height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isRecording ? Colors.red : Colors.transparent,
                border: Border.all(color: _isRecording ? Colors.red : Colors.white, width: 3),
              ),
              child: Icon(
                _isRecording ? Icons.mic : Icons.mic_none,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
          _ctrlBtn(icon: Icons.stop_rounded, onTap: () async {
            await _player.stop();
            await _stopMic();
            if (!mounted) return;
            _rawHz.isNotEmpty ? await _showResults() : Navigator.pop(context);
          }, size: 28),
        ],
      ),
    );
  }

  Widget _ctrlBtn({required IconData icon, required VoidCallback onTap, double size = 24}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46, height: 46,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08), shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Icon(icon, color: Colors.white, size: size),
      ),
    );
  }
}
