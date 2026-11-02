import 'admin_media_service.dart';
import 'song_audio_service.dart';

/// One song the app can actually offer.
class CatalogSong {
  final String title;
  final String artist;

  /// Whisper language code for this song's lyrics.
  ///
  /// The language token conditions the entire decode, so telling Whisper a
  /// song is Tagalog when it is sung in English measurably hurts it. Most
  /// of this catalog is OPM, hence the default, but it is per-song because
  /// at least one entry is not.
  final String language;

  /// Cover art, overriding the bundled asset. Normally empty.
  ///
  /// The catalog used to carry remote URLs here and most were unknown, so
  /// songs showed a placeholder icon — and the ones that did have a URL
  /// showed nothing offline, in an app whose whole point is working
  /// offline. The art now ships with the song; see [imagePath].
  final String image;

  const CatalogSong({
    required this.title,
    required this.artist,
    this.image = '',
    this.language = 'tl',
  });

  /// The naming convention every asset for this song follows:
  /// `assets/audio/<Title - Artist>.mp3` and
  /// `assets/ground_truth/<Title - Artist>.json`.
  String get assetName => '$title - $artist';

  /// Where this song's cover art lives: `assets/covers/<Title - Artist>.jpg`,
  /// unless [image] overrides it.
  String get imagePath =>
      image.isNotEmpty ? image : 'assets/covers/$assetName.jpg';

  Map<String, String> toMap() => {
        'title': title,
        'artist': artist,
        'image': imagePath,
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
  /// Exactly the ten tracks in assets/audio/, in filename order.
  ///
  /// This list and that folder have to agree: a song listed here with no
  /// `<Title> - <Artist>.mp3` beside it is offered in the app and then
  /// dead-ends. `backend/check_ground_truth.py` reports any drift, and
  /// test/all_songs_ground_truth_test.dart fails on it.
  static const List<CatalogSong> bundled = [
    // No `image` on any of these. Cover art now ships with the song as
    // `assets/covers/<Title - Artist>.jpg` (see CatalogSong.imagePath),
    // so there is no URL to go stale and nothing to fetch — which is
    // what this app being offline-first requires. The remote URLs that
    // used to sit here worked only while online, and only three of the
    // ten had one at all.
    CatalogSong(title: 'Araw-Araw', artist: 'Ben&Ben'),
    CatalogSong(title: 'Buwan', artist: 'Juan Karlos'),
    // Regine Velasquez's recording, not Ogie Alcasid's — the earlier
    // catalog credited Alcasid against a different backing track, and the
    // bundled lyric timings belong to that older recording.
    CatalogSong(title: 'Dadalhin', artist: 'Regine Velasquez'),
    // Sung entirely in English; its bundled lyrics contain no Tagalog.
    CatalogSong(title: 'Fallen', artist: 'Lola Amour', language: 'en'),
    CatalogSong(title: 'Ikaw Lang', artist: 'NOBITA'),
    CatalogSong(title: 'Kumpas', artist: 'Moira Dela Torre'),
    CatalogSong(title: 'Mundo', artist: 'IV Of Spades'),
    CatalogSong(title: 'Nasa Iyo Na Ang Lahat', artist: 'Daniel Padilla'),
    CatalogSong(title: 'Pano', artist: 'Zack Tabudlo'),
    CatalogSong(title: 'Randomantic', artist: 'James Reid'),
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

  /// The Whisper language code for a bundled song, defaulting to Tagalog
  /// for anything not in the catalog (an admin-added song, say).
  static String languageFor(String title) {
    final t = title.trim().toLowerCase();
    for (final s in bundled) {
      if (s.title.toLowerCase() == t) return s.language;
    }
    return 'tl';
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
