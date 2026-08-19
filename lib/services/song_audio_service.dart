/// Provides bundled asset paths for song audio.
/// Audio files are stored in assets/audio/ and registered in pubspec.yaml
/// so they play natively on Android/iOS without needing a web server.
/// File naming: use the exact song title (e.g. "Dadalhin.mp3", "Buwan.mp3").
class SongAudioService {
  static const Map<String, String> _audioFiles = {
    'Dadalhin': 'Dadalhin.mp3',
    'Paalam Muna Sandali': 'Paalam Muna Sandali.mp3',
    'Nasa Iyo Na Ang Lahat': 'Nasa Iyo Na Ang Lahat.mp3',
    'Ulap': 'Ulap.mp3',
    'Fallen': 'Fallen.mp3',
    'Mula Sa Puso': 'Mula Sa Puso.mp3',
    'Pangarap Ko Ang Iyo': 'Pangarap Ko Ang Iyo.mp3',
  };

  /// Returns the bundled asset path to the audio file for playback
  /// (e.g. via AudioPlayer.setAsset).
  static String? getAudioUrl(String songTitle) {
    final file = _audioFiles[songTitle];
    if (file == null) return null;
    return 'assets/audio/$file';
  }

  static bool hasAudio(String songTitle) {
    return _audioFiles.containsKey(songTitle);
  }

  static List<String> get availableSongs => _audioFiles.keys.toList();
}
