import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/app_colors.dart';
import '../../core/lyric_alignment_service.dart';
import '../../core/note_utils.dart' show PitchFrame;
import '../../core/ondevice_crepe_service.dart';
import '../../core/word_note_builder.dart';
import '../../models/free_sing_summary.dart';
import '../../models/word_note_entry.dart';
import '../../services/free_sing_storage_service.dart';

/// Shows the word-by-word note summary of a completed "without karaoke"
/// recording as a lyric-style synchronized timeline — no reference song, so
/// there's nothing to score against; this just lays out what was sung,
/// timestamp → detected pitch → recognized word, in order, for the whole
/// session.
///
/// Two ways to land on this page:
///  • [WithoutKaraokeResultsPage.new] — view an already-analyzed, already-
///    saved summary (e.g. tapped from the Library).
///  • [WithoutKaraokeResultsPage.processing] — a recording just finished;
///    the batch CREPE + Whisper pipeline runs here (not on the recording
///    page) so the screen itself appears immediately, with the header/
///    playback available right away and the word timeline filling in once
///    analysis completes.
class WithoutKaraokeResultsPage extends StatefulWidget {
  final FreeSingSummary? summary;

  final String? recordingId;
  final DateTime? pendingCreatedAt;
  final int? pendingDurationSeconds;
  final Uint8List? pendingWavBytes;
  final List<int>? pendingPcmSamples;

  const WithoutKaraokeResultsPage({super.key, required FreeSingSummary summary})
      : summary = summary,
        recordingId = null,
        pendingCreatedAt = null,
        pendingDurationSeconds = null,
        pendingWavBytes = null,
        pendingPcmSamples = null;

  const WithoutKaraokeResultsPage.processing({
    super.key,
    required String recordingId,
    required DateTime createdAt,
    required int durationSeconds,
    required Uint8List wavBytes,
    required List<int> pcmSamples,
  })  : summary = null,
        recordingId = recordingId,
        pendingCreatedAt = createdAt,
        pendingDurationSeconds = durationSeconds,
        pendingWavBytes = wavBytes,
        pendingPcmSamples = pcmSamples;

  @override
  State<WithoutKaraokeResultsPage> createState() =>
      _WithoutKaraokeResultsPageState();
}

