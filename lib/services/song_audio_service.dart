/// Provides audio stream URLs for songs that have playback support.
/// In production, these would point to a licensed streaming service.
/// For demo, we use freely available preview clips.
class SongAudioService {
  static const Map<String, String> _audioUrls = {
    'Dadalhin':
        'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
    'Nasa Iyo Na Ang Lahat':
        'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
  };

  static String? getAudioUrl(String songTitle) {
    return _audioUrls[songTitle];
  }

  static bool hasAudio(String songTitle) {
    return _audioUrls.containsKey(songTitle);
  }

  static List<String> get availableSongs => _audioUrls.keys.toList();
}
