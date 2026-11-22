import 'dart:async';

import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../services/lyrics_service.dart';
import '../../services/song_search_stats_service.dart';
import '../../services/youtube_search_service.dart';
import 'freestyle_recording_page.dart';

/// Search & Sing: search for any song, sing over its minus-one, and get
/// the same note/word/timestamp analysis Freestyle produces.
///
/// Searches YouTube directly for whatever is typed, rather than going
/// through a lyrics provider first. The provider only knew songs it had
/// lyrics for, so anything it had not indexed could not be found at all
/// even when a perfectly good karaoke track existed.
///
/// **Only minus-ones are listed.** Appending "karaoke" to a query is a
/// hint and not a filter — YouTube ranks by relevance and returns official
/// music videos for karaoke queries all the time. Singing over a track
/// that still carries the lead vocal means the pitch analysis hears the
/// original singer as much as the user, so results that look like the
/// original are dropped on the way back
/// ([YoutubeSearchService.looksLikeMinusOne]).
///
/// No reference melody exists for a song found this way, so the result
/// deliberately analyses what was sung rather than scoring it against a
/// target — that comparison belongs to Scored Karaoke, which has an
/// authored ground truth to compare against.
class SearchAndSingPage extends StatefulWidget {
  const SearchAndSingPage({super.key});

  @override
  State<SearchAndSingPage> createState() =>
      _SearchAndSingPageState();
}

