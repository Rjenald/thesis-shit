import 'dart:async';
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../core/audio_service.dart';
import '../../core/note_utils.dart';
import '../../models/session_result.dart';
import '../../services/lyrics_service.dart';
import 'results_page.dart';

const int _kResultSegments = 30;

class KaraokeRecordingPage extends StatefulWidget {
  final String songTitle;
  final String songArtist;
  final String songImage;
  final bool isAssignment;

  const KaraokeRecordingPage({
    super.key,
    this.songTitle = 'Dadalhin',
    this.songArtist = 'Regine Velasquez',
    this.songImage = '',
    this.isAssignment = false,
  });

  @override
  State<KaraokeRecordingPage> createState() => _KaraokeRecordingPageState();
}

class _KaraokeRecordingPageState extends State<KaraokeRecordingPage> {
  bool _isRecording = false;

  final ValueNotifier<NoteResult?> _pitchNotifier = ValueNotifier(null);
  final ValueNotifier<int> _posNotifier = ValueNotifier(0);

  final List<double> _rawHz = [];
  final List<double> _rawCents = [];

  final AudioService _audioService = AudioService();
  StreamSubscription<NoteResult?>? _audioSub;
  Timer? _posTimer;

  List<LrcLine> _lyrics = [];
  bool _lyricsLoading = true;
  final ValueNotifier<int> _lyricIdxNotifier = ValueNotifier(0);
  final ScrollController _lyricsScroll = ScrollController();
  static const double _lyricRowHeight = 56.0;

  static const _colorInTune = Color(0xFF4CAF50);
  static const _colorOffTune = Color(0xFFF44336);
  static const _colorSilent = Color(0xFF757575);

  @override
  void initState() {
    super.initState();
    _loadLyrics();
    _posNotifier.addListener(_updateCurrentLyric);
  }

  @override
  void dispose() {
    _posTimer?.cancel();
    _audioSub?.cancel();
    _audioService.dispose();
    _pitchNotifier.dispose();
    _posNotifier.removeListener(_updateCurrentLyric);
    _posNotifier.dispose();
    _lyricIdxNotifier.dispose();
    _lyricsScroll.dispose();
    super.dispose();
  }

  Future<void> _loadLyrics() async {
    final lines = await LyricsService.fetchLyrics(
      title: widget.songTitle,
      artist: widget.songArtist,
    );
    if (!mounted) return;
    setState(() {
      _lyrics = lines;
      _lyricsLoading = false;
    });
  }

