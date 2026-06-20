import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/api_client.dart';
import '../models/brand_model.dart';
import '../models/category_model.dart';
import '../models/homepage_section.dart';
import '../models/luxury_collection_model.dart';

const _kCacheKey = 'homepage_cache_v1';

class HomepageProvider extends ChangeNotifier {
  List<Map<String, dynamic>>   banners            = [];
  List<CategoryModel>          categories         = [];
  List<BrandModel>             brands             = [];
  List<HomepageSection>        sections           = [];
  List<Map<String, dynamic>>   featuredReviews    = [];
  Map<String, String>          socialLinks        = {};
  List<LuxuryCollectionModel>  luxuryCollections  = [];
  bool                         isLoading          = true;
  String?                      error;
  bool                         _hasLoaded         = false;
  bool                         _isFetching        = false;

  bool get hasLoaded => _hasLoaded;

  // ── Load: show cache immediately, refresh in background ───────
  Future<void> load({bool force = false}) async {
    if (_hasLoaded && !force) return;

    // 1. Try cache first — instant display, no skeleton flash
    final hadCache = await _loadFromCache();
    if (hadCache) {
      // Already showing cached content; fetch fresh silently
      _fetchAndCache(showLoadingOnEmpty: false);
    } else {
      // No cache — show skeleton until first fetch completes
      isLoading = true;
      notifyListeners();
      await _fetchAndCache(showLoadingOnEmpty: true);
    }
  }

  Future<void> refresh() async {
    await _fetchAndCache(showLoadingOnEmpty: false);
  }

  // ── Read cache → parse → notify immediately ───────────────────
  Future<bool> _loadFromCache() async {
    try {
      final prefs  = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 2));
      final cached = prefs.getString(_kCacheKey);
      if (cached == null) return false;
      final data   = json.decode(cached) as Map<String, dynamic>;
      _parseData(data);
      isLoading  = false;
      _hasLoaded = true;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Fetch from API → parse → cache → notify ──────────────────
  Future<void> _fetchAndCache({required bool showLoadingOnEmpty}) async {
    if (_isFetching) return; // already in-flight — don't double-fetch
    _isFetching = true;
    try {
      final res = await ApiClient.get('/api/homepage');
      if (!res.isSuccess) {
        if (showLoadingOnEmpty) {
          error     = res.error;
          isLoading = false;
          _hasLoaded = true;
          notifyListeners();
        }
        return;
      }
      final data = res.data!;
      _parseData(data);
      isLoading  = false;
      _hasLoaded = true;
      error      = null;
      notifyListeners();
      _writeCache(data);
    } catch (e) {
      debugPrint('HomepageProvider.load error: $e');
      if (showLoadingOnEmpty) {
        error     = e.toString();
        isLoading = false;
        _hasLoaded = true;
        notifyListeners();
      }
    } finally {
      _isFetching = false;
    }
  }

  // ── Parse raw API map into typed fields ───────────────────────
  void _parseData(Map<String, dynamic> data) {
    banners = (data['banners'] as List? ?? [])
        .whereType<Map>()
        .map((b) => Map<String, dynamic>.from(b))
        .toList();

    categories = (data['categories'] as List? ?? [])
        .whereType<Map>()
        .map((c) => CategoryModel.fromJson(Map<String, dynamic>.from(c)))
        .toList();

    brands = (data['brands'] as List? ?? [])
        .whereType<Map>()
        .map((b) => BrandModel.fromJson(Map<String, dynamic>.from(b)))
        .toList();

    sections = (data['sections'] as List? ?? [])
        .whereType<Map>()
        .map((s) => HomepageSection.fromJson(Map<String, dynamic>.from(s)))
        .where((s) => !s.isEmpty)
        .toList();

    featuredReviews = (data['featured_reviews'] as List? ?? [])
        .whereType<Map>()
        .map((r) => Map<String, dynamic>.from(r))
        .toList();

    final rawLinks = data['social_links'];
    if (rawLinks is Map) {
      socialLinks = rawLinks.map(
        (k, v) => MapEntry(k.toString(), v?.toString() ?? ''),
      );
    }

    luxuryCollections = (data['luxury_collections'] as List? ?? [])
        .whereType<Map>()
        .map((c) => LuxuryCollectionModel.fromJson(Map<String, dynamic>.from(c)))
        .toList();
  }

  // ── Write raw API response to cache (fire-and-forget) ─────────
  void _writeCache(Map<String, dynamic> data) {
    SharedPreferences.getInstance().then((prefs) {
      try { prefs.setString(_kCacheKey, json.encode(data)); } catch (_) {}
    }).catchError((_) {});
  }

  // ── Fire-and-forget tracking ──────────────────────────────────
  void trackView(String productId) {
    ApiClient.post('/api/homepage/view', {'product_id': productId})
        .catchError((_) => const ApiResponse(data: null, error: 'ignored'));
  }

  void trackClick({required String sectionKey, required String productId}) {
    ApiClient.post('/api/homepage/analytics', {
      'event_type':  'product_click',
      'section_key': sectionKey,
      'product_id':  productId,
    }).catchError((_) => const ApiResponse(data: null, error: 'ignored'));
  }

  // ── Reset on logout ───────────────────────────────────────────
  void clear() {
    banners           = [];
    categories        = [];
    brands            = [];
    sections          = [];
    featuredReviews   = [];
    socialLinks       = {};
    luxuryCollections = [];
    _hasLoaded        = false;
    _isFetching       = false;
    isLoading         = true;
    // Keep the cache so the next login shows content instantly (stale-while-revalidate).
    // Fresh personalized data replaces it silently in the background after re-fetch.
    notifyListeners();
  }
}
