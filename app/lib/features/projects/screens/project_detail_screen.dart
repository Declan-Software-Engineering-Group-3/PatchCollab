import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/projects_provider.dart';
import 'pending_requests_screen.dart';

class ProjectDetailScreen extends ConsumerWidget {
  final String projectId;

  const ProjectDetailScreen({super.key, required this.projectId});

  /// opens the repository in the browser or the github app. a link saved
  /// without a scheme (github.com/...) gets https added first.
  Future<void> _openGithub(BuildContext context, String url) async {
    final fixed = url.startsWith('http') ? url : 'https://$url';
    final opened = await launchUrl(
      Uri.parse(fixed),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open that link.')),
      );
    }
  }

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

          final isOwner = FirebaseAuth.instance.currentUser?.uid == project.ownerId;

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
                      onPressed: () => _openGithub(context, project.githubUrl!),
                      child: const Text('Open GitHub'),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),
              if (isOwner)
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PendingRequestsScreen(projectId: projectId),
                      ),
                    );
                  },
                  child: const Text('Manage Join Requests'),
                )
              else
                Consumer(
                builder: (context, ref, _) {
                  final statusAsync = ref.watch(myMembershipStatusProvider(projectId));
                  final joinState = ref.watch(joinRequestProvider);

                  return statusAsync.when(
                    data: (status) {
                      if (status == 'pending') {
                        return const FilledButton(
                          onPressed: null,
                          child: Text('Request Pending'),
                        );
                      }
                      if (status == 'approved') {
                        return const FilledButton(
                          onPressed: null,
                          child: Text('Already a Member'),
                        );
                      }
                      return FilledButton(
                        onPressed: joinState.isLoading
                            ? null
                            : () => ref
                                .read(joinRequestProvider.notifier)
                                .requestToJoin(projectId),
                        child: joinState.isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Request to Join'),
                      );
                    },
                    loading: () => const FilledButton(
                      onPressed: null,
                      child: Text('Request to Join'),
                    ),
                    error: (err, stack) => Text('Could not check membership: $err'),
                  );
                },
              ),
              if (!isOwner) ...[
                const SizedBox(height: 8),
                OutlinedButton(
                  // plugs into the messaging feature once it exists.
                  onPressed: () {},
                  child: const Text('Message Owner'),
                ),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Could not load project: $err')),
      ),
    );
  }
}
