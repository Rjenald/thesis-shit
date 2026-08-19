import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../../core/audio_service.dart';
import '../../core/crepe_pitch_service.dart';
import '../../core/mixed_recording_service.dart';
import '../../core/note_utils.dart';
import '../../core/pitch_detection_service.dart';
import '../../core/web_audio_fix.dart';
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
  PitchDetectionService? _micService;
  bool _usingCrepe = false;

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

  @override
  void initState() {
    super.initState();
    _initAudio();
    _loadLyrics();
  }

  Future<void> _initAudio() async {
    final audioUrl = SongAudioService.getAudioUrl(widget.songTitle);
    if (audioUrl == null) {
      debugPrint('No audio URL for "${widget.songTitle}"');
      return;
    }
    try {
      await _player.setAsset(audioUrl);
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
      _updateLyricIndex(pos);
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
      if (_lyrics[i].timestamp.inMilliseconds <= ms) idx = i;
      else break;
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
    final pos = at ?? _position;
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
    // Try the real CREPE model (backend/crepe_server.py) first; if the
    // server isn't reachable, fall back to the local YIN detector so
    // recording still works offline.
    final crepe = CrepePitchService();
    final crepeOk = await crepe.start();
    if (crepeOk) {
      _micService = crepe;
      _usingCrepe = true;
    } else {
      crepe.dispose();
      _usingCrepe = false;
      _micService = AudioService();
      final yinOk = await _micService!.start();
      if (!yinOk) {
        _micService?.dispose(); _micService = null;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Microphone permission denied')));
        }
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CREPE server unreachable — using offline pitch detection')),
        );
      }
    }
    _recordStartPosition = _position;
    _recordedPcm.clear(); _correctCount = 0; _totalDetections = 0;

    _bytesSub = _micService!.rawBytes.listen((b) => _recordedPcm.addAll(b));

    _micSub = _micService!.results.listen((result) {
      if (!mounted) return;
      _rawHz.add(result?.frequency ?? 0);
      _rawCents.add(result?.cents ?? 0);
      if (result != null && result.feedback != PitchFeedback.noSignal) {
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
        _scoreTick.value++;
      }
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

    // Mix the song into the recording so the saved file has song + voice,
    // not just the mic. Falls back to mic-only if mixing fails for any reason.
    if (wav != null) {
      final audioUrl = SongAudioService.getAudioUrl(widget.songTitle);
      if (audioUrl != null) {
        _showMixingDialog();
        final mixed = await mixSongAndVoice(
          songAssetPath: audioUrl,
          songStartOffset: _recordStartPosition,
          micWavBytes: wav,
          playbackSpeed: _playbackSpeed,
        );
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
        if (mixed != null) wav = mixed;
      }
    }

    if (!mounted) return;
    final session = SessionResult(
      songTitle: widget.songTitle, songArtist: widget.songArtist,
      songImage: widget.songImage, completedAt: DateTime.now(),
      lyricResults: _buildLyricResults(), durationSeconds: _position.inSeconds,
    );
    Navigator.pushReplacement(context, MaterialPageRoute(
      builder: (_) => ResultsPage(
        session: session, isAssignment: widget.isAssignment, recordedVoiceWav: wav),
    ));
  }

  void _showMixingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: const Padding(
            padding: EdgeInsets.all(24),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFF00E5FF)),
                SizedBox(width: 16),
                Text('Mixing your recording...',
                    style: TextStyle(color: Colors.white, fontFamily: 'Roboto')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<LyricPitchData> _buildLyricResults() {
    final total = _rawHz.length;
    if (total == 0) return [];
    final seg = _lyrics.isNotEmpty ? _lyrics.length.clamp(1, 30) : 30;
    final sz = (total / seg).ceil();
    return List.generate(seg, (i) {
      final s = i * sz; final e = (s + sz).clamp(0, total);
      if (s >= total) return null;
      return LyricPitchData(
        lyricText: i < _lyrics.length ? _lyrics[i].text : 'Segment ${i + 1}',
        pitchReadings: _rawHz.sublist(s, e), centsReadings: _rawCents.sublist(s, e));
    }).whereType<LyricPitchData>().toList();
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
    for(int i=0;i<n;i++) b.setUint8(44+i,pcm[i]&0xFF);
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
    _scoreTick.dispose();
    _bytesSub?.cancel(); _micSub?.cancel(); _micService?.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD — Spotify-style lyrics player
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
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
              if (_usingCrepe)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.5)),
                  ),
                  child: const Text('CREPE', style: TextStyle(color: Color(0xFF00E5FF), fontSize: 9, fontWeight: FontWeight.bold, fontFamily: 'Roboto', letterSpacing: 0.5)),
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
              color: const Color(0xFF1A1A1A),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: widget.songImage.isNotEmpty
                ? Image.network(widget.songImage, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _albumPlaceholder())
                : _albumPlaceholder(),
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

  Widget _albumPlaceholder() => Container(
    color: const Color(0xFF1E1E1E),
    child: const Center(child: Icon(Icons.music_note, color: Color(0xFF00E5FF), size: 28)),
  );

  // ── LYRICS BODY — Spotify-style scrolling lyrics ──
  Widget _buildLyricsBody() {
    if (_lyricsLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)));
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
                valueListenable: _positionNotifier,
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
                color: isSung ? const Color(0xFF1DB954) : Colors.white,
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
      child: Row(
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
              : const Color(0xFF00E5FF).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _playbackSpeed == 1.0
                ? Colors.white.withValues(alpha: 0.1)
                : const Color(0xFF00E5FF).withValues(alpha: 0.4),
          ),
        ),
        child: Text(
          '${_playbackSpeed.toStringAsFixed(1)}x',
          style: TextStyle(
            color: _playbackSpeed == 1.0 ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF00E5FF),
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
          // Record button
          GestureDetector(
            onTap: _toggleMic,
            child: Container(
              width: 58, height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _isRecording ? Colors.red : Colors.white, width: 3),
              ),
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: _isRecording ? 20 : 40, height: _isRecording ? 20 : 40,
                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(_isRecording ? 5 : 20)),
                ),
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
