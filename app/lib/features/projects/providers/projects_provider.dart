import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/project_model.dart';

/// all projects, newest first. filtering (technology/difficulty/category)
/// happens in the browse screen by watching this and narrowing the list,
/// so there is one source of truth for "all projects" rather than one
/// provider per filter combination.
final projectsProvider = StreamProvider<List<ProjectModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('projects')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map(ProjectModel.fromDoc).toList());
});

/// a single project by id, for the detail screen.
final projectDetailProvider =
    StreamProvider.family<ProjectModel?, String>((ref, projectId) {
  return FirebaseFirestore.instance
      .collection('projects')
      .doc(projectId)
      .snapshots()
      .map((doc) => doc.exists ? ProjectModel.fromDoc(doc) : null);
});

/// members of one project.
final projectMembersProvider =
    StreamProvider.family<List<ProjectMember>, String>((ref, projectId) {
  return FirebaseFirestore.instance
      .collection('projects')
      .doc(projectId)
      .collection('members')
      .snapshots()
      .map((snap) => snap.docs.map(ProjectMember.fromDoc).toList());
});

/// pending membership requests for one project, for the owner's review screen.
final pendingRequestsProvider =
    StreamProvider.family<List<MembershipRequest>, String>((ref, projectId) {
  return FirebaseFirestore.instance
      .collection('projects')
      .doc(projectId)
      .collection('membershipRequests')
      .where('status', isEqualTo: 'pending')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map(MembershipRequest.fromDoc).toList());
});

/// the three filter values the browse screen offers. null means "all".
class ProjectFilters {
  final String? technology;
  final String? difficulty;
  final String? category;

  const ProjectFilters({this.technology, this.difficulty, this.category});

  ProjectFilters copyWith({
    String? technology,
    String? difficulty,
    String? category,
    bool clearTechnology = false,
    bool clearDifficulty = false,
    bool clearCategory = false,
  }) {
    return ProjectFilters(
      technology: clearTechnology ? null : (technology ?? this.technology),
      difficulty: clearDifficulty ? null : (difficulty ?? this.difficulty),
      category: clearCategory ? null : (category ?? this.category),
    );
  }
}

/// holds the browse screen's selected filters. logic for this feature lives
/// here, not in the screen widget, per the team's riverpod convention.
class ProjectFiltersNotifier extends Notifier<ProjectFilters> {
  @override
  ProjectFilters build() => const ProjectFilters();

  void setTechnology(String? value) {
    state = state.copyWith(technology: value, clearTechnology: value == null);
  }

  void setDifficulty(String? value) {
    state = state.copyWith(difficulty: value, clearDifficulty: value == null);
  }

  void setCategory(String? value) {
    state = state.copyWith(category: value, clearCategory: value == null);
  }

  void clearAll() => state = const ProjectFilters();
}

final projectFiltersProvider =
    NotifierProvider<ProjectFiltersNotifier, ProjectFilters>(
  ProjectFiltersNotifier.new,
);

/// the full project list narrowed by the current filters. a plain Provider,
/// not a StreamProvider, since it derives from projectsProvider rather than
/// talking to firestore directly.
final filteredProjectsProvider = Provider<AsyncValue<List<ProjectModel>>>((ref) {
  final projectsAsync = ref.watch(projectsProvider);
  final filters = ref.watch(projectFiltersProvider);

  return projectsAsync.whenData((projects) {
    return projects.where((p) {
      if (filters.technology != null && p.technology != filters.technology) {
        return false;
      }
      if (filters.difficulty != null && p.difficulty != filters.difficulty) {
        return false;
      }
      if (filters.category != null && p.category != filters.category) {
        return false;
      }
      return true;
    }).toList();
  });
});
