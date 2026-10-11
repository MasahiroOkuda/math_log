import 'package:cloud_firestore/cloud_firestore.dart';

class UserLog {
  final String id;
  final String questionId;
  final String resultType;
  final List<String> mistakeReasons;
  final DateTime createdAt;

  UserLog({
    required this.id,
    required this.questionId,
    required this.resultType,
    required this.mistakeReasons,
    required this.createdAt,
  });

  factory UserLog.fromFirestore(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return UserLog(
      id: doc.id,
      questionId: data['questionId'] as String? ?? '',
      resultType: data['resultType'] as String? ?? '',
      mistakeReasons: List<String>.from(data['mistakeReasons'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
