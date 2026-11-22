import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/freestyle_summary.dart';

class FreestyleStorageService {
  static const _key = 'huni_freesing_v1';

  static Future<void> saveSummary(FreestyleSummary summary) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await loadSummaries();
    list.insert(0, summary);
    await prefs.setStringList(
      _key,
      list.map((s) => jsonEncode(s.toJson())).toList(),
    );
  }

  static Future<List<FreestyleSummary>> loadSummaries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw
        .map((s) {
          try {
            return FreestyleSummary.fromJson(
              jsonDecode(s) as Map<String, dynamic>,
            );
          } catch (_) {
            return null;
          }
        })
        .whereType<FreestyleSummary>()
        .toList();
  }

  static Future<void> deleteSummary(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await loadSummaries();
    list.removeWhere((s) => s.id == id);
    await prefs.setStringList(
      _key,
      list.map((s) => jsonEncode(s.toJson())).toList(),
    );
  }
}
