import 'package:cloud_firestore/cloud_firestore.dart';

/// matches a document in the projects collection in schema.md.
class ProjectModel {
  final String projectId;
  final String ownerId;
  final String title;
  final String description;
  final String technology;
  final String difficulty;
  final String category;
  final String? githubUrl;
  final Timestamp createdAt;

  ProjectModel({
    required this.projectId,
    required this.ownerId,
    required this.title,
    required this.description,
    required this.technology,
    required this.difficulty,
    required this.category,
    required this.createdAt,
    this.githubUrl,
  });

  factory ProjectModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return ProjectModel(
      projectId: doc.id,
      ownerId: data['ownerId'] as String,
      title: data['title'] as String,
      description: data['description'] as String,
      technology: data['technology'] as String,
      difficulty: data['difficulty'] as String,
      category: data['category'] as String,
      githubUrl: data['githubUrl'] as String?,
      createdAt: (data['createdAt'] as Timestamp?) ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'title': title,
      'description': description,
      'technology': technology,
      'difficulty': difficulty,
      'category': category,
      'githubUrl': githubUrl,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

/// matches a document in the members subcollection in schema.md.
class ProjectMember {
  final String userId;
  final String role; // "owner" or "member", lowercase in firestore
  final Timestamp joinedAt;

  ProjectMember({
    required this.userId,
    required this.role,
    required this.joinedAt,
  });

  factory ProjectMember.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return ProjectMember(
      userId: doc.id,
      role: data['role'] as String,
      joinedAt: (data['joinedAt'] as Timestamp?) ?? Timestamp.now(),
    );
  }
}

/// matches a document in the join requests subcollection in schema.md.
class MembershipRequest {
  final String requestId;
  final String userId;
  final String status; // "pending", "approved", "rejected"
  final Timestamp createdAt;

  MembershipRequest({
    required this.requestId,
    required this.userId,
    required this.status,
    required this.createdAt,
  });

  factory MembershipRequest.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return MembershipRequest(
      requestId: doc.id,
      userId: data['userId'] as String,
      status: data['status'] as String,
      createdAt: (data['createdAt'] as Timestamp?) ?? Timestamp.now(),
    );
  }
}
