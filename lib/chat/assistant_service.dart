import '../chat/search_result_model.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;


class AssistantService {
  Future<List<SearchResult>> deepSearchFromDomain(String domainUrl, String keyword) async {
    final Set<String> internalUrls = await _crawlDomain(domainUrl);
    return await deepSearch(keyword, internalUrls.toList());
  }

  Future<List<SearchResult>> deepSearch(String keyword, List<String> urls) async {
    final Set<String> seenUrls = {};
    final List<SearchResult> results = [];
    final lowerKeyword = keyword.toLowerCase();

    for (final domainUrl in urls) {
      if (seenUrls.contains(domainUrl)) continue;
      seenUrls.add(domainUrl);

      try {
        final response = await http.get(Uri.parse(domainUrl));
        if (response.statusCode == 200) {
          final document = html_parser.parse(response.body);
          final title = _extractTitle(document);
          final domain = Uri.parse(domainUrl).host;
          final timestamp = DateTime.now().toIso8601String();
          final favicon = 'https://www.google.com/s2/favicons?domain=$domain';

          final headings = _extractTextByTags(document, ['h1', 'h2', 'h3', 'h4']);
          // final paragraphs = _extractTextByTags(document, ['p']);

          for (final tag in ['h1', 'h2', 'h3', 'h4', 'h5' , 'h6']) {
            for (final element in document.querySelectorAll(tag)) {
              final content = element.text.trim();
              if (content.toLowerCase().contains(lowerKeyword)) {
                results.add(SearchResult(
                  title: title,
                  content: content,
                  url: domainUrl,
                  favicon: favicon,
                  metadata: {
                    'domain': domain,
                    'timestamp': timestamp,
                    'headings': headings,
                    // 'paragraphs': paragraphs,
                    'matchedTag': tag,
                  },
                ));
              }
            }
          }
        }
      } catch (_) {
        continue;
      }
    }

    return results;
  }

  /// Fallback mock for local testing
  static Future<List<SearchResult>> mockResults(String domainUrl, String keyword) async {
    await Future.delayed(const Duration(seconds: 2));
    return List.generate(6, (i) => SearchResult(
      title: 'Result for "$keyword" #$i',
      content: 'Example content for result #$i containing $keyword.',
      url: '$domainUrl/page$i',
      favicon: 'https://www.google.com/s2/favicons?domain=$domainUrl',
      metadata: {
        // 'matchedTag': 'p',
        'timestamp': DateTime.now().toIso8601String(),
        'domain': Uri.parse(domainUrl).host,
        'headings': [],
        // 'paragraphs': [],
      },
    ));
  }

  Future<Set<String>> _crawlDomain(String baseUrl) async {
    final Set<String> discoveredUrls = {baseUrl};
    final Uri baseUri = Uri.parse(baseUrl);

    try {
      final response = await http.get(baseUri);
      if (response.statusCode == 200) {
        final document = html_parser.parse(response.body);
        final links = document.querySelectorAll('a[href]');

        for (final link in links) {
          final href = link.attributes['href'];
          if (href != null && !href.startsWith('http') && !href.startsWith('#')) {
            final absoluteUrl = baseUri.resolve(href).toString();
            if (absoluteUrl.startsWith(baseUrl)) {
              discoveredUrls.add(absoluteUrl);
            }
          } else if (href != null && href.startsWith(baseUrl)) {
            discoveredUrls.add(href);
          }
        }
      }
    } catch (_) {
      // ignore crawling errors
    }

    return discoveredUrls;
  }

  String _extractTitle(dom.Document document) {
    return document.querySelector('title')?.text.trim() ?? 'Untitled';
  }

