import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Singleton that manages the user's profile picture.
///
/// Call [initialize] once in main() before runApp.
/// Use [setImage] to save a new picture (pass the path from image_picker).
/// Use [removeImage] to reset back to the initials avatar.
class ProfilePictureService extends ChangeNotifier {
  // ── Singleton ──────────────────────────────────────────────────────────────
  static final ProfilePictureService _instance =
      ProfilePictureService._internal();
  ProfilePictureService._internal();
  factory ProfilePictureService() => _instance;

  // ── Storage ────────────────────────────────────────────────────────────────
  static const _prefKey = 'profile_picture_path_v1';
  static const _fileName = 'profile_picture.jpg';

  // ── State ──────────────────────────────────────────────────────────────────
  String? _imagePath;

  String? get imagePath => _imagePath;

  /// Returns the [File] for the saved picture, or null if none.
  File? get imageFile => _imagePath != null ? File(_imagePath!) : null;

  /// True when a picture is saved and the file actually exists on disk.
  bool get hasImage {
    if (_imagePath == null) return false;
    return File(_imagePath!).existsSync();
  }

  // ── Initialisation ─────────────────────────────────────────────────────────

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _imagePath = prefs.getString(_prefKey);
    // If the file was deleted externally, clear the stale path
    if (_imagePath != null && !File(_imagePath!).existsSync()) {
      _imagePath = null;
      await prefs.remove(_prefKey);
    }
    notifyListeners();
  }

  // ── Mutations ──────────────────────────────────────────────────────────────

  /// Copies [sourcePath] (from image_picker) into the app's documents dir
  /// so it persists across app restarts, then notifies listeners.
  Future<void> setImage(String sourcePath) async {
    final dir = await getApplicationDocumentsDirectory();
    final dest = File('${dir.path}/$_fileName');
    await File(sourcePath).copy(dest.path);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, dest.path);
    _imagePath = dest.path;
    notifyListeners();
  }

  /// Deletes the saved picture and resets to the initials avatar.
  Future<void> removeImage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
    if (_imagePath != null) {
      final f = File(_imagePath!);
      if (await f.exists()) await f.delete();
    }
    _imagePath = null;
    notifyListeners();
  }
}
