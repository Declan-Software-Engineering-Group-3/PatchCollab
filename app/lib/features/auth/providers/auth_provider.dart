import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

final authProvider = NotifierProvider<AuthNotifier, AsyncValue<void>>(
  AuthNotifier.new,
);

class AuthNotifier extends Notifier<AsyncValue<void>> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  @override
  AsyncValue<void> build() {
    return const AsyncData(null);
  }

  Future<void> register({
    required String username,
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;

      if (user == null) {
        throw Exception('Unable to create user account.');
      }

      await _firestore.collection('users').doc(user.uid).set({
        'userId': user.uid,
        'displayName': username.trim(),
        'email': email.trim(),
        'profileImageUrl': null,
        'fcmTokens': <String>[],
        'createdAt': FieldValue.serverTimestamp(),
      });

      state = const AsyncData(null);
    } on FirebaseAuthException catch (e) {
      state = AsyncError(
        e.message ?? 'Registration failed.',
        StackTrace.current,
      );
    } catch (e, stackTrace) {
      state = AsyncError(e, stackTrace);
    }
  }

  Future<void> login({required String email, required String password}) async {
    state = const AsyncLoading();

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;

      if (user == null) {
        throw Exception('Unable to login.');
      }

      final token = await _messaging.getToken();

      if (token != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'fcmTokens': FieldValue.arrayUnion([token]),
        });
      }

      state = const AsyncData(null);
    } on FirebaseAuthException catch (e) {
      state = AsyncError(e.message ?? 'Login failed.', StackTrace.current);
    } catch (e, stackTrace) {
      state = AsyncError(e, stackTrace);
    }
  }
}
