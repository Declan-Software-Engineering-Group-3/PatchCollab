import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../community/community_theme.dart';
import '../../social/screens/chat_screen.dart';
import '../providers/projects_provider.dart';
import 'pending_requests_screen.dart';

// github.com/owner/repo, https and www optional
final _githubPattern = RegExp(
  r'^(?:https?://)?(?:www\.)?github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/?$',
);

// null url means clear the link
class _GithubEdit {
  final String? url;
  const _GithubEdit(this.url);
}

// link dialog, owns its controller
class _GithubDialog extends StatefulWidget {
  final String? current;

  const _GithubDialog({required this.current});

  @override
  State<_GithubDialog> createState() => _GithubDialogState();
}

class _GithubDialogState extends State<_GithubDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.current ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final text = _controller.text.trim();

    // empty clears the link
    if (text.isEmpty) {
      Navigator.of(context).pop(const _GithubEdit(null));
      return;
    }
    if (!_githubPattern.hasMatch(text)) {
      setState(() {
        _errorText = 'Use a link like github.com/owner/repository';
      });
      return;
    }

    final withScheme = text.startsWith('http') ? text : 'https://$text';
    Navigator.of(context).pop(
      _GithubEdit(withScheme.replaceAll(RegExp(r'/+$'), '')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: communityTheme,
      child: AlertDialog(
        title: const Text('GitHub repository'),
        content: TextField(
          controller: _controller,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            hintText: 'github.com/owner/repository',
            errorText: _errorText,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _save,
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class ProjectDetailScreen extends ConsumerWidget {
  final String projectId;

  const ProjectDetailScreen({super.key, required this.projectId});

  // opens the repo, adds https if missing
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

  // asks for the link and saves it
  Future<void> _editGithub(
    BuildContext context,
    WidgetRef ref,
    String? current,
  ) async {
    final result = await showDialog<_GithubEdit>(
      context: context,
      builder: (_) => _GithubDialog(current: current),
    );
    if (result == null) return;

    await ref.read(projectEditProvider.notifier).updateGithubUrl(
          projectId: projectId,
          githubUrl: result.url,
        );
    final state = ref.read(projectEditProvider);
    if (!context.mounted) return;
    state.whenOrNull(
      error: (err, stack) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save the link: $err')),
      ),
    );
  }

  // opens a chat with the owner
  Future<void> _messageOwner(
    BuildContext context,
    WidgetRef ref,
    String ownerId,
  ) async {
    final name = await ref.read(userDisplayNameProvider(ownerId).future);
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Theme(
          data: communityTheme,
          child: ChatScreen(otherUserId: ownerId, otherUserName: name),
        ),
      ),
    );
  }

  // asks first, then removes the member
  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    String userId,
    String name,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Theme(
        data: communityTheme,
        child: AlertDialog(
        title: const Text('Remove member'),
        content: Text('Remove $name from this project?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
      ),
    );
    if (confirmed != true) return;

    await ref.read(memberRemovalProvider.notifier).removeMember(
          projectId: projectId,
          userId: userId,
        );
    final state = ref.read(memberRemovalProvider);
    if (!context.mounted) return;
    state.whenOrNull(
      error: (err, stack) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not remove the member: $err')),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectAsync = ref.watch(projectDetailProvider(projectId));
    final membersAsync = ref.watch(projectMembersProvider(projectId));
    // use the community theme, this context is above it
    final theme = communityTheme;

    return Theme(
      data: communityTheme,
      child: Scaffold(
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
                      (m) => Consumer(
                        builder: (context, ref, _) {
                          final nameAsync = ref.watch(userDisplayNameProvider(m.userId));
                          final name = nameAsync.when(
                            data: (value) => value,
                            loading: () => '...',
                            error: (_, _) => 'Unknown student',
                          );
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const CircleAvatar(child: Icon(Icons.person)),
                            title: Text(name),
                            subtitle: Text(m.role),
                            // owner only, never the owner row
                            trailing: (isOwner && m.role != 'owner')
                                ? IconButton(
                                    tooltip: 'Remove from project',
                                    icon: const Icon(Icons.person_remove_outlined),
                                    onPressed: () =>
                                        _confirmRemove(context, ref, m.userId, name),
                                  )
                                : null,
                          );
                        },
                      ),
                    ),
                  ],
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Text('Could not load team: $err'),
              ),

              if (project.githubUrl != null || isOwner) ...[
                const SizedBox(height: 16),
                Text('GitHub', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(project.githubUrl ?? 'No repository linked yet'),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (project.githubUrl != null)
                              FilledButton.tonal(
                                onPressed: () => _openGithub(context, project.githubUrl!),
                                child: const Text('Open GitHub'),
                              ),
                            if (isOwner)
                              OutlinedButton(
                                onPressed: () =>
                                    _editGithub(context, ref, project.githubUrl),
                                child: Text(
                                  project.githubUrl == null ? 'Add link' : 'Edit link',
                                ),
                              ),
                          ],
                        ),
                      ],
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
                  onPressed: () => _messageOwner(context, ref, project.ownerId),
                  child: const Text('Message Owner'),
                ),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Could not load project: $err')),
      ),
      ),
    );
  }
}
