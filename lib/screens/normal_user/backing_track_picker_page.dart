import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../services/lyrics_service.dart' show LrcLine;
import '../../services/youtube_search_service.dart';
import 'freestyle_recording_page.dart';

/// Step two of Analysis Karaoke: pick a minus-one to sing over, or skip and
/// sing a cappella.
///
/// Skipping is a first-class choice, not a failure path — the analysis
/// (notes, words, timestamps) is identical either way, and a cappella
/// actually produces *cleaner* pitch data, since nothing from a speaker
/// can leak into the recording.
class BackingTrackPickerPage extends StatefulWidget {
  final String songTitle;
  final String songArtist;
  final List<LrcLine> lyrics;

  const BackingTrackPickerPage({
    super.key,
    required this.songTitle,
    required this.songArtist,
    required this.lyrics,
  });

  @override
  State<BackingTrackPickerPage> createState() =>
      _BackingTrackPickerPageState();
}

class _BackingTrackPickerPageState extends State<BackingTrackPickerPage> {
  YoutubeSearchResult _result =
      const YoutubeSearchResult(YoutubeSearchStatus.ok);
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _search();
  }

  Future<void> _search() async {
    setState(() => _loading = true);
    final result = await YoutubeSearchService.searchKaraoke(
      title: widget.songTitle,
      artist: widget.songArtist,
    );
    if (!mounted) return;
    setState(() {
      _result = result;
      _loading = false;
    });
  }

  void _start({String? videoId}) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => FreestyleRecordingPage(
          songTitle: widget.songTitle,
          songArtist: widget.songArtist,
          lyrics: widget.lyrics,
          backingTrackVideoId: videoId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: AppColors.bgDark,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Backing track',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
                fontFamily: 'Roboto',
              ),
            ),
            Text(
              widget.songTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.grey.withValues(alpha: 0.9),
                fontSize: 11.5,
                fontFamily: 'Roboto',
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildBody()),
          _buildSkipBar(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryCyan),
      );
    }

    switch (_result.status) {
      case YoutubeSearchStatus.ok:
        return _buildResults();
      case YoutubeSearchStatus.notConfigured:
        return _message(
          Icons.vpn_key_outlined,
          'No YouTube key configured',
          'Backing tracks need a YouTube Data API key. You can still sing '
              'this song a cappella — the analysis is the same.',
        );
      case YoutubeSearchStatus.rejected:
        return _message(
          Icons.block,
          'YouTube rejected the key',
          'Check the key is restricted to YouTube Data API v3, and that the '
              'package name and SHA-1 match this build.',
          onRetry: _search,
        );
      case YoutubeSearchStatus.quotaExceeded:
        return _message(
          Icons.hourglass_empty,
          'Daily quota used up',
          'The free YouTube quota resets at midnight US Pacific. Sing a '
              'cappella until then.',
        );
      case YoutubeSearchStatus.failed:
        return _message(
          Icons.wifi_off,
          'Could not reach YouTube',
          'Check your connection and try again.',
          onRetry: _search,
        );
      case YoutubeSearchStatus.noResults:
        return _message(
          Icons.search_off,
          'No karaoke version found',
          'Nothing embeddable came back for this song. Singing a cappella '
              'works just as well for the analysis.',
          onRetry: _search,
        );
    }
  }

  Widget _buildResults() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      itemCount: _result.videos.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        if (i == 0) return _headphonesNotice();
        final video = _result.videos[i - 1];
        return _VideoTile(
          video: video,
          onTap: () => _start(videoId: video.videoId),
        );
      },
    );
  }

  /// The single most important thing to get right in this mode: a backing
  /// track played out loud lands in the microphone, and the pitch analysis
  /// then describes the track as much as the singer.
  Widget _headphonesNotice() {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFF9800).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: const Color(0xFFFF9800).withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.headset, color: Color(0xFFFF9800), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Use headphones. If the backing track plays out loud, the mic '
              'records it too and your pitch results will include the song, '
              'not just your voice.',
              style: TextStyle(
                color: AppColors.grey.withValues(alpha: 0.9),
                fontSize: 11.5,
                fontFamily: 'Roboto',
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkipBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _start(),
            icon: const Icon(Icons.mic_none,
                color: AppColors.primaryCyan, size: 18),
            label: const Text(
              'Sing a cappella',
              style: TextStyle(
                color: AppColors.primaryCyan,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                fontFamily: 'Roboto',
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(
                  color: AppColors.primaryCyan.withValues(alpha: 0.5)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _message(IconData icon, String title, String body,
      {VoidCallback? onRetry}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.grey.withValues(alpha: 0.4), size: 50),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                fontFamily: 'Roboto',
              ),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.grey.withValues(alpha: 0.8),
                fontSize: 12.5,
                fontFamily: 'Roboto',
                height: 1.4,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 14),
              TextButton(
                onPressed: onRetry,
                child: const Text(
                  'Try again',
                  style: TextStyle(
                    color: AppColors.primaryCyan,
                    fontFamily: 'Roboto',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VideoTile extends StatelessWidget {
  final YoutubeVideo video;
  final VoidCallback onTap;

  const _VideoTile({required this.video, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: video.thumbnailUrl.isEmpty
                  ? Container(
                      width: 72,
                      height: 54,
                      color: AppColors.inputBg,
                      child: const Icon(Icons.music_video,
                          color: AppColors.grey, size: 20),
                    )
                  : Image.network(
                      video.thumbnailUrl,
                      width: 72,
                      height: 54,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 72,
                        height: 54,
                        color: AppColors.inputBg,
                        child: const Icon(Icons.music_video,
                            color: AppColors.grey, size: 20),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Roboto',
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    video.channelTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.grey.withValues(alpha: 0.85),
                      fontSize: 11,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.play_circle_outline,
                color: AppColors.primaryCyan, size: 22),
          ],
        ),
      ),
    );
  }
}
