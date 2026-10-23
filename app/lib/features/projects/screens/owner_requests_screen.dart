import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../community/community_theme.dart';
import '../data/project_model.dart';
import '../providers/projects_provider.dart';
import 'pending_requests_screen.dart';

// all waiting requests on my projects
class OwnerRequestsScreen extends ConsumerWidget {
  const OwnerRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ownedProjects = ref.watch(ownedProjectsProvider);
    final total = ref.watch(pendingRequestCountProvider);
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
        body: total == 0
            ? const Center(child: Text('No pending requests.'))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final project in ownedProjects)
                    _ProjectRequests(
                      project: project,
                      busy: responseState.isLoading,
                    ),
                ],
              ),
      ),
    );
  }
}

// requests for one project
class _ProjectRequests extends ConsumerWidget {
  final ProjectModel project;
  final bool busy;

  const _ProjectRequests({required this.project, required this.busy});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(pendingRequestsProvider(project.projectId)).value ??
        const <MembershipRequest>[];
    if (requests.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(project.title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        for (final request in requests) ...[
          JoinRequestCard(
            projectId: project.projectId,
            request: request,
            busy: busy,
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}
