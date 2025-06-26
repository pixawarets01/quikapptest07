import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../config/env_config.dart';

import 'dart:io';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// Channel IDs - configurable via EnvConfig
String get _channelId => '${EnvConfig.appName.toLowerCase()}_notifications';
String get _channelName => '${EnvConfig.appName} Notifications';
String get _channelDescription => 'Notifications for ${EnvConfig.appName}';

Future<void> initLocalNotifications() async {
  // Android initialization
  final AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  // iOS initialization
  final DarwinInitializationSettings iOSSettings = DarwinInitializationSettings(
    requestSoundPermission: true,
    requestBadgePermission: true,
    requestAlertPermission: true,
  );

  final InitializationSettings initSettings = InitializationSettings(
    android: androidSettings,
    iOS: iOSSettings,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      debugPrint("🔔 Notification tapped: ${response.payload}");
      // Handle notification tap
      if (response.payload != null) {
        // Handle the notification payload
        debugPrint("📱 Notification payload: ${response.payload}");
      }
    },
    onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
  );

  // Create Android notification channel
  if (Platform.isAndroid) {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDescription,
            importance: Importance.high,
          ),
        );
  }
}

// This callback is required for background notification handling
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  debugPrint("🔔 Background notification tapped: ${response.payload}");
  // Handle background notification tap
}

Future<void> initializeFirebaseMessaging() async {
  final FirebaseMessaging messaging = FirebaseMessaging.instance;

  // Enable auto initialization
  await messaging.setAutoInitEnabled(true);

  // Request permission
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
    provisional: false,
  );

  debugPrint('🔔 User granted permission: ${settings.authorizationStatus}');

  // Get FCM token
  String? token = await messaging.getToken();
  debugPrint('✅ FCM Token: $token');

  // Listen for token refresh
  messaging.onTokenRefresh.listen((newToken) {
    debugPrint('🔄 FCM Token refreshed: $newToken');
    // TODO: Send this token to your server
  });

  // Handle foreground messages
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    debugPrint('📨 Received foreground message:');
    debugPrint('   Title: ${message.notification?.title}');
    debugPrint('   Body: ${message.notification?.body}');
    debugPrint('   Data: ${message.data}');

    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;
    AppleNotification? apple = message.notification?.apple;

    if (notification != null) {
      await flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            icon: android?.smallIcon ?? '@mipmap/ic_launcher',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: message.data.toString(),
      );
    }
  });

  // Handle notification open events when app is in background/terminated
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    debugPrint('🔔 Notification opened app from background state:');
    debugPrint('   Title: ${message.notification?.title}');
    debugPrint('   Body: ${message.notification?.body}');
    debugPrint('   Data: ${message.data}');
    // TODO: Handle navigation based on message data
  });

  // Check if app was opened from a notification when in terminated state
  RemoteMessage? initialMessage = await messaging.getInitialMessage();
  if (initialMessage != null) {
    debugPrint('🔔 App opened from terminated state by notification:');
    debugPrint('   Title: ${initialMessage.notification?.title}');
    debugPrint('   Body: ${initialMessage.notification?.body}');
    debugPrint('   Data: ${initialMessage.data}');
    // TODO: Handle navigation based on initial message
  }
}
