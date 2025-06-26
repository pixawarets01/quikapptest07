import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'chat_message.dart';
import 'chat_response.dart';
import 'dart:math' as math;

@immutable
class ContentSection {
  final String text;
  final String type;
  final int relevance;

  const ContentSection({
    required this.text,
    required this.type,
    this.relevance = 0,
  });
}

@immutable
class KnowledgeBaseEntry {
  final String url;
  final String title;
  final List<String> headings;
  final List<String> paragraphs;
  final DateTime timestamp;
  final String domain;

  KnowledgeBaseEntry({
    required this.url,
    required this.title,
    required this.headings,
    required this.paragraphs,
    required this.domain,
  }) : timestamp = DateTime.now();

  bool get isStale => DateTime.now().difference(timestamp).inMinutes > 30;

  Map<String, dynamic> toJson() => {
        'url': url,
        'title': title,
        'headings': headings,
        'paragraphs': paragraphs,
        'timestamp': timestamp.toIso8601String(),
        'domain': domain,
      };

  factory KnowledgeBaseEntry.fromJson(Map<String, dynamic> json) =>
      KnowledgeBaseEntry(
        url: json['url'] as String,
        title: json['title'] as String,
        headings: List<String>.from(json['headings'] as List),
        paragraphs: List<String>.from(json['paragraphs'] as List),
        domain: json['domain'] as String,
      );
}

class ChatService {
  static const String _storageKey = 'chat_history';
  static const String _knowledgeBaseKey = 'knowledge_base';
  static const String _greetingShownKey = 'greeting_shown';
  static const int _chunkSize = 5;
  static const Duration _rateLimitDelay = Duration(milliseconds: 100);

  final Map<String, KnowledgeBaseEntry> _knowledgeBase = {};
  final List<ChatMessage> _chatHistory = [];
  final Set<String> _crawledUrls = {};

  late final String _currentUrl;
  late final String _currentDomain;
  KnowledgeBaseEntry? _currentPageEntry;
  final StreamController<List<ChatMessage>> _chatStreamController =
      StreamController<List<ChatMessage>>.broadcast();

  Stream<List<ChatMessage>> get chatStream => _chatStreamController.stream;
  List<ChatMessage> get chatHistory => List.unmodifiable(_chatHistory);

  bool _isInitialized = false;
  bool _hasShownGreeting = false;
  Completer<void>? _initCompleter;

  ChatService(String initialUrl) {
    _currentUrl = initialUrl;
    _currentDomain = Uri.parse(initialUrl).host;
    _initializeService();
  }

  Future<void> _initializeService() async {
    if (_isInitialized) return;

    _initCompleter = Completer<void>();
    try {
      await _loadStoredData();
      await _parseCurrentPage();
      _isInitialized = true;
      _initCompleter?.complete();
    } catch (e) {
      _initCompleter?.completeError(e);
      debugPrint('Error initializing service: $e');
    }
  }

  Future<void> ensureInitialized() async {
    if (_isInitialized) return;
    await _initCompleter?.future;
  }

  Future<void> _loadStoredData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _hasShownGreeting = prefs.getBool(_greetingShownKey) ?? false;

      final historyJson = prefs.getString(_storageKey);
      if (historyJson != null) {
        final List<dynamic> historyList = jsonDecode(historyJson);
        _chatHistory.addAll(historyList
            .map((item) => ChatMessage.fromJson(item as Map<String, dynamic>)));
        _chatStreamController.add(_chatHistory);
      }

