import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/project_model.dart';
import '../providers/projects_provider.dart';

/// lets a project owner approve or reject join requests. only reachable from
/// the detail screen when the signed in user is the owner, and the cloud
/// function checks ownership again on the server regardless.
class PendingRequestsScreen extends ConsumerWidget {
  final String projectId;

  const PendingRequestsScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(pendingRequestsProvider(projectId));
    final responseState = ref.watch(joinRequestResponseProvider);

    // show a message if approving or rejecting fails on the server.
    ref.listen(joinRequestResponseProvider, (previous, next) {
      next.whenOrNull(
        error: (err, stack) => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update the request: $err')),
        ),
      );
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Join Requests')),
      body: requestsAsync.when(
        data: (requests) {
          if (requests.isEmpty) {
            return const Center(child: Text('No pending requests.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _RequestCard(
              projectId: projectId,
              request: requests[index],
              busy: responseState.isLoading,
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Could not load requests: $err')),
      ),
    );
  }
}

class _RequestCard extends ConsumerWidget {
  final String projectId;
  final MembershipRequest request;
  final bool busy;

  const _RequestCard({
    required this.projectId,
    required this.request,
    required this.busy,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final nameAsync = ref.watch(userDisplayNameProvider(request.userId));
    final notifier = ref.read(joinRequestResponseProvider.notifier);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              nameAsync.when(
                data: (name) => name,
                loading: () => 'Loading...',
                error: (_, __) => 'Unknown student',
              ),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text('wants to join this project', style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: busy
                        ? null
                        : () => notifier.respond(
                              projectId: projectId,
                              requestId: request.requestId,
                              approve: true,
                            ),
                    child: const Text('Approve'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy
                        ? null
                        : () => notifier.respond(
                              projectId: projectId,
                              requestId: request.requestId,
                              approve: false,
                            ),
                    child: const Text('Reject'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
