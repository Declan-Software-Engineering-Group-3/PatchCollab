import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../github/data/diff_source.dart';
import '../../github/data/github_repo_model.dart';
import 'answer_model.dart';
import 'question_model.dart';

class CommunityRepository {
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  CommunityRepository(this._db, this._functions);

  Stream<List<Question>> watchQuestions({
    String? language,
    bool unansweredOnly = false,
  }) {
    Query<Map<String, dynamic>> query = _db.collection('questions');

    if (language != null) {
      query = query.where('language', isEqualTo: language);
    }
    if (unansweredOnly) {
      query = query.where('acceptedAnswerId', isNull: true);
    }

    return query
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Question.fromDoc).toList());
  }

  Stream<Question?> watchQuestion(String questionId) {
    return _db
        .collection('questions')
        .doc(questionId)
        .snapshots()
        .map((doc) => doc.exists ? Question.fromDoc(doc) : null);
  }

  Stream<List<Answer>> watchAnswers(String questionId) {
    return _db
        .collection('answers')
        .where('questionId', isEqualTo: questionId)
        .orderBy('createdAt')
        .snapshots()
        .map((snap) => snap.docs.map(Answer.fromDoc).toList());
  }

  // rules only let you read your own vote doc
  Stream<int?> watchMyVote({
    required String collection,
    required String docId,
    required String userId,
  }) {
    return _db
        .collection(collection)
        .doc(docId)
        .collection('votes')
        .doc(userId)
        .snapshots()
        .map(
          (doc) => doc.exists ? (doc.data()!['value'] as num).toInt() : null,
        );
  }

  Future<String> createQuestion({
    required String userId,
    required String title,
    required String content,
    required String category,
    required String type,
    String? language,
    String? codeSnippet,
    GithubRepo? repo,
    DiffSource? diff,
  }) async {
    final ref = _db.collection('questions').doc();
    await ref.set({
      'questionId': ref.id,
      'userId': userId,
      'title': title,
      'content': content,
      'codeSnippet': codeSnippet,
      'language': language,
      'category': category,
      'type': type,
      'githubUrl': null,
      if (repo != null) ...repo.toLinkFields(),
      if (repo != null && diff != null) ...{
        'githubDiffKind': diff.kind.name,
        'githubDiffValue': diff.value,
      },
      'voteCount': 0,
      'acceptedAnswerId': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> createAnswer({
    required String userId,
    required String questionId,
    required String content,
    String? anchorPath,
    int? anchorLine,
    bool anchorNewSide = true,
  }) async {
    final ref = _db.collection('answers').doc();
    await ref.set({
      'answerId': ref.id,
      'questionId': questionId,
      'userId': userId,
      'content': content,
      'voteCount': 0,
      'isAccepted': false,
      if (anchorPath != null && anchorLine != null) ...{
        'anchorPath': anchorPath,
        'anchorLine': anchorLine,
        'anchorNewSide': anchorNewSide,
      },
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // same arrow twice removes the vote, voteCount is the cloud function's job
  Future<void> vote({
    required String collection,
    required String docId,
    required String userId,
    required int value,
    required int? currentVote,
  }) async {
    final ref = _db
        .collection(collection)
        .doc(docId)
        .collection('votes')
        .doc(userId);

    if (currentVote == value) {
      await ref.delete();
    } else {
      await ref.set({
        'userId': userId,
        'value': value,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // TODO: acceptAnswer callable doesn't exist yet, check the name with Arav
  Future<void> acceptAnswer({
    required String questionId,
    required String answerId,
  }) async {
    final callable = _functions.httpsCallable('acceptAnswer');
    await callable.call({'questionId': questionId, 'answerId': answerId});
  }
}
