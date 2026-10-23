import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/community_options.dart';
import '../providers/community_providers.dart';
import '../widgets/question_card.dart';
import 'ask_question_screen.dart';
import 'question_detail_screen.dart';
import '../community_theme.dart';

class CommunityScreen extends ConsumerWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signIn = ref.watch(devSignInProvider);

    return Theme(
      data: communityTheme,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Community'),
          actions: [
            IconButton(
              tooltip: 'Sign out',
              icon: const Icon(Icons.logout),
              onPressed: () => FirebaseAuth.instance.signOut(),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AskQuestionScreen()),
            );
          },
          icon: const Icon(Icons.add),
          label: const Text('Ask'),
        ),
        body: signIn.when(
          data: (_) => const _QuestionList(),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) =>
              Center(child: Text('Dev sign in failed: $err')),
        ),
      ),
    );
  }
}

class _QuestionList extends ConsumerWidget {
  const _QuestionList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final questionsAsync = ref.watch(questionsProvider);
    final filters = ref.watch(communityFiltersProvider);
    final notifier = ref.read(communityFiltersProvider.notifier);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Unanswered'),
                  selected: filters.unansweredOnly,
                  onSelected: notifier.setUnansweredOnly,
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('All languages'),
                  selected: filters.language == null,
                  onSelected: (_) => notifier.setLanguage(null),
                ),
                ...questionLanguages.map(
                  (lang) => Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: ChoiceChip(
                      label: Text(lang),
                      selected: filters.language == lang,
                      onSelected: (_) => notifier.setLanguage(lang),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: questionsAsync.when(
            data: (questions) {
              if (questions.isEmpty) {
                return const Center(child: Text('No questions yet.'));
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: questions.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final question = questions[index];
                  return QuestionCard(
                    question: question,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => QuestionDetailScreen(
                            questionId: question.questionId,
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) =>
                Center(child: Text('Could not load questions: $err')),
          ),
        ),
      ],
    );
  }
}
