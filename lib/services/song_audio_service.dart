import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'admin_media_service.dart';
import 'song_catalog_service.dart';

/// Where a song's backing track lives. [isAsset] distinguishes a path into
/// the read-only asset bundle from an absolute path to an admin upload on
/// disk; the two need different loaders everywhere they're used.
class AudioRef {
  final String path;
  final bool isAsset;
  const AudioRef({required this.path, required this.isAsset});
}

/// Resolves a song title to its backing track.
///
/// Bundled tracks follow one convention — `assets/audio/<Title - Artist>.mp3`
/// — so the catalog is the only list of songs, rather than a second
/// title-to-filename table that could drift out of step with it.
class SongAudioService {
  /// The bundled asset path for [songTitle], or null if the app doesn't
  /// ship that song. Ignores admin uploads; prefer [resolve].
  static String? getAudioUrl(String songTitle) {
    final name = SongCatalogService.assetNameFor(songTitle);
    return name == null ? null : 'assets/audio/$name.mp3';
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

  /// Whether the bundled MP3 is actually there.
  ///
  /// [getAudioUrl] only builds a path from the catalog entry, so it says
  /// nothing about whether the file was ever added. The admin screen
  /// showed "Built-in" on that basis and so could never report a missing
  /// backing track for a catalogued song — the one thing that screen
  /// exists to tell you.
  ///
  /// Asked of the asset manifest, not by loading the file: these MP3s are
  /// 6-11MB each and the admin screen checks all ten, so loading them to
  /// answer a yes/no question would pull ~80MB into memory for nothing.
  static Future<bool> bundledAudioExists(String songTitle) async {
    final path = getAudioUrl(songTitle);
    if (path == null) return false;
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      return manifest.listAssets().contains(path);
    } catch (_) {
      return false;
    }
  }

  static bool hasAudio(String songTitle) =>
      SongCatalogService.assetNameFor(songTitle) != null ||
      AdminMediaService.audioPathFor(songTitle) != null;

  static List<String> get availableSongs =>
      SongCatalogService.bundled.map((s) => s.title).toList();
}
