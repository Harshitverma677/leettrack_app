import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  StreamSubscription<String>? _tokenRefreshSubscription;
  String? _activeUid;

  /// Requests notification permission and registers this device's FCM token
  /// against the currently authenticated LEETO account.
  Future<void> initializeForUser(String uid) async {
    if (_activeUid == uid && _tokenRefreshSubscription != null) return;

    await _tokenRefreshSubscription?.cancel();
    _activeUid = uid;

    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('LEETO notifications permission was denied.');
        return;
      }

      // iOS requires an APNs token before an FCM token can be issued.
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        String? apnsToken;
        for (var attempt = 0; attempt < 5 && apnsToken == null; attempt++) {
          apnsToken = await _messaging.getAPNSToken();
          if (apnsToken == null) {
            await Future<void>.delayed(const Duration(seconds: 1));
          }
        }
        if (apnsToken == null) {
          debugPrint('LEETO: APNs token is not available yet.');
          return;
        }
      }

      final token = await _messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await _saveToken(uid, token);
      }

      _tokenRefreshSubscription =
          _messaging.onTokenRefresh.listen((refreshedToken) {
        if (_activeUid == uid && refreshedToken.isNotEmpty) {
          _saveToken(uid, refreshedToken);
        }
      });
    } catch (error, stackTrace) {
      debugPrint('LEETO FCM registration failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _saveToken(String uid, String token) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

    try {
      // Auth state can arrive just before the sign-up flow finishes creating
      // users/{uid}. Wait for that owner document rather than attempting a
      // create that would fail the Firestore rule requiring a matching uid.
      var userExists = false;
      for (var attempt = 0; attempt < 10; attempt++) {
        final snapshot = await userRef.get();
        if (snapshot.exists) {
          userExists = true;
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }

      if (!userExists) {
        debugPrint('LEETO: users/$uid is not ready; FCM token was not saved.');
        return;
      }

      await userRef.update({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('LEETO: FCM token saved for user $uid.');
    } catch (error) {
      debugPrint('LEETO could not save the FCM token: $error');
    }
  }

  Future<void> stopForSignOut() async {
    final uid = _activeUid;
    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;

    // Remove this device from the previous account before another account
    // can sign in on the same device.
    if (uid != null) {
      try {
        final token = await _messaging.getToken();
        if (token != null && token.isNotEmpty) {
          await FirebaseFirestore.instance.collection('users').doc(uid).update({
            'fcmTokens': FieldValue.arrayRemove([token]),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      } catch (error) {
        debugPrint('LEETO could not remove the signed-out device token: $error');
      }
    }

    _activeUid = null;
  }
}
