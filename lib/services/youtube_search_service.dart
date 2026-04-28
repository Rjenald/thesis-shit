/// Searches YouTube for karaoke videos using youtube_explode_dart.
/// No API key required.
library;

import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class YoutubeSearchService {
  /// Returns up to [maxResults] YouTube video IDs matching
  /// "$artist $title karaoke", ordered by relevance.
  /// Returns an empty list on error or no results.
  static Future<List<String>> findVideoIds(
    String title,
    String artist, {
    int maxResults = 8,
  }) async {
    final yt = YoutubeExplode();
    try {
      // search() already filters to Video results only in v3.x
      final results = await yt.search
          .search('$artist $title karaoke')
          .timeout(const Duration(seconds: 12));

      return results.take(maxResults).map((v) => v.id.value).toList();
    } catch (_) {
      return [];
    } finally {
      yt.close();
    }
  }
}
