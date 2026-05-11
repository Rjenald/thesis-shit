import 'dart:async';
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../constants/app_colors.dart';
import '../core/audio_service.dart';
import '../core/note_utils.dart';
import '../models/session_result.dart';
import '../services/youtube_service.dart';
import '../services/lyrics_service.dart';
import 'results_page.dart';

// ── How many pitch segments appear in the results heatmap ─────────────────────
const int _kResultSegments = 30;

class KaraokeRecordingPage extends StatefulWidget {
  final String songTitle;
  final String songArtist;
  final String songImage;

  /// When provided the page skips the YouTube search and uses this ID directly.
  final String? youtubeVideoId;

  /// When true the results page shows [Try Again | Submit] instead of
  /// [Try Again | Listen | Save].
  final bool isAssignment;

  const KaraokeRecordingPage({
    super.key,
    this.songTitle     = 'Dadalhin',
    this.songArtist    = 'Regine Velasquez',
    this.songImage     = '',
    this.youtubeVideoId,
    this.isAssignment  = false,
  });

  @override
  State<KaraokeRecordingPage> createState() => _KaraokeRecordingPageState();
}

class _KaraokeRecordingPageState extends State<KaraokeRecordingPage> {
  // ── Coarse state — only these trigger a full-tree rebuild ──────────────────
  bool _isPlaying   = false;
  bool _isRecording = false;
  /// True when user pressed play before video finished loading.
  bool _pendingPlay = false;

  // ── Fine-grained notifiers — rebuild only the widgets that need it ─────────
  /// Current pitch reading. Rebuilt: status row only.
  final ValueNotifier<NoteResult?> _pitchNotifier = ValueNotifier(null);
  /// Position in milliseconds. Rebuilt: timer label only.
  final ValueNotifier<int> _posNotifier = ValueNotifier(0);

  // ── Pitch history (raw, never triggers rebuilds directly) ─────────────────
  final List<double> _rawHz    = [];
  final List<double> _rawCents = [];

  // ── Audio ──────────────────────────────────────────────────────────────────
  final AudioService               _audioService = AudioService();
  StreamSubscription<NoteResult?>? _audioSub;

  // ── YouTube ────────────────────────────────────────────────────────────────
  YoutubePlayerController? _ytController;
  bool _ytPositionActive = false;
  Timer?  _posTimer;         // fallback position ticker

  // ── Lyrics ─────────────────────────────────────────────────────────────────
  List<LrcLine> _lyrics      = [];
  bool _lyricsLoading        = true;
  final ValueNotifier<int> _lyricIdxNotifier = ValueNotifier(0);
  final ScrollController    _lyricsScroll    = ScrollController();
  static const double _lyricRowHeight        = 56.0;

  // ── Pitch colours ──────────────────────────────────────────────────────────
  static const _colorInTune  = Color(0xFF4CAF50);
  static const _colorOffTune = Color(0xFFF44336);
  static const _colorSilent  = Color(0xFF757575);

