import 'package:flutter/foundation.dart';

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
}

/// Shared state that bridges the Teacher and Student accounts.
///
/// Flow:
///   Teacher  → sendInvite()     → adds to [pendingInvites]
///   Student  → acceptInvite()   → moves className to [enrolledClasses]
///   Student  → declineInvite()  → removes from [pendingInvites]
class EnrollmentService extends ChangeNotifier {
  final List<EnrollmentInvite> _pending = [];
  final List<String> _enrolledClasses = [];

  /// All invitations waiting for the student's response.
  List<EnrollmentInvite> get pendingInvites => List.unmodifiable(_pending);

  /// Classes the student has accepted enrollment into.
  List<String> get enrolledClasses => List.unmodifiable(_enrolledClasses);

  /// True once the student has accepted at least one invitation.
  bool get isEnrolled => _enrolledClasses.isNotEmpty;

  /// The first class the student enrolled in (shown in the classroom banner).
  String? get primaryClass =>
      _enrolledClasses.isEmpty ? null : _enrolledClasses.first;

  // ── Teacher API ─────────────────────────────────────────────────────────────

  /// Teacher calls this to send an enrollment invitation.
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
  }

  // ── Student API ─────────────────────────────────────────────────────────────

  /// Student accepts an invitation — moves the class into [enrolledClasses].
  void acceptInvite(String id) {
    final idx = _pending.indexWhere((i) => i.id == id);
    if (idx == -1) return;
    final invite = _pending.removeAt(idx);
    if (!_enrolledClasses.contains(invite.className)) {
      _enrolledClasses.add(invite.className);
    }
    notifyListeners();
  }

  /// Student declines an invitation — removes it with no enrollment.
  void declineInvite(String id) {
    _pending.removeWhere((i) => i.id == id);
    notifyListeners();
  }
}
