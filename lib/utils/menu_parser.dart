import 'dart:convert';
import 'package:flutter/foundation.dart';

List<Map<String, dynamic>> parseBottomMenuItems(String rawJson) {
  try {
    final decoded = jsonDecode(rawJson) as List;
    return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
  } catch (e) {
    debugPrint("⚠️ Failed to parse BOTTOMMENU_ITEMS: $e");
    return [];
  }
}
