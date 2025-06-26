import 'package:flutter/foundation.dart';
import 'chat_message.dart';

class Link {
  final String url;
  final String title;

  const Link({
    required this.url,
    required this.title,
  });
}

@immutable
class ChatResponse {
  final String message;
  final List<Link> links;
  final List<SearchResult>? searchResults;
  final List<String>? keywords;
  final bool isAppInfo;

  const ChatResponse({
    required this.message,
    this.links = const [],
    this.searchResults,
    this.keywords,
    this.isAppInfo = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatResponse &&
          runtimeType == other.runtimeType &&
          message == other.message &&
          listEquals(links, other.links) &&
          listEquals(searchResults, other.searchResults) &&
          listEquals(keywords, other.keywords) &&
          isAppInfo == other.isAppInfo;

  @override
  int get hashCode => Object.hash(
        message,
        Object.hashAll(links),
        Object.hashAll(searchResults ?? []),
        Object.hashAll(keywords ?? []),
        isAppInfo,
      );
}
