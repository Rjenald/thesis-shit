import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StudentSubmission {
  final String id;
  final String studentName;
  final String className;
  final String activityName;
  final String activityType;
  final double score;
  final DateTime submittedAt;
  final String? recordingId;

  const StudentSubmission({
    required this.id,
    required this.studentName,
    required this.className,
    required this.activityName,
    required this.activityType,
    required this.score,
    required this.submittedAt,
    this.recordingId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'studentName': studentName,
    'className': className,
    'activityName': activityName,
    'activityType': activityType,
    'score': score,
    'submittedAt': submittedAt.toIso8601String(),
    'recordingId': recordingId,
  };

  factory StudentSubmission.fromJson(Map<String, dynamic> j) =>
      StudentSubmission(
        id: j['id'] as String,
        studentName: j['studentName'] as String,
        className: j['className'] as String? ?? '',
        activityName: j['activityName'] as String,
        activityType: j['activityType'] as String? ?? 'Practice',
        score: (j['score'] as num).toDouble(),
        submittedAt: DateTime.parse(j['submittedAt'] as String),
        recordingId: j['recordingId'] as String?,
      );
}

class SubmissionService extends ChangeNotifier {
  static final SubmissionService _instance = SubmissionService._internal();
  SubmissionService._internal();
  factory SubmissionService() => _instance;

  static const _key = 'huni_submissions_v2';
  List<StudentSubmission> _submissions = [];

  List<StudentSubmission> get submissions => List.unmodifiable(_submissions);

  List<StudentSubmission> forClass(String className) =>
      _submissions.where((s) => s.className == className).toList();

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        _submissions = list
            .map((e) => StudentSubmission.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        if (kDebugMode) print('SubmissionService load error: $e');
      }
    }
    notifyListeners();
  }

  Future<void> addSubmission(StudentSubmission sub) async {
    _submissions.insert(0, sub);
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final json = _submissions.map((s) => s.toJson()).toList();
    await prefs.setString(_key, jsonEncode(json));
  }
}