  List<String> _extractTextByTags(dom.Document document, List<String> tags) {
    return tags
        .expand((tag) => document.querySelectorAll(tag))
        .map((e) => e.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();
  }
}

// import 'dart:convert';
// import 'package:flutter/foundation.dart';
// import 'package:http/http.dart' as http;
// import 'package:html/parser.dart' show parse;
// import 'package:html/dom.dart';
// import 'search_result_model.dart';
//
// class AssistantService {
//   /// Deep search that parses the current web page content
//   // static Future<List<SearchResult>> deepSearch(String domainUrl, String keyword) async {
//   //   try {
//   //     final response = await http.get(Uri.parse(domainUrl));
//   //     if (response.statusCode != 200) {
//   //       throw Exception('Failed to load page');
//   //     }
//   //
//   //     final document = parse(response.body);
//   //     final elements = [
//   //       ...document.getElementsByTagName('h1'),
//   //       ...document.getElementsByTagName('h2'),
//   //       ...document.getElementsByTagName('h3'),
//   //       ...document.getElementsByTagName('h4'),
//   //       ...document.getElementsByTagName('p'),
//   //     ];
//   //
//   //     final matches = elements.where((element) {
//   //       final text = element.text.trim().toLowerCase();
//   //       return text.contains(keyword.toLowerCase());
//   //     }).toList();
//   //
//   //     final baseUri = Uri.parse(domainUrl);
//   //     final favicon = 'https://www.google.com/s2/favicons?domain=${baseUri.host}';
//   //
//   //     return matches.asMap().entries.map((entry) {
//   //       final i = entry.key;
//   //       final element = entry.value;
//   //       return SearchResult(
//   //         title: element.text.trim(),
//   //         url: domainUrl,
//   //         favicon: favicon,
//   //       );
//   //     }).toList();
//   //   } catch (e) {
//   //     print('[AssistantService] Error: $e');
//   //     return [];
//   //   }
//   // }
//   static Future<List<SearchResult>> deepSearch(String domainUrl, String keyword) async {
//     try {
//       final response = await http.get(Uri.parse(domainUrl));
//       if (response.statusCode != 200) {
//         throw Exception('Failed to load page');
//       }
//
//       final document = parse(response.body);
//       final elements = [
//         ...document.getElementsByTagName('h1'),
//         ...document.getElementsByTagName('h2'),
//         ...document.getElementsByTagName('h3'),
//         ...document.getElementsByTagName('h4'),
//         ...document.getElementsByTagName('p'),
//       ];
//
//       final baseUri = Uri.parse(domainUrl);
//       final favicon = 'https://www.google.com/s2/favicons?domain=${baseUri.host}';
//
//       final matches = elements.where((element) {
//         final text = element.text.trim().toLowerCase();
//         return text.contains(keyword.toLowerCase());
//       }).toList();
//
//       return matches.map((element) {
//         String? id = element.id;
//         if (id == null || id.isEmpty) {
//           id = element.text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '-').replaceAll(RegExp(r'[^a-z0-9\-]'), '');
//         }
//
//         final anchorUrl = '${baseUri.toString()}#$id';
//
//         return SearchResult(
//           title: element.text.trim(),
//           url: anchorUrl,
//           favicon: favicon,
//         );
//       }).toList();
//     } catch (e) {
//       if (kDebugMode) {
//         print('[AssistantService] Error: $e');
//       }
//       return [];
//     }
//   }
//
//   // static Future<List<SearchResult>> deepSearch(String domainUrl, String keyword) async {
//   //   try {
//   //     final response = await http.get(Uri.parse(domainUrl));
//   //     if (response.statusCode != 200) {
//   //       throw Exception('Failed to load page');
//   //     }
//   //
//   //     final document = parse(response.body);
//   //     final elements = [
//   //       ...document.getElementsByTagName('h1'),
//   //       ...document.getElementsByTagName('h2'),
//   //       ...document.getElementsByTagName('h3'),
//   //       ...document.getElementsByTagName('h4'),
//   //       ...document.getElementsByTagName('p'),
//   //     ];
//   //
//   //     final baseUri = Uri.parse(domainUrl);
//   //     final favicon = 'https://www.google.com/s2/favicons?domain=${baseUri.host}';
//   //
//   //     final matches = elements.where((element) {
//   //       final text = element.text.trim().toLowerCase();
//   //       return text.contains(keyword.toLowerCase());
//   //     }).toList();
//   //
//   //     return matches.map((element) {
//   //       // Attempt to get the element's ID or generate one
//   //       String? id = element.id;
//   //       if (id == null || id.isEmpty) {
//   //         // Try to use parent or generate an artificial id
//   //         id = element.text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '-').replaceAll(RegExp(r'[^a-z0-9\-]'), '');
//   //       }
//   //
//   //       final anchorUrl = '${baseUri.toString()}#$id';
//   //
//   //       return SearchResult(
//   //         title: element.text.trim(),
//   //         url: anchorUrl,
//   //         favicon: favicon,
//   //       );
//   //     }).toList();
//   //   } catch (e) {
//   //     print('[AssistantService] Error: $e');
//   //     return [];
//   //   }
//   // }
//
//
//   /// Fallback mock for local testing
//   static Future<List<SearchResult>> mockResults(String domainUrl, String keyword) async {
//     await Future.delayed(const Duration(seconds: 2));
//     return List.generate(6, (i) => SearchResult(
//       title: 'Result for "$keyword" #$i',
//       url: '$domainUrl/page$i',
//       favicon: 'https://www.google.com/s2/favicons?domain=$domainUrl',
//     ));
//   }
// }
