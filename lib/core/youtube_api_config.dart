/// YouTube Data API v3 key for karaoke video search.
///
/// How to get one (free):
///   1. Go to https://console.cloud.google.com
///   2. Create a project → Enable "YouTube Data API v3"
///   3. Credentials → Create API Key → paste it below
///
/// Free quota: 10,000 units/day  (~100 searches/day at 100 units each)
library;

class YouTubeApiConfig {
  /// Paste your YouTube Data API v3 key here.
  static const String apiKey = 'YOUR_YOUTUBE_API_KEY_HERE';

  /// Returns true when a real key has been set.
  static bool get hasKey =>
      apiKey.isNotEmpty && !apiKey.startsWith('YOUR_');

  /// YouTube Data API v3 search endpoint.
  static const String searchUrl =
      'https://www.googleapis.com/youtube/v3/search';
}
