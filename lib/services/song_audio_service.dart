/// Provides audio URLs for songs.
/// Audio files are stored in web/audio/ folder as MP3 files.
/// File naming: use the exact song title (e.g. "Dadalhin.mp3", "Buwan.mp3").
class SongAudioService {
  static const Map<String, String> _audioFiles = {
    'Dadalhin': 'Dadalhin.mp3',
    'Paalam Muna Sandali': 'Paalam Muna Sandali.mp3',
    'Nasa Iyo Na Ang Lahat': 'Nasa Iyo Na Ang Lahat.mp3',
    'Ulap': 'Ulap.mp3',
    'Fallen': 'Fallen.mp3',
  };

  /// Returns the URL path to the audio file for playback.
  /// Files are served from web/audio/ folder.
  static String? getAudioUrl(String songTitle) {
    final file = _audioFiles[songTitle];
    if (file == null) return null;
    return 'audio/$file';
  }

  static bool hasAudio(String songTitle) {
    return _audioFiles.containsKey(songTitle);
  }

  static List<String> get availableSongs => _audioFiles.keys.toList();
}
