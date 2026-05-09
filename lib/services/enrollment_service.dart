import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'session_storage_service.dart';

// ── Model ──────────────────────────────────────────────────────────────────────

/// A single enrollment invitation sent by a teacher to a student.
class EnrollmentInvite {
  final String id;
  final String teacherName;
  final String className;
  final String studentName;
  final DateTime sentAt;

  const EnrollmentInvite({
    required this.id,
    required this.teacherName,
    required this.className,
    required this.studentName,
    required this.sentAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'teacherName': teacherName,
        'className': className,
        'studentName': studentName,
        'sentAt': sentAt.toIso8601String(),
      };

  factory EnrollmentInvite.fromJson(Map<String, dynamic> j) => EnrollmentInvite(
        id: j['id'] as String,
        teacherName: j['teacherName'] as String,
        className: j['className'] as String,
        studentName: j['studentName'] as String,
        sentAt: DateTime.parse(j['sentAt'] as String),
      );
}

// ── Service ────────────────────────────────────────────────────────────────────

/// Shared state that bridges the Teacher and Student accounts.
///
/// Uses a singleton + SharedPreferences so enrollment state survives app
/// restarts and hot-reloads.
///
/// Flow:
///   Teacher  → sendInvite()   → persists invite to [_pendingKey]
///   Student  → acceptInvite() → removes invite, adds class to enrolled list,
///                               writes student name into teacher's class data
///   Student  → declineInvite() → removes invite from storage
class EnrollmentService extends ChangeNotifier {
  // ── Singleton ──────────────────────────────────────────────────────────────
  static final EnrollmentService _instance = EnrollmentService._internal();
  EnrollmentService._internal();
  factory EnrollmentService() => _instance;

  // ── Storage keys ──────────────────────────────────────────────────────────
  static const _pendingKey  = 'enrollment_pending_v1';
  static const _enrolledKey = 'enrollment_enrolled_v1';

  // ── State ──────────────────────────────────────────────────────────────────
  final List<EnrollmentInvite> _pending        = [];
  final List<String>           _enrolledClasses = [];

  // ── Public getters ─────────────────────────────────────────────────────────
  List<EnrollmentInvite> get pendingInvites  => List.unmodifiable(_pending);
  List<String>           get enrolledClasses => List.unmodifiable(_enrolledClasses);
  bool                   get isEnrolled      => _enrolledClasses.isNotEmpty;
  String?                get primaryClass    =>
      _enrolledClasses.isEmpty ? null : _enrolledClasses.first;

  // ── Initialization (call once in main()) ──────────────────────────────────

  /// Loads persisted invites and enrolled classes from SharedPreferences.
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();

    // ── Pending invites ──────────────────────────────────────────────────────
    final pendingRaw = prefs.getString(_pendingKey);
    if (pendingRaw != null) {
      try {
        final list = jsonDecode(pendingRaw) as List<dynamic>;
        _pending
          ..clear()
          ..addAll(list.map(
              (e) => EnrollmentInvite.fromJson(e as Map<String, dynamic>)));
      } catch (e) {
        if (kDebugMode) print('EnrollmentService: error loading pending: $e');
      }
    }

    // ── Enrolled classes ─────────────────────────────────────────────────────
    final enrolledRaw = prefs.getString(_enrolledKey);
    if (enrolledRaw != null) {
      try {
        final list = jsonDecode(enrolledRaw) as List<dynamic>;
        _enrolledClasses
          ..clear()
          ..addAll(list.cast<String>());
      } catch (e) {
        if (kDebugMode) print('EnrollmentService: error loading enrolled: $e');
      }
    }

    notifyListeners();
  }

  // ── Persistence helper ─────────────────────────────────────────────────────

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _pendingKey,
      jsonEncode(_pending.map((e) => e.toJson()).toList()),
    );
    await prefs.setString(
      _enrolledKey,
      jsonEncode(_enrolledClasses),
    );
  }

  // ── Teacher API ────────────────────────────────────────────────────────────

  /// Teacher sends an enrollment invitation — saved to SharedPreferences
  /// immediately so it survives restarts before the student responds.
  void sendInvite({
    required String teacherName,
    required String className,
    required String studentName,
  }) {
    _pending.add(EnrollmentInvite(
      id: '${DateTime.now().millisecondsSinceEpoch}',
      teacherName: teacherName,
      className: className,
      studentName: studentName,
      sentAt: DateTime.now(),
    ));
    notifyListeners();
    _save(); // fire-and-forget — persists in background
  }

  // ── Student API ────────────────────────────────────────────────────────────

  /// Student accepts — UI updates immediately (notifyListeners before awaits),
  /// then persists both the enrollment state and the student entry in the
  /// teacher's class list.
  Future<void> acceptInvite(String id) async {
    final idx = _pending.indexWhere((i) => i.id == id);
    if (idx == -1) return;
    final invite = _pending.removeAt(idx);
    if (!_enrolledClasses.contains(invite.className)) {
      _enrolledClasses.add(invite.className);
    }
    // Notify immediately so the invite card disappears without waiting for I/O.
    notifyListeners();
    // Persist both in parallel.
    await Future.wait([
      _save(),
      _persistStudentToClass(invite.className, invite.studentName),
    ]);
  }

  /// Student declines — removes invite from storage, no enrollment added.
  void declineInvite(String id) {
    _pending.removeWhere((i) => i.id == id);
    notifyListeners();
    _save(); // fire-and-forget
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  /// Finds the teacher's class by name and appends [studentName] to its
  /// `students` list in SharedPreferences.
  Future<void> _persistStudentToClass(
      String className, String studentName) async {
    final classes = await SessionStorageService.loadClasses();
    final idx = classes.indexWhere(
      (c) =>
          (c['name'] as String? ?? '').toLowerCase() ==
          className.toLowerCase(),
    );
    if (idx == -1) return; // class not found — edge case
    final students =
        List<String>.from(classes[idx]['students'] as List? ?? []);
    if (!students.contains(studentName)) {
      students.add(studentName);
      classes[idx] = {...classes[idx], 'students': students};
      await SessionStorageService.saveClasses(classes);
    }
  }
}
