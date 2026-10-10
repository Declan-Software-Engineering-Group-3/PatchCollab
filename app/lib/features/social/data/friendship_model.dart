import 'package:cloud_firestore/cloud_firestore.dart';

class Friendship {
  final String friendshipId;
  final String userId;
  final String friendId;
  final List<String> participants;
  final String status;
  final Timestamp createdAt;

  const Friendship({
    required this.friendshipId,
    required this.userId,
    required this.friendId,
    required this.participants,
    required this.status,
    required this.createdAt,
  });

  factory Friendship.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Friendship(
      friendshipId: doc.id,
      userId: data['userId'] as String,
      friendId: data['friendId'] as String,
      participants: List<String>.from(data['participants'] as List),
      status: data['status'] as String,
      createdAt: data['createdAt'] as Timestamp,
    );
  }

  String otherUserId(String currentUserId) =>
      userId == currentUserId ? friendId : userId;
}
