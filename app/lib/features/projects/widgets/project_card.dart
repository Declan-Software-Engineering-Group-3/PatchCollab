import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/project_model.dart';
import '../providers/projects_provider.dart';

/// a single project row for the browse list. uses the theme from context
/// rather than hardcoded colors, so it follows whatever theme the app already
/// defines. on the signed in user's own projects it also shows how many join
/// requests are waiting, one tap away from answering them.
class ProjectCard extends ConsumerWidget {
  final ProjectModel project;
  final VoidCallback onTap;

  // opens the join requests for this project, used only on the user's own.
  final VoidCallback? onOpenRequests;

  const ProjectCard({
    super.key,
    required this.project,
    required this.onTap,
    this.onOpenRequests,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isOwner = FirebaseAuth.instance.currentUser?.uid == project.ownerId;
    final pending = isOwner
        ? (ref
                  .watch(pendingRequestsProvider(project.projectId))
                  .value
                  ?.length ??
              0)
        : 0;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(project.title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                project.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text(project.technology)),
                  Chip(label: Text(project.difficulty)),
                  Chip(label: Text(project.category)),
                ],
              ),
              if (isOwner) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    const Chip(label: Text('Your project')),
                    if (pending > 0)
                      ActionChip(
                        label: Text(
                          '$pending pending request${pending == 1 ? '' : 's'}',
                        ),
                        onPressed: onOpenRequests,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
