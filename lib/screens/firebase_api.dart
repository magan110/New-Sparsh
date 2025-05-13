import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:learning2/screens/notification_screen.dart';

class FirebaseApi{
  final _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = 
      FlutterLocalNotificationsPlugin();

  // Add a field to store the notification provider
  NotificationProvider? _notificationProvider;

  Future<void> handleBackgroundMessage(RemoteMessage message) async{
    print("title : ${message.notification?.title}");
    print("Body : ${message.notification?.body}");
    print("data : ${message.data}");
  }

  void handleForegroundMessage(RemoteMessage message) {
    print("Foreground Message:");
    print("title : ${message.notification?.title}");
    print("Body : ${message.notification?.body}");
    print("data : ${message.data}");

    // Show local notification
    _showLocalNotification(message);

    // Add to notification provider if available
    if (_notificationProvider != null) {
      _notificationProvider!.addFirebaseNotification(
        message.notification?.title,
        message.notification?.body,
      );
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final android = message.notification?.android;

    if (notification != null && android != null) {
      await _flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        payload: message.data.toString(),
      );
    }
  }

  Future<void> _initLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
    );
  }

  Future<void> initNotification([NotificationProvider? notificationProvider]) async{
    // Store the notification provider if provided
    _notificationProvider = notificationProvider;

    await _firebaseMessaging.requestPermission();
    final fcmToken = await _firebaseMessaging.getToken();
    print('Token: $fcmToken');

    await _initLocalNotifications();

    FirebaseMessaging.onBackgroundMessage(handleBackgroundMessage);
    FirebaseMessaging.onMessage.listen(handleForegroundMessage);
  }
}
