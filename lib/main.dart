import 'dart:io' show Platform;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/firebase_service.dart';
import '../config/env_config.dart';
import '../module/myapp.dart';
import '../module/offline_screen.dart';
import '../services/notification_service.dart';
import '../services/connectivity_service.dart';
import '../utils/menu_parser.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (kDebugMode) {
    print("🔔 Handling a background message: ${message.messageId}");
    print("📝 Message data: ${message.data}");
    print("📌 Notification: ${message.notification?.title}");
  }
}

class FirebaseErrorWidget extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const FirebaseErrorWidget({
    super.key,
    required this.error,
    required this.onRetry,
  });

  String get platformSpecificHelp {
    if (Platform.isIOS) {
      return """
Please check:
1. GoogleService-Info.plist is properly configured
2. Push notification capability is enabled
3. Valid provisioning profile with push enabled
4. Bundle ID matches Firebase configuration""";
    } else {
      return """
Please check:
1. google-services.json is properly configured
2. Package name matches Firebase configuration
3. SHA-1 fingerprint is added to Firebase console
4. Firebase SDK is properly initialized""";
    }
  }

  String get platformName => Platform.isIOS ? "iOS" : "Android";

  String get platformSpecificError {
    final errorLower = error.toLowerCase();
    if (Platform.isIOS) {
      if (errorLower.contains('googleservice-info.plist')) {
        return 'GoogleService-Info.plist is missing or invalid. Please check your Firebase iOS app configuration.';
      } else if (errorLower.contains('bundle identifier')) {
        return 'Bundle identifier mismatch. Please ensure it matches your Firebase iOS app configuration.';
      } else if (errorLower.contains('provision')) {
        return 'Provisioning profile issue. Please ensure push notifications are enabled in your profile.';
      }
    } else {
      if (errorLower.contains('google-services.json')) {
        return 'google-services.json is missing or invalid. Please check your Firebase Android app configuration.';
      } else if (errorLower.contains('package name')) {
        return 'Package name mismatch. Please ensure it matches your Firebase Android app configuration.';
      } else if (errorLower.contains('sha-1') || errorLower.contains('sha1')) {
        return 'SHA-1 fingerprint missing. Please add it to your Firebase Android app configuration.';
      }
    }
    return error;
  }

  Widget _buildHelpButton(BuildContext context) {
    return TextButton.icon(
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('$platformName Firebase Setup Help'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(platformSpecificHelp),
                  const SizedBox(height: 16),
                  const Text('Documentation Links:'),
                  const SizedBox(height: 8),
                  if (Platform.isIOS) ...[
                    _buildLink(
                      'iOS Firebase Setup Guide',
                      'https://firebase.google.com/docs/ios/setup',
                    ),
                    _buildLink(
                      'iOS Push Notification Setup',
                      'https://firebase.google.com/docs/cloud-messaging/ios/client',
                    ),
                  ] else ...[
                    _buildLink(
                      'Android Firebase Setup Guide',
                      'https://firebase.google.com/docs/android/setup',
                    ),
                    _buildLink(
                      'Android Push Notification Setup',
                      'https://firebase.google.com/docs/cloud-messaging/android/client',
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
      icon: const Icon(Icons.help_outline),
      label: const Text('Setup Help'),
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildLink(String title, String url) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: GestureDetector(
        onTap: () {
          // You might want to add url_launcher package to handle URL opening
          debugPrint('Opening URL: $url');
        },
        child: Text(
          title,
          style: const TextStyle(
            color: Color(0xFF667eea),
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primaryColor: const Color(0xFF667eea),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF667eea),
          primary: const Color(0xFF667eea),
          secondary: const Color(0xFF4fd1c5),
        ),
      ),
      home: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.white,
                      size: 64,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '$platformName Firebase Initialization Failed',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      platformSpecificError,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: onRetry,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF667eea),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.refresh),
                      label: const Text(
                        'Retry',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildHelpButton(context),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        runApp(const MyApp(
                          webUrl: EnvConfig.webUrl,
                          isSplash: EnvConfig.isSplash,
                          splashLogo: EnvConfig.splashUrl,
                          splashBg: EnvConfig.splashBg,
                          splashDuration: EnvConfig.splashDuration,
                          splashAnimation: EnvConfig.splashAnimation,
                          taglineColor: EnvConfig.splashTaglineColor,
                          spbgColor: EnvConfig.splashBgColor,
                          isBottomMenu: EnvConfig.isBottommenu,
                          bottomMenuItems: EnvConfig.bottommenuItems,
                          isDomainUrl: EnvConfig.isDomainUrl,
                          backgroundColor: EnvConfig.bottommenuBgColor,
                          activeTabColor: EnvConfig.bottommenuActiveTabColor,
                          textColor: EnvConfig.bottommenuTextColor,
                          iconColor: EnvConfig.bottommenuIconColor,
                          iconPosition: EnvConfig.bottommenuIconPosition,
                          isLoadIndicator: EnvConfig.isLoadIndicator,
                          splashTagline: EnvConfig.splashTagline,
                        ));
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white70,
                      ),
                      child: const Text(
                        'Continue Without Firebase',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> initializeApp() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    // Lock orientation to portrait only
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    // Initialize connectivity service
    await ConnectivityService().initialize();

    // Initialize local notifications first
    await initLocalNotifications();

    if (EnvConfig.pushNotify) {
      try {
        // Use the Firebase service that handles remote config files
        final options = await loadFirebaseOptionsFromJson();
        await Firebase.initializeApp(options: options);
        FirebaseMessaging.onBackgroundMessage(
            _firebaseMessagingBackgroundHandler);
        await initializeFirebaseMessaging();
        debugPrint("✅ Firebase initialized successfully");
      } catch (e) {
        debugPrint("❌ Firebase initialization error: $e");
        // Show Firebase error UI
        runApp(FirebaseErrorWidget(
          error: e.toString(),
          onRetry: () => initializeApp(),
        ));
        return;
      }
    } else {
      debugPrint(
          "🚫 Firebase not initialized (pushNotify: ${EnvConfig.pushNotify}, isWeb: $kIsWeb)");
    }

    if (EnvConfig.webUrl.isEmpty) {
      debugPrint("❗ Missing WEB_URL environment variable.");
      runApp(const MaterialApp(
        home: Scaffold(
          body: Center(child: Text("WEB_URL not configured.")),
        ),
      ));
      return;
    }

    debugPrint("""
      🛠 Runtime Config:
      - pushNotify: ${EnvConfig.pushNotify}
      - webUrl: ${EnvConfig.webUrl}
      - isSplash: ${EnvConfig.isSplash},
      - splashLogo: ${EnvConfig.splashUrl},
      - splashBg: ${EnvConfig.splashBg},
      - splashDuration: ${EnvConfig.splashDuration},
      - splashAnimation: ${EnvConfig.splashAnimation},
      - taglineColor: ${EnvConfig.splashTaglineColor},
      - spbgColor: ${EnvConfig.splashBgColor},
      - isBottomMenu: ${EnvConfig.isBottommenu},
      - bottomMenuItems: ${parseBottomMenuItems(EnvConfig.bottommenuItems)},
      - isDomainUrl: ${EnvConfig.isDomainUrl},
      - backgroundColor: ${EnvConfig.bottommenuBgColor},
      - activeTabColor: ${EnvConfig.bottommenuActiveTabColor},
      - textColor: ${EnvConfig.bottommenuTextColor},
      - iconColor: ${EnvConfig.bottommenuIconColor},
      - iconPosition: ${EnvConfig.bottommenuIconPosition},
      - Permissions:
        - Camera: ${EnvConfig.isCamera}
        - Location: ${EnvConfig.isLocation}
        - Mic: ${EnvConfig.isMic}
        - Notification: ${EnvConfig.isNotification}
        - Contact: ${EnvConfig.isContact}
      """);

    runApp(const MyApp(
      webUrl: EnvConfig.webUrl,
      isSplash: EnvConfig.isSplash,
      splashLogo: EnvConfig.splashUrl,
      splashBg: EnvConfig.splashBg,
      splashDuration: EnvConfig.splashDuration,
      splashAnimation: EnvConfig.splashAnimation,
      taglineColor: EnvConfig.splashTaglineColor,
      spbgColor: EnvConfig.splashBgColor,
      isBottomMenu: EnvConfig.isBottommenu,
      bottomMenuItems: EnvConfig.bottommenuItems,
      isDomainUrl: EnvConfig.isDomainUrl,
      backgroundColor: EnvConfig.bottommenuBgColor,
      activeTabColor: EnvConfig.bottommenuActiveTabColor,
      textColor: EnvConfig.bottommenuTextColor,
      iconColor: EnvConfig.bottommenuIconColor,
      iconPosition: EnvConfig.bottommenuIconPosition,
      isLoadIndicator: EnvConfig.isLoadIndicator,
      splashTagline: EnvConfig.splashTagline,
    ));
  } catch (e, stackTrace) {
    debugPrint("❌ Fatal error during initialization: $e");
    debugPrint("Stack trace: $stackTrace");
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(child: Text("Error: $e")),
      ),
    ));
  }
}

void main() {
  initializeApp();
}
