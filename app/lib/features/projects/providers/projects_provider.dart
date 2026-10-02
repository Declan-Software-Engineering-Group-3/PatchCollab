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
