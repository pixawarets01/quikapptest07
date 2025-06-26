import 'dart:async';
import 'dart:convert';

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_svg/svg.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '/config/env_config.dart';
import '/services/notification_service.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '/chat/chat_widget.dart';

import '../config/trusted_domains.dart';
// import '../utils/icon_parser.dart';

class MainHome extends StatefulWidget {
  final String webUrl;
  final bool isBottomMenu;
  final String bottomMenuItems;
  final bool isDomainUrl;
  final String backgroundColor;
  final String activeTabColor;
  final String textColor;
  final String iconColor;
  final String iconPosition;
  final String taglineColor;
  final bool isLoadIndicator;
  const MainHome(
      {super.key,
      required this.webUrl,
      required this.isBottomMenu,
      required this.bottomMenuItems,
      required this.isDomainUrl,
      required this.backgroundColor,
      required this.activeTabColor,
      required this.textColor,
      required this.iconColor,
      required this.iconPosition,
      required this.taglineColor,
      required this.isLoadIndicator});

  @override
  State<MainHome> createState() => _MainHomeState();
}

class _MainHomeState extends State<MainHome> {
  final GlobalKey webViewKey = GlobalKey();
  late bool isBottomMenu;

  int _currentIndex = 0;

  InAppWebViewController? webViewController;
  late PullToRefreshController? pullToRefreshController;

  static Color _parseHexColor(String hexColor) {
    hexColor = hexColor.replaceFirst('#', '');
    if (hexColor.length == 6) hexColor = 'FF$hexColor';
    return Color(int.parse('0x$hexColor'));
  }

  bool? hasInternet;
// Convert the JSON string into a List of menu objects
  List<Map<String, dynamic>> bottomMenuItems = [];

  String url = "";
  double progress = 0;
  final urlController = TextEditingController();
  DateTime? _lastBackPressed;
  String? _pendingInitialUrl; // 🔹 NEW
  bool isChatVisible = false;

  String myDomain = "";

  InAppWebViewGroupOptions options = InAppWebViewGroupOptions(
    crossPlatform: InAppWebViewOptions(
      useShouldOverrideUrlLoading: true,
      mediaPlaybackRequiresUserGesture: false,
      useOnLoadResource: true,
    ),
    android: AndroidInAppWebViewOptions(
      useHybridComposition: true,
    ),
    ios: IOSInAppWebViewOptions(
      allowsInlineMediaPlayback: true,
    ),
  );

  Offset _dragPosition =
      const Offset(16, 300); // Initial position for chat toggle
  String get InitialCurrentURL => widget.webUrl;

  // Chat icon boundary constraints
  late Size _screenSize;
  late double _chatIconSize;
  late double _bottomMenuHeight;

  // Method to set initial position based on screen size
  void _setInitialChatPosition() {
    if (_screenSize.width > 0) {
      // Position in bottom-right corner with proper spacing
      _dragPosition = Offset(
        _screenSize.width - _chatIconSize - 16, // Right edge with padding
        _screenSize.height -
            _chatIconSize -
            _bottomMenuHeight -
            80, // Above bottom menu
      );
    }
  }

  // Method to ensure chat icon is within bounds
  void _ensureChatIconInBounds() {
    if (_screenSize.width > 0) {
      double maxX = _screenSize.width - _chatIconSize - 16;
      double minX = 16;
      double maxY = _screenSize.height - _chatIconSize - _bottomMenuHeight - 16;
      double minY = MediaQuery.of(context).padding.top + 16;

      _dragPosition = Offset(
        _dragPosition.dx.clamp(minX, maxX),
        _dragPosition.dy.clamp(minY, maxY),
      );
    }
  }

  void requestPermissions() async {
    if (EnvConfig.isCamera) await Permission.camera.request();
    if (EnvConfig.isLocation) await Permission.location.request();
    if (EnvConfig.isMic) await Permission.microphone.request();
    if (EnvConfig.isContact) await Permission.contacts.request();
    if (EnvConfig.isCalendar) await Permission.calendar.request();
    if (EnvConfig.isNotification) await Permission.notification.request();
    await Permission.storage.request();
    if (EnvConfig.isBiometric) {
      if (Platform.isIOS) {
        await Permission.byValue(33).request();
      }
    }
  }

