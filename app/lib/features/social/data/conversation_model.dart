import 'package:cloud_firestore/cloud_firestore.dart';

class Conversation {
  final String conversationId;
  final List<String> participants;
  final String lastMessage;
  final Timestamp lastMessageAt;

  const Conversation({
    required this.conversationId,
    required this.participants,
    required this.lastMessage,
    required this.lastMessageAt,
  });

  factory Conversation.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;

    return Conversation(
      conversationId: doc.id,
      participants: List<String>.from(data['participants'] as List),
      lastMessage: (data['lastMessage'] ?? '') as String,
      lastMessageAt: data['lastMessageAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  String otherUserId(String currentUserId) {
    return participants.firstWhere((id) => id != currentUserId);
  }
}

class ChatMessage {
  final String messageId;
  final String senderId;
  final String text;
  final bool isRead;
  final Timestamp createdAt;

  const ChatMessage({
    required this.messageId,
    required this.senderId,
    required this.text,
    required this.isRead,
    required this.createdAt,
  });

  factory ChatMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;

    return ChatMessage(
      messageId: doc.id,
      senderId: data['senderId'] as String,
      text: data['text'] as String,
      isRead: (data['isRead'] ?? false) as bool,
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }
}
