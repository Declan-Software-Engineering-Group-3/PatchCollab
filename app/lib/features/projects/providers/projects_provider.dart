import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
/// sorted in dart rather than in the query, because filtering on status and
/// ordering by time together would need a composite index.
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

/// display name for a user id, read from the users collection. used so the
/// owner sees a name on a join request instead of a raw uid.
final userDisplayNameProvider =
    StreamProvider.family<String, String>((ref, userId) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .snapshots()
      .map((doc) => (doc.data()?['displayName'] as String?) ?? 'Unknown student');
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

/// the full project list narrowed by the current filters. a plain provider,
/// not a stream provider, since it derives from the projects stream rather than
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

/// handles submitting the create-project form. state is the async status of
/// the last attempt, so the screen can show a spinner or an error.
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

      // the owner's own member row is written here directly. every other
      // member row is written by the approval cloud function, per schema.md.
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

/// handles submitting a request to join a project. separate from
/// the create notifier since they're different user actions with
/// different state to track.
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

/// the current user's request status for this project, so the detail screen
/// can show the right button. returns approved, pending, rejected or null when
/// the user never asked. filters on the user id only, so no composite index is
/// needed, and picks the most relevant status in dart.
final myMembershipStatusProvider =
    StreamProvider.family<String?, String>((ref, projectId) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(null);

  return FirebaseFirestore.instance
      .collection('projects')
      .doc(projectId)
      .collection('membershipRequests')
      .where('userId', isEqualTo: uid)
      .snapshots()
      .map((snap) {
    final statuses = snap.docs.map((d) => d['status'] as String).toSet();
    if (statuses.contains('approved')) return 'approved';
    if (statuses.contains('pending')) return 'pending';
    if (statuses.contains('rejected')) return 'rejected';
    return null;
  });
});

/// handles the owner approving or rejecting a join request. this never writes
/// to firestore directly: approving must be validated on the server, and the
/// status field is only ever changed by the cloud function, per schema.md.
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
      // the region must match the one the function is deployed in.
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