  @override
  void initState() {
    super.initState();

    // Initialize chat icon constraints
    _chatIconSize = 56.0; // Standard FAB size
    _bottomMenuHeight =
        widget.isBottomMenu ? 80.0 : 0.0; // Bottom menu height if enabled

    if (EnvConfig.pushNotify) {
      try {
        if (!Firebase.apps.isNotEmpty) {
          Firebase.initializeApp();
        }

        Future.delayed(Duration.zero, () async {
          try {
            final token = await FirebaseMessaging.instance.getToken();
            if (kDebugMode) {
              print("🔑 Firebase Token: $token");
            }
          } catch (e) {
            if (kDebugMode) {
              print("🚨 Error getting Firebase token: $e");
            }
          }
        });
      } catch (e) {
        if (kDebugMode) {
          print("🚨 Error initializing Firebase: $e");
        }
      }
    }

    requestPermissions();

    if (EnvConfig.pushNotify) {
      setupFirebaseMessaging();
      FirebaseMessaging.instance.getInitialMessage().then((message) async {
        if (message != null) {
          final internalUrl = message.data['url'];
          if (internalUrl != null && internalUrl.isNotEmpty) {
            _pendingInitialUrl = internalUrl;
          }
          await _showLocalNotification(message);
        }
      });
    }

    isBottomMenu = widget.isBottomMenu;

    if (widget.bottomMenuItems.isNotEmpty) {
      try {
        bottomMenuItems = List<Map<String, dynamic>>.from(
            json.decode(widget.bottomMenuItems));
      } catch (e) {
        print("Error parsing bottom menu items: $e");
      }
    }

    Connectivity().onConnectivityChanged.listen((_) {
      _checkInternetConnection();
    });

    _checkInternetConnection();

    if (!kIsWeb &&
        [TargetPlatform.android, TargetPlatform.iOS]
            .contains(defaultTargetPlatform) &&
        EnvConfig.isPulldown) {
      pullToRefreshController = PullToRefreshController(
        options: PullToRefreshOptions(
          color: Colors.blue,
        ),
        onRefresh: () async {
          if (Platform.isAndroid) {
            webViewController?.reload();
          } else if (Platform.isIOS) {
            webViewController?.loadUrl(
              urlRequest: URLRequest(url: WebUri(widget.webUrl)),
            );
          }
        },
      );
    } else {
      pullToRefreshController = null;
    }

    Uri parsedUri = Uri.parse(widget.webUrl);
    myDomain = parsedUri.host;
    if (myDomain.startsWith('www.')) {
      myDomain = myDomain.substring(4);
    }
  }

  /// ✅ Navigation from notification
  void _handleNotificationNavigation(RemoteMessage message) {
    final internalUrl = message.data['url'];
    if (internalUrl != null && webViewController != null) {
      webViewController?.loadUrl(
        urlRequest: URLRequest(url: WebUri(internalUrl ?? widget.webUrl)),
      );
    }
  }

  /// ✅ Setup push notification logic
  void setupFirebaseMessaging() async {
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        await messaging.subscribeToTopic('all_users');
        // Platform-specific topics
        if (Platform.isAndroid) {
          await messaging.subscribeToTopic('android_users');
        } else if (Platform.isIOS) {
          await messaging.subscribeToTopic('ios_users');
        }
      } else {
        if (kDebugMode) {
          print("Notification permission not granted.");
        }
      }

