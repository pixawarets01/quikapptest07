import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _connectivityController =
      StreamController<bool>.broadcast();

  Stream<bool> get connectivityStream => _connectivityController.stream;
  bool _isConnected = true;

  bool get isConnected => _isConnected;

  Future<void> initialize() async {
    try {
      // Check initial connectivity
      final result = await _connectivity.checkConnectivity();
      _isConnected =
          result.isNotEmpty && result.first != ConnectivityResult.none;
      _connectivityController.add(_isConnected);

      // Listen to connectivity changes
      _connectivity.onConnectivityChanged
          .listen((List<ConnectivityResult> results) {
        _isConnected =
            results.isNotEmpty && results.first != ConnectivityResult.none;
        _connectivityController.add(_isConnected);
        debugPrint(
            '🌐 Connectivity changed: ${_isConnected ? 'Connected' : 'Disconnected'}');
      });
    } catch (e) {
      debugPrint('❌ Error initializing connectivity service: $e');
      _isConnected = false;
      _connectivityController.add(false);
    }
  }

  Future<bool> checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _isConnected =
          result.isNotEmpty && result.first != ConnectivityResult.none;
      return _isConnected;
    } catch (e) {
      debugPrint('❌ Error checking connectivity: $e');
      _isConnected = false;
      return false;
    }
  }

  void dispose() {
    _connectivityController.close();
  }
}
