import 'package:flutter/material.dart';
import '../data/wishlist_service.dart';
import '../models/product_model.dart';

class WishlistProvider extends ChangeNotifier {
  final WishlistService _service = WishlistService();

  List<ProductModel> _products    = [];
  Set<String>        _ids         = {};
  bool               _isLoading   = false;

  // ── Getters ───────────────────────────────────────────────────
  List<ProductModel> get products  => _products;
  Set<String>        get ids       => _ids;
  bool               get isLoading => _isLoading;
  int                get count     => _ids.length;

  bool isWishlisted(String productId) => _ids.contains(productId);

  // ── Load full wishlist (products + IDs) ───────────────────────
  Future<void> loadWishlist() async {
    _isLoading = true;
    notifyListeners();
    try {
      _products = await _service.getWishlist();
      _ids      = _products.map((p) => p.id).toSet();
    } catch (_) {
      _products = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Load only IDs (fast — used for heart icons across the app) ─
  Future<void> loadIds() async {
    try {
      _ids = await _service.getWishlistIds();
      notifyListeners();
    } catch (_) {}
  }

  // ── Toggle (optimistic) ───────────────────────────────────────
  Future<void> toggleWishlist(String productId,
      {ProductModel? product}) async {
    if (_ids.contains(productId)) {
      // Remove
      _ids.remove(productId);
      _products.removeWhere((p) => p.id == productId);
      notifyListeners();
      await _service.removeFromWishlist(productId);
    } else {
      // Add
      _ids.add(productId);
      if (product != null) _products.insert(0, product);
      notifyListeners();
      await _service.addToWishlist(productId);
    }
  }

  // ── Remove (called from wishlist screen) ─────────────────────
  Future<void> removeFromWishlist(String productId) async {
    _ids.remove(productId);
    _products.removeWhere((p) => p.id == productId);
    notifyListeners();
    await _service.removeFromWishlist(productId);
  }

  // ── Reset on logout ───────────────────────────────────────────
  void clear() {
    _products = [];
    _ids      = {};
    notifyListeners();
  }
}
