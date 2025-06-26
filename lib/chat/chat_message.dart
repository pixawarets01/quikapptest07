import 'package:flutter/foundation.dart';
import 'chat_response.dart';

@immutable
class ChatMessage {
  final String text;
  final bool isUser;
  final List<Link> links;
  final DateTime timestamp;
  final List<SearchResult>? searchResults;
  final List<String>? keywords;

  const ChatMessage({
    required this.text,
    required this.isUser,
    this.links = const [],
    required this.timestamp,
    this.searchResults,
    this.keywords,
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'isUser': isUser,
        'links': links
            .map((link) => {
                  'url': link.url,
                  'title': link.title,
                })
            .toList(),
        'timestamp': timestamp.toIso8601String(),
        'searchResults': searchResults?.map((r) => r.toJson()).toList(),
        'keywords': keywords,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        text: json['text'] as String,
        isUser: json['isUser'] as bool,
        links: (json['links'] as List?)
                ?.map((link) => Link(
                      url: link['url'] as String,
                      title: link['title'] as String,
                    ))
                .toList() ??
            [],
        timestamp: DateTime.parse(json['timestamp'] as String),
        searchResults: json['searchResults'] != null
            ? List<SearchResult>.from((json['searchResults'] as List)
                .map((e) => SearchResult.fromJson(e)))
            : null,
        keywords: json['keywords'] != null
            ? List<String>.from(json['keywords'] as List)
            : null,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatMessage &&
          runtimeType == other.runtimeType &&
          text == other.text &&
          isUser == other.isUser &&
          timestamp == other.timestamp;

  @override
  int get hashCode => Object.hash(text, isUser, timestamp);
}

@immutable
class SearchResult {
  final String title;
  final String content;
  final String url;
  final List<String> matchedKeywords;
  final int index;

  const SearchResult({
    required this.title,
    required this.content,
    required this.url,
    required this.matchedKeywords,
    required this.index,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'content': content,
        'url': url,
        'matchedKeywords': matchedKeywords,
        'index': index,
      };

  factory SearchResult.fromJson(Map<String, dynamic> json) => SearchResult(
        title: json['title'] as String,
        content: json['content'] as String,
        url: json['url'] as String,
        matchedKeywords: List<String>.from(json['matchedKeywords'] as List),
        index: json['index'] as int,
      );
}
