import 'api_client.dart';
import 'category_service.dart';
import '../models/product_model.dart';

class ProductService {
  Future<List<ProductModel>> getProducts({
    String? categoryId,
    bool? isFlashDeal,
    String? searchQuery,
    String sortBy = 'popular',
    double? minPrice,
    double? maxPrice,
    List<String>? brands,
    bool? inStockOnly,
    int limit = 50,
  }) async {
    final params = <String, String>{
      'limit': '$limit',
      if (categoryId != null) 'category_id': categoryId,
      if (searchQuery  != null && searchQuery.isNotEmpty) 'search': searchQuery,
      if (minPrice     != null) 'min_price': '$minPrice',
      if (maxPrice     != null) 'max_price': '$maxPrice',
      // Pass sort to backend so ORDER BY is server-side (sold_count, rating, price_low, price_high, newest)
      if (sortBy != 'popular') 'sort': sortBy,
    };
    final query = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    final res = await ApiClient.get('/api/products?$query', auth: false);
    if (!res.isSuccess) return [];
    try {
      final list = res.data!['products'] as List? ?? [];
      var products = list
          .map((p) => ProductModel.fromJson(p as Map<String, dynamic>))
          .toList();

      // Flash deals — filter client-side if no server param
      if (isFlashDeal == true) {
        products = products
            .where((p) =>
                p.flashDealPrice != null &&
                (p.flashDealExpiry == null || p.flashDealExpiry!.isAfter(DateTime.now())))
            .toList();
      }
      if (inStockOnly == true) {
        products = products.where((p) => p.stock > 0).toList();
      }
      if (brands != null && brands.isNotEmpty) {
        products = products.where((p) => brands.contains(p.brand)).toList();
      }

      // Sort
      int byDate(ProductModel a, ProductModel b) =>
          (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0));
      switch (sortBy) {
        case 'price_low':
          products.sort((a, b) {
            final c = a.price.compareTo(b.price); return c != 0 ? c : byDate(a, b);
          });
          break;
        case 'price_high':
          products.sort((a, b) {
            final c = b.price.compareTo(a.price); return c != 0 ? c : byDate(a, b);
          });
          break;
        case 'newest': products.sort(byDate); break;
        default: break;
      }
      return products;
    } catch (_) {
      return [];
    }
  }

  Future<ProductModel?> getProductById(String id) async {
    final res = await ApiClient.get('/api/products/$id', auth: false);
    if (!res.isSuccess || res.data == null) return null;
    try {
      return ProductModel.fromJson(res.data!);
    } catch (_) {
      return null;
    }
  }

  Future<List<ProductModel>> getFeaturedProducts({int limit = 6}) async {
    final res = await ApiClient.get('/api/products?is_featured=true&limit=$limit', auth: false);
    if (!res.isSuccess) return [];
    try {
      final list = res.data!['products'] as List? ?? [];
      return list.map((p) => ProductModel.fromJson(p as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<ProductModel>> getFlashDeals({int limit = 6}) async {
    final res = await ApiClient.get('/api/products?is_flash_deal=true&limit=$limit', auth: false);
    if (!res.isSuccess) return [];
    try {
      final list = res.data!['products'] as List? ?? [];
      return list.map((p) => ProductModel.fromJson(p as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<ProductModel>> getProductsByCategory(String categoryId, {String sortBy = 'popular'}) =>
      getProducts(categoryId: categoryId, sortBy: sortBy);

  Future<List<ProductModel>> searchProducts(String query, {int limit = 20}) =>
      getProducts(searchQuery: query, limit: limit);

  // ── Section-specific fetchers ────────────────────────────────

  /// Best sellers — ordered by sold_count DESC on the server
  Future<List<ProductModel>> getBestSellers({int limit = 50}) =>
      getProducts(sortBy: 'sold_count', limit: limit);

  /// New arrivals — ordered by created_at DESC
  Future<List<ProductModel>> getNewArrivals({int limit = 50}) =>
      getProducts(sortBy: 'newest', limit: limit);

  /// Staff picks — is_staff_pick = true
  Future<List<ProductModel>> getStaffPicks({int limit = 50}) async {
    final params = <String, String>{
      'is_staff_pick': 'true',
      'limit': '$limit',
    };
    final query = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    final res = await ApiClient.get('/api/products?$query', auth: false);
    if (!res.isSuccess) return [];
    try {
      final list = res.data!['products'] as List? ?? [];
      return list.map((p) => ProductModel.fromJson(p as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Products under a price cap
  Future<List<ProductModel>> getUnderPrice(double maxPrice, {int limit = 50}) =>
      getProducts(maxPrice: maxPrice, sortBy: 'price_low', limit: limit);

  /// Products by brand name (ILIKE on server)
  Future<List<ProductModel>> getByBrand(String brandName, {int limit = 100}) async {
    final params = <String, String>{
      'brand': brandName,
      'limit': '$limit',
    };
    final query = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    final res = await ApiClient.get('/api/products?$query', auth: false);
    if (!res.isSuccess) return [];
    try {
      final list = res.data!['products'] as List? ?? [];
      return list.map((p) => ProductModel.fromJson(p as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Products linked to a luxury collection.
  /// For 'manual' source_type: fetches from /:id/products endpoint (curated list).
  /// For 'category' source_type: resolves category_slug → products.
  Future<List<ProductModel>> getCollectionProducts(String collectionId, {int limit = 100}) async {
    final res = await ApiClient.get('/api/luxury-collections/$collectionId', auth: false);
    if (!res.isSuccess) return [];
    try {
      final col = res.data!;
      final sourceType = col['source_type'] as String? ?? 'category';

      if (sourceType == 'manual') {
        // Fetch manually-curated products from the collection_products table
        final prodRes = await ApiClient.get(
          '/api/luxury-collections/$collectionId/products', auth: false);
        if (!prodRes.isSuccess) return [];
        final raw = prodRes.data!;
        final list = raw['_list'] as List? ?? [];
        return list
            .map((p) => ProductModel.fromJson(p as Map<String, dynamic>))
            .toList();
      }

      // Category-based: resolve slug → category → products
      final slug = col['category_slug'] as String?
          ?? col['source_value'] as String?;
      if (slug == null || slug.isEmpty) return [];
      final cat = await CategoryService().getCategoryBySlug(slug);
      if (cat == null) return [];
      return getProductsByCategory(cat.id, sortBy: 'popular');
    } catch (_) {
      return [];
    }
  }

  Future<List<String>> getBrands({String? categoryId}) async {
    final products = await getProducts(categoryId: categoryId, limit: 200);
    return products
        .map((p) => p.brand ?? '')
        .where((b) => b.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }
}
