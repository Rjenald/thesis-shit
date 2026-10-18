import 'admin_media_service.dart';
import 'song_audio_service.dart';

/// One song the app can actually offer.
class CatalogSong {
  final String title;
  final String artist;

  const CatalogSong({required this.title, required this.artist});

  /// The naming convention every asset for this song follows:
  /// `assets/audio/<Title - Artist>.mp3` and
  /// `assets/ground_truth/<Title - Artist>.json`.
  String get assetName => '$title - $artist';

  Map<String, String> toMap() => {
        'title': title,
        'artist': artist,
        'image': '',
        'hasAudio': 'true',
      };
}

/// The songs this app ships with.
///
/// Every entry here has a real bundled backing track and ground-truth
/// melody — the catalog previously listed hundreds of songs the app had no
/// audio for, so most of it led to a dead end. Listing only what exists
/// means a song in the catalog is always singable.
///
/// Adding a song is three steps: drop `<Title - Artist>.mp3` into
/// assets/audio/, drop `<Title - Artist>.json` into assets/ground_truth/,
/// and add a line here. pubspec bundles both folders wholesale, so there is
/// nothing else to register.
class SongCatalogService {
  static const List<CatalogSong> bundled = [
    CatalogSong(title: 'Araw-Araw', artist: 'Ben&Ben'),
    CatalogSong(title: 'Binibini', artist: 'Zack Tabudlo'),
    CatalogSong(title: 'Dadalhin', artist: 'Alcasid'),
    CatalogSong(title: 'Ere', artist: 'Juan Karlos'),
    CatalogSong(title: 'Fallen', artist: 'Lola Amour'),
    CatalogSong(title: 'Mula Sa Puso', artist: 'Regine Velasquez'),
    CatalogSong(title: 'Nasa Iyo Na Ang Lahat', artist: 'Daniel Padilla'),
    CatalogSong(title: 'Paalam Muna Sandali', artist: 'Darren'),
    CatalogSong(title: 'Tahanan', artist: 'Adie'),
    CatalogSong(title: 'Ulap', artist: 'Rob Daniel'),
  ];

  /// The bundled songs, ignoring anything an admin added.
  static List<Map<String, String>> get bundledSongs =>
      bundled.map((s) => s.toMap()).toList();

  /// Every song available to sing: the bundled ones plus anything an admin
  /// added at runtime, which can only live in [AdminMediaService]'s index
  /// because assets are read-only.
  static List<Map<String, String>> get allSongs => [
        ...bundledSongs,
        for (final s in AdminMediaService.customSongs)
          {
            'title': s.title,
            'artist': s.artist,
            'image': '',
            if (SongAudioService.hasAudio(s.title)) 'hasAudio': 'true',
          },
      ];

  /// Songs that can be played with a backing track. Every bundled song
  /// qualifies; an admin-added one only once its MP3 is uploaded.
  static List<Map<String, String>> get songsWithAudio => allSongs
      .where((s) =>
          s['hasAudio'] == 'true' ||
          SongAudioService.hasAudio(s['title'] ?? ''))
      .toList();

  static List<Map<String, String>> search(String query) {
    final q = query.toLowerCase();
    return allSongs
        .where((s) =>
            (s['title'] ?? '').toLowerCase().contains(q) ||
            (s['artist'] ?? '').toLowerCase().contains(q))
        .toList();
  }

  static bool containsTitle(String title) {
    final t = title.trim().toLowerCase();
    return bundled.any((s) => s.title.toLowerCase() == t);
  }

  /// The `Title - Artist` asset stem for a bundled song, or null if the
  /// app doesn't ship that song.
  static String? assetNameFor(String title) {
    final t = title.trim().toLowerCase();
    for (final s in bundled) {
      if (s.title.toLowerCase() == t) return s.assetName;
    }
    return null;
  }
}
