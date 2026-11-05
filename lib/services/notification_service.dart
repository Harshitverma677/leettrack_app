import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  String? _activeUid;
  bool _localNotificationsInitialized = false;

  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
    'leeto_accepted_submissions',
    'Accepted submissions',
    description: 'Notifications when your teammates solve a LeetCode problem.',
    importance: Importance.high,
  );

  /// Requests notification permission, initializes local notifications,
  /// and registers this device's FCM token for the authenticated LEETO user.
  Future<void> initializeForUser(String uid) async {
    if (_activeUid == uid && _tokenRefreshSubscription != null) return;

    await _tokenRefreshSubscription?.cancel();
    await _foregroundMessageSubscription?.cancel();
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

      await _initializeLocalNotifications();
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // FCM does not automatically display notification messages in the
      // foreground on Android. Display them through local notifications.
      _foregroundMessageSubscription =
          FirebaseMessaging.onMessage.listen(_showForegroundNotification);

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

  Future<void> _initializeLocalNotifications() async {
    if (_localNotificationsInitialized) return;

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        debugPrint('LEETO notification tapped: ${response.payload ?? ''}');
      },
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_androidChannel);
    await androidPlugin?.requestNotificationsPermission();

    _localNotificationsInitialized = true;
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final title = message.notification?.title ?? 'Accepted submission 🎉';
    final body = message.notification?.body ??
        '${message.data['username'] ?? 'Your teammate'} solved '
            '${message.data['title'] ?? 'a LeetCode problem'}';

    await _localNotifications.show(
      id: message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: message.data['url'] as String?,
    );
  }

  Future<void> _saveToken(String uid, String token) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

    try {
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
    await _foregroundMessageSubscription?.cancel();
    _tokenRefreshSubscription = null;
    _foregroundMessageSubscription = null;

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
