import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  void requestNotificationService() async{
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      announcement: true,
      carPlay: true,
      criticalAlert: true,
      provisional: true,
      sound: true,
    );
    if(settings.authorizationStatus==AuthorizationStatus.authorized){
      print('user approved permission');
    }
    else if(settings.authorizationStatus==AuthorizationStatus.provisional){
      print('user provisional approved permission');
    }
    else{
      print('user denied permission');
    }
  }
}