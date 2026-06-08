import 'api_client.dart';
import '../models/category_model.dart';

class CategoryService {
  // ── Fallback parent categories (used when backend unreachable) ─
  // Matches the full hierarchy from category_migration.sql
  static final List<CategoryModel> _fallbackParents = [
    CategoryModel(id: 'p1',  name: 'Fashion',                   slug: 'fashion',                  displayOrder: 1,
        imageUrl: 'https://images.unsplash.com/photo-1490481651871-ab68de25d43d?w=400'),
    CategoryModel(id: 'p2',  name: 'Watches',                   slug: 'watches',                  displayOrder: 2,
        imageUrl: 'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=400'),
    CategoryModel(id: 'p3',  name: 'Beauty & Personal Care',    slug: 'beauty-personal-care',     displayOrder: 3,
        imageUrl: 'https://images.unsplash.com/photo-1596462502278-27bfdc403348?w=400'),
    CategoryModel(id: 'p4',  name: 'Electronics',               slug: 'electronics',              displayOrder: 4,
        imageUrl: 'https://images.unsplash.com/photo-1498049794561-7780e7231661?w=400'),
    CategoryModel(id: 'p5',  name: 'Home Decor',                slug: 'home-decor',               displayOrder: 5,
        imageUrl: 'https://images.unsplash.com/photo-1586023492125-27b2c045efd7?w=400'),
    CategoryModel(id: 'p6',  name: 'Jewelry & Accessories',     slug: 'jewelry-accessories',      displayOrder: 6,
        imageUrl: 'https://images.unsplash.com/photo-1515562141207-7a88fb7ce338?w=400'),
    CategoryModel(id: 'p7',  name: 'Bags & Luggage',            slug: 'bags-luggage',             displayOrder: 7,
        imageUrl: 'https://images.unsplash.com/photo-1622560480605-d83c853bc5c3?w=400'),
    CategoryModel(id: 'p8',  name: 'Footwear',                  slug: 'footwear',                 displayOrder: 8,
        imageUrl: 'https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=400'),
    CategoryModel(id: 'p9',  name: 'Gifts & Luxury Collections',slug: 'gifts-luxury-collections', displayOrder: 9,
        imageUrl: 'https://images.unsplash.com/photo-1513201099705-a9746072228d?w=400'),
    CategoryModel(id: 'p10', name: 'Health & Wellness',         slug: 'health-wellness',          displayOrder: 10,
        imageUrl: 'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=400'),
    CategoryModel(id: 'p11', name: 'Mobiles & Accessories',     slug: 'mobiles-accessories',      displayOrder: 11,
        imageUrl: 'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?w=400'),
    CategoryModel(id: 'p12', name: 'Seasonal Collections',      slug: 'seasonal-collections',     displayOrder: 12,
        imageUrl: 'https://images.unsplash.com/photo-1607082348824-0a96f2a4b9da?w=400'),
    CategoryModel(id: 'p13', name: 'Featured Categories',       slug: 'featured-categories',      displayOrder: 13,
        imageUrl: 'https://images.unsplash.com/photo-1607082349566-187342175e2f?w=400'),
  ];

  List<CategoryModel> _parse(dynamic data) {
    if (data is! List) return [];
    return data
        .map((c) => CategoryModel.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  Future<List<CategoryModel>> getParentCategories() async {
    final res = await ApiClient.get('/api/categories/parents', auth: false);
    if (!res.isSuccess) return _fallbackParents;
    final list = _parse(res.data!['_list']);
    return list.isNotEmpty ? list : _fallbackParents;
  }

  Future<List<CategoryModel>> getSubcategories(String parentId) async {
    // Detect fake fallback IDs (e.g. 'p1'..'p13') and resolve to real UUID via slug
    String resolvedId = parentId;
    if (RegExp(r'^p\d+$').hasMatch(parentId)) {
      // Find the slug for this fake ID in the fallback list
      final fallback = _fallbackParents.firstWhere(
        (c) => c.id == parentId,
        orElse: () => _fallbackParents.first,
      );
      final slugRes = await ApiClient.get(
        '/api/categories/slug/${fallback.slug}',
        auth: false,
      );
      if (slugRes.isSuccess && slugRes.data != null) {
        resolvedId = slugRes.data!['id'] as String? ?? parentId;
      } else {
        return []; // backend unreachable — can't load subcategories
      }
    }
    final res = await ApiClient.get(
      '/api/categories/$resolvedId/subcategories',
      auth: false,
    );
    if (!res.isSuccess) return [];
    return _parse(res.data!['_list']);
  }

  /// Resolve a category by slug — used by luxury collection product fetch
  Future<CategoryModel?> getCategoryBySlug(String slug) async {
    final res = await ApiClient.get('/api/categories/slug/$slug', auth: false);
    if (!res.isSuccess || res.data == null) return null;
    try {
      return CategoryModel.fromJson(res.data!);
    } catch (_) {
      return null;
    }
  }

  Future<List<CategoryModel>> getCategories() async {
    final res = await ApiClient.get('/api/categories', auth: false);
    if (!res.isSuccess) return _fallbackParents;
    final list = _parse(res.data!['_list']);
    // Return only parent categories for the home screen grid
    final parents = list.where((c) => c.isParent).toList();
    return parents.isNotEmpty ? parents : _fallbackParents;
  }

  // Returns full tree: parents with nested children list
  Future<List<Map<String, dynamic>>> getCategoryTree() async {
    final res = await ApiClient.get('/api/categories/tree', auth: false);
    if (!res.isSuccess) return [];
    final list = res.data!['_list'];
    if (list is! List) return [];
    return List<Map<String, dynamic>>.from(list);
  }

  Future<CategoryModel?> getCategoryById(String id) async {
    final res = await ApiClient.get('/api/categories/$id', auth: false);
    if (!res.isSuccess || res.data == null) return null;
    try {
      return CategoryModel.fromJson(res.data!);
    } catch (_) {
      return null;
    }
  }
}
