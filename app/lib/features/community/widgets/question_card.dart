import 'package:flutter/material.dart';

import '../data/question_model.dart';

class QuestionCard extends StatelessWidget {
  final Question question;
  final VoidCallback onTap;

  const QuestionCard({super.key, required this.question, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(question.title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                question.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (question.language != null)
                    Chip(label: Text(question.language!)),
                  Chip(label: Text(question.category)),
                  if (question.type == 'reviewRequest')
                    const Chip(label: Text('Review request')),
                  if (question.isAnswered)
                    const Chip(
                      avatar: Icon(Icons.check_circle, size: 18),
                      label: Text('Answered'),
                    ),
                  Text('${question.voteCount} votes'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
