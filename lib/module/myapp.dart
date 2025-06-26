import 'package:flutter/material.dart';

import '../config/env_config.dart';
import '../services/connectivity_service.dart';
import 'main_home.dart' show MainHome;
import 'splash_screen.dart';
import 'offline_screen.dart';

class MyApp extends StatefulWidget {
  final String webUrl;
  final bool isBottomMenu;
  final bool isSplash;
  final String splashLogo;
  final String splashBg;
  final int splashDuration;
  final String splashTagline;
  final String splashAnimation;
  final bool isDomainUrl;
  final String backgroundColor;
  final String activeTabColor;
  final String textColor;
  final String iconColor;
  final String iconPosition;
  final String taglineColor;
  final String spbgColor;
  final bool isLoadIndicator;
  final String bottomMenuItems;
  const MyApp(
      {super.key,
      required this.webUrl,
      required this.isBottomMenu,
      required this.isSplash,
      required this.splashLogo,
      required this.splashBg,
      required this.splashDuration,
      required this.splashAnimation,
      required this.bottomMenuItems,
      required this.isDomainUrl,
      required this.backgroundColor,
      required this.activeTabColor,
      required this.textColor,
      required this.iconColor,
      required this.iconPosition,
      required this.taglineColor,
      required this.spbgColor,
      required this.isLoadIndicator,
      required this.splashTagline});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool showSplash = false;
  bool isOnline = true;
  final ConnectivityService _connectivityService = ConnectivityService();

  @override
  void initState() {
    super.initState();
    setState(() {
      showSplash = widget.isSplash;
      isOnline = _connectivityService.isConnected;
    });

    // Listen to connectivity changes
    _connectivityService.connectivityStream.listen((connected) {
      if (mounted) {
        setState(() {
          isOnline = connected;
        });
      }
    });

    if (showSplash) {
      Future.delayed(Duration(seconds: widget.splashDuration), () {
        if (mounted) {
          setState(() {
            showSplash = false;
          });
        }
      });
    }
  }

  void _handleRetryConnection() {
    // This will trigger a rebuild and show the main app if connection is restored
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: showSplash
          ? SplashScreen(
              splashLogo: widget.splashLogo,
              splashBg: widget.splashBg,
              splashAnimation: widget.splashAnimation,
              spbgColor: widget.spbgColor,
              taglineColor: widget.taglineColor,
              splashTagline: EnvConfig.splashTagline,
            )
          : !isOnline
              ? OfflineScreen(
                  onRetry: _handleRetryConnection,
                  appName: EnvConfig.appName,
                )
              : MainHome(
                  webUrl: widget.webUrl,
                  isBottomMenu: widget.isBottomMenu,
                  bottomMenuItems: widget.bottomMenuItems,
                  isDomainUrl: widget.isDomainUrl,
                  backgroundColor: widget.backgroundColor,
                  activeTabColor: widget.activeTabColor,
                  textColor: widget.textColor,
                  iconColor: widget.iconColor,
                  iconPosition: widget.iconPosition,
                  taglineColor: widget.taglineColor,
                  isLoadIndicator: widget.isLoadIndicator,
                ),
    );
  }
}