  void _updateCurrentLyric() {
    if (_lyrics.isEmpty) return;
    final ms = _posNotifier.value;
    int lo = 0, hi = _lyrics.length - 1, idx = 0;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (_lyrics[mid].timestamp.inMilliseconds <= ms) {
        idx = mid;
        lo = mid + 1;
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
    final offset =
        (idx * _lyricRowHeight) -
        (_lyricsScroll.position.viewportDimension / 2 - _lyricRowHeight / 2);
    _lyricsScroll.animateTo(
      offset.clamp(0.0, _lyricsScroll.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

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
      _rawHz.add(result?.frequency ?? 0);
      _rawCents.add(result?.cents ?? 0);
      _pitchNotifier.value = result;
    });

    _posTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted || !_isRecording) return;
      _posNotifier.value += 200;
    });

    setState(() => _isRecording = true);
  }

  Future<void> _stopRecording() async {
    _posTimer?.cancel();
    _posTimer = null;
    await _audioSub?.cancel();
    _audioSub = null;
    await _audioService.stop();
    _pitchNotifier.value = null;
    if (mounted) setState(() => _isRecording = false);
  }

  Future<void> _finishAndShowResults() async {
    _posTimer?.cancel();
    _posTimer = null;
    if (_isRecording) await _stopRecording();

    final session = SessionResult(
      songTitle: widget.songTitle,
      songArtist: widget.songArtist,
      songImage: widget.songImage,
      completedAt: DateTime.now(),
      lyricResults: _buildLyricResults(),
      durationSeconds: _posNotifier.value ~/ 1000,
    );

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ResultsPage(session: session, isAssignment: widget.isAssignment),
      ),
    );
  }

  List<LyricPitchData> _buildLyricResults() {
    final total = _rawHz.length;
    if (total == 0) return [];
    final n = _kResultSegments.clamp(1, total);
    final segSize = (total / n).ceil();
    return List.generate(n, (i) {
      final start = i * segSize;
      final end = (start + segSize).clamp(0, total);
      if (start >= total) return null;
      return LyricPitchData(
        lyricText: 'seg${i + 1}',
        pitchReadings: _rawHz.sublist(start, end),
        centsReadings: _rawCents.sublist(start, end),
      );
    }).whereType<LyricPitchData>().toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSongInfoRow(),
            Expanded(child: _buildLyricsPanel()),
            if (_isRecording) _buildLivePitchRow(),
            _buildControls(),
          ],
        ),
      ),
    );
  }

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
                Text(
                  'Record',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Roboto',
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          if (_isRecording)
            ValueListenableBuilder<int>(
              valueListenable: _posNotifier,
              builder: (ctx2, ms, child2) {
                final s = ms ~/ 1000;
                final mm = (s ~/ 60).toString().padLeft(2, '0');
                final ss = (s % 60).toString().padLeft(2, '0');
                return Text(
                  '$mm:$ss',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 12,
                    fontFamily: 'Roboto',
                    letterSpacing: 1.2,
                  ),
                );
              },
            ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildSongInfoRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1E1E1E),
              image: widget.songImage.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(widget.songImage),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: widget.songImage.isEmpty
                ? const Icon(
                    Icons.music_note,
                    color: AppColors.primaryCyan,
                    size: 20,
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.songTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Roboto',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  widget.songArtist,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                    fontFamily: 'Roboto',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (_isRecording)
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
                  Text(
                    'REC',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 9,
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

  Widget _buildLyricsPanel() {
    if (_lyricsLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: AppColors.primaryCyan,
              strokeWidth: 2,
            ),
            SizedBox(height: 10),
            Text(
              'Loading lyrics...',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 13,
                fontFamily: 'Roboto',
              ),
            ),
          ],
        ),
      );
    }

    if (_lyrics.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lyrics_outlined,
              color: Colors.white.withValues(alpha: 0.2),
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              'No synced lyrics found',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 14,
                fontFamily: 'Roboto',
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap the mic button to start singing',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 12,
                fontFamily: 'Roboto',
              ),
            ),
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
              controller: _lyricsScroll,
              padding: const EdgeInsets.symmetric(vertical: 32),
              itemCount: _lyrics.length,
              itemExtent: _lyricRowHeight,
              itemBuilder: (ctx3, i) {
                final isCurrent = i == currentIdx;
                final isPast = i < currentIdx;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  alignment: Alignment.center,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 2,
                  ),
                  decoration: isCurrent
                      ? BoxDecoration(
                          color: lineColor,
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
                        fontSize: isCurrent ? 20 : 15,
                        fontWeight:
                            isCurrent ? FontWeight.bold : FontWeight.normal,
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

  Widget _buildLivePitchRow() {
    return ValueListenableBuilder<NoteResult?>(
      valueListenable: _pitchNotifier,
      builder: (ctx2, pitch, child2) {
        final bool active =
            pitch != null &&
            pitch.frequency > 0 &&
            pitch.feedback != PitchFeedback.noSignal;

        final Color color;
        final String statusText;
        final String noteText;
        final String centsText;

        if (!active) {
          color = _colorSilent;
          statusText = 'Listening...';
          noteText = '';
          centsText = '';
        } else {
          noteText = pitch.fullName;
          centsText =
              '${pitch.cents >= 0 ? '+' : ''}${pitch.cents.toStringAsFixed(0)}c';
          switch (pitch.feedback) {
            case PitchFeedback.correct:
              color = _colorInTune;
              statusText = 'In Tune';
              break;
            case PitchFeedback.tooHigh:
              color = _colorOffTune;
              statusText = 'Too High';
              break;
            case PitchFeedback.tooLow:
              color = _colorOffTune;
              statusText = 'Too Low';
              break;
            case PitchFeedback.noSignal:
              color = _colorSilent;
              statusText = 'Listening...';
              break;
          }
        }

        return Container(
          color: color.withValues(alpha: 0.07),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              if (noteText.isNotEmpty) ...[
                Text(
                  noteText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Roboto',
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                statusText,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Roboto',
                ),
              ),
              const Spacer(),
              if (centsText.isNotEmpty)
                Text(
                  centsText,
                  style: TextStyle(
                    color: color.withValues(alpha: 0.75),
                    fontSize: 12,
                    fontFamily: 'Roboto',
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 36),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: _toggleRecording,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isRecording ? Colors.red[700] : Colors.red,
              ),
              child: Icon(
                _isRecording ? Icons.stop_rounded : Icons.mic,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
          const SizedBox(width: 32),
          GestureDetector(
            onTap: _finishAndShowResults,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.black,
                size: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
