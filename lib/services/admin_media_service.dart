import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Admin-managed song media: backing-track MP3s and ground-truth melodies
/// uploaded from the device, plus any songs the admin added beyond the ones
/// shipped with the app.
///
/// Everything the app ships with lives in `assets/`, which is baked into the
/// APK and read-only at runtime — nothing can ever be uploaded *into* it. So
/// admin uploads are copied into the app's documents directory and recorded
/// in an index here, and the services that resolve a song's audio or ground
/// truth check this store first and fall back to the bundled asset. That
/// makes an upload an override rather than a replacement: deleting it
/// restores the shipped file instead of leaving the song broken.
///
/// The index is cached in memory by [init] (called once at startup) because
/// the callers that resolve audio are synchronous UI code; only the mutating
/// methods touch disk.
class AdminMediaService {
  AdminMediaService._();

  static const _indexKey = 'huni_admin_media_index_v1';
  static const _audioDirName = 'huni_admin/audio';
  static const _groundTruthDirName = 'huni_admin/ground_truth';

  /// title (lowercased) -> stored media paths.
  static Map<String, _SongMedia> _media = {};

  /// Songs the admin added that aren't in the bundled catalog.
  static List<AdminSong> _customSongs = [];

  static bool _initialized = false;

  /// Loads the index into memory. Safe to call more than once.
  static Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_indexKey);
      if (raw != null) _decode(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      // A corrupt index must not stop the app from starting — the bundled
      // songs still work, and the admin can re-upload.
      debugPrint('Admin media index failed to load: $e');
    }
    _initialized = true;
  }

  static void _decode(Map<String, dynamic> json) {
    final media = <String, _SongMedia>{};
    final rawMedia = json['media'] as Map<String, dynamic>? ?? {};
    rawMedia.forEach((key, value) {
      media[key] = _SongMedia.fromJson(value as Map<String, dynamic>);
    });

    _media = media;
    _customSongs = (json['customSongs'] as List<dynamic>? ?? [])
        .map((e) => AdminSong.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _indexKey,
      jsonEncode({
        'media': _media.map((k, v) => MapEntry(k, v.toJson())),
        'customSongs': _customSongs.map((s) => s.toJson()).toList(),
      }),
    );
  }

  static String _key(String title) => title.trim().toLowerCase();

  // ── Lookups (synchronous — see class doc) ─────────────────────────────────

  /// Absolute path to an admin-uploaded MP3 for [title], or null to fall
  /// back to whatever the app bundles.
  static String? audioPathFor(String title) => _media[_key(title)]?.audioPath;

  /// Absolute path to an admin-uploaded ground-truth JSON for [title], or
  /// null to fall back to the bundled one.
  static String? groundTruthPathFor(String title) =>
      _media[_key(title)]?.groundTruthPath;

  static List<AdminSong> get customSongs => List.unmodifiable(_customSongs);

  static bool isCustomSong(String title) =>
      _customSongs.any((s) => _key(s.title) == _key(title));

  // ── Uploads ───────────────────────────────────────────────────────────────

  /// Copies [source] into app storage as the backing track for [title].
  /// The file is copied rather than referenced in place because the picker
  /// hands back a path in a cache directory the OS is free to clear.
  static Future<void> saveAudio(String title, File source) async {
    final path = await _copyInto(_audioDirName, title, source, 'mp3');
    _media[_key(title)] = (_media[_key(title)] ?? const _SongMedia())
        .copyWith(audioPath: path);
    await _persist();
  }

  /// Copies [source] in as the ground truth for [title]. Throws
  /// [FormatException] if it isn't a usable ground-truth file — storing an
  /// unreadable one would silently break karaoke scoring for that song
  /// instead of failing here where the admin can see it.
  static Future<void> saveGroundTruth(String title, File source) async {
    final text = await source.readAsString();
    validateGroundTruthJson(text);
    final path = await _copyInto(_groundTruthDirName, title, source, 'json');
    _media[_key(title)] = (_media[_key(title)] ?? const _SongMedia())
        .copyWith(groundTruthPath: path);
    await _persist();
  }

  /// Throws [FormatException] unless [text] parses as a ground-truth file
  /// with at least one usable syllable. Mirrors what GroundTruthService
  /// actually reads, so anything accepted here will load there.
  static void validateGroundTruthJson(String text) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(text);
    } catch (_) {
      throw const FormatException('Not a valid JSON file.');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected a JSON object at the top level.');
    }
    // The extraction notebook writes two JSON files per song and the file
    // picker offers both, because both end in .json. Naming the mistake
    // beats "expected a data list": the word-timing file is a perfectly
    // valid file, just not this one.
    if (decoded.containsKey('words') && !decoded.containsKey('data')) {
      throw const FormatException(
          'That is the word-timing file (<song>.words.json). The app does '
          'not use it — it feeds the lyric-timing script at build time. '
          'Pick the notes file, <song>.json, instead.');
    }

    final data = decoded['data'];
    if (data is! List || data.isEmpty) {
      throw const FormatException(
          'Expected a non-empty "data" list of syllables.');
    }
    final usable = data.whereType<Map<String, dynamic>>().where((m) {
      final start = m['start'];
      final end = m['end'];
      return m['note'] is String &&
          start is num &&
          end is num &&
          end > start;
    });
    if (usable.isEmpty) {
      throw const FormatException(
          'No usable entries — each needs "note", "start" and "end" '
          '(with end after start).');
    }
  }

  static Future<String> _copyInto(
    String dirName,
    String title,
    File source,
    String extension,
  ) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/$dirName');
    await dir.create(recursive: true);

    // Fresh filename per upload, with the old one removed afterwards, so a
    // re-upload can't be served from a stale cached copy of the same path.
    final safe = _key(title).replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    final dest = File('${dir.path}/${safe}_'
        '${DateTime.now().millisecondsSinceEpoch}.$extension');
    await source.copy(dest.path);
    return dest.path;
  }

  // ── Deletions ─────────────────────────────────────────────────────────────

  /// Removes the uploaded MP3 for [title]; the bundled track (if any) takes
  /// over again.
  static Future<void> deleteAudio(String title) async {
    final entry = _media[_key(title)];
    if (entry?.audioPath == null) return;
    await _deleteFile(entry!.audioPath!);
    _media[_key(title)] = entry.copyWith(audioPath: null, clearAudio: true);
    _pruneEmpty(_key(title));
    await _persist();
  }

  static Future<void> deleteGroundTruth(String title) async {
    final entry = _media[_key(title)];
    if (entry?.groundTruthPath == null) return;
    await _deleteFile(entry!.groundTruthPath!);
    _media[_key(title)] =
        entry.copyWith(groundTruthPath: null, clearGroundTruth: true);
    _pruneEmpty(_key(title));
    await _persist();
  }

  static void _pruneEmpty(String key) {
    final entry = _media[key];
    if (entry != null && entry.audioPath == null && entry.groundTruthPath == null) {
      _media.remove(key);
    }
  }

  static Future<void> _deleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (e) {
      // The index entry is dropped either way; a leftover file on disk is
      // harmless next to losing track of it.
      debugPrint('Could not delete $path: $e');
    }
  }

  // ── Custom songs ──────────────────────────────────────────────────────────

  /// Adds a song that isn't in the bundled catalog. Throws [StateError] if
  /// that title already exists, bundled or custom — two songs with one title
  /// would be indistinguishable everywhere else in the app, which keys on it.
  static Future<void> addCustomSong({
    required String title,
    required String artist,
    required bool titleAlreadyInCatalog,
  }) async {
    final clean = title.trim();
    if (clean.isEmpty) throw StateError('Title cannot be empty.');
    if (titleAlreadyInCatalog || isCustomSong(clean)) {
      throw StateError('A song called "$clean" already exists.');
    }
    _customSongs = [..._customSongs, AdminSong(title: clean, artist: artist.trim())];
    await _persist();
  }

  /// Removes a custom song and both of its uploaded files. Bundled songs
  /// can't be removed this way — only their uploaded overrides can.
  static Future<void> deleteCustomSong(String title) async {
    await deleteAudio(title);
    await deleteGroundTruth(title);
    _customSongs =
        _customSongs.where((s) => _key(s.title) != _key(title)).toList();
    await _persist();
  }

  /// Test seam — resets in-memory state so each test starts clean.
  @visibleForTesting
  static void resetForTest() {
    _media = {};
    _customSongs = [];
    _initialized = false;
  }
}

