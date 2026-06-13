import 'package:flutter/material.dart';
import '../data/order_service.dart';
import '../models/cart_item_model.dart';
import '../models/order_model.dart';

class OrderProvider extends ChangeNotifier {
  final OrderService _service = OrderService();

  List<OrderModel> _orders     = [];
  bool             _isLoading  = false;
  bool             _hasLoaded  = false;
  String?          _loadError;

  // ── Getters ───────────────────────────────────────────────────
  List<OrderModel> get orders    => _orders;
  bool             get isLoading => _isLoading;
  int              get count     => _orders.length;
  bool             get hasLoaded => _hasLoaded;
  /// Non-null when the last loadOrders() call failed — callers should show an error.
  String?          get loadError => _loadError;

  // ── Load orders ───────────────────────────────────────────────
  Future<void> loadOrders({bool force = false}) async {
    if (_hasLoaded && !force) return;
    _isLoading = true;
    _loadError = null;
    notifyListeners();
    try {
      final (orders, error) = await _service.getOrders();
      _orders    = orders;
      _loadError = error; // null on success, message on failure
    } catch (e) {
      _orders    = [];
      _loadError = 'Unexpected error: $e';
    } finally {
      _hasLoaded = true;
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Place order ───────────────────────────────────────────────
  Future<(OrderModel?, String?)> placeOrder({
    required List<CartItemModel> cartItems,
    required String addressId,
    required PaymentMethod paymentMethod,
    required double subtotal,
    required double shipping,
    required double total,
    double discount = 0,
    String? couponCode,
    String? paymentReference,
  }) async {
    final result = await _service.placeOrder(
      cartItems:        cartItems,
      addressId:        addressId,
      paymentMethod:    paymentMethod,
      subtotal:         subtotal,
      shipping:         shipping,
      total:            total,
      discount:         discount,
      couponCode:       couponCode,
      paymentReference: paymentReference,
    );
    if (result.$1 != null) {
      _orders.insert(0, result.$1!); // prepend new order
      notifyListeners();
    }
    return result;
  }

  // ── Cancel order ──────────────────────────────────────────────
  Future<String?> cancelOrder(String orderId) async {
    final error = await _service.cancelOrder(orderId);
    if (error == null) {
      final idx = _orders.indexWhere((o) => o.id == orderId);
      if (idx != -1) {
        _orders[idx] = _orders[idx].copyWith(
            status: OrderStatus.cancelled);
        notifyListeners();
      }
    }
    return error;
  }

  // ── Reset on logout ───────────────────────────────────────────
  void clear() {
    _orders    = [];
    _hasLoaded = false;
    _loadError = null;
    notifyListeners();
  }
}
