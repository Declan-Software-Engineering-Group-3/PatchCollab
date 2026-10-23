import 'package:cloud_firestore/cloud_firestore.dart';

class Answer {
  final String answerId;
  final String questionId;
  final String userId;
  final String content;
  final int voteCount;
  final bool isAccepted;
  final Timestamp createdAt;

  Answer({
    required this.answerId,
    required this.questionId,
    required this.userId,
    required this.content,
    required this.voteCount,
    required this.isAccepted,
    required this.createdAt,
  });

  factory Answer.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Answer(
      answerId: doc.id,
      questionId: data['questionId'] as String,
      userId: data['userId'] as String,
      content: data['content'] as String,
      voteCount: (data['voteCount'] as num?)?.toInt() ?? 0,
      isAccepted: data['isAccepted'] as bool? ?? false,
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }
}