      final knowledgeJson = prefs.getString(_knowledgeBaseKey);
      if (knowledgeJson != null) {
        final Map<String, dynamic> knowledgeMap =
            jsonDecode(knowledgeJson) as Map<String, dynamic>;
        knowledgeMap.forEach((key, value) {
          final entry =
              KnowledgeBaseEntry.fromJson(value as Map<String, dynamic>);
          if (!entry.isStale) {
            _knowledgeBase[key] = entry;
            _crawledUrls.add(key);
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading stored data: $e');
    }
  }

  Future<void> _saveData() async {
    if (!_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool(_greetingShownKey, _hasShownGreeting);

      final historyJson =
          jsonEncode(_chatHistory.map((msg) => msg.toJson()).toList());
      await prefs.setString(_storageKey, historyJson);

      final knowledgeJson = jsonEncode(Map.fromEntries(_knowledgeBase.entries
          .map((e) => MapEntry(e.key, e.value.toJson()))));
      await prefs.setString(_knowledgeBaseKey, knowledgeJson);
    } catch (e) {
      debugPrint('Error saving data: $e');
    }
  }

  void dispose() {
    _chatStreamController.close();
    _initCompleter = null;
  }

  Future<void> clearHistory() async {
    await ensureInitialized();
    _chatHistory.clear();
    _hasShownGreeting = false;
    _chatStreamController.add(_chatHistory);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    await prefs.remove(_greetingShownKey);
  }

  Future<void> updateCurrentUrl(String newUrl) async {
    await ensureInitialized();
    _currentUrl = newUrl;
    _currentDomain = Uri.parse(newUrl).host;
    await _parseCurrentPage();
  }

  Future<void> _addMessage(ChatMessage message) async {
    await ensureInitialized();
    _chatHistory.add(message);
    _chatStreamController.add(_chatHistory);
    unawaited(_saveData());
  }

  Future<void> _parseCurrentPage() async {
    if (_knowledgeBase[_currentUrl]?.isStale == false) {
      _currentPageEntry = _knowledgeBase[_currentUrl];
      return;
    }

    try {
      final response = await http.get(Uri.parse(_currentUrl));
      if (response.statusCode != 200) return;

      final content = await compute(_extractContent, response.body);

      _currentPageEntry = KnowledgeBaseEntry(
        url: _currentUrl,
        title: content['title'] as String,
        headings: List<String>.from(content['headings'] as List),
        paragraphs: List<String>.from(content['paragraphs'] as List),
        domain: _currentDomain,
      );

      _knowledgeBase[_currentUrl] = _currentPageEntry!;
      unawaited(_saveData());

      unawaited(_parseLinkedPages(html_parser.parse(response.body)));
    } catch (e) {
      debugPrint('Error parsing current page $_currentUrl: $e');
    }
  }

  static Map<String, dynamic> _extractContent(String html) {
    final document = html_parser.parse(html);
    final titleElement = document.getElementsByTagName('title').firstOrNull;
    final title = titleElement?.text.trim() ?? 'Untitled Page';
    final headings = <String>[];
    final paragraphs = <String>[];

    for (var tag in ['h1', 'h2', 'h3', 'h4', 'h5', 'h6']) {
      for (var element in document.getElementsByTagName(tag)) {
        final headingText = element.text.trim();
        if (headingText.isNotEmpty) {
          headings.add(headingText);
        }
      }
    }

    for (var element in document.getElementsByTagName('p')) {
      final paragraphText = element.text.trim();
      if (paragraphText.isNotEmpty && paragraphText.split(' ').length > 3) {
        paragraphs.add(paragraphText);
      }
    }

    return {
      'title': title,
      'headings': headings,
      'paragraphs': paragraphs,
    };
  }

  Future<void> _parseLinkedPages(dom.Document document) async {
    final urlsToProcess = _extractValidUrls(document);
    final chunks = _createUrlChunks(urlsToProcess);

    for (final chunk in chunks) {
      final futures = chunk.map((url) {
        _crawledUrls.add(url);
        return _fetchAndParsePage(url);
      });

      await Future.wait(futures);
      await Future.delayed(_rateLimitDelay);
    }
  }

  Set<String> _extractValidUrls(dom.Document document) {
    final baseUri = Uri.parse(_currentUrl);
    final urlsToProcess = <String>{};

    for (var tag in document.getElementsByTagName('a')) {
      final href = tag.attributes['href'];
      if (href == null || href.isEmpty) continue;

      try {
        final nextUrl = baseUri.resolve(href).toString();
        final nextUri = Uri.parse(nextUrl);

        if (nextUri.host == _currentDomain &&
            !_crawledUrls.contains(nextUrl) &&
            nextUrl != _currentUrl &&
            _knowledgeBase[nextUrl]?.isStale != false) {
          urlsToProcess.add(nextUrl);
        }
      } catch (e) {
        debugPrint('Error parsing URL $href: $e');
      }
    }

    return urlsToProcess;
  }

  List<List<String>> _createUrlChunks(Set<String> urls) {
    final chunks = <List<String>>[];
    final urlList = urls.toList();

    for (var i = 0; i < urlList.length; i += _chunkSize) {
      chunks.add(urlList.sublist(i,
          i + _chunkSize > urlList.length ? urlList.length : i + _chunkSize));
    }

    return chunks;
  }

  Future<void> _fetchAndParsePage(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return;

      final content = await compute(_extractContent, response.body);

      _knowledgeBase[url] = KnowledgeBaseEntry(
        url: url,
        title: content['title'] as String,
        headings: List<String>.from(content['headings'] as List),
        paragraphs: List<String>.from(content['paragraphs'] as List),
        domain: _currentDomain,
      );

      unawaited(_saveData());
    } catch (e) {
      debugPrint('Error fetching page $url: $e');
    }
  }

  Future<void> processUserMessage(String userMessage) async {
    await _addMessage(ChatMessage(
      text: userMessage,
      isUser: true,
      timestamp: DateTime.now(),
    ));

    final lowerMessage = userMessage.toLowerCase();
    final response = await _generateResponse(lowerMessage, userMessage);

    await _addMessage(ChatMessage(
      text: response.message,
      isUser: false,
      links: response.links,
      timestamp: DateTime.now(),
    ));
  }

  Future<ChatResponse> _generateResponse(
      String lowerMessage, String originalMessage) async {
    // Greetings
    if (_isGreeting(lowerMessage)) {
      if (!_hasShownGreeting) {
        _hasShownGreeting = true;
        unawaited(_saveData());
        return ChatResponse(
          message:
              'Hello! 👋\nWelcome to $_currentDomain\nI am an Intelligent Assistant. \nHow can I help you today?',
        );
      } else {
        return ChatResponse(
          message: 'Hi! How can I help you today?',
        );
      }
    }

    // About queries
    if (_isAboutQuery(lowerMessage)) {
      return await _getSimpleResponse('about');
    }

    // Contact queries
    if (_isContactQuery(lowerMessage)) {
      return await _getSimpleResponse('contact');
    }

    // General search
    return await _getSimpleResponse(originalMessage);
  }

  Future<ChatResponse> _getSimpleResponse(String query) async {
    if (_currentPageEntry == null) {
      await _parseCurrentPage();
    }

    final results = <Map<String, String>>[];

    // Search through knowledge base
    for (final entry in _knowledgeBase.values) {
      if (entry.isStale) continue;

      final titleMatch =
          entry.title.toLowerCase().contains(query.toLowerCase());
      final headingMatch = entry.headings
          .any((h) => h.toLowerCase().contains(query.toLowerCase()));

      if (titleMatch || headingMatch) {
        results.add({
          'title': entry.title,
          'url': entry.url,
        });
      }
    }

    if (results.isEmpty) {
      return ChatResponse(
        message:
            'I found no relevant pages. Please try a different search term.',
      );
    }

    // Sort results by relevance (title matches first)
    results.sort((a, b) {
      final aTitleMatch =
          a['title']!.toLowerCase().contains(query.toLowerCase());
      final bTitleMatch =
          b['title']!.toLowerCase().contains(query.toLowerCase());
      if (aTitleMatch && !bTitleMatch) return -1;
      if (!aTitleMatch && bTitleMatch) return 1;
      return 0;
    });

    // Build response with clean numbered list, each title as a link
    final buffer = StringBuffer('Here are the relevant pages I found:\n\n');
    for (var i = 0; i < results.length; i++) {
      // Each title on its own line, as a link
      buffer
          .writeln('${i + 1}. [${results[i]['title']}](${results[i]['url']})');
    }

    return ChatResponse(
      message: buffer.toString().trim(),
      links: results
          .map((r) => Link(
                url: r['url']!,
                title: r['title']!,
              ))
          .toList(),
    );
  }

  bool _isGreeting(String message) {
    const greetings = {
      'hi',
      'hello',
      'hey',
      'hai',
      'halo',
      'howdy',
      'greetings',
    };
    return greetings.any(message.contains);
  }

  bool _isAboutQuery(String message) {
    const aboutQueries = {
      'about',
      'about us',
      'who are you',
      'what is this',
      'company info',
      'tell me about',
      'who we are',
      'info',
    };
    return aboutQueries.any(message.contains);
  }

  bool _isContactQuery(String message) {
    const contactQueries = {
      'contact',
      'contact us',
      'get in touch',
      'reach out',
      'lets talk',
      'talk to us',
      'address',
      'phone',
      'email',
      'help',
    };
    return contactQueries.any(message.contains);
  }
}
