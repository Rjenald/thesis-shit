import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/youtube_config.dart';

/// One YouTube video that could serve as a backing track.
class YoutubeVideo {
  final String videoId;
  final String title;
  final String channelTitle;
  final String thumbnailUrl;

  const YoutubeVideo({
    required this.videoId,
    required this.title,
    required this.channelTitle,
    required this.thumbnailUrl,
  });
}

/// Why a search produced nothing, so the UI can say something useful
/// instead of a bare empty list.
enum YoutubeSearchStatus {
  ok,

  /// No API key configured — the feature is simply off.
  notConfigured,

  /// The key was rejected: wrong key, API not enabled on the project, or
  /// the Android package/fingerprint restriction didn't match.
  rejected,

  /// Daily quota spent. Resets at midnight US Pacific.
  quotaExceeded,

  /// Network failure, timeout, or anything else.
  failed,

  /// The search worked, there just aren't any matches.
  noResults,
}

class YoutubeSearchResult {
  final YoutubeSearchStatus status;
  final List<YoutubeVideo> videos;

  const YoutubeSearchResult(this.status, [this.videos = const []]);

  bool get isOk => status == YoutubeSearchStatus.ok;
}

/// Searches YouTube for a karaoke/instrumental version of a song.
///
/// Playback is always through the embedded player — this only ever asks
/// for video metadata. Downloading or extracting the audio would breach
/// YouTube's terms, so the backing track stays streamed, which is also why
/// headphones matter in this mode: anything coming out of the speaker ends
/// up in the recording and corrupts the pitch analysis.
class YoutubeSearchService {
  static const _endpoint = 'https://www.googleapis.com/youtube/v3/search';

  // ── telling a minus-one from the original ──────────────────────────
  //
  // Appending "karaoke" to the query is a hint, not a filter: YouTube
  // ranks by relevance and will happily return the official music video
  // for a song whose query mentioned karaoke. Singing over a track that
  // still has the vocal on it means CREPE analyses the original singer as
  // much as the user, so the score stops meaning anything — which is why
  // results are filtered on the way back as well.

  /// Phrases that mark a backing track. Matched against title AND channel,
  /// because some channels put "Karaoke" only in their name.
  static const List<String> _minusOneMarkers = [
    'karaoke', 'minus one', 'minus-one', 'minusone', 'instrumental',
    'backing track', 'sing along', 'singalong', 'sing-along',
    // Singular and plural both, because the boundary check below is
    // strict: "no vocal" does not match "No Vocals", and that is the
    // commoner spelling of the two.
    'no vocal', 'no vocals', 'without vocal', 'without vocals',
    'off vocal', 'off vocals', 'vocal removed', 'vocals removed',
    'lower key', 'higher key', 'piano version',
    'acoustic karaoke', 'karafun', 'sing king', 'kstar',
  ];

  /// Phrases that mark the original recording or someone else singing.
  ///
  /// Checked after the markers above and allowed to veto them, because a
  /// title like "Official Music Video (Karaoke Version)" is reliably the
  /// original with a misleading tag — the positive word alone is not
  /// enough to trust.
  static const List<String> _hasVocalMarkers = [
    'official music video', 'official video', 'official mv',
    'official audio', 'music video', 'lyric video', 'lyrics video',
    'live performance', 'live at', 'live in', 'live session',
    'vocal only', 'vocals only', 'with vocal', 'acapella', 'a cappella',
    'cover by', 'reaction', 'tutorial', 'how to sing', 'full album',
  ];

  /// Whether a result looks like something you can sing over.
  ///
  /// Deliberately strict: the mode's whole premise is that the backing
  /// track has no lead vocal, so a maybe is treated as a no. Showing a
  /// clean list of five is better than a list of twenty where some
  /// silently ruin the score.
  ///
  /// Public so it can be tested directly — getting this wrong is not
  /// visible in the UI until someone has already sung over the wrong
  /// thing.
  static bool looksLikeMinusOne(String title, [String channel = '']) {
    final hay = '${title.toLowerCase()} ${channel.toLowerCase()}';
    // Word-ish boundaries so "no vocal" is not cancelled by the "vocal"
    // inside it, and "cover by" does not match "discover".
    bool has(String phrase) {
      final i = hay.indexOf(phrase);
      if (i < 0) return false;
      final before = i == 0 ? ' ' : hay[i - 1];
      final afterAt = i + phrase.length;
      final after = afterAt >= hay.length ? ' ' : hay[afterAt];
      bool edge(String c) => !RegExp(r'[a-z0-9]').hasMatch(c);
      return edge(before) && edge(after);
    }

    if (!_minusOneMarkers.any(has)) return false;
    if (_hasVocalMarkers.any(has)) return false;
    return true;
  }

