import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../chat/search_result_model.dart';
import '../chat/voice_input_card.dart';
import 'package:url_launcher/url_launcher.dart';

import 'assistant_service.dart';

class SmartAssistantWidget extends StatefulWidget {
  final Function(bool) onVisibilityChanged;
  final String currentUrl;

  final InAppWebViewController webViewController;

  const SmartAssistantWidget({
    super.key,
    required this.webViewController,
    required this.onVisibilityChanged,
    required this.currentUrl,
  });

  @override
  State<SmartAssistantWidget> createState() => _SmartAssistantWidgetState();
}

class _SmartAssistantWidgetState extends State<SmartAssistantWidget> {
  InAppWebViewController? webViewController;
  final TextEditingController _searchController = TextEditingController();
  bool isListening = false;
  List<SearchResult> searchResults = [];
  bool isFullScreen = false;
  bool isDarkMode = false;
  bool isLoading = false;
  @override
  void initState() {
    super.initState();
    webViewController = widget.webViewController;
  }

  void _onSearch() async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) return;

    setState(() {
      searchResults.clear();
      isLoading = true;
    });

    // TODO: Replace with actual deep domain parsing logic
    final results = await AssistantService()
        .deepSearchFromDomain(widget.currentUrl, keyword);

    // final results = await AssistantService.deepSearch(widget.currentUrl, keyword);

    setState(() {
      searchResults = results;
      isLoading = false;
    });
  }

  void _onVoiceInput(String text) {
    setState(() {
      _searchController.text = text;
    });
    _onSearch();
  }

  void _openResultInWebView(SearchResult result) async {
    final url = result.url;
    if (url != null && widget.webViewController != null) {
      await widget.webViewController!
          .loadUrl(urlRequest: URLRequest(url: WebUri(url)));

      // Optionally, scroll to a specific element if necessary
      if (result.title != null) {
        final js = """
          const el = [...document.querySelectorAll('*')].find(el => el.innerText.includes("${result.title!.replaceAll('"', '')}"));
          if (el) el.scrollIntoView({behavior: 'smooth'});
        """;
        await widget.webViewController!.evaluateJavascript(source: js);
        widget.onVisibilityChanged(false);
      }
    }
  }

  Future<void> _handleUrl(String url) async {
    if (url.startsWith('tel:') ||
        url.startsWith('mailto:') ||
        url.startsWith('whatsapp:') ||
        url.startsWith('sms:')) {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      } else {
        throw 'Could not launch $url';
      }
    } else {
      await widget.webViewController!.loadUrl(
        urlRequest: URLRequest(url: WebUri(url)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = isDarkMode ? ThemeData.dark() : ThemeData.light();

    return Theme(
      data: theme,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: isFullScreen
            ? AppBar(
                title: const Text("Smart Assistant"),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close_fullscreen),
                    onPressed: () => setState(() => isFullScreen = false),
                  )
                ],
              )
            : null,
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Enter your command or search keyword...',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _onSearch(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.mic),
                    onPressed: () => showModalBottomSheet(
                      context: context,
                      builder: (_) => VoiceInputCard(
                        onResult: _onVoiceInput,
                        recognizedText: '',
                        onClose: () {},
                        isListening: isListening,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _onSearch,
                  ),
                ],
              ),
            ),
            if (isLoading) const Center(child: CircularProgressIndicator()),
            if (!isLoading)
              Expanded(
                child: searchResults.isEmpty
                    ? Center(
                        child: Text(
                          _searchController.text.isEmpty
                              ? "👋 Welcome to ${_getCleanHost(Uri.parse(widget.currentUrl))} Assistant!"
                              : "❌ No results found for '${_searchController.text}'",
                          style: const TextStyle(fontSize: 18),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(8.0),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                                childAspectRatio: 1.5),
                        itemCount: searchResults.length,
                        itemBuilder: (_, index) {
                          final result = searchResults[index];
                          return GestureDetector(
                            onTap: () => _openResultInWebView(result),
                            child: Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 4,
                              child: Padding(
                                padding: const EdgeInsets.all(10.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Image.network(
                                          scale: 0.7,
                                          result.favicon,
                                          width: 30,
                                          height: 30,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(Icons.link),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            result.title,
                                            style: TextStyle(fontSize: 16),
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    )
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => setState(() => isDarkMode = !isDarkMode),
          child: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
        ),
      ),
    );
  }

  String _getCleanHost(Uri uri) {
    final host = uri.host;
    return host.startsWith('www.') ? host.substring(4) : host;
  }
}

// class SearchResult {
//   final String title;
//   final String url;
//   final String favicon;
//
//   SearchResult({required this.title, required this.url, required this.favicon});
// }
//
// class AssistantService {
//   static Future<List<SearchResult>> deepSearch(String domainUrl, String keyword) async {
//     // Mocked data for testing
//     await Future.delayed(const Duration(seconds: 2));
//     return List.generate(6, (i) => SearchResult(
//       title: 'Result for "$keyword" #$i',
//       url: '$domainUrl/page$i',
//       favicon: 'https://www.google.com/s2/favicons?domain=$domainUrl',
//     ));
//   }
// }
