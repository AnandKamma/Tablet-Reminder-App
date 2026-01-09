import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FCMService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Initialize FCM and request permissions
  Future<void> initialize() async {
    try {
      // Request permission for iOS
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      print('📱 FCM Permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // Get FCM token with retry (APNs token might not be ready immediately on iOS)
        String? token = await _getFCMTokenWithRetry();
        if (token != null) {
          print('✅ FCM Token: $token');
          await _saveFCMToken(token);
        } else {
          print('⚠️ Could not get FCM token after retries');
        }

        // Listen for token refresh
        _messaging.onTokenRefresh.listen(_saveFCMToken);
      } else {
        print('⚠️ User declined FCM permissions');
      }
    } catch (e) {
      print('❌ Error initializing FCM: $e');
    }
  }

  Future<String?> _getFCMTokenWithRetry({int maxRetries = 5}) async {
    for (int i = 0; i < maxRetries; i++) {
      try {
        String? token = await _messaging.getToken();
        if (token != null) {
          return token;
        }
      } catch (e) {
        print('⏳ Attempt ${i + 1}/$maxRetries - Waiting for APNs token...');
        if (i < maxRetries - 1) {
          await Future.delayed(Duration(seconds: 2)); // Wait 2 seconds between retries
        }
      }
    }
    return null;
  }

  /// Save FCM token to Firestore
  Future<void> _saveFCMToken(String token) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        print('❌ No user logged in, cannot save FCM token');
        return;
      }

      await _firestore.collection('users').doc(userId).update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ FCM token saved to Firestore for user: $userId');
    } catch (e) {
      print('❌ Error saving FCM token: $e');
    }
  }

  /// Get FCM token for a specific user
  Future<String?> getFCMToken(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return doc.data()?['fcmToken'];
      }
      return null;
    } catch (e) {
      print('❌ Error getting FCM token: $e');
      return null;
    }
  }


  
}