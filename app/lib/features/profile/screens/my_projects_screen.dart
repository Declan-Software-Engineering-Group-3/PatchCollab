import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../projects/data/project_model.dart';
import '../../projects/screens/project_detail_screen.dart';

const _background = Color(0xFF061C1C);
const _surface = Color(0xFF0D2928);
const _border = Color(0xFF164C49);
const _accent = Color(0xFF22D3C5);
const _text = Color(0xFFF2FFFF);
const _muted = Color(0xFF9BB8B6);

enum MyProjectFilter { all, created, joined }

final myProjectsProvider = FutureProvider.autoDispose<List<ProjectModel>>((
  ref,
) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;

  if (uid == null) {
    return <ProjectModel>[];
  }

  final memberships = await FirebaseFirestore.instance
      .collectionGroup('members')
      .where('userId', isEqualTo: uid)
      .get();

  final projectRefs = <String, DocumentReference<Map<String, dynamic>>>{};

  for (final membership in memberships.docs) {
    final projectRef = membership.reference.parent.parent;

    if (projectRef != null) {
      projectRefs[projectRef.id] = projectRef;
    }
  }

  final projectDocs = await Future.wait(
    projectRefs.values.map((reference) => reference.get()),
  );

  final projects = <ProjectModel>[];

  for (final document in projectDocs) {
    if (document.exists) {
      projects.add(ProjectModel.fromDoc(document));
    }
  }

  projects.sort((a, b) => b.createdAt.compareTo(a.createdAt));

  return projects;
});

class MyProjectsScreen extends ConsumerStatefulWidget {
  const MyProjectsScreen({super.key});

  @override
  ConsumerState<MyProjectsScreen> createState() => _MyProjectsScreenState();
}

class _MyProjectsScreenState extends ConsumerState<MyProjectsScreen> {
  MyProjectFilter _filter = MyProjectFilter.all;

  Future<void> _refresh() async {
    ref.invalidate(myProjectsProvider);
    await ref.read(myProjectsProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(myProjectsProvider);
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: _text,
        elevation: 0,
        iconTheme: const IconThemeData(color: _text, size: 33),
        title: const Text(
          'My Projects',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: projectsAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(color: _accent)),
          error: (error, stackTrace) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_outlined, color: _muted, size: 36),
                  const SizedBox(height: 12),
                  const Text(
                    'Unable to load your projects',
                    style: TextStyle(color: _text, fontSize: 24),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _refresh,
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
          ),
          data: (projects) {
            final created = projects
                .where((project) => project.ownerId == uid)
                .toList();

            final joined = projects
                .where((project) => project.ownerId != uid)
                .toList();

            final visibleProjects = switch (_filter) {
              MyProjectFilter.all => projects,
              MyProjectFilter.created => created,
              MyProjectFilter.joined => joined,
            };

            return RefreshIndicator(
              color: _accent,
              backgroundColor: _surface,
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  const Text(
                    'Your teams and projects',
                    style: TextStyle(color: _muted, fontSize: 21),
                  ),
                  const SizedBox(height: 18),

                  Row(
                    children: [
                      Expanded(
                        child: _SummaryCard(
                          icon: Icons.layers_outlined,
                          label: 'Total projects',
                          count: projects.length,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryCard(
                          icon: Icons.person_outline_rounded,
                          label: 'Owned by you',
                          count: created.length,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Your Projects',
                    style: TextStyle(
                      color: _text,
                      fontSize: 27,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _FilterButton(
                          label: 'All',
                          icon: Icons.layers_outlined,
                          selected: _filter == MyProjectFilter.all,
                          onTap: () =>
                              setState(() => _filter = MyProjectFilter.all),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _FilterButton(
                          label: 'Created',
                          icon: Icons.person_outline_rounded,
                          selected: _filter == MyProjectFilter.created,
                          onTap: () =>
                              setState(() => _filter = MyProjectFilter.created),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _FilterButton(
                          label: 'Joined',
                          icon: Icons.people_outline_rounded,
                          selected: _filter == MyProjectFilter.joined,
                          onTap: () =>
                              setState(() => _filter = MyProjectFilter.joined),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (visibleProjects.isEmpty)
                    const _EmptyProjects()
                  else
                    ...visibleProjects.map(
                      (project) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ProjectTile(
                          project: project,
                          isOwner: project.ownerId == uid,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => ProjectDetailScreen(
                                  projectId: project.projectId,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.count,
  });

  final IconData icon;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _accent, size: 48),
          const SizedBox(height: 10),
          Text(
            '$count',
            style: const TextStyle(
              color: _text,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(color: _muted, fontSize: 22)),
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _accent.withValues(alpha: 0.15) : _surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? _accent : _border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 23, color: selected ? _accent : _muted),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? _accent : _muted,
                    fontSize: 21,
                    fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectTile extends StatelessWidget {
  const _ProjectTile({
    required this.project,
    required this.isOwner,
    required this.onTap,
  });

  final ProjectModel project;
  final bool isOwner;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.folder_outlined,
                  color: _accent,
                  size: 27,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _text,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      project.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 18,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _Tag(label: isOwner ? 'Your project' : 'Member'),
                        if (project.technology.isNotEmpty)
                          _Tag(label: project.technology),
                        if (project.category.isNotEmpty)
                          _Tag(label: project.category),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: _muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF123A38),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: _muted, fontSize: 18),
      ),
    );
  }
}

class _EmptyProjects extends StatelessWidget {
  const _EmptyProjects();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 16),
      child: Column(
        children: [
          Icon(
            Icons.folder_open_outlined,
            color: _muted.withValues(alpha: 0.8),
            size: 72,
          ),
          const SizedBox(height: 12),
          const Text(
            'No projects here yet, Join one',
            style: TextStyle(
              color: _muted,
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
