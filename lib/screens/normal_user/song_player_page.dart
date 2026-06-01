import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../../constants/app_colors.dart';
import '../../core/audio_service.dart';
import '../../core/note_utils.dart';
import '../../models/session_result.dart';
import '../../data/song_lyrics.dart';
import '../../services/lyrics_service.dart';
import '../../services/song_audio_service.dart';
import 'results_page.dart';

class SongPlayerPage extends StatefulWidget {
  final String songTitle;
  final String songArtist;
  final String songImage;
  final bool isAssignment;

  const SongPlayerPage({
    super.key,
    required this.songTitle,
    required this.songArtist,
    this.songImage = '',
    this.isAssignment = false,
  });

  @override
  State<SongPlayerPage> createState() => _SongPlayerPageState();
}

class _SongPlayerPageState extends State<SongPlayerPage> {
  final AudioPlayer _player = AudioPlayer();
  AudioService? _micService;

  bool _isPlaying = false;
  bool _isRecording = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  List<LrcLine> _lyrics = [];
  bool _lyricsLoading = true;
  int _currentLyricIdx = -1;
  final ScrollController _lyricsScroll = ScrollController();

  final List<double> _rawHz = [];
  final List<double> _rawCents = [];
  StreamSubscription<NoteResult?>? _micSub;

  final ValueNotifier<NoteResult?> _pitchNotifier = ValueNotifier(null);

  // Live pitch log (shown in table while recording)
  final List<_PitchEntry> _pitchLog = [];

  // Voice recording — raw PCM bytes for WAV playback on results
  StreamSubscription<List<int>>? _bytesSub;
  final List<int> _recordedPcm = [];

  // Equalizer bars
  Timer? _eqTimer;
  final List<double> _eqBars = List.filled(24, 0.15);
  final List<double> _eqTargets = List.filled(24, 0.15);
  final _rng = math.Random();

  @override
  void initState() {
    super.initState();
    _initAudio();
    _loadLyrics();
    _startEqualizer();
  }

  void _startEqualizer() {
    _eqTimer = Timer.periodic(const Duration(milliseconds: 60), (_) {
      if (!mounted) return;
      setState(() {
        for (int i = 0; i < _eqBars.length; i++) {
          if (_isPlaying) {
            _eqTargets[i] = 0.15 + _rng.nextDouble() * 0.85;
          } else {
            _eqTargets[i] = 0.15;
          }
          _eqBars[i] += (_eqTargets[i] - _eqBars[i]) * 0.25;
        }
      });
    });
  }

  Future<void> _initAudio() async {
    final audioUrl = SongAudioService.getAudioUrl(widget.songTitle);
    if (audioUrl == null) return;

    try {
      await _player.setUrl(audioUrl);
      _duration = _player.duration ?? Duration.zero;
      setState(() {});
    } catch (_) {}

    _player.positionStream.listen((pos) {
      if (!mounted) return;
      setState(() => _position = pos);
      _updateLyricIndex(pos);
    });

    _player.durationStream.listen((dur) {
      if (!mounted || dur == null) return;
      setState(() => _duration = dur);
    });

    _player.playerStateStream.listen((state) {
      if (!mounted) return;
      if (state.processingState == ProcessingState.completed) {
        _onSongComplete();
      }
      setState(() => _isPlaying = state.playing);
    });
  }

