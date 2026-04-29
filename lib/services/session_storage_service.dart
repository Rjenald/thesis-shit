/// Persists SessionResult objects and user profile data locally using
/// SharedPreferences. Supports up to 500 stored sessions (FIFO eviction).
/// Deleted sessions are soft-deleted into a trash bin for 30 days.
library;

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/session_result.dart';

class TrashEntry {
  final SessionResult session;
  final DateTime deletedAt;

  const TrashEntry({required this.session, required this.deletedAt});

  /// Days remaining before auto-purge (30-day window).
  int get daysRemaining {
    final expiry = deletedAt.add(const Duration(days: 30));
    return expiry.difference(DateTime.now()).inDays.clamp(0, 30);
  }

  bool get isExpired => daysRemaining == 0;

  Map<String, dynamic> toJson() => {
        ...session.toJson(),
        'deletedAt': deletedAt.toIso8601String(),
      };

  factory TrashEntry.fromJson(Map<String, dynamic> j) => TrashEntry(
        session: SessionResult.fromJson(j),
        deletedAt:
            DateTime.tryParse(j['deletedAt'] as String? ?? '') ?? DateTime.now(),
      );
}

class SessionStorageService {
  static const _sessionsKey = 'huni_sessions_v1';
  static const _trashKey = 'huni_trash_v1';
  static const _usernameKey = 'huni_username';
  static const _classesKey = 'huni_classes_v1';
  static const _maxSessions = 500;

  // ── Session persistence ────────────────────────────────────────────────────

  static Future<void> saveSession(SessionResult session) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await loadSessions();
    existing.insert(0, session); // newest first
    final capped = existing.take(_maxSessions).toList();
    await prefs.setStringList(
      _sessionsKey,
      capped.map((s) => jsonEncode(s.toJson())).toList(),
    );
  }

  static Future<List<SessionResult>> loadSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_sessionsKey) ?? [];
    return list
        .map((raw) {
          try {
            return SessionResult.fromJson(
                jsonDecode(raw) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<SessionResult>()
        .toList();
  }

  /// Soft-delete: moves session at [index] into the trash bin.
  static Future<void> deleteSession(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final sessions = await loadSessions();
    if (index < 0 || index >= sessions.length) return;

    final removed = sessions[index];
    sessions.removeAt(index);
    await prefs.setStringList(
      _sessionsKey,
      sessions.map((s) => jsonEncode(s.toJson())).toList(),
    );

    // Add to trash
    final trash = await loadTrash();
    trash.insert(0, TrashEntry(session: removed, deletedAt: DateTime.now()));
    await _saveTrash(prefs, trash);
  }

  // ── Trash bin ─────────────────────────────────────────────────────────────

  static Future<List<TrashEntry>> loadTrash() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_trashKey) ?? [];
    final entries = list
        .map((raw) {
          try {
            return TrashEntry.fromJson(jsonDecode(raw) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<TrashEntry>()
        .toList();

    // Auto-purge expired items
    final valid = entries.where((e) => !e.isExpired).toList();
    if (valid.length != entries.length) {
      await _saveTrash(prefs, valid);
    }
    return valid;
  }

  static Future<void> _saveTrash(
      SharedPreferences prefs, List<TrashEntry> trash) async {
    await prefs.setStringList(
      _trashKey,
      trash.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  /// Restore a trashed session back to the library.
  static Future<void> restoreFromTrash(int trashIndex) async {
    final prefs = await SharedPreferences.getInstance();
    final trash = await loadTrash();
    if (trashIndex < 0 || trashIndex >= trash.length) return;

    final entry = trash[trashIndex];
    trash.removeAt(trashIndex);
    await _saveTrash(prefs, trash);

    // Re-save the session into main library
    await saveSession(entry.session);
  }

  /// Permanently delete one item from trash.
  static Future<void> permanentlyDeleteFromTrash(int trashIndex) async {
    final prefs = await SharedPreferences.getInstance();
    final trash = await loadTrash();
    if (trashIndex < 0 || trashIndex >= trash.length) return;
    trash.removeAt(trashIndex);
    await _saveTrash(prefs, trash);
  }

  /// Empty entire trash bin.
  static Future<void> emptyTrash() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_trashKey);
  }

  // ── User profile ──────────────────────────────────────────────────────────

  static const _roleKey = 'huni_role';

  static Future<void> saveUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usernameKey, username);
  }

  static Future<String?> loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_usernameKey);
  }

  /// Saves account role: 'student' or 'teacher'.
  static Future<void> saveRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roleKey, role);
  }

  static Future<String> loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_roleKey) ?? 'student';
  }

  static Future<bool> isTeacher() async {
    return (await loadRole()) == 'teacher';
  }

  // ── Teacher class storage ─────────────────────────────────────────────────
  // Each class = { name, students: [String], assignedSongs: [String] }

  static Future<List<Map<String, dynamic>>> loadClasses() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_classesKey) ?? [];
    return list
        .map((raw) {
          try {
            return jsonDecode(raw) as Map<String, dynamic>;
          } catch (_) {
            return null;
          }
        })
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  static Future<void> saveClasses(List<Map<String, dynamic>> classes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _classesKey,
      classes.map((c) => jsonEncode(c)).toList(),
    );
  }

  static Future<void> addClass(Map<String, dynamic> cls) async {
    final classes = await loadClasses();
    classes.add(cls);
    await saveClasses(classes);
  }

  static Future<void> updateClass(
      int index, Map<String, dynamic> cls) async {
    final classes = await loadClasses();
    if (index >= 0 && index < classes.length) {
      classes[index] = cls;
      await saveClasses(classes);
    }
  }

  static Future<void> deleteClass(int index) async {
    final classes = await loadClasses();
    if (index >= 0 && index < classes.length) {
      classes.removeAt(index);
      await saveClasses(classes);
    }
  }

  // ── Generic storage ───────────────────────────────────────────────────────

  static Future<void> saveToStorage(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  static Future<String?> loadFromStorage(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  static Future<void> removeFromStorage(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  /// Clear all student account data
  static Future<void> clearStudentAccount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionsKey);
    await prefs.remove(_trashKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_roleKey);
    await prefs.remove(_classesKey);
    await prefs.clear(); // Clear everything for safety
  }
}
