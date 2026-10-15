import 'admin_media_service.dart';

/// Where a song's backing track lives. [isAsset] distinguishes a path into
/// the read-only asset bundle from an absolute path to an admin upload on
/// disk; the two need different loaders everywhere they're used.
class AudioRef {
  final String path;
  final bool isAsset;
  const AudioRef({required this.path, required this.isAsset});
}

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
  /// (e.g. via AudioPlayer.setAsset), ignoring any admin upload.
  /// Prefer [resolve], which accounts for both sources.
  static String? getAudioUrl(String songTitle) {
    final file = _audioFiles[songTitle];
    if (file == null) return null;
    return 'assets/audio/$file';
  }

  /// Where this song's backing track actually comes from: an admin upload
  /// if one exists, otherwise the bundled asset, or null if neither does.
  ///
  /// Callers must branch on [AudioRef.isAsset] — a bundled track loads
  /// through the asset bundle and an uploaded one through the filesystem,
  /// and passing one path to the other's loader just fails at runtime.
  static AudioRef? resolve(String songTitle) {
    final uploaded = AdminMediaService.audioPathFor(songTitle);
    if (uploaded != null) return AudioRef(path: uploaded, isAsset: false);

    final bundled = getAudioUrl(songTitle);
    if (bundled != null) return AudioRef(path: bundled, isAsset: true);

    return null;
  }

  static bool hasAudio(String songTitle) {
    return _audioFiles.containsKey(songTitle) ||
        AdminMediaService.audioPathFor(songTitle) != null;
  }

  static List<String> get availableSongs => _audioFiles.keys.toList();
}
