import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../../firebase_options.dart';

/// Top-level handler required by Firebase Messaging for background messages.
@pragma('vm:entry-point')
Future<void> socialFirebaseMessagingBackgroundHandler(
    RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

/// Initialises FCM for the signed-in user.
///
/// Call this after Firebase.initializeApp() and after authentication.
/// This class only owns FCM wiring; notification documents themselves are
/// created by Cloud Functions.
class SocialMessagingService {
  SocialMessagingService({
    FirebaseMessaging? messaging,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<void> initialize() async {
    FirebaseMessaging.onBackgroundMessage(
      socialFirebaseMessagingBackgroundHandler,
    );

    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    await _saveCurrentToken();

    _messaging.onTokenRefresh.listen((token) async {
      await _saveToken(token);
    });

    FirebaseMessaging.onMessage.listen((_) {
      // The Notifications screen listens to Firestore, so the in-app
      // notification list updates without requiring a local-notification plugin.
    });

    FirebaseMessaging.onMessageOpenedApp.listen((_) {
      // Navigation can be added by the shared navigation shell later.
    });
  }

  Future<void> handleInitialMessage() async {
    await _messaging.getInitialMessage();
  }

  Future<void> _saveCurrentToken() async {
    final token = await _messaging.getToken();

    if (token != null) {
      await _saveToken(token);
    }
  }

  Future<void> _saveToken(String token) async {
    final user = _auth.currentUser;

    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).set(
      {
        'fcmTokens': FieldValue.arrayUnion([token]),
      },
      SetOptions(merge: true),
    );
  }
}