      // ✅ Listen for foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        await _showLocalNotification(message);
        _handleNotificationNavigation(message);
      });

      // ✅ Handle background tap
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint("📲 Opened from background tap: ${message.data}");
        _handleNotificationNavigation(message);
      });
    } catch (e) {
      if (kDebugMode) {
        print("❌ Error during Firebase Messaging setup: $e");
      }
    }
  }

  /// ✅ Local push with optional image
  Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      final notification = message.notification;
      final android = notification?.android;
      final imageUrl = notification?.android?.imageUrl ?? message.data['image'];

      if (notification == null) {
        if (kDebugMode) {
          print("❌ Notification is null");
        }
        return;
      }

      AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'default_channel',
        'Default',
        channelDescription: 'Default notification channel',
        importance: Importance.max,
        priority: Priority.high,
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction('id_1', 'View'),
          AndroidNotificationAction('id_2', 'Dismiss'),
        ],
      );

      if (imageUrl != null && imageUrl.isNotEmpty) {
        try {
          final http.Response response = await http.get(Uri.parse(imageUrl));
          if (response.statusCode != 200) {
            throw Exception('Failed to download image: ${response.statusCode}');
          }

          final tempDir = await getTemporaryDirectory();
          final filePath = '${tempDir.path}/notif_image.jpg';
          final file = File(filePath);
          await file.writeAsBytes(response.bodyBytes);

          androidDetails = AndroidNotificationDetails(
            'default_channel',
            'Default',
            channelDescription: 'Default notification channel',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            icon: '@mipmap/ic_launcher',
            styleInformation: BigPictureStyleInformation(
              FilePathAndroidBitmap(filePath),
              largeIcon: FilePathAndroidBitmap(filePath),
              contentTitle: '<b>${notification.title}</b>',
              summaryText: notification.body,
              htmlFormatContentTitle: true,
              htmlFormatSummaryText: true,
            ),
          );
        } catch (e) {
          if (kDebugMode) {
            print('❌ Failed to load notification image: $e');
          }
        }
      }

      final DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        attachments:
            imageUrl != null ? [DarwinNotificationAttachment(imageUrl)] : null,
      );

      NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iOSDetails,
      );

      await flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        platformDetails,
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error showing local notification: $e');
      }
    }
  }

  /// ✅ Connectivity
  Future<void> _checkInternetConnection() async {
    final result = await Connectivity().checkConnectivity();
    final isOnline = result != ConnectivityResult.none;
    if (mounted) {
      setState(() {
        hasInternet = isOnline;
      });
    }
  }

  /// ✅ Back button double-press exit
  Future<bool> _onBackPressed() async {
    if (webViewController != null) {
      bool canGoBack = await webViewController!.canGoBack();
      if (canGoBack) {
        await webViewController!.goBack();
        return false; // Don't exit app
      }
    }

    DateTime now = DateTime.now();
    if (_lastBackPressed == null ||
        now.difference(_lastBackPressed!) > Duration(seconds: 2)) {
      _lastBackPressed = now;
      Fluttertoast.showToast(
        msg: "Press back again to exit",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.black54,
        textColor: Colors.white,
      );
      return false;
    }

    return true; // Exit app
  }

  bool isLoading = true;
  bool hasError = false;
  TextStyle _getMenuTextStyle(bool isActive) {
    return GoogleFonts.getFont(
      EnvConfig.bottommenuFont,
      fontSize: EnvConfig.bottommenuFontSize,
      fontWeight:
          EnvConfig.bottommenuFontBold ? FontWeight.bold : FontWeight.normal,
      fontStyle:
          EnvConfig.bottommenuFontItalic ? FontStyle.italic : FontStyle.normal,
      color: isActive
          ? _parseHexColor(widget.activeTabColor)
          : _parseHexColor(widget.textColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get screen size for boundary constraints
    _screenSize = MediaQuery.of(context).size;

    // Set initial position if not already set
    if (_dragPosition.dx == 16 && _dragPosition.dy == 300) {
      _setInitialChatPosition();
    }

    // Ensure chat icon is within bounds
    _ensureChatIconInBounds();

    return WillPopScope(
      onWillPop: _onBackPressed,
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              Builder(
                builder: (context) {
                  if (hasInternet == null) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (hasInternet == false) {
                    return const Center(
                        child: Text('📴 No Internet Connection'));
                  }

                  return Stack(
                    children: [
                      if (!hasError)
                        InAppWebView(
                          key: webViewKey,
                          initialUrlRequest:
                              URLRequest(url: WebUri(widget.webUrl)),
                          initialOptions: options,
                          pullToRefreshController: pullToRefreshController,
                          onWebViewCreated: (controller) {
                            webViewController = controller;
                          },
                          shouldOverrideUrlLoading:
                              (controller, navigationAction) async {
                            var uri = navigationAction.request.url!;
                            var url = uri.toString();

                            // Handle special scheme URLs (always allowed)
                            if (isSpecialSchemeUrl(url)) {
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri);
                                return NavigationActionPolicy.CANCEL;
                              }
                            }

                            // Handle URLs based on domain rules
                            if (isUrlFromSameDomain(url) ||
                                (EnvConfig.pushNotify &&
                                    isPushNotificationUrl(url))) {
                              // Allow navigation within the app for same domain or push notification URLs
                              return NavigationActionPolicy.ALLOW;
                            }

                            // Allow trusted payment domains regardless of IS_DOMAIN_URL setting
                            if (isUrlFromTrustedDomain(url)) {
                              // Open in external browser
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri,
                                    mode: LaunchMode.externalApplication);
                                return NavigationActionPolicy.CANCEL;
                              }
                            }

                            // Check if external URLs are allowed for non-trusted domains
                            if (!EnvConfig.isDomainUrl) {
                              // IS_DOMAIN_URL is false - block non-trusted external URLs
                              if (kDebugMode) {
                                print(
                                    "🚫 External URL blocked (IS_DOMAIN_URL=false): $url");
                              }
                              return NavigationActionPolicy.CANCEL;
                            }

                            // IS_DOMAIN_URL is true - allow all other external URLs
                            // For all other external domains (when IS_DOMAIN_URL is true)
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri,
                                  mode: LaunchMode.externalApplication);
                              return NavigationActionPolicy.CANCEL;
                            }

                            return NavigationActionPolicy.ALLOW;
                          },
                          onLoadStart: (controller, url) {
                            setState(() {
                              this.url = url.toString();
                              urlController.text = this.url;
                            });
                          },
                          onLoadStop: (controller, url) async {
                            pullToRefreshController?.endRefreshing();
                            setState(() {
                              this.url = url.toString();
                              urlController.text = this.url;
                            });
                          },
                          onProgressChanged: (controller, progress) {
                            if (progress == 100) {
                              pullToRefreshController?.endRefreshing();
                            }
                            setState(() {
                              this.progress = progress / 100;
                              urlController.text = this.url;
                            });
                          },
                          onUpdateVisitedHistory: (controller, url, isReload) {
                            setState(() {
                              this.url = url.toString();
                              urlController.text = this.url;
                            });
                          },
                          onConsoleMessage: (controller, consoleMessage) {
                            print("Console Message: ${consoleMessage.message}");
                          },
                        ),

                      // Loading Indicator
                      if (widget.isLoadIndicator && isLoading)
                        const Center(child: CircularProgressIndicator()),

                      // Error Screen
                      if (hasError)
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline,
                                  size: 48, color: Colors.red),
                              const SizedBox(height: 16),
                              const Text('Failed to load page'),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    hasError = false;
                                    isLoading = true;
                                  });
                                  webViewController?.loadUrl(
                                    urlRequest:
                                        URLRequest(url: WebUri(widget.webUrl)),
                                  );
                                },
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),

                      // Chat Icon
                      if (EnvConfig.isChatbot)
                        Positioned(
                          left: _dragPosition.dx,
                          top: _dragPosition.dy,
                          child: GestureDetector(
                            onPanUpdate: (details) {
                              setState(() {
                                // Calculate new position
                                Offset newPosition =
                                    _dragPosition + details.delta;

                                // Apply boundary constraints
                                double maxX =
                                    _screenSize.width - _chatIconSize - 16;
                                double minX = 16;
                                double maxY = _screenSize.height -
                                    _chatIconSize -
                                    _bottomMenuHeight -
                                    16;
                                double minY =
                                    MediaQuery.of(context).padding.top + 16;

                                // Constrain position within bounds
                                newPosition = Offset(
                                  newPosition.dx.clamp(minX, maxX),
                                  newPosition.dy.clamp(minY, maxY),
                                );

                                _dragPosition = newPosition;
                              });
                            },
                            onPanEnd: (details) {
                              // Snap to edges if close enough
                              setState(() {
                                double snapThreshold = 32.0;
                                double leftEdge = 16.0;
                                double rightEdge =
                                    _screenSize.width - _chatIconSize - 16;

                                if (_dragPosition.dx <
                                    leftEdge + snapThreshold) {
                                  _dragPosition =
                                      Offset(leftEdge, _dragPosition.dy);
                                } else if (_dragPosition.dx >
                                    rightEdge - snapThreshold) {
                                  _dragPosition =
                                      Offset(rightEdge, _dragPosition.dy);
                                }

                                _ensureChatIconInBounds();
                              });
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: FloatingActionButton(
                                onPressed: () {
                                  setState(() {
                                    isChatVisible = !isChatVisible;
                                  });
                                },
                                backgroundColor: const Color(0xFF667eea),
                                child:
                                    const Icon(Icons.chat, color: Colors.white),
                              ),
                            ),
                          ),
                        ),

                      // Chat Widget
                      if (EnvConfig.isChatbot && isChatVisible)
                        Positioned.fill(
                          child: Container(
                            margin: EdgeInsets.only(
                              top: MediaQuery.of(context).padding.top + 16,
                              left: 16,
                              right: 16,
                              bottom: widget.isBottomMenu ? 96 : 16,
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: ChatWidget(
                                webViewController: webViewController!,
                                currentUrl: InitialCurrentURL,
                                onVisibilityChanged: (visible) {
                                  setState(() {
                                    isChatVisible = visible;
                                  });
                                },
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        bottomNavigationBar: widget.isBottomMenu
            ? BottomNavigationBar(
                type: BottomNavigationBarType
                    .fixed, // Required for more than 3 items
                currentIndex: _currentIndex,
                onTap: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                  if (bottomMenuItems.isNotEmpty &&
                      index < bottomMenuItems.length) {
                    final item = bottomMenuItems[index];
                    final url = item['url'] as String?;
                    if (url != null && url.isNotEmpty) {
                      webViewController?.loadUrl(
                        urlRequest: URLRequest(url: WebUri(url)),
                      );
                    }
                  }
                },
                items: bottomMenuItems.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return BottomNavigationBarItem(
                    icon: FutureBuilder<Widget>(
                      future: buildMenuIcon(
                        item,
                        _currentIndex == index,
                        _parseHexColor(widget.activeTabColor),
                        _parseHexColor(widget.iconColor),
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.done &&
                            snapshot.hasData) {
                          return snapshot.data!;
                        }
                        if (snapshot.hasError) {
                          return Icon(Icons.error,
                              color: _parseHexColor(widget.iconColor));
                        }
                        // Show a placeholder while loading custom icons
                        return const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.0),
                        );
                      },
                    ),
                    label: item['label'] as String? ?? '',
                  );
                }).toList(),
                backgroundColor: _parseHexColor(widget.backgroundColor),
                selectedLabelStyle: _getMenuTextStyle(true),
                unselectedLabelStyle: _getMenuTextStyle(false),
                selectedItemColor: _parseHexColor(widget.activeTabColor),
                unselectedItemColor: _parseHexColor(widget.iconColor),
              )
            : null,
      ),
    );
  }

  Future<Widget> buildMenuIcon(Map<String, dynamic> item, bool isActive,
      Color activeColor, Color defaultColor) async {
    final iconData = item['icon'];
    if (iconData == null) {
      return Icon(Icons.error, color: isActive ? activeColor : defaultColor);
    }

    // Handle legacy string-based icon name for backward compatibility
    if (iconData is String) {
      return Icon(
        _getIconByName(iconData),
        color: isActive ? activeColor : defaultColor,
      );
    }

    if (iconData is! Map<String, dynamic>) {
      debugPrint("Invalid bottom menu icon format: $iconData");
      return Icon(Icons.error_outline,
          color: isActive ? activeColor : defaultColor);
    }

    if (iconData['type'] == 'preset') {
      return Icon(
        _getIconByName(iconData['name'] ?? ''),
        color: isActive ? activeColor : defaultColor,
      );
    }

    if (iconData['type'] == 'custom' && iconData['icon_url'] != null) {
      final labelSanitized = (item['label'] as String)
          .toLowerCase()
          .replaceAll(RegExp(r'\s+'), '_');
      final fileName = '$labelSanitized.svg';
      final assetPath = 'assets/icons/$fileName';

      // Use SvgPicture.asset to load from pre-downloaded assets folder
      // Icons are downloaded during build process by download_custom_icons.sh
      return SvgPicture.asset(
        assetPath,
        width: double.tryParse(iconData['icon_size']?.toString() ?? '24') ?? 24,
        height:
            double.tryParse(iconData['icon_size']?.toString() ?? '24') ?? 24,
        colorFilter: ColorFilter.mode(
            isActive ? activeColor : defaultColor, BlendMode.srcIn),
        placeholderBuilder: (_) => Icon(Icons.image_not_supported,
            color: isActive ? activeColor : defaultColor), // Fallback icon
      );
    }

    // Fallback for unknown icon type
    return Icon(Icons.help_outline,
        color: isActive ? activeColor : defaultColor);
  }

  /// ✅ Update all Uri instances to WebUri
  void _handleUrl(String url) {
    if (url.startsWith('tel:') ||
        url.startsWith('mailto:') ||
        url.startsWith('whatsapp:') ||
        url.startsWith('sms:')) {
      launchUrl(WebUri(url));
    } else {
      webViewController?.loadUrl(
        urlRequest: URLRequest(url: WebUri(url)),
      );
    }
  }

  void _loadInitialUrl() {
    webViewController?.loadUrl(
      urlRequest: URLRequest(url: WebUri(_pendingInitialUrl ?? widget.webUrl)),
    );
  }

  // Add missing getters
  bool get isCameraEnabled => EnvConfig.isCamera;
  bool get isLocationEnabled => EnvConfig.isLocation;
  bool get isMicEnabled => EnvConfig.isMic;
  bool get isContactEnabled => EnvConfig.isContact;
  bool get isCalendarEnabled => EnvConfig.isCalendar;
  bool get isNotificationEnabled => EnvConfig.isNotification;
  bool get isBiometricEnabled => EnvConfig.isBiometric;
  bool get isPullDown => EnvConfig.isPulldown;

  // Fix URI type mismatches
  WebUri _parseWebUri(String url) {
    return WebUri(url);
  }

  // Update URL parsing methods
  void _loadUrl(String url) {
    webViewController?.loadUrl(urlRequest: URLRequest(url: _parseWebUri(url)));
  }

  bool isUrlFromSameDomain(String url) {
    try {
      Uri uri = Uri.parse(url);
      String domain = uri.host;
      if (domain.startsWith('www.')) {
        domain = domain.substring(4);
      }
      return domain == myDomain;
    } catch (e) {
      return false;
    }
  }

  bool isUrlFromTrustedDomain(String url) {
    try {
      Uri uri = Uri.parse(url);
      String domain = uri.host;
      if (domain.startsWith('www.')) {
        domain = domain.substring(4);
      }
      return trustedDomains
          .any((gateway) => domain.endsWith(gateway['domain']!));
    } catch (e) {
      return false;
    }
  }

  bool isSpecialSchemeUrl(String url) {
    return url.startsWith('tel:') ||
        url.startsWith('mailto:') ||
        url.startsWith('whatsapp:') ||
        url.startsWith('sms:');
  }

  bool isPushNotificationUrl(String url) {
    if (!EnvConfig.pushNotify) return false;
    try {
      Uri uri = Uri.parse(url);
      String domain = uri.host;
      if (domain.startsWith('www.')) {
        domain = domain.substring(4);
      }
      return domain == myDomain;
    } catch (e) {
      return false;
    }
  }
}