class _WithoutKaraokeResultsPageState
    extends State<WithoutKaraokeResultsPage> {
  FreeSingSummary? _summary;
  bool _analyzing = false;

  late final String _audioRef;
  late final DateTime _createdAt;
  late final int _durationSeconds;

  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoadingAudio = false;

  @override
  void initState() {
    super.initState();
    final saved = widget.summary;
    if (saved != null) {
      _summary = saved;
      _audioRef = saved.audioRef;
      _createdAt = saved.createdAt;
      _durationSeconds = saved.durationSeconds;
    } else {
      _audioRef = 'local:${widget.recordingId}';
      _createdAt = widget.pendingCreatedAt!;
      _durationSeconds = widget.pendingDurationSeconds!;
      _analyzing = true;
      _runPipeline();
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  // ── Post-recording analysis (moved off the recording page so the result
  // screen itself — header, duration, playback — appears immediately) ──────

  Future<void> _runPipeline() async {
    final crepe = OnDeviceCrepeService();
    try {
      // Batch CREPE and Whisper both run once over the full take,
      // independently and concurrently, then get combined by timestamp.
      // A finer hop than the default matters here: each word gets further
      // split into syllable-sized sub-windows (see buildWordNotes), so
      // denser pitch samples make it more likely each sub-window actually
      // has a frame in or near it.
      // Bounded so an unforeseen hang anywhere in this pipeline can never
      // leave the user stuck on this screen forever — shows as a normal
      // "failed to analyze" error instead, same as any other failure here.
      final results = await Future.wait([
        crepe.analyzeOffline(widget.pendingPcmSamples!, hopMs: 50),
        transcribeWords(widget.pendingWavBytes!),
      ]).timeout(const Duration(minutes: 2));
      final pitchFrames = results[0] as List<PitchFrame>;
      final words = results[1] as List<TranscribedWord>;

      debugPrint('Freestyle analysis: ${words.length} words, '
          '${pitchFrames.where((f) => f.hasSignal).length} voiced pitch frames');

      // Whisper and CREPE are independent — if the speech pass recognized
      // nothing (quiet take, singing rather than speech) but real pitch was
      // detected, still show the timestamps and notes that analysis did
      // produce instead of discarding them for an empty screen.
      var wordNotes = buildWordNotes(words: words, pitchFrames: pitchFrames);
      if (wordNotes.isEmpty) {
        wordNotes = buildPitchOnlyNotes(pitchFrames: pitchFrames);
      }

      final summary = FreeSingSummary(
        id: widget.recordingId!,
        createdAt: _createdAt,
        durationSeconds: _durationSeconds,
        audioRef: _audioRef,
        words: wordNotes,
      );
      await FreeSingStorageService.saveSummary(summary);

      if (mounted) {
        setState(() {
          _summary = summary;
          _analyzing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _analyzing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to analyze recording: $e')),
        );
      }
    } finally {
      crepe.dispose();
    }
  }

  // ── Playback ───────────────────────────────────────────────────────────────

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
      if (mounted) setState(() => _isPlaying = false);
      return;
    }

    if (_player.processingState == ProcessingState.idle) {
      setState(() => _isLoadingAudio = true);
      try {
        if (_audioRef.startsWith('local:')) {
          final id = _audioRef.replaceFirst('local:', '');
          final prefs = await SharedPreferences.getInstance();
          final b64 = prefs.getString('wav_$id');
          if (b64 == null) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Audio data not found.')),
              );
              setState(() => _isLoadingAudio = false);
            }
            return;
          }
          final Uint8List bytes = base64Decode(b64);
          final dataUri = Uri.dataFromBytes(bytes, mimeType: 'audio/wav');
          await _player.setAudioSource(AudioSource.uri(dataUri));
        } else {
          await _player.setAudioSource(AudioSource.uri(Uri.file(_audioRef)));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Playback error: $e')),
          );
          setState(() => _isLoadingAudio = false);
        }
        return;
      }
    }

    if (mounted) setState(() => _isLoadingAudio = false);
    await _player.play();
    if (mounted) setState(() => _isPlaying = true);
    _player.playerStateStream.listen((state) {
      if (!mounted) return;
      if (state.processingState == ProcessingState.completed) {
        setState(() => _isPlaying = false);
      }
    });
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// Entries carrying an actually-recognized word. Pitch-only entries (see
  /// [buildPitchOnlyNotes]) are real detected sound but not words, so
  /// counting them here would overstate what speech recognition found.
  int _recognizedWordCount(List<WordNoteEntry> words) =>
      words.where((w) => w.word.isNotEmpty).length;

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}  '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  // ── Group words into lyric-style "lines" so the whole session reads as a
  // vertically scrollable timeline instead of one giant horizontal strip —
  // a new line starts on a natural pause (>1.2s gap) or after maxPerLine
  // words, whichever comes first. Purely a display grouping; doesn't touch
  // the underlying word/note/timestamp data. ────────────────────────────────
  List<List<WordNoteEntry>> _groupIntoLines(
    List<WordNoteEntry> words, {
    int maxPerLine = 6,
    int gapMs = 1200,
  }) {
    final lines = <List<WordNoteEntry>>[];
    var current = <WordNoteEntry>[];
    int? prevEnd;

    for (final word in words) {
      final naturalPause = prevEnd != null && word.startTimeMs - prevEnd > gapMs;
      if (current.isNotEmpty && (current.length >= maxPerLine || naturalPause)) {
        lines.add(current);
        current = [];
      }
      current.add(word);
      prevEnd = word.endTimeMs;
    }
    if (current.isNotEmpty) lines.add(current);
    return lines;
  }

  @override
  Widget build(BuildContext context) {
    final words = _summary?.words ?? const <WordNoteEntry>[];
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            _buildSummaryBar(words),
            const Divider(color: Colors.white12, height: 1),
            Expanded(
              child: _analyzing
                  ? _buildAnalyzingState()
                  : words.isEmpty
                  ? _buildEmptyState()
                  : _buildTimeline(words),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back,
              color: AppColors.white,
              size: 26,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              'Freestyle Summary',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.white,
                fontFamily: 'Roboto',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBar(List<WordNoteEntry> words) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: _isLoadingAudio ? null : _togglePlay,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryCyan.withValues(alpha: 0.15),
              ),
              child: _isLoadingAudio
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primaryCyan,
                      ),
                    )
                  : Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: AppColors.primaryCyan,
                      size: 26,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDate(_createdAt),
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Roboto',
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _analyzing
                      ? '${_formatDuration(_durationSeconds)}  •  Analyzing…'
                      : '${_formatDuration(_durationSeconds)}  •  '
                          '${_recognizedWordCount(words)} '
                          'word${_recognizedWordCount(words) == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: AppColors.grey.withValues(alpha: 0.7),
                    fontSize: 12,
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

  Widget _buildAnalyzingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.primaryCyan),
            const SizedBox(height: 20),
            Text(
              'Preparing the result...',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.grey.withValues(alpha: 0.8),
                fontSize: 14,
                fontFamily: 'Roboto',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.mic_off_outlined,
              color: AppColors.grey.withValues(alpha: 0.4),
              size: 56,
            ),
            const SizedBox(height: 16),
            Text(
              'No words were recognized in this recording',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.grey.withValues(alpha: 0.7),
                fontSize: 14,
                fontFamily: 'Roboto',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Lyric-style timeline ───────────────────────────────────────────────────
  // Whole session, vertically scrollable, broken into short chronological
  // "lines" (like a lyrics sheet) so nothing ever needs horizontal scrolling.

  Widget _buildTimeline(List<WordNoteEntry> words) {
    final lines = _groupIntoLines(words);
    // Pitch was detected but speech recognition came back with nothing —
    // say so, rather than leaving a screen of "♪" unexplained.
    final pitchOnly = _recognizedWordCount(words) == 0;

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: lines.length + (pitchOnly ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 18),
      itemBuilder: (context, i) {
        if (pitchOnly && i == 0) return const _PitchOnlyNotice();
        return _TimelineLine(entries: lines[i - (pitchOnly ? 1 : 0)]);
      },
    );
  }
}

