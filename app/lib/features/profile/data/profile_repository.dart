import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchCurrentUser() {
    final user = _auth.currentUser;

    if (user == null) {
      return const Stream.empty();
    }

    return _firestore.collection('users').doc(user.uid).snapshots();
  }

  Future<void> updateProfile({required String displayName}) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('No authenticated user.');
    }

    final trimmedDisplayName = displayName.trim();

    await _firestore.collection('users').doc(user.uid).update({
      'displayName': trimmedDisplayName,
    });
  }

  Future<String> uploadProfileImage(File imageFile) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('No authenticated user.');
    }

    final extension = imageFile.path.split('.').last.toLowerCase();

    final contentType = switch (extension) {
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      _ => throw Exception('Only PNG and JPEG images are supported.'),
    };

    final imageRef = _storage
        .ref()
        .child('profile_images')
        .child('${user.uid}.$extension');

    await imageRef.putFile(
      imageFile,
      SettableMetadata(contentType: contentType),
    );

    final downloadUrl = await imageRef.getDownloadURL();

    await _firestore.collection('users').doc(user.uid).update({
      'profileImageUrl': downloadUrl,
    });

    return downloadUrl;
  }
}
