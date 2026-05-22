import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/app_colors.dart';
import '../../services/recording_storage_service.dart';

class SaveRecordPage extends StatefulWidget {
  const SaveRecordPage({super.key});

  @override
  State<SaveRecordPage> createState() => _SaveRecordPageState();
}

class _SaveRecordPageState extends State<SaveRecordPage> {
  final AudioPlayer _player = AudioPlayer();

  List<RecordingEntry> _recordings = [];
  String? _playingId;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRecordings();
    _player.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(() => _isPlaying = state.playing);
      if (state.processingState == ProcessingState.completed) {
        setState(() {
          _isPlaying = false;
          _playingId = null;
          _position = Duration.zero;
        });
      }
    });
    _player.positionStream.listen((pos) {
      if (!mounted) return;
      setState(() => _position = pos);
    });
    _player.durationStream.listen((dur) {
      if (!mounted) return;
      setState(() => _duration = dur ?? Duration.zero);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _loadRecordings() async {
    final list = await RecordingStorageService.loadRecordings();
    if (mounted) {
      setState(() {
        _recordings = list;
        _loading = false;
      });
    }
  }

  Future<void> _togglePlay(RecordingEntry entry) async {
    if (_playingId == entry.id) {
      if (_isPlaying) {
        await _player.pause();
      } else {
        await _player.play();
      }
      return;
    }

    setState(() {
      _playingId = entry.id;
      _position = Duration.zero;
    });
    await _player.stop();

    try {
      if (entry.filePath.startsWith('local:')) {
        final id = entry.filePath.replaceFirst('local:', '');
        final prefs = await SharedPreferences.getInstance();
        final b64 = prefs.getString('wav_$id');
        if (b64 == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Audio data not found.')),
            );
          }
          setState(() => _playingId = null);
          return;
        }
        final Uint8List bytes = base64Decode(b64);
        final dataUri = Uri.dataFromBytes(bytes, mimeType: 'audio/wav');
        await _player.setAudioSource(AudioSource.uri(dataUri));
      } else {
        await _player.setAudioSource(AudioSource.uri(Uri.file(entry.filePath)));
      }
      await _player.play();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Playback error: $e')),
        );
        setState(() => _playingId = null);
      }
    }
  }

  Future<void> _deleteRecording(RecordingEntry entry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Delete this recording?',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text(
                      'Delete',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm != true) return;

    if (_playingId == entry.id) {
      await _player.stop();
      setState(() {
        _playingId = null;
        _isPlaying = false;
      });
    }

    await RecordingStorageService.deleteRecording(entry);
    await _loadRecordings();
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}  '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ─────────────────────────────────────────────────────
            Padding(
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
                    'Saved Recordings',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ],
              ),
            ),

            const Divider(color: Colors.white12, height: 1),

            // ── List ───────────────────────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryCyan,
                      ),
                    )
                  : _recordings.isEmpty
                  ? const Center(
                      child: Text(
                        'No recordings yet.\nRecord something and it will appear here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.grey,
                          fontSize: 14,
                          fontFamily: 'Roboto',
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      itemCount: _recordings.length,
                      separatorBuilder: (_, _) =>
                          const Divider(color: Colors.white10, height: 1),
                      itemBuilder: (context, i) {
                        final entry = _recordings[i];
                        final isThisPlaying = _playingId == entry.id;
                        return _RecordingCard(
                          entry: entry,
                          isPlaying: isThisPlaying && _isPlaying,
                          isPaused: isThisPlaying && !_isPlaying,
                          position: isThisPlaying ? _position : Duration.zero,
                          duration: isThisPlaying ? _duration : Duration.zero,
                          formatDuration: _formatDuration,
                          formatDate: _formatDate,
                          onPlayPause: () => _togglePlay(entry),
                          onDelete: () => _deleteRecording(entry),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordingCard extends StatelessWidget {
  final RecordingEntry entry;
  final bool isPlaying;
  final bool isPaused;
  final Duration position;
  final Duration duration;
  final String Function(int) formatDuration;
  final String Function(DateTime) formatDate;
  final VoidCallback onPlayPause;
  final VoidCallback onDelete;

  const _RecordingCard({
    required this.entry,
    required this.isPlaying,
    required this.isPaused,
    required this.position,
    required this.duration,
    required this.formatDuration,
    required this.formatDate,
    required this.onPlayPause,
    required this.onDelete,
  });

  String _durationStr(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final active = isPlaying || isPaused;
    return Container(
      color: active
          ? AppColors.primaryCyan.withValues(alpha: 0.07)
          : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Play / Pause button
              GestureDetector(
                onTap: onPlayPause,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active
                        ? AppColors.primaryCyan
                        : AppColors.primaryCyan.withValues(alpha: 0.2),
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Title + date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Roboto',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatDate(entry.createdAt),
                      style: TextStyle(
                        color: AppColors.grey.withValues(alpha: 0.7),
                        fontSize: 11,
                        fontFamily: 'Roboto',
                      ),
                    ),
                  ],
                ),
              ),

              // Duration label
              Text(
                formatDuration(entry.durationSeconds),
                style: TextStyle(
                  color: AppColors.grey.withValues(alpha: 0.7),
                  fontSize: 12,
                  fontFamily: 'Roboto',
                ),
              ),
              const SizedBox(width: 8),

              // Delete button
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                  size: 20,
                ),
                onPressed: onDelete,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),

          // Progress bar (only when active)
          if (active) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const SizedBox(width: 56),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: duration.inMilliseconds > 0
                          ? (position.inMilliseconds / duration.inMilliseconds)
                                .clamp(0.0, 1.0)
                          : 0.0,
                      minHeight: 4,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.primaryCyan,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_durationStr(position)} / ${_durationStr(duration)}',
                  style: const TextStyle(
                    color: AppColors.grey,
                    fontSize: 10,
                    fontFamily: 'Roboto',
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
