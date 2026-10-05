import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/projects_provider.dart';

class ProjectDetailScreen extends ConsumerWidget {
  final String projectId;

  const ProjectDetailScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectAsync = ref.watch(projectDetailProvider(projectId));
    final membersAsync = ref.watch(projectMembersProvider(projectId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Project Details')),
      body: projectAsync.when(
        data: (project) {
          if (project == null) {
            return const Center(child: Text('This project no longer exists.'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(project.title, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(project.description, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 16),

              Text('Technologies', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text(project.technology)),
                  Chip(label: Text(project.difficulty)),
                  Chip(label: Text(project.category)),
                ],
              ),
              const SizedBox(height: 16),

              Text('Team', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              membersAsync.when(
                data: (members) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${members.length} member${members.length == 1 ? '' : 's'}',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    ...members.map(
                      (m) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(m.userId),
                        subtitle: Text(m.role),
                      ),
                    ),
                  ],
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Text('Could not load team: $err'),
              ),

              if (project.githubUrl != null) ...[
                const SizedBox(height: 16),
                Text('GitHub', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.link),
                    title: Text(project.githubUrl!),
                    trailing: FilledButton.tonal(
                      // opening the url plugs in here once the github
                      // integration teammate's helper is ready.
                      onPressed: () {},
                      child: const Text('Open GitHub'),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),
              FilledButton(
                // real join-request logic is item #5 on the build order,
                // writes to membershipRequests. this is the visual stub.
                onPressed: () {},
                child: const Text('Request to Join'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                // plugs into the messaging feature once it exists.
                onPressed: () {},
                child: const Text('Message Owner'),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Could not load project: $err')),
      ),
    );
  }
}
