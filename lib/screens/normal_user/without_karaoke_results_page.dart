import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/app_colors.dart';
import '../../models/free_sing_summary.dart';
import '../../models/word_note_entry.dart';

/// Shows the word-by-word note summary of a completed "without karaoke"
/// recording — no reference song, so there's nothing to score against; this
/// just lays out what was sung and the note detected for each word, in order.
class WithoutKaraokeResultsPage extends StatefulWidget {
  final FreeSingSummary summary;
  const WithoutKaraokeResultsPage({super.key, required this.summary});

  @override
  State<WithoutKaraokeResultsPage> createState() =>
      _WithoutKaraokeResultsPageState();
}

class _WithoutKaraokeResultsPageState
    extends State<WithoutKaraokeResultsPage> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoadingAudio = false;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
      if (mounted) setState(() => _isPlaying = false);
      return;
    }

    if (_player.processingState == ProcessingState.idle) {
      setState(() => _isLoadingAudio = true);
      try {
        final ref = widget.summary.audioRef;
        if (ref.startsWith('local:')) {
          final id = ref.replaceFirst('local:', '');
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
          await _player.setAudioSource(AudioSource.uri(Uri.file(ref)));
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

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}  '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            _buildSummaryBar(summary),
            const Divider(color: Colors.white12, height: 1),
            Expanded(
              child: summary.words.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      itemCount: summary.words.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) =>
                          _WordNoteRow(index: i, entry: summary.words[i]),
                    ),
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
          const Text(
            'Free Sing Summary',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.white,
              fontFamily: 'Roboto',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBar(FreeSingSummary summary) {
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
                  _formatDate(summary.createdAt),
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Roboto',
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_formatDuration(summary.durationSeconds)}  •  '
                  '${summary.words.length} word'
                  '${summary.words.length == 1 ? '' : 's'}',
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
}

class _WordNoteRow extends StatelessWidget {
  final int index;
  final WordNoteEntry entry;
  const _WordNoteRow({required this.index, required this.entry});

  String _timeLabel(int ms) {
    final totalSeconds = ms ~/ 1000;
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final hasNote = entry.note != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '${index + 1}',
              style: TextStyle(
                color: AppColors.grey.withValues(alpha: 0.4),
                fontSize: 11,
                fontFamily: 'Roboto',
              ),
            ),
          ),
          Expanded(
            child: Text(
              entry.word,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'Roboto',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _timeLabel(entry.startTimeMs),
            style: TextStyle(
              color: AppColors.grey.withValues(alpha: 0.5),
              fontSize: 11,
              fontFamily: 'Roboto',
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: hasNote
                  ? AppColors.primaryCyan.withValues(alpha: 0.12)
                  : AppColors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: hasNote
                    ? AppColors.primaryCyan.withValues(alpha: 0.35)
                    : AppColors.grey.withValues(alpha: 0.25),
              ),
            ),
            child: Text(
              entry.note ?? '—',
              style: TextStyle(
                color: hasNote ? AppColors.primaryCyan : AppColors.grey,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                fontFamily: 'Roboto',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