  /// A video title reduced to something a lyrics search can use.
  ///
  /// YouTube titles carry the karaoke marker, the channel's branding and
  /// assorted brackets — "Araw Araw - Ben&Ben (KARAOKE VERSION) | Sing
  /// King". Lyrics providers match on the song, so all of that has to come
  /// off before asking.
  static String cleanSongTitle(String videoTitle) {
    var s = videoTitle;
    // Anything bracketed is nearly always a tag, not part of the name.
    s = s.replaceAll(RegExp(r'[\(\[\{][^\)\]\}]*[\)\]\}]'), ' ');
    // Channel branding after a pipe.
    s = s.split('|').first;
    for (final marker in _minusOneMarkers) {
      s = s.replaceAll(RegExp(RegExp.escape(marker), caseSensitive: false),
          ' ');
    }
    s = s.replaceAll(
        RegExp(r'\b(version|hd|hq|official|lyrics?|with lyrics)\b',
            caseSensitive: false),
        ' ');
    // Leftover separators at either end once the tags are gone.
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    s = s.replaceAll(RegExp(r'^[\s\-–—_/:|]+|[\s\-–—_/:|]+$'), '').trim();
    return s;
  }

  /// Searches for a minus-one matching whatever the singer typed.
  ///
  /// Unlike [searchKaraoke] this takes the raw query rather than a
  /// title/artist pair, so Search & Sing can look up anything instead of
  /// only songs a lyrics provider happens to know.
  static Future<YoutubeSearchResult> searchMinusOne({
    required String query,
    int maxResults = 25,
  }) {
    final q = query.trim();
    if (q.isEmpty) {
      return Future.value(
          const YoutubeSearchResult(YoutubeSearchStatus.noResults));
    }
    // Asking for more than will be shown, because filtering throws most of
    // them away: a query that returns 10 originals and 2 karaoke versions
    // should still fill a usable list.
    return _search('$q karaoke instrumental', maxResults: maxResults,
        onlyMinusOne: true);
  }

  /// Finds likely karaoke versions of [title] by [artist].
  ///
  /// "karaoke" is appended to the query because the goal is a minus-one,
  /// not the original recording — singing over a track that already has
  /// the vocal on it would leave CREPE analysing the original singer as
  /// much as the user.
  static Future<YoutubeSearchResult> searchKaraoke({
    required String title,
    String artist = '',
    int maxResults = 10,
  }) {
    if (title.trim().isEmpty) {
      return Future.value(
          const YoutubeSearchResult(YoutubeSearchStatus.noResults));
    }
    return _search('${title.trim()} ${artist.trim()} karaoke'.trim(),
        maxResults: maxResults, onlyMinusOne: true);
  }

  static Future<YoutubeSearchResult> _search(
    String query, {
    required int maxResults,
    required bool onlyMinusOne,
  }) async {
    if (!YoutubeConfig.isConfigured) {
      return const YoutubeSearchResult(YoutubeSearchStatus.notConfigured);
    }

    try {
      final uri = Uri.parse(_endpoint).replace(queryParameters: {
        'part': 'snippet',
        'q': query,
        'type': 'video',
        // Only videos that are actually allowed to play embedded —
        // otherwise the player shows "video unavailable" at record time.
        'videoEmbeddable': 'true',
        'maxResults': '$maxResults',
        'key': YoutubeConfig.apiKey,
      });

      final res = await http
          .get(uri, headers: YoutubeConfig.restrictionHeaders)
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 403) {
        final body = res.body.toLowerCase();
        final quota = body.contains('quota');
        debugPrint('YouTube search rejected (403): ${res.body}');
        return YoutubeSearchResult(quota
            ? YoutubeSearchStatus.quotaExceeded
            : YoutubeSearchStatus.rejected);
      }
      if (res.statusCode != 200) {
        debugPrint('YouTube search failed ${res.statusCode}: ${res.body}');
        return const YoutubeSearchResult(YoutubeSearchStatus.failed);
      }

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final items = json['items'] as List<dynamic>? ?? const [];

      final videos = items
          .whereType<Map<String, dynamic>>()
          .map((item) {
            final id = (item['id'] as Map<String, dynamic>?)?['videoId'];
            final snippet = item['snippet'] as Map<String, dynamic>? ?? {};
            final thumbs =
                snippet['thumbnails'] as Map<String, dynamic>? ?? {};
            final medium = thumbs['medium'] as Map<String, dynamic>? ??
                thumbs['default'] as Map<String, dynamic>? ??
                {};
            if (id is! String || id.isEmpty) return null;

            return YoutubeVideo(
              videoId: id,
              title: _unescape(snippet['title'] as String? ?? ''),
              channelTitle:
                  _unescape(snippet['channelTitle'] as String? ?? ''),
              thumbnailUrl: medium['url'] as String? ?? '',
            );
          })
          .whereType<YoutubeVideo>()
          .toList();

      if (onlyMinusOne) {
        final before = videos.length;
        videos.retainWhere(
            (v) => looksLikeMinusOne(v.title, v.channelTitle));
        if (before != videos.length) {
          debugPrint('YouTube: dropped ${before - videos.length} of $before '
              'result(s) that still have a lead vocal');
        }
      }

      return videos.isEmpty
          ? const YoutubeSearchResult(YoutubeSearchStatus.noResults)
          : YoutubeSearchResult(YoutubeSearchStatus.ok, videos);
    } catch (e) {
      debugPrint('YouTube search error: $e');
      return const YoutubeSearchResult(YoutubeSearchStatus.failed);
    }
  }

  /// YouTube returns titles HTML-escaped (&amp;, &#39; and friends), which
  /// would otherwise render literally in the list.
  static String _unescape(String s) => s
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');
}
