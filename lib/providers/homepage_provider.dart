import 'package:flutter/material.dart';
import '../data/api_client.dart';
import '../models/brand_model.dart';
import '../models/category_model.dart';
import '../models/homepage_section.dart';
import '../models/luxury_collection_model.dart';

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

  bool get hasLoaded => _hasLoaded;

  // ── Load all homepage data in one call ────────────────────────
  Future<void> load({bool force = false}) async {
    if (_hasLoaded && !force) return;
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final res = await ApiClient.get('/api/homepage');
      if (!res.isSuccess) {
        error = res.error;
        return;
      }

      final data = res.data!;

      banners = (data['banners'] as List? ?? [])
          .cast<Map<String, dynamic>>();

      categories = (data['categories'] as List? ?? [])
          .map((c) => CategoryModel.fromJson(c as Map<String, dynamic>))
          .toList();

      brands = (data['brands'] as List? ?? [])
          .map((b) => BrandModel.fromJson(b as Map<String, dynamic>))
          .toList();

      sections = (data['sections'] as List? ?? [])
          .map((s) => HomepageSection.fromJson(s as Map<String, dynamic>))
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
          .map((c) => LuxuryCollectionModel.fromJson(
                Map<String, dynamic>.from(c)))
          .toList();
    } catch (e) {
      error = e.toString();
      debugPrint('HomepageProvider.load error: $e');
    } finally {
      _hasLoaded = true;
      isLoading  = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => load(force: true);

  // ── Fire-and-forget: record product view for "Recently Viewed" ─
  void trackView(String productId) {
    ApiClient.post('/api/homepage/view', {'product_id': productId})
        .catchError((_) => const ApiResponse(data: null, error: 'ignored'));
  }

  // ── Fire-and-forget: record analytics event ──────────────────
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
    notifyListeners();
  }
}
