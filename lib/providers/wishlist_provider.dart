import 'package:flutter/material.dart';
import '../data/wishlist_service.dart';
import '../models/product_model.dart';

class WishlistProvider extends ChangeNotifier {
  final WishlistService _service = WishlistService();

  List<ProductModel> _products    = [];
  Set<String>        _ids         = {};
  bool               _isLoading   = false;
  String?            _loadError;
  String?            _toggleError;

  // ── Getters ───────────────────────────────────────────────────
  List<ProductModel> get products    => _products;
  Set<String>        get ids         => _ids;
  bool               get isLoading   => _isLoading;
  int                get count       => _ids.length;
  String?            get loadError   => _loadError;
  String?            get toggleError => _toggleError;

  bool isWishlisted(String productId) => _ids.contains(productId);

  // ── Load full wishlist (products + IDs) ───────────────────────
  Future<void> loadWishlist() async {
    _isLoading = true;
    _loadError = null;
    notifyListeners();
    try {
      _products = await _service.getWishlist();
      _ids      = _products.map((p) => p.id).toSet();
    } catch (e) {
      _loadError = 'Failed to load wishlist. Tap to retry.';
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

  // ── Toggle (optimistic with rollback on failure) ──────────────
  Future<bool> toggleWishlist(String productId, {ProductModel? product}) async {
    _toggleError = null;
    final wasIn = _ids.contains(productId);

    // Optimistic update
    if (wasIn) {
      _ids.remove(productId);
      _products.removeWhere((p) => p.id == productId);
    } else {
      _ids.add(productId);
      if (product != null) _products.insert(0, product);
    }
    notifyListeners();

    try {
      if (wasIn) {
        await _service.removeFromWishlist(productId);
      } else {
        await _service.addToWishlist(productId);
      }
      return true;
    } catch (_) {
      // Rollback optimistic update
      if (wasIn) {
        _ids.add(productId);
        if (product != null && !_products.any((p) => p.id == productId)) {
          _products.insert(0, product);
        }
      } else {
        _ids.remove(productId);
        _products.removeWhere((p) => p.id == productId);
      }
      _toggleError = wasIn ? 'Failed to remove from wishlist' : 'Failed to add to wishlist';
      notifyListeners();
      return false;
    }
  }

  // ── Remove (called from wishlist screen) ─────────────────────
  Future<void> removeFromWishlist(String productId) async {
    _ids.remove(productId);
    _products.removeWhere((p) => p.id == productId);
    notifyListeners();
    await _service.removeFromWishlist(productId);
  }

  // ── Reset on logout (also clears image cache) ────────────────
  void clear() {
    _products    = [];
    _ids         = {};
    _loadError   = null;
    _toggleError = null;
    notifyListeners();
  }
}
