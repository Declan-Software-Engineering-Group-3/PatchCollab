import 'package:cloud_firestore/cloud_firestore.dart';

class Answer {
  final String answerId;
  final String questionId;
  final String userId;
  final String content;
  final int voteCount;
  final bool isAccepted;

  /// Set when the answer is pinned to a line of the question's diff.
  final String? anchorPath;
  final int? anchorLine;
  final bool anchorNewSide;
  final Timestamp createdAt;

  Answer({
    required this.answerId,
    required this.questionId,
    required this.userId,
    required this.content,
    required this.voteCount,
    required this.isAccepted,
    required this.createdAt,
    this.anchorPath,
    this.anchorLine,
    this.anchorNewSide = true,
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
      anchorPath: data['anchorPath'] as String?,
      anchorLine: (data['anchorLine'] as num?)?.toInt(),
      anchorNewSide: data['anchorNewSide'] as bool? ?? true,
    );
  }

  bool get isAnchored => anchorPath != null && anchorLine != null;
}
