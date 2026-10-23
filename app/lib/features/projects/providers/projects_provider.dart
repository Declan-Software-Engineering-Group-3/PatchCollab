import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/project_model.dart';

// all projects, newest first
final projectsProvider = StreamProvider<List<ProjectModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('projects')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map(ProjectModel.fromDoc).toList());
});

// one project for the detail page
final projectDetailProvider =
    StreamProvider.family<ProjectModel?, String>((ref, projectId) {
  return FirebaseFirestore.instance
      .collection('projects')
      .doc(projectId)
      .snapshots()
      .map((doc) => doc.exists ? ProjectModel.fromDoc(doc) : null);
});

// members of a project
final projectMembersProvider =
    StreamProvider.family<List<ProjectMember>, String>((ref, projectId) {
  return FirebaseFirestore.instance
      .collection('projects')
      .doc(projectId)
      .collection('members')
      .snapshots()
      .map((snap) => snap.docs.map(ProjectMember.fromDoc).toList());
});

// pending requests for a project
final pendingRequestsProvider =
    StreamProvider.family<List<MembershipRequest>, String>((ref, projectId) {
  return FirebaseFirestore.instance
      .collection('projects')
      .doc(projectId)
      .collection('membershipRequests')
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map((snap) {
    final requests = snap.docs.map(MembershipRequest.fromDoc).toList();
    requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return requests;
  });
});

// name of a user, shown on requests
final userDisplayNameProvider =
    StreamProvider.family<String, String>((ref, userId) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .snapshots()
      .map((doc) => (doc.data()?['displayName'] as String?) ?? 'Unknown student');
});

// selected filters, null means all
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

// keeps the selected filters
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

// projects after the filters are applied
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

// saves a new project
class ProjectCreationNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<void> createProject({
    required String title,
    required String description,
    required String technology,
    required String difficulty,
    required String category,
    String? githubUrl,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final docRef = FirebaseFirestore.instance.collection('projects').doc();

      await docRef.set({
        'ownerId': uid,
        'title': title,
        'description': description,
        'technology': technology,
        'difficulty': difficulty,
        'category': category,
        'githubUrl': githubUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // owner gets their own member row here
      await docRef.collection('members').doc(uid).set({
        'userId': uid,
        'role': 'owner',
        'joinedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}

final projectCreationProvider =
    NotifierProvider<ProjectCreationNotifier, AsyncValue<void>>(
  ProjectCreationNotifier.new,
);

// sends a join request
class JoinRequestNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<void> requestToJoin(String projectId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('membershipRequests')
          .add({
        'userId': uid,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }
}

final joinRequestProvider =
    NotifierProvider<JoinRequestNotifier, AsyncValue<void>>(
  JoinRequestNotifier.new,
);

// true if the user is in the members list
final myMemberRowProvider =
    StreamProvider.family<bool, String>((ref, projectId) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(false);

  return FirebaseFirestore.instance
      .collection('projects')
      .doc(projectId)
      .collection('members')
      .doc(uid)
      .snapshots()
      .map((doc) => doc.exists);
});

// join status for the current user
final myMembershipStatusProvider =
    StreamProvider.family<String?, String>((ref, projectId) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(null);

  final isMember = ref.watch(myMemberRowProvider(projectId)).value ?? false;
  if (isMember) return Stream.value('approved');

  return FirebaseFirestore.instance
      .collection('projects')
      .doc(projectId)
      .collection('membershipRequests')
      .where('userId', isEqualTo: uid)
      .snapshots()
      .map((snap) {
    final statuses = snap.docs.map((d) => d['status'] as String).toSet();
    if (statuses.contains('pending')) return 'pending';
    if (statuses.contains('rejected')) return 'rejected';
    return null;
  });
});

// owner approves or rejects through the cloud function
class JoinRequestResponseNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<void> respond({
    required String projectId,
    required String requestId,
    required bool approve,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      // same region as the function
      final callable = FirebaseFunctions.instanceFor(region: 'africa-south1')
          .httpsCallable('respondToJoinRequest');
      await callable.call({
        'projectId': projectId,
        'requestId': requestId,
        'decision': approve ? 'approved' : 'rejected',
      });
    });
  }
}

final joinRequestResponseProvider =
    NotifierProvider<JoinRequestResponseNotifier, AsyncValue<void>>(
  JoinRequestResponseNotifier.new,
);

// removes a member, owner only (see rules)
class MemberRemovalNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<void> removeMember({
    required String projectId,
    required String userId,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('members')
          .doc(userId)
          .delete();
    });
  }
}

final memberRemovalProvider =
    NotifierProvider<MemberRemovalNotifier, AsyncValue<void>>(
  MemberRemovalNotifier.new,
);

// saves or clears the github link
class ProjectEditNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<void> updateGithubUrl({
    required String projectId,
    required String? githubUrl,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .update({'githubUrl': githubUrl});
    });
  }
}

final projectEditProvider =
    NotifierProvider<ProjectEditNotifier, AsyncValue<void>>(
  ProjectEditNotifier.new,
);

// projects owned by the current user
final ownedProjectsProvider = Provider<List<ProjectModel>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  final projects = ref.watch(projectsProvider).value ?? const <ProjectModel>[];
  return projects.where((p) => p.ownerId == uid).toList();
});

// waiting requests across my projects
final pendingRequestCountProvider = Provider<int>((ref) {
  var total = 0;
  for (final project in ref.watch(ownedProjectsProvider)) {
    total += ref.watch(pendingRequestsProvider(project.projectId)).value?.length ?? 0;
  }
  return total;
});
