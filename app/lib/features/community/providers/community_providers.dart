import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/answer_model.dart';
import '../data/community_repository.dart';
import '../data/question_model.dart';

// DEV ONLY: remove kDevUserId and devSignInProvider once feature/auth is merged
const kDevUserId = 'dev-user';

final devSignInProvider = FutureProvider<void>((ref) async {
  if (FirebaseAuth.instance.currentUser == null) {
    await FirebaseAuth.instance.signInAnonymously();
  }
});

final _authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final currentUserIdProvider = Provider<String>((ref) {
  // stream is empty on the first read
  final user =
      ref.watch(_authStateProvider).value ?? FirebaseAuth.instance.currentUser;
  return user?.uid ?? kDevUserId;
});

final communityRepositoryProvider = Provider<CommunityRepository>((ref) {
  return CommunityRepository(
    FirebaseFirestore.instance,
    // same region as the ai function
    FirebaseFunctions.instanceFor(region: 'africa-south1'),
  );
});

class CommunityFilters {
  final String? language;
  final bool unansweredOnly;

  const CommunityFilters({this.language, this.unansweredOnly = false});
}

class CommunityFiltersNotifier extends Notifier<CommunityFilters> {
  @override
  CommunityFilters build() => const CommunityFilters();

  void setLanguage(String? language) {
    state = CommunityFilters(
      language: language,
      unansweredOnly: state.unansweredOnly,
    );
  }

  void setUnansweredOnly(bool value) {
    state = CommunityFilters(language: state.language, unansweredOnly: value);
  }
}

final communityFiltersProvider =
    NotifierProvider<CommunityFiltersNotifier, CommunityFilters>(
      CommunityFiltersNotifier.new,
    );

final questionsProvider = StreamProvider<List<Question>>((ref) {
  final filters = ref.watch(communityFiltersProvider);
  return ref
      .watch(communityRepositoryProvider)
      .watchQuestions(
        language: filters.language,
        unansweredOnly: filters.unansweredOnly,
      );
});

final questionProvider = StreamProvider.family<Question?, String>((
  ref,
  questionId,
) {
  return ref.watch(communityRepositoryProvider).watchQuestion(questionId);
});

final answersProvider = StreamProvider.family<List<Answer>, String>((
  ref,
  questionId,
) {
  return ref.watch(communityRepositoryProvider).watchAnswers(questionId);
});

final myQuestionVoteProvider = StreamProvider.family<int?, String>((
  ref,
  questionId,
) {
  return ref
      .watch(communityRepositoryProvider)
      .watchMyVote(
        collection: 'questions',
        docId: questionId,
        userId: ref.watch(currentUserIdProvider),
      );
});

final myAnswerVoteProvider = StreamProvider.family<int?, String>((
  ref,
  answerId,
) {
  return ref
      .watch(communityRepositoryProvider)
      .watchMyVote(
        collection: 'answers',
        docId: answerId,
        userId: ref.watch(currentUserIdProvider),
      );
});
