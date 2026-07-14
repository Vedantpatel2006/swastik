import 'index.dart';

/// Search filters for comprehensive search
class SearchFilters {
  final bool includeTemples;
  final bool includeEvents;
  final bool includeCommunity;
  final List<String>? traditions;
  final bool? hasLiveDarshan;
  final Location? location;
  final double? radius;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? templeId;
  final List<String>? eventTypes;
  final List<String>? postTypes;
  final double? minRating;
  final String? sortBy;
  final bool descending;

  const SearchFilters({
    this.includeTemples = true,
    this.includeEvents = true,
    this.includeCommunity = true,
    this.traditions,
    this.hasLiveDarshan,
    this.location,
    this.radius,
    this.startDate,
    this.endDate,
    this.templeId,
    this.eventTypes,
    this.postTypes,
    this.minRating,
    this.sortBy,
    this.descending = true,
  });

  /// Create SearchFilters from JSON
  factory SearchFilters.fromJson(Map<String, dynamic> json) {
    return SearchFilters(
      includeTemples: json['includeTemples'] as bool? ?? true,
      includeEvents: json['includeEvents'] as bool? ?? true,
      includeCommunity: json['includeCommunity'] as bool? ?? true,
      traditions: json['traditions'] != null
          ? List<String>.from(json['traditions'] as List)
          : null,
      hasLiveDarshan: json['hasLiveDarshan'] as bool?,
      location: json['location'] != null
          ? Location.fromJson(json['location'] as Map<String, dynamic>)
          : null,
      radius: json['radius'] as double?,
      startDate: json['startDate'] != null
          ? DateTime.parse(json['startDate'] as String)
          : null,
      endDate: json['endDate'] != null
          ? DateTime.parse(json['endDate'] as String)
          : null,
      templeId: json['templeId'] as String?,
      eventTypes: json['eventTypes'] != null
          ? List<String>.from(json['eventTypes'] as List)
          : null,
      postTypes: json['postTypes'] != null
          ? List<String>.from(json['postTypes'] as List)
          : null,
      minRating: json['minRating'] as double?,
      sortBy: json['sortBy'] as String?,
      descending: json['descending'] as bool? ?? true,
    );
  }

  /// Convert SearchFilters to JSON
  Map<String, dynamic> toJson() {
    return {
      'includeTemples': includeTemples,
      'includeEvents': includeEvents,
      'includeCommunity': includeCommunity,
      if (traditions != null) 'traditions': traditions,
      if (hasLiveDarshan != null) 'hasLiveDarshan': hasLiveDarshan,
      if (location != null) 'location': location!.toJson(),
      if (radius != null) 'radius': radius,
      if (startDate != null) 'startDate': startDate!.toIso8601String(),
      if (endDate != null) 'endDate': endDate!.toIso8601String(),
      if (templeId != null) 'templeId': templeId,
      if (eventTypes != null) 'eventTypes': eventTypes,
      if (postTypes != null) 'postTypes': postTypes,
      if (minRating != null) 'minRating': minRating,
      if (sortBy != null) 'sortBy': sortBy,
      'descending': descending,
    };
  }

