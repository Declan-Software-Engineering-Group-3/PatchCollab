import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/answer_model.dart';
import '../data/question_model.dart';
import '../providers/community_providers.dart';
import '../widgets/vote_buttons.dart';
import '../community_theme.dart';

class QuestionDetailScreen extends ConsumerStatefulWidget {
  final String questionId;

  const QuestionDetailScreen({super.key, required this.questionId});

  @override
  ConsumerState<QuestionDetailScreen> createState() =>
      _QuestionDetailScreenState();
}

class _QuestionDetailScreenState extends ConsumerState<QuestionDetailScreen> {
  final _answerController = TextEditingController();
  bool _posting = false;

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _postAnswer() async {
    final text = _answerController.text.trim();
    if (text.isEmpty) return;

    setState(() => _posting = true);
    try {
      await ref
          .read(communityRepositoryProvider)
          .createAnswer(
            userId: ref.read(currentUserIdProvider),
            questionId: widget.questionId,
            content: text,
          );
      _answerController.clear();
    } catch (e) {
      if (mounted) _showError('Could not post answer: $e');
    }
    if (mounted) setState(() => _posting = false);
  }

  Future<void> _vote({
    required String collection,
    required String docId,
    required int value,
    required int? currentVote,
  }) async {
    try {
      await ref
          .read(communityRepositoryProvider)
          .vote(
            collection: collection,
            docId: docId,
            userId: ref.read(currentUserIdProvider),
            value: value,
            currentVote: currentVote,
          );
    } catch (e) {
      if (mounted) _showError('Could not vote: $e');
    }
  }

  Future<void> _accept(String answerId) async {
    try {
      await ref
          .read(communityRepositoryProvider)
          .acceptAnswer(questionId: widget.questionId, answerId: answerId);
    } catch (e) {
      if (mounted) _showError('Could not accept answer: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final questionAsync = ref.watch(questionProvider(widget.questionId));
    final answersAsync = ref.watch(answersProvider(widget.questionId));
    final userId = ref.watch(currentUserIdProvider);

    return Theme(
      data: communityTheme,
      child: Scaffold(
        appBar: AppBar(title: const Text('Question')),
        body: questionAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) =>
              Center(child: Text('Could not load question: $err')),
          data: (question) {
            if (question == null) {
              return const Center(
                child: Text('This question no longer exists.'),
              );
            }

            final isAuthor = question.userId == userId;

            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildQuestion(question),
                      const Divider(height: 32),
                      ..._buildAnswers(answersAsync, question, isAuthor),
                    ],
                  ),
                ),
                _buildAnswerBox(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildQuestion(Question question) {
    final theme = Theme.of(context);
    final myVote = ref.watch(myQuestionVoteProvider(question.questionId)).value;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        VoteButtons(
          voteCount: question.voteCount,
          myVote: myVote,
          onVote: (value) => _vote(
            collection: 'questions',
            docId: question.questionId,
            value: value,
            currentVote: myVote,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(question.title, style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(question.content),
              if (question.codeSnippet != null) ...[
                const SizedBox(height: 12),
                _CodeBlock(code: question.codeSnippet!),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  if (question.language != null)
                    Chip(label: Text(question.language!)),
                  Chip(label: Text(question.category)),
                  if (question.type == 'reviewRequest')
                    const Chip(label: Text('Review request')),
                ],
              ),
              Text(
                'Asked by ${_shortId(question.userId)}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildAnswers(
    AsyncValue<List<Answer>> answersAsync,
    Question question,
    bool isAuthor,
  ) {
    final theme = Theme.of(context);

    return answersAsync.when(
      loading: () => [const Center(child: CircularProgressIndicator())],
      error: (err, stack) => [Text('Could not load answers: $err')],
      data: (answers) {
        final sorted = [...answers]
          ..sort((a, b) {
            if (a.isAccepted == b.isAccepted) return 0;
            return a.isAccepted ? -1 : 1;
          });

        return [
          Text(
            '${answers.length} answer${answers.length == 1 ? '' : 's'}',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (answers.isEmpty) const Text('No answers yet, be the first.'),
          ...sorted.map(
            (answer) => _AnswerTile(
              answer: answer,
              canAccept: isAuthor && !question.isAnswered,
              onAccept: () => _accept(answer.answerId),
              onVote: (value, currentVote) => _vote(
                collection: 'answers',
                docId: answer.answerId,
                value: value,
                currentVote: currentVote,
              ),
            ),
          ),
        ];
      },
    );
  }

  Widget _buildAnswerBox() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _answerController,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Write an answer',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _posting ? null : _postAnswer,
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnswerTile extends ConsumerWidget {
  final Answer answer;
  final bool canAccept;
  final VoidCallback onAccept;
  final void Function(int value, int? currentVote) onVote;

  const _AnswerTile({
    required this.answer,
    required this.canAccept,
    required this.onAccept,
    required this.onVote,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final myVote = ref.watch(myAnswerVoteProvider(answer.answerId)).value;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            VoteButtons(
              voteCount: answer.voteCount,
              myVote: myVote,
              onVote: (value) => onVote(value, myVote),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (answer.isAccepted)
                      const Chip(
                        avatar: Icon(Icons.check_circle, size: 18),
                        label: Text('Accepted'),
                      ),
                    Text(answer.content),
                    const SizedBox(height: 8),
                    Text(
                      'Answered by ${_shortId(answer.userId)}',
                      style: theme.textTheme.bodySmall,
                    ),
                    if (canAccept)
                      TextButton(
                        onPressed: onAccept,
                        child: const Text('Accept this answer'),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CodeBlock extends StatelessWidget {
  final String code;

  const _CodeBlock({required this.code});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Text(code, style: const TextStyle(fontFamily: 'monospace')),
      ),
    );
  }
}

// no displayName in the schema yet
String _shortId(String userId) {
  return userId.length <= 6 ? userId : userId.substring(0, 6);
}