class _SearchAndSingPageState extends State<SearchAndSingPage> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  YoutubeSearchResult _result =
      const YoutubeSearchResult(YoutubeSearchStatus.ok);
  bool _searching = false;
  bool _hasSearched = false;

  /// Set while a pick is resolving its lyrics, so the tile cannot be
  /// tapped twice into two recording screens.
  bool _opening = false;

  List<YoutubeVideo> get _results => _result.videos;

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
        _result = const YoutubeSearchResult(YoutubeSearchStatus.ok);
        _hasSearched = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), () => _search(value));
  }

  Future<void> _search(String query) async {
    setState(() => _searching = true);
    final result = await YoutubeSearchService.searchMinusOne(query: query);
    if (!mounted) return;
    setState(() {
      _result = result;
      _searching = false;
      _hasSearched = true;
    });
  }

  Future<void> _pick(YoutubeVideo video) async {
    if (_opening) return;
    setState(() => _opening = true);

    // The video title carries the karaoke marker and the channel's
    // branding, neither of which a lyrics provider will match on.
    final songName = YoutubeSearchService.cleanSongTitle(video.title);

    // Counted here — on a real choice to sing — rather than per keystroke,
    // so the admin's demand data reflects intent. See
    // [SongSearchStatsService].
    await SongSearchStatsService.recordPick(songName, video.channelTitle);

    // Best-effort: lyrics make the sing-along nicer but are not required,
    // and a provider that has never heard of this song must not stop
    // anyone from singing it.
    List<LrcLine> lyrics = const [];
    try {
      final matches = await LyricsService.searchSongs(songName);
      if (matches.isNotEmpty) lyrics = matches.first.syncedLyrics;
    } catch (e) {
      debugPrint('Lyrics lookup for "$songName" failed: $e');
    }

    if (!mounted) return;
    setState(() => _opening = false);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FreestyleRecordingPage(
          songTitle: songName.isEmpty ? video.title : songName,
          songArtist: video.channelTitle,
          lyrics: lyrics,
          backingTrackVideoId: video.videoId,
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
          'Search & Sing',
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
          if (_hasSearched) _buildAcappellaBar(),
        ],
      ),
    );
  }

  /// Singing with no backing track at all.
  ///
  /// Always offered once a search has run, not just when the search
  /// failed: the notes, words and timing analysis is identical either
  /// way, so wanting no accompaniment is a choice rather than a
  /// consolation. Folding the old two-step flow into one search took the
  /// picker screen away, and this is the part of it worth keeping.
  Widget _buildAcappellaBar() {
    final typed = _controller.text.trim();
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _opening || typed.isEmpty ? null : _singAcappella,
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
              padding: const EdgeInsets.symmetric(vertical: 13),
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

  Future<void> _singAcappella() async {
    if (_opening) return;
    final typed = _controller.text.trim();
    if (typed.isEmpty) return;
    setState(() => _opening = true);
    await SongSearchStatsService.recordPick(typed, '');

    List<LrcLine> lyrics = const [];
    try {
      final matches = await LyricsService.searchSongs(typed);
      if (matches.isNotEmpty) lyrics = matches.first.syncedLyrics;
    } catch (e) {
      debugPrint('Lyrics lookup for "$typed" failed: $e');
    }

    if (!mounted) return;
    setState(() => _opening = false);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FreestyleRecordingPage(
          songTitle: typed,
          songArtist: '',
          lyrics: lyrics,
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (!_hasSearched) return _hint();
    if (_searching && _results.isEmpty) return const SizedBox.shrink();

    // Each status is a different thing to do about it, so each says so.
    // Collapsing them into "no results" sent people hunting for a better
    // search term when the real problem was an unconfigured key.
    switch (_result.status) {
      case YoutubeSearchStatus.notConfigured:
        return _message(
          Icons.vpn_key_off,
          'No YouTube key configured',
          'Searching for backing tracks needs a YouTube Data API key. '
              'Freestyle still works without one.',
        );
      case YoutubeSearchStatus.rejected:
        return _message(
          Icons.block,
          'YouTube rejected the key',
          'Check it is restricted to YouTube Data API v3, and that the '
              'package name and SHA-1 match this build.',
        );
      case YoutubeSearchStatus.quotaExceeded:
        return _message(
          Icons.hourglass_disabled,
          'Daily quota used up',
          'The free YouTube quota resets at midnight US Pacific.',
        );
      case YoutubeSearchStatus.failed:
        return _message(
          Icons.wifi_off,
          'Could not reach YouTube',
          'Check your connection and try again.',
        );
      case YoutubeSearchStatus.noResults:
        return _message(
          Icons.search_off,
          'No minus-one found',
          'Only backing tracks are listed here, so versions with the '
              'original vocal are filtered out. Try the title with the '
              'artist name, or a different spelling.',
        );
      case YoutubeSearchStatus.ok:
        break;
    }

    if (_results.isEmpty) {
      return _message(
        Icons.search_off,
        'No minus-one found',
        'Try the song title with the artist name.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: _results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _MinusOneTile(
        video: _results[i],
        busy: _opening,
        onTap: () => _pick(_results[i]),
      ),
    );
  }

  Widget _hint() => _message(
        Icons.library_music_outlined,
        'Search for a song',
        'Only karaoke and instrumental versions are shown, so there is no '
            'original vocal competing with yours. Your notes, words and '
            'timing get analysed afterwards.',
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

class _MinusOneTile extends StatelessWidget {
  final YoutubeVideo video;
  final VoidCallback onTap;
  final bool busy;

  const _MinusOneTile({
    required this.video,
    required this.onTap,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: busy ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Opacity(
        opacity: busy ? 0.5 : 1,
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
                    ? _placeholder()
                    : Image.network(
                        video.thumbnailUrl,
                        width: 72,
                        height: 54,
                        fit: BoxFit.cover,
                        // Thumbnails are remote, and this mode is used on
                        // whatever connection the singer has.
                        errorBuilder: (_, _, _) => _placeholder(),
                      ),
              ),
              const SizedBox(width: 11),
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
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Roboto',
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      video.channelTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.grey.withValues(alpha: 0.85),
                        fontSize: 11.5,
                        fontFamily: 'Roboto',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primaryCyan,
                      ),
                    )
                  : const Icon(Icons.mic,
                      color: AppColors.primaryCyan, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        width: 72,
        height: 54,
        color: AppColors.primaryCyan.withValues(alpha: 0.12),
        child: const Icon(Icons.music_note,
            color: AppColors.primaryCyan, size: 20),
      );
}
