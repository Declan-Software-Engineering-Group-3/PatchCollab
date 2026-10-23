import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../community/community_theme.dart';
import '../data/project_model.dart';
import '../providers/projects_provider.dart';

// owner approves or rejects requests
class PendingRequestsScreen extends ConsumerWidget {
  final String projectId;

  const PendingRequestsScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(pendingRequestsProvider(projectId));
    final responseState = ref.watch(joinRequestResponseProvider);

    // show errors from approve or reject
    ref.listen(joinRequestResponseProvider, (previous, next) {
      next.whenOrNull(
        error: (err, stack) => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update the request: $err')),
        ),
      );
    });

    return Theme(
      data: communityTheme,
      child: Scaffold(
      appBar: AppBar(title: const Text('Join Requests')),
      body: requestsAsync.when(
        data: (requests) {
          if (requests.isEmpty) {
            return const Center(child: Text('No pending requests.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) => JoinRequestCard(
              projectId: projectId,
              request: requests[index],
              busy: responseState.isLoading,
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Could not load requests: $err')),
      ),
      ),
    );
  }
}

// one request with approve and reject
class JoinRequestCard extends ConsumerWidget {
  final String projectId;
  final MembershipRequest request;
  final bool busy;

  const JoinRequestCard({
    super.key,
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
                error: (_, _) => 'Unknown student',
              ),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text('wants to join this project', style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: busy
                      ? null
                      : () => notifier.respond(
                            projectId: projectId,
                            requestId: request.requestId,
                            approve: true,
                          ),
                  child: const Text('Approve'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: busy
                      ? null
                      : () => notifier.respond(
                            projectId: projectId,
                            requestId: request.requestId,
                            approve: false,
                          ),
                  child: const Text('Reject'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