  Future<void> _loadLyrics() async {
    final local = LocalSongLyrics.getLyrics(widget.songTitle);
    if (local != null && local.isNotEmpty) {
      if (!mounted) return;
      setState(() {
        _lyrics = local;
        _lyricsLoading = false;
      });
      return;
    }

    try {
      final online = await LyricsService.fetchLyrics(
        title: widget.songTitle,
        artist: widget.songArtist,
      );
      if (online.isNotEmpty && mounted) {
        setState(() {
          _lyrics = online;
          _lyricsLoading = false;
        });
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

    // Show first lyric immediately when playing starts
    if (idx == -1 &&
        _isPlaying &&
        _lyrics.first.timestamp.inMilliseconds == 0) {
      idx = 0;
    }

    if (idx != _currentLyricIdx) {
      _currentLyricIdx = idx;
      if (mounted) setState(() {});
      if (idx >= 0) _scrollToLyric(idx);
    }
  }

  void _scrollToLyric(int idx) {
    if (!_lyricsScroll.hasClients) return;
    const rowH = 48.0;
    final offset =
        (idx * rowH) -
        (_lyricsScroll.position.viewportDimension / 2 - rowH / 2);
    _lyricsScroll.animateTo(
      offset.clamp(0.0, _lyricsScroll.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> _toggleMic() async {
    if (_isRecording) {
      await _stopMic();
    } else {
      await _startMic();
    }
  }

  Future<void> _startMic() async {
    _micService = AudioService();
    final ok = await _micService!.start();
    if (!ok) {
      _micService?.dispose();
      _micService = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied')),
        );
      }
      return;
    }

    // Record raw PCM bytes for WAV playback on results
    _recordedPcm.clear();
    _bytesSub = _micService!.rawBytes.listen((bytes) {
      _recordedPcm.addAll(bytes);
    });

    _micSub = _micService!.results.listen((result) {
      if (!mounted) return;
      _rawHz.add(result?.frequency ?? 0);
      _rawCents.add(result?.cents ?? 0);
      _pitchNotifier.value = result;

      // Add to live pitch log
      if (result != null) {
        final feedback = result.feedback;
        String pitch;
        String direction;
        switch (feedback) {
          case PitchFeedback.correct:
            pitch = 'In Tune';
            direction = '-';
            break;
          case PitchFeedback.tooLow:
            pitch = 'Flat';
            direction = 'Too Low';
            break;
          case PitchFeedback.tooHigh:
            pitch = 'Sharp';
            direction = 'Too High';
            break;
          case PitchFeedback.noSignal:
            return; // Don't log silence
        }
        setState(() {
          _pitchLog.add(_PitchEntry(
            time: _fmtDuration(_position),
            pitch: pitch,
            direction: direction,
          ));
          // Keep only last 50 entries
          if (_pitchLog.length > 50) _pitchLog.removeAt(0);
        });
      }
    });
    setState(() => _isRecording = true);

    if (!_isPlaying) {
      await _player.play();
    }
  }

  Future<void> _stopMic() async {
    await _bytesSub?.cancel();
    _bytesSub = null;
    await _micSub?.cancel();
    _micSub = null;
    await _micService?.stop();
    _micService?.dispose();
    _micService = null;
    _pitchNotifier.value = null;
    setState(() => _isRecording = false);
  }

  void _onSongComplete() {
    _stopMic();
    _showResults();
  }

  void _showResults() {
    if (_rawHz.isEmpty) {
      Navigator.pop(context);
      return;
    }

    // Build WAV from recorded PCM bytes
    Uint8List? recordedWav;
    if (_recordedPcm.isNotEmpty) {
      recordedWav = _buildWavBytes(
        _recordedPcm,
        sampleRate: 16000,
        channels: 1,
      );
    }

    final session = SessionResult(
      songTitle: widget.songTitle,
      songArtist: widget.songArtist,
      songImage: widget.songImage,
      completedAt: DateTime.now(),
      lyricResults: _buildLyricResults(),
      durationSeconds: _position.inSeconds,
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ResultsPage(
              session: session,
              isAssignment: widget.isAssignment,
              recordedVoiceWav: recordedWav,
            ),
      ),
    );
  }

  List<LyricPitchData> _buildLyricResults() {
    final total = _rawHz.length;
    if (total == 0) return [];
    final segCount = _lyrics.isNotEmpty ? _lyrics.length.clamp(1, 30) : 30;
    final segSize = (total / segCount).ceil();
    return List.generate(segCount, (i) {
      final start = i * segSize;
      final end = (start + segSize).clamp(0, total);
      if (start >= total) return null;
      final lyricText =
          i < _lyrics.length ? _lyrics[i].text : 'Segment ${i + 1}';
      return LyricPitchData(
        lyricText: lyricText,
        pitchReadings: _rawHz.sublist(start, end),
        centsReadings: _rawCents.sublist(start, end),
      );
    }).whereType<LyricPitchData>().toList();
  }

  // ── WAV builder (same logic as recording page) ──
  Uint8List _buildWavBytes(
    List<int> pcm, {
    required int sampleRate,
    required int channels,
  }) {
    const bitsPerSample = 16;
    final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    final blockAlign = channels * bitsPerSample ~/ 8;
    final dataLength = pcm.length;
    final buf = ByteData(44 + dataLength);

    // RIFF chunk
    buf.setUint8(0, 0x52);
    buf.setUint8(1, 0x49);
    buf.setUint8(2, 0x46);
    buf.setUint8(3, 0x46);
    buf.setUint32(4, 36 + dataLength, Endian.little);
    buf.setUint8(8, 0x57);
    buf.setUint8(9, 0x41);
    buf.setUint8(10, 0x56);
    buf.setUint8(11, 0x45);
    // fmt sub-chunk
    buf.setUint8(12, 0x66);
    buf.setUint8(13, 0x6D);
    buf.setUint8(14, 0x74);
    buf.setUint8(15, 0x20);
    buf.setUint32(16, 16, Endian.little);
    buf.setUint16(20, 1, Endian.little);
    buf.setUint16(22, channels, Endian.little);
    buf.setUint32(24, sampleRate, Endian.little);
    buf.setUint32(28, byteRate, Endian.little);
    buf.setUint16(32, blockAlign, Endian.little);
    buf.setUint16(34, bitsPerSample, Endian.little);
    // data sub-chunk
    buf.setUint8(36, 0x64);
    buf.setUint8(37, 0x61);
    buf.setUint8(38, 0x74);
    buf.setUint8(39, 0x61);
    buf.setUint32(40, dataLength, Endian.little);
    for (int i = 0; i < dataLength; i++) {
      buf.setUint8(44 + i, pcm[i] & 0xFF);
    }
    return buf.buffer.asUint8List();
  }

  @override
  void dispose() {
    _eqTimer?.cancel();
    _player.dispose();
    _bytesSub?.cancel();
    _micSub?.cancel();
    _micService?.dispose();
    _pitchNotifier.dispose();
    _lyricsScroll.dispose();
    super.dispose();
  }

  String _fmtDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header: "← Record" ──
            _buildHeader(),

            // ── Equalizer bars ──
            _buildEqualizer(),

            // ── Song info card ──
            _buildSongInfoCard(),

            // ── Lyrics area ──
            Expanded(child: _buildLyricsPanel()),

            // ── Live pitch results table ──
            if (_pitchLog.isNotEmpty) _buildPitchTable(),

            // ── Timer ──
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                '${_fmtDuration(_position)} / ${_fmtDuration(_duration)}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontFamily: 'Roboto',
                ),
              ),
            ),

            // ── Controls: Play / Record / Stop ──
            _buildControls(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
            onPressed: () {
              _player.stop();
              _stopMic();
              Navigator.pop(context);
            },
          ),
          const Text(
            'Record',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              fontFamily: 'Roboto',
            ),
          ),
          const Spacer(),
          if (_isRecording)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.mic, color: Colors.white, size: 13),
                  SizedBox(width: 3),
                  Text(
                    'REC',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEqualizer() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 60,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(
          _eqBars.length,
          (i) => Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Container(
                height: _eqBars[i] * 55,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSongInfoCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              'Title: ${widget.songTitle}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontFamily: 'Roboto',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Artist: ${widget.songArtist}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13,
                fontFamily: 'Roboto',
              ),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLyricsPanel() {
    if (_lyricsLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryCyan),
      );
    }
    if (_lyrics.isEmpty) {
      return Center(
        child: Text(
          'No lyrics available\nSing along with the music!',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 14,
            fontFamily: 'Roboto',
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.builder(
        controller: _lyricsScroll,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _lyrics.length,
        itemBuilder: (context, index) {
          final isCurrent = index == _currentLyricIdx;
          final isPast = index < _currentLyricIdx;
          return Container(
            height: 48,
            alignment: Alignment.centerLeft,
            child: Text(
              _lyrics[index].text,
              style: TextStyle(
                color: isCurrent
                    ? AppColors.primaryCyan
                    : isPast
                        ? Colors.white.withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.6),
                fontSize: isCurrent ? 17 : 14,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                fontFamily: 'Roboto',
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPitchTable() {
    // Show last 4 entries
    final entries = _pitchLog.length > 4
        ? _pitchLog.sublist(_pitchLog.length - 4)
        : _pitchLog;
    final startIdx = _pitchLog.length > 4 ? _pitchLog.length - 4 : 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: entries.asMap().entries.map((entry) {
          final i = startIdx + entry.key;
          final e = entry.value;
          final isFlat = e.pitch == 'Flat';
          final isSharp = e.pitch == 'Sharp';
          final color = (isFlat || isSharp)
              ? const Color(0xFFF44336)
              : const Color(0xFF4CAF50);

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: Text(
                    '${i + 1}.',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ),
                SizedBox(
                  width: 50,
                  child: Text(
                    e.time,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    e.pitch,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ),
                Text(
                  e.direction,
                  style: TextStyle(
                    color: color.withValues(alpha: 0.75),
                    fontSize: 12,
                    fontFamily: 'Roboto',
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Play / Pause
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),

          // Record (red circle)
          GestureDetector(
            onTap: _toggleMic,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: Center(
                child: Container(
                  width: _isRecording ? 24 : 44,
                  height: _isRecording ? 24 : 44,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(
                      _isRecording ? 4 : 22,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Stop → go to results
          GestureDetector(
            onTap: () {
              _player.stop();
              _stopMic();
              if (_rawHz.isNotEmpty) {
                _showResults();
              } else {
                Navigator.pop(context);
              }
            },
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.stop,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PitchEntry {
  final String time;
  final String pitch;
  final String direction;
  const _PitchEntry({
    required this.time,
    required this.pitch,
    required this.direction,
  });
}