/// Shown when the pitch pass found real notes but speech recognition
/// recognized no words, so the "♪" placeholders below have an explanation.
class _PitchOnlyNotice extends StatelessWidget {
  const _PitchOnlyNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFF9800).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFF9800).withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Color(0xFFFF9800), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'No words were recognized in this recording, so only the '
              'detected pitch is shown. Recording closer to the mic, at a '
              'steadier volume, usually helps.',
              style: TextStyle(
                color: AppColors.grey.withValues(alpha: 0.85),
                fontSize: 12,
                fontFamily: 'Roboto',
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineLine extends StatelessWidget {
  final List<WordNoteEntry> entries;
  const _TimelineLine({required this.entries});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.start,
        children: entries.map((e) => _WordToken(entry: e)).toList(),
      ),
    );
  }
}

/// One word's time / detected note / lyric text, stacked top-to-bottom —
/// this is the "timestamp row / pitch row / word row" the design calls for,
/// expressed per-word so each column stays aligned to its own word even
/// after the line wraps on a narrow screen.
class _WordToken extends StatelessWidget {
  final WordNoteEntry entry;
  const _WordToken({required this.entry});

  String get _timeLabel => '${(entry.startTimeMs / 1000).toStringAsFixed(1)}s';

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Timestamp row
        Text(
          _timeLabel,
          style: TextStyle(
            color: AppColors.grey.withValues(alpha: 0.5),
            fontSize: 10,
            fontFamily: 'Roboto',
          ),
        ),
        const SizedBox(height: 4),
        // Pitch/note row — one chip per syllable in the word
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < entry.syllableNotes.length; i++) ...[
              if (i > 0) const SizedBox(width: 3),
              _NoteChip(note: entry.syllableNotes[i]),
            ],
          ],
        ),
        const SizedBox(height: 4),
        // Word/lyric row. A musical note, not a word, when speech
        // recognition didn't catch anything here — the pitch above it is
        // real and measured, so inventing a word for it would be worse
        // than admitting none was recognized.
        Text(
          entry.word.isEmpty ? '♪' : entry.word,
          style: TextStyle(
            color: entry.word.isEmpty
                ? AppColors.grey.withValues(alpha: 0.6)
                : AppColors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            fontFamily: 'Roboto',
          ),
        ),
      ],
    );
  }
}

/// A single syllable's detected note (or "--" if none was confidently
/// detected nearby).
class _NoteChip extends StatelessWidget {
  final String? note;
  const _NoteChip({required this.note});

  @override
  Widget build(BuildContext context) {
    final hasNote = note != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: hasNote
            ? AppColors.primaryCyan.withValues(alpha: 0.12)
            : AppColors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: hasNote
              ? AppColors.primaryCyan.withValues(alpha: 0.35)
              : AppColors.grey.withValues(alpha: 0.25),
        ),
      ),
      child: Text(
        note ?? '--',
        style: TextStyle(
          color: hasNote ? AppColors.primaryCyan : AppColors.grey,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          fontFamily: 'Roboto',
        ),
      ),
    );
  }
}
