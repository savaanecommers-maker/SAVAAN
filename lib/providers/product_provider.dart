import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../data/category_service.dart';
import '../data/product_service.dart';
import '../models/category_model.dart';
import '../models/product_model.dart';

class ProductProvider extends ChangeNotifier {
  final ProductService  _productService  = ProductService();
  final CategoryService _categoryService = CategoryService();

  List<CategoryModel> _categories       = [];
  List<ProductModel>  _featuredProducts = [];
  List<ProductModel>  _flashDeals       = [];
  bool                _isLoading        = false;
  bool                _hasLoaded        = false; // prevents redundant fetches

  // ── Getters ───────────────────────────────────────────────────
  List<CategoryModel> get categories       => _categories;
  List<ProductModel>  get featuredProducts => _featuredProducts;
  List<ProductModel>  get flashDeals       => _flashDeals;
  bool                get isLoading        => _isLoading;
  bool                get hasLoaded        => _hasLoaded;

  // ── Load home screen data in parallel ────────────────────────
  Future<void> loadHomeData({bool force = false}) async {
    if (_hasLoaded && !force) return; // use cache unless forced
    _isLoading = true;
    notifyListeners();

    try {
      final results = await Future.wait([
        _categoryService.getCategories(),
        _productService.getFeaturedProducts(limit: 6),
        _productService.getFlashDeals(limit: 6),
      ]);

      _categories       = results[0] as List<CategoryModel>;
      _featuredProducts = results[1] as List<ProductModel>;
      _flashDeals       = results[2] as List<ProductModel>;
    } catch (e) {
      debugPrint('ProductProvider loadHomeData error: $e');
      // Keep empty lists — user can pull-to-refresh to retry
    } finally {
      _hasLoaded = true; // mark as attempted regardless of success/failure
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Refresh (pull-to-refresh) ─────────────────────────────────
  Future<void> refresh() => loadHomeData(force: true);

  // ── Reset on logout ───────────────────────────────────────────
  void clear() {
    _categories       = [];
    _featuredProducts = [];
    _flashDeals       = [];
    _hasLoaded        = false;
    notifyListeners();
  }
}
