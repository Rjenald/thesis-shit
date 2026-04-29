import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'karaoke_recording_page.dart';

class KaraokeSongDetailPage extends StatefulWidget {
  final String songTitle;
  final String songArtist;
  final String songImage;
  final String youtubeId;

  const KaraokeSongDetailPage({
    super.key,
    required this.songTitle,
    required this.songArtist,
    required this.songImage,
    this.youtubeId = '',
  });

  @override
  State<KaraokeSongDetailPage> createState() => _KaraokeSongDetailPageState();
}

class _KaraokeSongDetailPageState extends State<KaraokeSongDetailPage> {
  Timer? _eqTimer;
  final List<double> _bars = List.filled(32, 0.15);
  final List<double> _targets = List.filled(32, 0.15);
  final _rng = math.Random();

  @override
  void initState() {
    super.initState();
    _startEqualizer();
  }

  @override
  void dispose() {
    _eqTimer?.cancel();
    super.dispose();
  }

  void _startEqualizer() {
    _eqTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted) return;
      setState(() {
        for (int i = 0; i < _bars.length; i++) {
          _targets[i] = 0.15 + _rng.nextDouble() * 0.85;
          _bars[i] += (_targets[i] - _bars[i]) * 0.3;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 16, 20),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      color: AppColors.white,
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.songTitle,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.white,
                            fontFamily: 'Roboto',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          widget.songArtist,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.grey.withValues(alpha: 0.7),
                            fontFamily: 'Roboto',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Song image and equalizer
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    // Album art
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        image: DecorationImage(
                          image: NetworkImage(widget.songImage),
                          fit: BoxFit.cover,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: widget.songImage.isEmpty
                          ? const Icon(
                              Icons.music_note,
                              size: 80,
                              color: AppColors.grey,
                            )
                          : null,
                    ),

                    const SizedBox(height: 40),

                    // Equalizer bars
                    Expanded(
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: List.generate(
                            _bars.length,
                            (i) => Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 1,
                                ),
                                child: Container(
                                  height: _bars[i] * 80,
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryCyan,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Start recording button
            Padding(
              padding: const EdgeInsets.all(20),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => KaraokeRecordingPage(
                        songTitle: widget.songTitle,
                        songArtist: widget.songArtist,
                        songImage: widget.songImage,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryCyan,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 8,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.mic, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Start Recording',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        fontFamily: 'Roboto',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