  // ══════════════════════════════════════════════════════════════════════════
  // Lifecycle
  // ══════════════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    _loadYouTubeVideo();
    _loadLyrics();
    _posNotifier.addListener(_updateCurrentLyric);
    // Mic is NOT auto-started — user presses the mic button when ready to sing.
  }

  @override
  void dispose() {
    _posTimer?.cancel();
    _audioSub?.cancel();
    _audioService.dispose();
    _ytController?.removeListener(_onYTUpdate);
    _ytController?.dispose();
    _pitchNotifier.dispose();
    _posNotifier.removeListener(_updateCurrentLyric);
    _posNotifier.dispose();
    _lyricIdxNotifier.dispose();
    _lyricsScroll.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // YouTube
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _loadYouTubeVideo() async {
    // Use the pre-supplied ID if available, otherwise search the API.
    final videoId = widget.youtubeVideoId?.isNotEmpty == true
        ? widget.youtubeVideoId
        : await YouTubeService.searchVideoId(
            title:  widget.songTitle,
            artist: widget.songArtist,
          );
    if (!mounted) return;

    if (videoId != null && videoId.isNotEmpty) {
      final ctrl = YoutubePlayerController(
        initialVideoId: videoId,
        flags: YoutubePlayerFlags(
          autoPlay:        _pendingPlay,
          mute:            false,
          disableDragSeek: false,
          hideControls:    false,
          enableCaption:   false,
        ),
      );
      ctrl.addListener(_onYTUpdate);
      setState(() {
        _ytController = ctrl;
        if (_pendingPlay) {
          _isPlaying   = true;
          _pendingPlay = false;
        }
      });
    } else {
      setState(() => _pendingPlay = false);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Lyrics
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _loadLyrics() async {
    final lines = await LyricsService.fetchLyrics(
      title:  widget.songTitle,
      artist: widget.songArtist,
    );
    if (!mounted) return;
    setState(() {
      _lyrics        = lines;
      _lyricsLoading = false;
    });
  }

  /// Called every time _posNotifier changes — O(log n) binary search.
  void _updateCurrentLyric() {
    if (_lyrics.isEmpty) return;
    final ms = _posNotifier.value;
    int lo = 0, hi = _lyrics.length - 1, idx = 0;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (_lyrics[mid].timestamp.inMilliseconds <= ms) {
        idx = mid;
        lo  = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    if (idx != _lyricIdxNotifier.value) {
      _lyricIdxNotifier.value = idx;
      _scrollToLyric(idx);
    }
  }

  void _scrollToLyric(int idx) {
    if (!_lyricsScroll.hasClients) return;
    final offset = (idx * _lyricRowHeight) -
        (_lyricsScroll.position.viewportDimension / 2 - _lyricRowHeight / 2);
    _lyricsScroll.animateTo(
      offset.clamp(0.0, _lyricsScroll.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve:    Curves.easeInOut,
    );
  }

  void _onYTUpdate() {
    if (!mounted || _ytController == null) return;
    final v = _ytController!.value;

    // Only setState for play-state changes (infrequent).
    if (_isPlaying != v.isPlaying) {
      setState(() => _isPlaying = v.isPlaying);
    }

    if (v.isPlaying && !_ytPositionActive) {
      _ytPositionActive = true;
      _posTimer?.cancel();
      _posTimer = null;
    }

    // Position: update notifier — does NOT rebuild the main tree.
    if (v.isPlaying || v.position.inMilliseconds > 0) {
      final ms = v.position.inMilliseconds;
      if (ms != _posNotifier.value) _posNotifier.value = ms;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Play / pause
  // ══════════════════════════════════════════════════════════════════════════

  void _togglePlayPause() {
    if (_ytController == null) {
      setState(() => _pendingPlay = !_pendingPlay);
      return;
    }
    final ytPlaying = _ytController!.value.isPlaying;
    if (ytPlaying) {
      _ytController!.pause();
      _posTimer?.cancel();
      _posTimer = null;
      setState(() => _isPlaying = false);
    } else {
      _ytController!.play();
      setState(() => _isPlaying = true);
      _posTimer ??= Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (!mounted || !_isPlaying) return;
        // Update notifier — no setState needed.
        if (!_ytPositionActive) _posNotifier.value += 200;
      });
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Microphone — never touches the video
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _startRecording() async {
    final ok = await _audioService.start();
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied')),
        );
      }
      return;
    }

    _audioSub = _audioService.results.listen((result) {
      if (!mounted) return;

      // ── Accumulate raw data — O(1), no rebuild ────────────────────────
      _rawHz   .add(result?.frequency ?? 0);
      _rawCents.add(result?.cents     ?? 0);

      // ── Pitch notifier — only rebuilds status row ────────────────────
      _pitchNotifier.value = result;
      // NO setState here — main widget tree is NOT rebuilt.
    });

    // One setState to flip the recording button.
    setState(() => _isRecording = true);
  }

  Future<void> _stopRecording() async {
    await _audioSub?.cancel();
    _audioSub = null;
    await _audioService.stop();
    _pitchNotifier.value = null;
    if (mounted) setState(() => _isRecording = false);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Finish
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _finishAndShowResults() async {
    _posTimer?.cancel();
    _posTimer = null;
    _ytController?.pause();
    if (_isRecording) await _stopRecording();

    final session = SessionResult(
      songTitle:       widget.songTitle,
      songArtist:      widget.songArtist,
      songImage:       widget.songImage,
      completedAt:     DateTime.now(),
      lyricResults:    _buildLyricResults(),
      durationSeconds: _posNotifier.value ~/ 1000,
    );

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ResultsPage(
          session:      session,
          isAssignment: widget.isAssignment,
        ),
      ),
    );
  }

  List<LyricPitchData> _buildLyricResults() {
    final total = _rawHz.length;
    if (total == 0) return [];
    final n       = _kResultSegments.clamp(1, total);
    final segSize = (total / n).ceil();
    return List.generate(n, (i) {
      final start = i * segSize;
      final end   = (start + segSize).clamp(0, total);
      if (start >= total) return null;
      return LyricPitchData(
        lyricText:     'seg${i + 1}',
        pitchReadings: _rawHz   .sublist(start, end),
        centsReadings: _rawCents.sublist(start, end),
      );
    }).whereType<LyricPitchData>().toList();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Build — rebuilt only when _isPlaying / _isRecording / _ytVideoId changes
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSongInfoRow(),
            // YouTube player hidden but alive so audio keeps playing
            // Small video strip at top
            SizedBox(height: 180, child: _buildVideoBox()),
            // Scrolling lyrics — main content
            Expanded(child: _buildLyricsPanel()),
            // Real-time pitch bar while mic is on
            if (_isRecording) _buildLivePitchRow(),
            _buildControls(),
          ],
        ),
      ),
    );
  }

  // ── Video box ──────────────────────────────────────────────────────────────

  Widget _buildVideoBox() {
    if (_ytController == null) {
      return _videoShell(child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
              color: AppColors.primaryCyan, strokeWidth: 2),
          SizedBox(height: 10),
          Text('Loading video…',
              style: TextStyle(color: Colors.white30, fontSize: 12)),
        ],
      ));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: RepaintBoundary(
          child: YoutubePlayer(
            controller:                 _ytController!,
            showVideoProgressIndicator: true,
            progressIndicatorColor:     Colors.red,
            progressColors: const ProgressBarColors(
              playedColor:     Colors.red,
              handleColor:     Colors.redAccent,
              bufferedColor:   Colors.white24,
              backgroundColor: Colors.white12,
            ),
            topActions:    const [],
            bottomActions: const [
              CurrentPosition(),
              ProgressBar(isExpanded: true),
              RemainingDuration(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _videoShell({required Widget child}) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            decoration: BoxDecoration(
              color:        const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(6),
              border:       Border.all(color: Colors.white12, width: 0.5),
            ),
            child: Center(child: child),
          ),
        ),
      );

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
                SizedBox(width: 6),
                Text('Record',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Roboto')),
              ],
            ),
          ),
          const Spacer(),

          // ── Elapsed timer — rebuilt by notifier, NOT by setState ──────
          if (_isPlaying || _isRecording)
            ValueListenableBuilder<int>(
              valueListenable: _posNotifier,
              builder: (ctx2, ms, child2) {
                final s  = ms ~/ 1000;
                final mm = (s ~/ 60).toString().padLeft(2, '0');
                final ss = (s  % 60).toString().padLeft(2, '0');
                return Text('$mm:$ss',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 12,
                        fontFamily: 'Roboto',
                        letterSpacing: 1.2));
              },
            ),

          const SizedBox(width: 8),
          const Icon(Icons.more_horiz, color: Colors.white, size: 22),
        ],
      ),
    );
  }

  // ── Song info row ──────────────────────────────────────────────────────────

  Widget _buildSongInfoRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Row(
        children: [
          const Icon(Icons.music_note, color: AppColors.primaryCyan, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(widget.songTitle,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Roboto'),
                overflow: TextOverflow.ellipsis),
          ),
          Text(widget.songArtist,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                  fontFamily: 'Roboto'),
              overflow: TextOverflow.ellipsis),
          if (_isRecording) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, color: Colors.red, size: 5),
                  SizedBox(width: 3),
                  Text('REC',
                      style: TextStyle(
                          color: Colors.red,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Roboto')),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Lyrics panel (WeSing-style scrolling) ─────────────────────────────────

  Widget _buildLyricsPanel() {
    if (_lyricsLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primaryCyan, strokeWidth: 2),
            SizedBox(height: 10),
            Text('Loading lyrics…',
                style: TextStyle(color: Colors.white38, fontSize: 13,
                    fontFamily: 'Roboto')),
          ],
        ),
      );
    }

    if (_lyrics.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lyrics_outlined,
                color: Colors.white.withValues(alpha: 0.2), size: 48),
            const SizedBox(height: 12),
            Text('No synced lyrics found',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 14, fontFamily: 'Roboto')),
            const SizedBox(height: 4),
            Text('Sing along with the video above',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 12, fontFamily: 'Roboto')),
          ],
        ),
      );
    }

    return ValueListenableBuilder<int>(
      valueListenable: _lyricIdxNotifier,
      builder: (ctx, currentIdx, _) {
        return ValueListenableBuilder<NoteResult?>(
          valueListenable: _pitchNotifier,
          builder: (ctx2, pitch, _) {
            // Determine pitch color for current line highlight
            Color lineColor = Colors.white.withValues(alpha: 0.15);
            if (_isRecording && pitch != null && pitch.frequency > 0) {
              switch (pitch.feedback) {
                case PitchFeedback.correct:
                  lineColor = _colorInTune.withValues(alpha: 0.25);
                  break;
                case PitchFeedback.tooHigh:
                case PitchFeedback.tooLow:
                  lineColor = _colorOffTune.withValues(alpha: 0.2);
                  break;
                case PitchFeedback.noSignal:
                  lineColor = Colors.white.withValues(alpha: 0.15);
                  break;
              }
            }

            return ListView.builder(
              controller:   _lyricsScroll,
              padding: const EdgeInsets.symmetric(vertical: 32),
              itemCount:    _lyrics.length,
              itemExtent:   _lyricRowHeight,
              itemBuilder:  (ctx3, i) {
                final isCurrent = i == currentIdx;
                final isPast    = i < currentIdx;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  alignment: Alignment.center,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  decoration: isCurrent
                      ? BoxDecoration(
                          color:        lineColor,
                          borderRadius: BorderRadius.circular(10),
                        )
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      _lyrics[i].text,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isCurrent
                            ? Colors.white
                            : isPast
                                ? Colors.white.withValues(alpha: 0.3)
                                : Colors.white.withValues(alpha: 0.55),
                        fontSize:   isCurrent ? 20 : 15,
                        fontWeight: isCurrent
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontFamily: 'Roboto',
                        height: 1.3,
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // ── Live pitch status row — only rebuilt via ValueListenableBuilder ─────────

  Widget _buildLivePitchRow() {
    return ValueListenableBuilder<NoteResult?>(
      valueListenable: _pitchNotifier,
      builder: (ctx2, pitch, child2) {
        final bool active = pitch != null &&
            pitch.frequency > 0 &&
            pitch.feedback != PitchFeedback.noSignal;

        final Color  color;
        final String statusText;
        final String noteText;
        final String centsText;

        if (!active) {
          color      = _colorSilent;
          statusText = 'Listening…';
          noteText   = '';
          centsText  = '';
        } else {
          noteText  = pitch.fullName;
          centsText =
              '${pitch.cents >= 0 ? '+' : ''}${pitch.cents.toStringAsFixed(0)}¢';
          switch (pitch.feedback) {
            case PitchFeedback.correct:
              color      = _colorInTune;
              statusText = 'In Tune ✓';
              break;
            case PitchFeedback.tooHigh:
              color      = _colorOffTune;
              statusText = 'Too High ↑';
              break;
            case PitchFeedback.tooLow:
              color      = _colorOffTune;
              statusText = 'Too Low ↓';
              break;
            case PitchFeedback.noSignal:
              color      = _colorSilent;
              statusText = 'Listening…';
              break;
          }
        }

        // Plain Container — no AnimatedContainer (saves layout passes)
        return Container(
          color: color.withValues(alpha: 0.07),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                    color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              if (noteText.isNotEmpty) ...[
                Text(noteText,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Roboto')),
                const SizedBox(width: 8),
              ],
              Text(statusText,
                  style: TextStyle(
                      color:      color,
                      fontSize:   13,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Roboto')),
              const Spacer(),
              if (centsText.isNotEmpty)
                Text(centsText,
                    style: TextStyle(
                        color:     color.withValues(alpha: 0.75),
                        fontSize:  12,
                        fontFamily: 'Roboto')),
            ],
          ),
        );
      },
    );
  }

  // ── Controls ───────────────────────────────────────────────────────────────

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 36),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ▶ / ❚❚  Play-pause
          GestureDetector(
            onTap: _togglePlayPause,
            child: Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                shape:  BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: _pendingPlay
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : Icon(
                      _isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white, size: 28),
            ),
          ),

          const SizedBox(width: 24),

          // 🔴  Mic toggle — start/stop recording, video never pauses
          GestureDetector(
            onTap: () async {
              if (_isRecording) {
                await _stopRecording();
              } else {
                await _startRecording();
              }
            },
            child: Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isRecording ? Colors.red[700] : Colors.red,
              ),
              child: Icon(
                _isRecording ? Icons.stop_rounded : Icons.mic,
                color: Colors.white, size: 30),
            ),
          ),

          const SizedBox(width: 24),

          // ⬜  Finish → results
          GestureDetector(
            onTap: _finishAndShowResults,
            child: Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color:        Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.stop_rounded,
                  color: Colors.black, size: 28),
            ),
          ),
        ],
      ),
    );
  }
}

