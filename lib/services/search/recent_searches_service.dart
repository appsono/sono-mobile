import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sono/models/search/recent_search_model.dart';

/// Service for managing recent search queries with SharedPreferences
class RecentSearchesService {
  static const String _recentSearchesKey = 'recent_searches_v1';
  static const int _maxRecentSearches = 20;

  SharedPreferences? _prefs;

  /// Get SharedPreferences instance
  Future<SharedPreferences> get prefs async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  /// Get all recent searches => sorted by most recent first
  Future<List<RecentSearch>> getRecentSearches() async {
    try {
      final prefs = await this.prefs;
      final String? jsonString = prefs.getString(_recentSearchesKey);

      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final List<dynamic> jsonList = jsonDecode(jsonString);
      final searches =
          jsonList
              .map(
                (json) => RecentSearch.fromJson(json as Map<String, dynamic>),
              )
              .toList();

      //sort by timestamp => most recent first
      searches.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      return searches;
    } catch (e) {
      debugPrint('RecentSearchesService: Error loading recent searches: $e');
      return [];
    }
  }

  /// Add a new search to recent searches
  /// If query already exists => updates the timestamp
  Future<void> addRecentSearch(RecentSearch search) async {
    try {
      final searches = await getRecentSearches();

      //remove existing search with same query, case-sensitive
      searches.removeWhere(
        (s) => s.query.toLowerCase() == search.query.toLowerCase(),
      );

      //add new search at beginning
      searches.insert(0, search);

      //keep only most recent searches
      if (searches.length > _maxRecentSearches) {
        searches.removeRange(_maxRecentSearches, searches.length);
      }

      await _saveSearches(searches);
    } catch (e) {
      debugPrint('RecentSearchesService: Error adding recent search: $e');
    }
  }

  /// Remove a specific search from recent searches
  Future<void> removeRecentSearch(String query) async {
    try {
      final searches = await getRecentSearches();

      //emove search with matching query, case-insensitive
      searches.removeWhere((s) => s.query.toLowerCase() == query.toLowerCase());

      await _saveSearches(searches);
    } catch (e) {
      debugPrint('RecentSearchesService: Error removing recent search: $e');
    }
  }

  /// Clear all recent searches
  Future<void> clearRecentSearches() async {
    try {
      final prefs = await this.prefs;
      await prefs.remove(_recentSearchesKey);
    } catch (e) {
      debugPrint('RecentSearchesService: Error clearing recent searches: $e');
    }
  }

  /// Save searches list to SharedPreferences
  Future<void> _saveSearches(List<RecentSearch> searches) async {
    try {
      final prefs = await this.prefs;
      final jsonList = searches.map((s) => s.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      await prefs.setString(_recentSearchesKey, jsonString);
    } catch (e) {
      debugPrint('RecentSearchesService: Error saving searches: $e');
    }
  }

  /// Check if a query exists in recent searches
  Future<bool> hasRecentSearch(String query) async {
    final searches = await getRecentSearches();
    return searches.any((s) => s.query.toLowerCase() == query.toLowerCase());
  }

  /// Get recent search count
  Future<int> getRecentSearchCount() async {
    final searches = await getRecentSearches();
    return searches.length;
  }
}
