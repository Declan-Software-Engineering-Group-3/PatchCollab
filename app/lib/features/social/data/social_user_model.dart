import 'package:cloud_firestore/cloud_firestore.dart';

class SocialUser {
  final String userId;
  final String displayName;
  final String email;
  final String? profileImageUrl;

  const SocialUser({
    required this.userId,
    required this.displayName,
    required this.email,
    required this.profileImageUrl,
  });

  factory SocialUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return SocialUser(
      userId: doc.id,
      displayName: (data['displayName'] ?? '') as String,
      email: (data['email'] ?? '') as String,
      profileImageUrl: data['profileImageUrl'] as String?,
    );
  }
}
