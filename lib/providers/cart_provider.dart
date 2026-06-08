import 'package:flutter/material.dart';
import '../data/cart_service.dart';
import '../data/coupon_service.dart';
import '../models/cart_item_model.dart';

class CartProvider extends ChangeNotifier {
  final CartService   _cartService   = CartService();
  final CouponService _couponService = CouponService();

  List<CartItemModel> _items          = [];
  bool                _isLoading      = false;
  String?             _couponCode;
  double              _couponDiscount = 0;
  String?             _couponError;
  bool                _isApplyingCoupon = false;

  // ── Getters ───────────────────────────────────────────────────
  List<CartItemModel> get items          => _items;
  bool                get isLoading      => _isLoading;
  bool                get isEmpty        => _items.isEmpty;
  String?             get couponCode     => _couponCode;
  double              get couponDiscount => _couponDiscount;
  String?             get couponError    => _couponError;
  bool                get isApplyingCoupon => _isApplyingCoupon;

  /// Total number of individual units in the cart (for badge display)
  int get itemCount =>
      _items.fold(0, (sum, i) => sum + i.quantity);

  double get subtotal =>
      _items.fold(0.0, (sum, i) => sum + i.totalPrice);

  // Shipping — set by admin via app_settings, defaults to ₹99 / free above ₹999
  double _shippingCharge    = 99.0;
  double _freeShippingAbove = 999.0;

  double get shippingCharge    => _shippingCharge;
  double get freeShippingAbove => _freeShippingAbove;

  void updateShippingSettings(double charge, double freeAbove) {
    _shippingCharge    = charge;
    _freeShippingAbove = freeAbove;
    notifyListeners();
  }

  double get shipping =>
      isEmpty ? 0 : (subtotal >= _freeShippingAbove ? 0 : _shippingCharge);

  double get total => subtotal - _couponDiscount + shipping;

  // ── Load ──────────────────────────────────────────────────────
  Future<void> loadCart() async {
    _isLoading = true;
    notifyListeners();
    try {
      _items = await _cartService.getCartItems();
    } catch (_) {
      _items = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Add to cart ───────────────────────────────────────────────
  Future<String?> addToCart({
    required String productId,
    String? variantId,
    int quantity = 1,
  }) async {
    final error = await _cartService.addToCart(
      productId: productId,
      variantId: variantId,
      quantity:  quantity,
    );
    // Fire-and-forget refresh so the button is never blocked waiting for reload
    if (error == null) loadCart();
    return error;
  }

  // ── Update quantity ───────────────────────────────────────────
  Future<void> updateQuantity(String cartItemId, int quantity) async {
    // Optimistic UI — update locally first
    final idx = _items.indexWhere((i) => i.id == cartItemId);
    if (idx != -1) {
      if (quantity <= 0) {
        _items.removeAt(idx);
      } else {
        _items[idx] = _items[idx].copyWith(quantity: quantity);
      }
      notifyListeners();
    }
    await _cartService.updateQuantity(cartItemId, quantity);
  }

  // ── Remove item ───────────────────────────────────────────────
  Future<void> removeFromCart(String cartItemId) async {
    _items.removeWhere((i) => i.id == cartItemId);
    notifyListeners();
    await _cartService.removeFromCart(cartItemId);
  }

  // ── Clear entire cart ─────────────────────────────────────────
  Future<void> clearCart() async {
    await _cartService.clearCart();
    _items = [];
    _couponCode     = null;
    _couponDiscount = 0;
    _couponError    = null;
    notifyListeners();
  }

  // ── Apply coupon ──────────────────────────────────────────────
  Future<void> applyCoupon(String code) async {
    if (code.trim().isEmpty) return;
    _isApplyingCoupon = true;
    _couponError      = null;
    notifyListeners();

    final (discount, error) =
        await _couponService.applyCoupon(code, subtotal);

    if (error == null) {
      _couponCode     = code.trim().toUpperCase();
      _couponDiscount = discount;
    } else {
      _couponError = error;
    }
    _isApplyingCoupon = false;
    notifyListeners();
  }

  // ── Remove coupon ─────────────────────────────────────────────
  void removeCoupon() {
    _couponCode     = null;
    _couponDiscount = 0;
    _couponError    = null;
    notifyListeners();
  }

  // ── Reset on logout ───────────────────────────────────────────
  void clear() {
    _items          = [];
    _couponCode     = null;
    _couponDiscount = 0;
    _couponError    = null;
    notifyListeners();
  }
}
