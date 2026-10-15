import 'dart:async';

import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../services/lyrics_service.dart';
import '../../services/song_search_stats_service.dart';
import 'backing_track_picker_page.dart';

/// Analysis Karaoke: find any song online, sing it, and get the same
/// note/word/timestamp analysis Freestyle produces.
///
/// No reference melody exists for a song found this way, so the result
/// deliberately analyses what was sung rather than scoring it against a
/// target — that comparison belongs to Scored Karaoke, which has an
/// authored ground truth to compare against.
class AnalysisSongSearchPage extends StatefulWidget {
  const AnalysisSongSearchPage({super.key});

  @override
  State<AnalysisSongSearchPage> createState() =>
      _AnalysisSongSearchPageState();
}

class _AnalysisSongSearchPageState extends State<AnalysisSongSearchPage> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  List<OnlineSongResult> _results = const [];
  bool _searching = false;
  bool _hasSearched = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    // Debounced so typing a title doesn't fire a request per keystroke.
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _results = const [];
        _hasSearched = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), () => _search(value));
  }

  Future<void> _search(String query) async {
    setState(() => _searching = true);
    final results = await LyricsService.searchSongs(query);
    if (!mounted) return;
    setState(() {
      _results = results;
      _searching = false;
      _hasSearched = true;
    });
  }

  Future<void> _pick(OnlineSongResult song) async {
    // Counted here — on a real choice to sing — rather than per keystroke,
    // so the admin's demand data reflects intent. See
    // [SongSearchStatsService].
    await SongSearchStatsService.recordPick(song.title, song.artist);
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BackingTrackPickerPage(
          songTitle: song.title,
          songArtist: song.artist,
          lyrics: song.syncedLyrics,
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
        title: const Text(
          'Analysis Karaoke',
          style: TextStyle(
            color: AppColors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Roboto',
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: TextField(
              controller: _controller,
              onChanged: _onQueryChanged,
              textInputAction: TextInputAction.search,
              onSubmitted: _search,
              style: const TextStyle(
                  color: AppColors.white, fontFamily: 'Roboto'),
              decoration: InputDecoration(
                hintText: 'Search any song…',
                hintStyle: TextStyle(
                    color: AppColors.grey.withValues(alpha: 0.8),
                    fontFamily: 'Roboto'),
                prefixIcon:
                    const Icon(Icons.search, color: AppColors.grey, size: 20),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.primaryCyan),
                        ),
                      )
                    : null,
                filled: true,
                fillColor: AppColors.inputBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (!_hasSearched) return _hint();
    if (_searching && _results.isEmpty) return const SizedBox.shrink();
    if (_results.isEmpty) {
      return _message(
        Icons.search_off,
        'No songs found',
        'Try the song title, or add the artist name.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: _results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) =>
          _SongResultTile(song: _results[i], onTap: () => _pick(_results[i])),
    );
  }

  Widget _hint() => _message(
        Icons.library_music_outlined,
        'Search for a song',
        'Pick any song and sing it — your notes, words and timing get '
            'analysed afterwards.',
      );

  Widget _message(IconData icon, String title, String body) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.grey.withValues(alpha: 0.4), size: 52),
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
          ],
        ),
      ),
    );
  }
}

class _SongResultTile extends StatelessWidget {
  final OnlineSongResult song;
  final VoidCallback onTap;

  const _SongResultTile({required this.song, required this.onTap});

  String get _duration {
    final m = song.duration.inMinutes;
    final s = (song.duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primaryCyan.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.music_note,
                  color: AppColors.primaryCyan, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Roboto',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    song.artist.isEmpty ? 'Unknown artist' : song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.grey.withValues(alpha: 0.9),
                      fontSize: 12,
                      fontFamily: 'Roboto',
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      if (song.duration > Duration.zero) ...[
                        Text(
                          _duration,
                          style: TextStyle(
                            color: AppColors.grey.withValues(alpha: 0.7),
                            fontSize: 10.5,
                            fontFamily: 'Roboto',
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      // Whether the lyrics will follow along while singing.
                      _badge(
                        song.hasSyncedLyrics ? 'Timed lyrics' : 'No timing',
                        song.hasSyncedLyrics
                            ? const Color(0xFF4CAF50)
                            : AppColors.grey,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.mic, color: AppColors.primaryCyan, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
          fontFamily: 'Roboto',
        ),
      ),
    );
  }
}