List<Map<String, dynamic>> parseBottomMenuItems(String raw) {
  try {
    return List<Map<String, dynamic>>.from(json.decode(raw));
  } catch (e) {
    debugPrint("❌ Failed to parse BOTTOMMENU_ITEMS: $e");
    return [];
  }
}

List<Map<String, dynamic>> convertIcons(List<Map<String, dynamic>> items) {
  return items.map((item) {
    return {
      "label": item["label"],
      "icon": _getIconByName(item["icon"]),
      "url": item["url"],
    };
  }).toList();
}

IconData _getIconByName(String? name) {
  if (name == null || name.trim().isEmpty) {
    return Icons.apps; // Default icon
  }

  final lowerName = name.toLowerCase().trim();

  final iconMap = {
    'ac_unit': Icons.ac_unit,
    'access_alarm': Icons.access_alarm,
    'access_time': Icons.access_time,
    'account_balance': Icons.account_balance,
    'account_circle': Icons.account_circle,
    'add': Icons.add,
    'add_a_photo': Icons.add_a_photo,
    'alarm': Icons.alarm,
    'android': Icons.android,
    'announcement': Icons.announcement,
    'apps': Icons.apps,
    'archive': Icons.archive,
    'arrow_back': Icons.arrow_back,
    'arrow_downward': Icons.arrow_downward,
    'arrow_forward': Icons.arrow_forward,
    'arrow_upward': Icons.arrow_upward,
    'aspect_ratio': Icons.aspect_ratio,
    'assessment': Icons.assessment,
    'assignment': Icons.assignment,
    'autorenew': Icons.autorenew,
    'backup': Icons.backup,
    'battery_alert': Icons.battery_alert,
    'battery_charging_full': Icons.battery_charging_full,
    'beach_access': Icons.beach_access,
    'block': Icons.block,
    'bluetooth': Icons.bluetooth,
    'book': Icons.book,
    'bookmark': Icons.bookmark,
    'bug_report': Icons.bug_report,
    'build': Icons.build,
    'calendar_today': Icons.calendar_today,
    'camera': Icons.camera,
    'card_giftcard': Icons.card_giftcard,
    'chat': Icons.chat,
    'check': Icons.check,
    'chevron_left': Icons.chevron_left,
    'chevron_right': Icons.chevron_right,
    'close': Icons.close,
    'cloud': Icons.cloud,
    'code': Icons.code,
    'comment': Icons.comment,
    'compare': Icons.compare,
    'computer': Icons.computer,
    'content_copy': Icons.content_copy,
    'create': Icons.create,
    'delete': Icons.delete,
    'desktop_mac': Icons.desktop_mac,
    'done': Icons.done,
    'download': Icons.download,
    'drag_handle': Icons.drag_handle,
    'edit': Icons.edit,
    'email': Icons.email,
    'error': Icons.error,
    'event': Icons.event,
    'explore': Icons.explore,
    'face': Icons.face,
    'favorite': Icons.favorite,
    'feedback': Icons.feedback,
    'file_copy': Icons.file_copy,
    'filter_list': Icons.filter_list,
    'flag': Icons.flag,
    'folder': Icons.folder,
    'format_align_left': Icons.format_align_left,
    'format_bold': Icons.format_bold,
    'forward': Icons.forward,
    'fullscreen': Icons.fullscreen,
    'gps_fixed': Icons.gps_fixed,
    'grade': Icons.grade,
    'group': Icons.group,
    'help': Icons.help,
    'highlight': Icons.highlight,
    'home': Icons.home,
    'hourglass_empty': Icons.hourglass_empty,
    'http': Icons.http,
    'https': Icons.https,
    'image': Icons.image,
    'info': Icons.info,
    'input': Icons.input,
    'invert_colors': Icons.invert_colors,
    'keyboard': Icons.keyboard,
    'label': Icons.label,
    'language': Icons.language,
    'launch': Icons.launch,
    'link': Icons.link,
    'list': Icons.list,
    'lock': Icons.lock,
    'map': Icons.map,
    'menu': Icons.menu,
    'message': Icons.message,
    'mic': Icons.mic,
    'mood': Icons.mood,
    'more_horiz': Icons.more_horiz,
    'more_vert': Icons.more_vert,
    'navigation': Icons.navigation,
    'notifications': Icons.notifications,
    'offline_bolt': Icons.offline_bolt,
    'palette': Icons.palette,
    'person': Icons.person,
    'phone': Icons.phone,
    'photo': Icons.photo,
    'place': Icons.place,
    'play_arrow': Icons.play_arrow,
    'print': Icons.print,
    'refresh': Icons.refresh,
    'remove': Icons.remove,
    'reorder': Icons.reorder,
    'reply': Icons.reply,
    'report': Icons.report,
    'save': Icons.save,
    'schedule': Icons.schedule,
    'school': Icons.school,
    'search': Icons.search,
    'security': Icons.security,
    'send': Icons.send,
    'settings': Icons.settings,
    'share': Icons.share,
    'shopping_cart': Icons.shopping_cart,
    'star': Icons.star,
    'store': Icons.store,
    'sync': Icons.sync,
    'thumb_up': Icons.thumb_up,
    'title': Icons.title,
    'translate': Icons.translate,
    'trending_up': Icons.trending_up,
    'update': Icons.update,
    'verified_user': Icons.verified_user,
    'visibility': Icons.visibility,
    'volume_up': Icons.volume_up,
    'warning': Icons.warning,
    'watch': Icons.watch,
    'wifi': Icons.wifi,
    'about': Icons.info,
    'contact': Icons.contact_page,
    'shop': Icons.storefront,
    'cart': Icons.shopping_cart_outlined,
    'shoppingcart': Icons.shopping_cart,
    'orders': Icons.receipt_long,
    'order': Icons.receipt_long,
    'wishlist': Icons.favorite,
    'like': Icons.favorite,
    'category': Icons.category,
    'account': Icons.account_circle,
    'profile': Icons.account_circle,
    'offer': Icons.local_offer,
    'discount': Icons.local_offer,
    'services': Icons.miscellaneous_services,
    'blogs': Icons.article,
    'blog': Icons.article,
    'company': Icons.business,
    'aboutus': Icons.business,
    'more': Icons.more_horiz,
    'home_outline': Icons.home_outlined,
    'search_outline': Icons.search_outlined,
    'person_outline': Icons.person_outline,
    'settings_outline': Icons.settings_outlined,
    'favorite_outline': Icons.favorite_outline,
    'info_outline': Icons.info_outline,
    'help_outline': Icons.help_outline,
    'lock_outline': Icons.lock_outline,
    'visibility_outline': Icons.visibility_outlined,
    'calendar_today_outline': Icons.calendar_today_outlined,
    'check_circle_outline': Icons.check_circle_outline,
    'delete_outline': Icons.delete_outline,
    'edit_outlined': Icons.edit_outlined,
    'language_outlined': Icons.language_outlined,
    'star_outline': Icons.star_outline,
    'map_outlined': Icons.map_outlined,
    'menu_outlined': Icons.menu_outlined,
    'notifications_none': Icons.notifications_none,
    'camera_outlined': Icons.camera_outlined,
    'email_outlined': Icons.email_outlined,
    'shopping_cart_outlined': Icons.shopping_cart_outlined,
    'account_circle_outlined': Icons.account_circle_outlined,
    'calendar_today_outlined': Icons.calendar_today_outlined,
    'home_outlined': Icons.home_outlined,
    'search_outlined': Icons.search_outlined,
    'visibility_outlined': Icons.visibility_outlined,
  };

  final icon = iconMap[lowerName];
  if (icon == null) {
    if (kDebugMode) {
      print("🚫 Icon not found for name: $name");
    }
  }
  return icon ?? Icons.error_outline;
}