  /// Create a copy with updated fields
  SearchFilters copyWith({
    bool? includeTemples,
    bool? includeEvents,
    bool? includeCommunity,
    List<String>? traditions,
    bool? hasLiveDarshan,
    Location? location,
    double? radius,
    DateTime? startDate,
    DateTime? endDate,
    String? templeId,
    List<String>? eventTypes,
    List<String>? postTypes,
    double? minRating,
    String? sortBy,
    bool? descending,
  }) {
    return SearchFilters(
      includeTemples: includeTemples ?? this.includeTemples,
      includeEvents: includeEvents ?? this.includeEvents,
      includeCommunity: includeCommunity ?? this.includeCommunity,
      traditions: traditions ?? this.traditions,
      hasLiveDarshan: hasLiveDarshan ?? this.hasLiveDarshan,
      location: location ?? this.location,
      radius: radius ?? this.radius,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      templeId: templeId ?? this.templeId,
      eventTypes: eventTypes ?? this.eventTypes,
      postTypes: postTypes ?? this.postTypes,
      minRating: minRating ?? this.minRating,
      sortBy: sortBy ?? this.sortBy,
      descending: descending ?? this.descending,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SearchFilters &&
        other.includeTemples == includeTemples &&
        other.includeEvents == includeEvents &&
        other.includeCommunity == includeCommunity &&
        _listEquals(other.traditions, traditions) &&
        other.hasLiveDarshan == hasLiveDarshan &&
        other.location == location &&
        other.radius == radius &&
        other.startDate == startDate &&
        other.endDate == endDate &&
        other.templeId == templeId &&
        _listEquals(other.eventTypes, eventTypes) &&
        _listEquals(other.postTypes, postTypes) &&
        other.minRating == minRating &&
        other.sortBy == sortBy &&
        other.descending == descending;
  }

  @override
  int get hashCode {
    return Object.hashAll([
      includeTemples,
      includeEvents,
      includeCommunity,
      traditions,
      hasLiveDarshan,
      location,
      radius,
      startDate,
      endDate,
      templeId,
      eventTypes,
      postTypes,
      minRating,
      sortBy,
      descending,
    ]);
  }

  bool _listEquals(List<String>? a, List<String>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Search results containing all content types
class SearchResults {
  final String query;
  final List<Temple> temples;
  final List<Event> events;
  final List<Review> reviews;
  final List<CommunityPost> posts;
  int totalResults;
  final DateTime searchTime;

  SearchResults({
    required this.query,
    required this.temples,
    required this.events,
    required this.reviews,
    required this.posts,
    required this.totalResults,
    required this.searchTime,
  });

  /// Create empty search results
  factory SearchResults.empty() {
    return SearchResults(
      query: '',
      temples: [],
      events: [],
      reviews: [],
      posts: [],
      totalResults: 0,
      searchTime: DateTime.now(),
    );
  }

  /// Create SearchResults from JSON
  factory SearchResults.fromJson(Map<String, dynamic> json) {
    return SearchResults(
      query: json['query'] as String,
      temples: json['temples'] != null
          ? (json['temples'] as List)
                .map((t) => Temple.fromJson(t as Map<String, dynamic>))
                .toList()
          : [],
      events: json['events'] != null
          ? (json['events'] as List)
                .map((e) => Event.fromJson(e as Map<String, dynamic>))
                .toList()
          : [],
      reviews: json['reviews'] != null
          ? (json['reviews'] as List)
                .map((r) => Review.fromJson(r as Map<String, dynamic>))
                .toList()
          : [],
      posts: json['posts'] != null
          ? (json['posts'] as List)
                .map((p) => CommunityPost.fromJson(p as Map<String, dynamic>))
                .toList()
          : [],
      totalResults: json['totalResults'] as int,
      searchTime: DateTime.parse(json['searchTime'] as String),
    );
  }

  /// Convert SearchResults to JSON
  Map<String, dynamic> toJson() {
    return {
      'query': query,
      'temples': temples.map((t) => t.toJson()).toList(),
      'events': events.map((e) => e.toJson()).toList(),
      'reviews': reviews.map((r) => r.toJson()).toList(),
      'posts': posts.map((p) => p.toJson()).toList(),
      'totalResults': totalResults,
      'searchTime': searchTime.toIso8601String(),
    };
  }

  /// Check if results are empty
  bool get isEmpty {
    return temples.isEmpty &&
        events.isEmpty &&
        reviews.isEmpty &&
        posts.isEmpty;
  }

  /// Check if results are not empty
  bool get isNotEmpty => !isEmpty;

  /// Get all results as a mixed list
  List<dynamic> get allResults {
    final results = <dynamic>[];
    results.addAll(temples);
    results.addAll(events);
    results.addAll(reviews);
    results.addAll(posts);
    return results;
  }

  /// Get results by category
  Map<String, List<dynamic>> get resultsByCategory {
    return {
      'temples': temples,
      'events': events,
      'reviews': reviews,
      'posts': posts,
    };
  }

  /// Get result counts by category
  Map<String, int> get resultCounts {
    return {
      'temples': temples.length,
      'events': events.length,
      'reviews': reviews.length,
      'posts': posts.length,
    };
  }

  @override
  String toString() {
    return 'SearchResults(query: $query, totalResults: $totalResults, '
        'temples: ${temples.length}, events: ${events.length}, '
        'reviews: ${reviews.length}, posts: ${posts.length})';
  }
}

/// Search suggestion with metadata
class SearchSuggestion {
  final String text;
  final SearchSuggestionType type;
  final String? category;
  final int? popularity;
  final Map<String, dynamic>? metadata;

  const SearchSuggestion({
    required this.text,
    required this.type,
    this.category,
    this.popularity,
    this.metadata,
  });

  /// Create SearchSuggestion from JSON
  factory SearchSuggestion.fromJson(Map<String, dynamic> json) {
    return SearchSuggestion(
      text: json['text'] as String,
      type: SearchSuggestionType.values[json['type'] as int],
      category: json['category'] as String?,
      popularity: json['popularity'] as int?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Convert SearchSuggestion to JSON
  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'type': type.index,
      if (category != null) 'category': category,
      if (popularity != null) 'popularity': popularity,
      if (metadata != null) 'metadata': metadata,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SearchSuggestion &&
        other.text == text &&
        other.type == type &&
        other.category == category &&
        other.popularity == popularity;
  }

  @override
  int get hashCode {
    return Object.hash(text, type, category, popularity);
  }
}

/// Types of search suggestions
enum SearchSuggestionType {
  history,
  popular,
  temple,
  event,
  location,
  tradition,
  autocomplete,
}

/// Voice search result
class VoiceSearchResult {
  final String? recognizedText;
  final double confidence;
  final bool isComplete;
  final String? error;

  const VoiceSearchResult({
    this.recognizedText,
    required this.confidence,
    required this.isComplete,
    this.error,
  });

  /// Check if result is successful
  bool get isSuccessful => recognizedText != null && error == null;

  /// Check if result has error
  bool get hasError => error != null;

  @override
  String toString() {
    return 'VoiceSearchResult(text: $recognizedText, confidence: $confidence, '
        'complete: $isComplete, error: $error)';
  }
}
