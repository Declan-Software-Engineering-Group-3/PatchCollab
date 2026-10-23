import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SocialRepository {
  SocialRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String get currentUserId => _auth.currentUser!.uid;

  String conversationIdFor(String firstUserId, String secondUserId) {
    final ids = [firstUserId, secondUserId]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  Future<void> sendFriendRequest(String friendId) async {
    if (friendId == currentUserId) {
      throw ArgumentError('You cannot send a friend request to yourself.');
    }

    final existing = await _firestore
        .collection('friendships')
        .where('participants', arrayContains: currentUserId)
        .get();

    for (final doc in existing.docs) {
      final data = doc.data();
      final participants = List<String>.from(data['participants'] as List);
      if (participants.contains(friendId)) {
        throw StateError('A friendship or request already exists.');
      }
    }

    final ref = _firestore.collection('friendships').doc();
    await ref.set({
      'friendshipId': ref.id,
      'userId': currentUserId,
      'friendId': friendId,
      'participants': [currentUserId, friendId],
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> acceptFriendRequest(String friendshipId) {
    return _firestore.collection('friendships').doc(friendshipId).update({
      'status': 'accepted',
    });
  }

  Future<void> rejectFriendRequest(String friendshipId) {
    return _firestore.collection('friendships').doc(friendshipId).delete();
  }

  Future<void> sendMessage({
    required String otherUserId,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final conversationId =
        conversationIdFor(currentUserId, otherUserId);
    final conversationRef =
        _firestore.collection('conversations').doc(conversationId);

    final messageRef = conversationRef.collection('messages').doc();

    final batch = _firestore.batch();

    batch.set(
      conversationRef,
      {
        'conversationId': conversationId,
        'participants': [currentUserId, otherUserId]..sort(),
        'lastMessage': trimmed,
        'lastMessageAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    batch.set(messageRef, {
      'messageId': messageRef.id,
      'senderId': currentUserId,
      'text': trimmed,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<void> markMessageRead({
    required String conversationId,
    required String messageId,
  }) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .update({'isRead': true});
  }

  Future<void> markNotificationRead(String notificationId) {
    return _firestore.collection('notifications').doc(notificationId).update({
      'isRead': true,
    });
  }

  Future<void> deleteNotification(String notificationId) {
    return _firestore.collection('notifications').doc(notificationId).delete();
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> searchUsers(
      String query) async {
    final value = query.trim();
    if (value.isEmpty) return [];

    return (await _firestore
            .collection('users')
            .orderBy('displayName')
            .startAt([value])
            .endAt(['$value\uf8ff'])
            .limit(20)
            .get())
        .docs
        .where((doc) => doc.id != currentUserId)
        .toList();
  }
}
