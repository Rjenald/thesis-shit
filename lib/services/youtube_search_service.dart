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
  }) async {
    if (!YoutubeConfig.isConfigured) {
      return const YoutubeSearchResult(YoutubeSearchStatus.notConfigured);
    }
    if (title.trim().isEmpty) {
      return const YoutubeSearchResult(YoutubeSearchStatus.noResults);
    }

    final query = '${title.trim()} ${artist.trim()} karaoke'.trim();

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
