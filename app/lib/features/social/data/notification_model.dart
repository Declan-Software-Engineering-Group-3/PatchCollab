import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  final String notificationId;
  final String userId;
  final String type;
  final String message;
  final String? relatedId;
  final bool isRead;
  final Timestamp createdAt;

  const AppNotification({
    required this.notificationId,
    required this.userId,
    required this.type,
    required this.message,
    required this.relatedId,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return AppNotification(
      notificationId: doc.id,
      userId: data['userId'] as String,
      type: data['type'] as String,
      message: data['message'] as String,
      relatedId: data['relatedId'] as String?,
      isRead: (data['isRead'] ?? false) as bool,
      createdAt: data['createdAt'] as Timestamp,
    );
  }
}