/// A song the admin added, beyond the bundled catalog.
class AdminSong {
  final String title;
  final String artist;

  const AdminSong({required this.title, required this.artist});

  Map<String, dynamic> toJson() => {'title': title, 'artist': artist};

  factory AdminSong.fromJson(Map<String, dynamic> j) => AdminSong(
        title: j['title'] as String? ?? '',
        artist: j['artist'] as String? ?? '',
      );
}

class _SongMedia {
  final String? audioPath;
  final String? groundTruthPath;

  const _SongMedia({this.audioPath, this.groundTruthPath});

  _SongMedia copyWith({
    String? audioPath,
    String? groundTruthPath,
    bool clearAudio = false,
    bool clearGroundTruth = false,
  }) {
    return _SongMedia(
      audioPath: clearAudio ? null : (audioPath ?? this.audioPath),
      groundTruthPath:
          clearGroundTruth ? null : (groundTruthPath ?? this.groundTruthPath),
    );
  }

  Map<String, dynamic> toJson() => {
        'audioPath': audioPath,
        'groundTruthPath': groundTruthPath,
      };

  factory _SongMedia.fromJson(Map<String, dynamic> j) => _SongMedia(
        audioPath: j['audioPath'] as String?,
        groundTruthPath: j['groundTruthPath'] as String?,
      );
}
