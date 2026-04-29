/// YouTube API Configuration
class YouTubeConfig {
  /// YouTube Data API v3 Key
  /// Get from: https://console.cloud.google.com/
  static const String apiKey = 'YOUR_YOUTUBE_API_KEY_HERE';

  /// Search parameters for karaoke
  static const int maxResults = 10;
  static const String regionCode = 'PH'; // Philippines
  static const String relevanceLanguage = 'tl'; // Tagalog

  /// Video type - karaoke videos
  static const List<String> videoCategories = ['10']; // Music category

  /// Safe search - moderate content
  static const String safeSearch = 'moderate';

  /// Video duration - prefer 2-5 minute songs
  static const String videoDuration = 'medium'; // 4-20 minutes

  /// Video definition - HD preferred
  static const String videoDefinition = 'any';

  /// Common karaoke keywords to append
  static const List<String> karaokeKeywords = [
    'karaoke',
    'official lyrics',
    'with lyrics',
    'karaoke version',
  ];

  /// Validate API key is set
  static bool isConfigured() {
    return apiKey != 'YOUR_YOUTUBE_API_KEY_HERE' && apiKey.isNotEmpty;
  }

  /// Get full search query
  static String buildSearchQuery(String songTitle, String artist) {
    return '$songTitle $artist karaoke';
  }
}
