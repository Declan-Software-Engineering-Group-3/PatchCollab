import 'package:cloud_firestore/cloud_firestore.dart';

import '../../github/data/diff_source.dart';
import '../../github/data/github_repo_model.dart';

class Question {
  final String questionId;
  final String userId;
  final String title;
  final String content;
  final String? codeSnippet;
  final String? language;
  final String category;
  final String type; // "question" or "reviewRequest"
  final String? githubUrl;
  final GithubRepo? linkedRepo;
  final DiffSource? diffSource;
  final int voteCount;
  final String? acceptedAnswerId;
  final Timestamp createdAt;

  Question({
    required this.questionId,
    required this.userId,
    required this.title,
    required this.content,
    required this.category,
    required this.type,
    required this.voteCount,
    required this.createdAt,
    this.codeSnippet,
    this.language,
    this.githubUrl,
    this.linkedRepo,
    this.diffSource,
    this.acceptedAnswerId,
  });

  factory Question.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Question(
      questionId: doc.id,
      userId: data['userId'] as String,
      title: data['title'] as String,
      content: data['content'] as String,
      codeSnippet: data['codeSnippet'] as String?,
      language: data['language'] as String?,
      category: data['category'] as String,
      type: data['type'] as String,
      githubUrl: data['githubUrl'] as String?,
      linkedRepo: GithubRepo.fromLinkedRepo(data['linkedRepo']),
      diffSource: DiffSource.fromDiffRef(data['diffRef']),
      voteCount: (data['voteCount'] as num?)?.toInt() ?? 0,
      acceptedAnswerId: data['acceptedAnswerId'] as String?,
      // null until the server timestamp comes back
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  bool get hasDiff => diffSource != null && linkedRepo != null;

  bool get isAnswered => acceptedAnswerId != null;
}
