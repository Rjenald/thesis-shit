import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class RecordingEntry {
  final String id;
  final String title;
  final String filePath;
  final int durationSeconds;
  final DateTime createdAt;

  const RecordingEntry({
    required this.id,
    required this.title,
    required this.filePath,
    required this.durationSeconds,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'filePath': filePath,
    'durationSeconds': durationSeconds,
    'createdAt': createdAt.toIso8601String(),
  };

  factory RecordingEntry.fromJson(Map<String, dynamic> j) => RecordingEntry(
    id: j['id'] as String,
    title: j['title'] as String,
    filePath: j['filePath'] as String,
    durationSeconds: j['durationSeconds'] as int,
    createdAt: DateTime.parse(j['createdAt'] as String),
  );
}

class RecordingStorageService {
  static const _key = 'huni_voice_recordings_v1';

  static Future<void> saveRecording(RecordingEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await loadRecordings();
    list.insert(0, entry);
    await prefs.setStringList(
      _key,
      list.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  static Future<List<RecordingEntry>> loadRecordings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw
        .map((s) {
          try {
            return RecordingEntry.fromJson(
              jsonDecode(s) as Map<String, dynamic>,
            );
          } catch (_) {
            return null;
          }
        })
        .whereType<RecordingEntry>()
        .toList();
  }

  static Future<void> deleteRecording(RecordingEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await loadRecordings();
    list.removeWhere((e) => e.id == entry.id);
    await prefs.setStringList(
      _key,
      list.map((e) => jsonEncode(e.toJson())).toList(),
    );
    // Remove stored WAV data if it was saved locally
    if (entry.filePath.startsWith('local:')) {
      final id = entry.filePath.replaceFirst('local:', '');
      await prefs.remove('wav_$id');
    }
  }
}
