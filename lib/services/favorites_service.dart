import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesService {
  static const _key = 'huni_favorites';

  static Future<List<Map<String, String>>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final List decoded = json.decode(raw);
    return decoded.map((e) => Map<String, String>.from(e)).toList();
  }

  static Future<void> _save(List<Map<String, String>> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, json.encode(list));
  }

  static Future<bool> isFavorite(String title) async {
    final list = await getFavorites();
    return list.any((s) => s['title'] == title);
  }

  static Future<void> addFavorite(Map<String, String> song) async {
    final list = await getFavorites();
    if (list.any((s) => s['title'] == song['title'])) return;
    final entry = Map<String, String>.from(song);
    entry['date'] = _today();
    list.insert(0, entry);
    await _save(list);
  }

  static Future<void> removeFavorite(String title) async {
    final list = await getFavorites();
    list.removeWhere((s) => s['title'] == title);
    await _save(list);
  }

  static Future<void> toggleFavorite(Map<String, String> song) async {
    if (await isFavorite(song['title']!)) {
      await removeFavorite(song['title']!);
    } else {
      await addFavorite(song);
    }
  }

  static String _today() {
    final now = DateTime.now();
    return '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}-'
        '${now.year.toString().substring(2)}';
  }
}
