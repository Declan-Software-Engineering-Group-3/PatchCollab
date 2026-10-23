import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../community/community_theme.dart';
import '../data/project_options.dart';
import '../providers/projects_provider.dart';
import '../widgets/project_card.dart';
import 'create_project_screen.dart';
import 'owner_requests_screen.dart';
import 'pending_requests_screen.dart';
import 'project_detail_screen.dart';

class BrowseProjectsScreen extends ConsumerWidget {
  const BrowseProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredAsync = ref.watch(filteredProjectsProvider);
    final filters = ref.watch(projectFiltersProvider);
    final notifier = ref.read(projectFiltersProvider.notifier);
    final ownsProjects = ref.watch(ownedProjectsProvider).isNotEmpty;
    final pendingCount = ref.watch(pendingRequestCountProvider);

    return Theme(
      data: communityTheme,
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Projects'),
        actions: [
          // only owners have requests
          if (ownsProjects)
            IconButton(
              tooltip: 'Join requests',
              icon: Badge(
                isLabelVisible: pendingCount > 0,
                label: Text('$pendingCount'),
                child: const Icon(Icons.inbox_outlined),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const OwnerRequestsScreen()),
                );
              },
            ),
        ],
      ),
      // create button, the nav bar has none
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CreateProjectScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Create'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FilterRow(
                  label: 'Technology',
                  options: projectTechnologies,
                  selected: filters.technology,
                  onSelected: notifier.setTechnology,
                ),
                const SizedBox(height: 8),
                _FilterRow(
                  label: 'Difficulty',
                  options: projectDifficulties,
                  selected: filters.difficulty,
                  onSelected: notifier.setDifficulty,
                ),
                const SizedBox(height: 8),
                _FilterRow(
                  label: 'Category',
                  options: projectCategories,
                  selected: filters.category,
                  onSelected: notifier.setCategory,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: filteredAsync.when(
              data: (projects) {
                if (projects.isEmpty) {
                  return const Center(child: Text('No projects match these filters.'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: projects.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final project = projects[index];
                    return ProjectCard(
                      project: project,
                      onOpenRequests: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PendingRequestsScreen(
                              projectId: project.projectId,
                            ),
                          ),
                        );
                      },
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ProjectDetailScreen(
                              projectId: project.projectId,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Could not load projects: $err')),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

// one row of filter chips
class _FilterRow extends StatelessWidget {
  final String label;
  final List<String> options;
  final String? selected;
  final ValueChanged<String?> onSelected;

  const _FilterRow({
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('All'),
                selected: selected == null,
                onSelected: (_) => onSelected(null),
              ),
              const SizedBox(width: 8),
              ...options.map(
                (option) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(option),
                    selected: selected == option,
                    onSelected: (_) => onSelected(option),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
