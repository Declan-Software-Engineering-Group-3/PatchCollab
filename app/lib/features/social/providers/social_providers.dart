import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/conversation_model.dart';
import '../data/friendship_model.dart';
import '../data/notification_model.dart';
import '../data/social_repository.dart';
import '../data/social_user_model.dart';

final socialRepositoryProvider = Provider<SocialRepository>((ref) {
  return SocialRepository();
});

final currentSocialUserIdProvider = Provider<String?>((ref) {
  return FirebaseAuth.instance.currentUser?.uid;
});

final socialUserProvider =
    StreamProvider.family<SocialUser?, String>((ref, userId) {
  return FirebaseFirestore.instance.collection('users').doc(userId).snapshots().map(
        (doc) => doc.exists ? SocialUser.fromDoc(doc) : null,
      );
});

final friendshipsProvider = StreamProvider<List<Friendship>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(const []);

  return FirebaseFirestore.instance
      .collection('friendships')
      .where('participants', arrayContains: uid)
      .snapshots()
      .map((snap) => snap.docs.map(Friendship.fromDoc).toList());
});

final incomingFriendRequestsProvider =
    StreamProvider<List<Friendship>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(const []);

  return FirebaseFirestore.instance
      .collection('friendships')
      .where('participants', arrayContains: uid)
      .snapshots()
      .map(
        (snap) => snap.docs
            .map(Friendship.fromDoc)
            .where(
              (item) =>
                  item.friendId == uid &&
                  item.status == 'pending',
            )
            .toList(),
      );
});

final friendsProvider = StreamProvider<List<Friendship>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(const []);

  return FirebaseFirestore.instance
      .collection('friendships')
      .where('participants', arrayContains: uid)
      .snapshots()
      .map((snap) => snap.docs
          .map(Friendship.fromDoc)
          .where((item) => item.status == 'accepted')
          .toList());
});

final conversationsProvider = StreamProvider<List<Conversation>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(const []);

  return FirebaseFirestore.instance
      .collection('conversations')
      .where('participants', arrayContains: uid)
      .orderBy('lastMessageAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map(Conversation.fromDoc).toList());
});

final messagesProvider =
    StreamProvider.family<List<ChatMessage>, String>((ref, conversationId) {
  return FirebaseFirestore.instance
      .collection('conversations')
      .doc(conversationId)
      .collection('messages')
      .orderBy('createdAt')
      .snapshots()
      .map((snap) => snap.docs.map(ChatMessage.fromDoc).toList());
});

final notificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(const []);

  return FirebaseFirestore.instance
      .collection('notifications')
      .where('userId', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map(AppNotification.fromDoc).toList());
});

final friendSearchProvider =
    FutureProvider.family<List<SocialUser>, String>((ref, query) async {
  final docs = await ref.read(socialRepositoryProvider).searchUsers(query);
  return docs.map(SocialUser.fromDoc).toList();
});

final socialActionProvider =
    NotifierProvider<SocialActionNotifier, AsyncValue<void>>(
  SocialActionNotifier.new,
);

class SocialActionNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  SocialRepository get _repository => ref.read(socialRepositoryProvider);

  Future<void> sendFriendRequest(String friendId) async {
    await _run(() => _repository.sendFriendRequest(friendId));
  }

  Future<void> acceptFriendRequest(String friendshipId) async {
    await _run(() => _repository.acceptFriendRequest(friendshipId));
  }

  Future<void> rejectFriendRequest(String friendshipId) async {
    await _run(() => _repository.rejectFriendRequest(friendshipId));
  }

  Future<void> sendMessage({
    required String otherUserId,
    required String text,
  }) async {
    await _run(
      () => _repository.sendMessage(otherUserId: otherUserId, text: text),
    );
  }

  Future<void> markMessageRead({
    required String conversationId,
    required String messageId,
  }) async {
    try {
      await _repository.markMessageRead(
        conversationId: conversationId,
        messageId: messageId,
      );
    } catch (_) {
      // A stale message can disappear while a chat is open; do not break the UI.
    }
  }

  Future<void> markNotificationRead(String notificationId) async {
    await _run(() => _repository.markNotificationRead(notificationId));
  }

  Future<void> deleteNotification(String notificationId) async {
    await _run(() => _repository.deleteNotification(notificationId));
  }

  Future<void> _run(Future<void> Function() action) async {
    state = const AsyncLoading();
    try {
      await action();
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}
