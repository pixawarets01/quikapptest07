class SearchResult {
  final String title;
  final String content;
  final String url;
  final Map<String, dynamic> metadata;
  final String favicon;

  SearchResult({
    required this.title,
    required this.content,
    required this.url,
    required this.metadata,
    required this.favicon,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      url: json['url'] ?? '',
      favicon: json['favicon'] ?? '',
      metadata: json['metadata'] ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'content': content,
      'url': url,
      'favicon': favicon,
      'metadata': metadata,
    };
  }
}

// class SearchResult {
//   final String title;
//   final String url;
//   final String favicon;
//
//   SearchResult({
//     required this.title,
//     required this.url,
//     required this.favicon,
//   });
//
//   factory SearchResult.fromJson(Map<String, dynamic> json) {
//     return SearchResult(
//       title: json['title'] ?? '',
//       url: json['url'] ?? '',
//       favicon: json['favicon'] ?? '',
//     );
//   }
//
//   Map<String, dynamic> toJson() {
//     return {
//       'title': title,
//       'url': url,
//       'favicon': favicon,
//     };
//   }
// }
