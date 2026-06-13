import 'api_client.dart';
import '../models/cart_item_model.dart';
import '../models/order_model.dart';

class OrderService {
  /// Returns a tuple of (orders, errorMessage).
  /// On API failure the error string is non-null — callers must show an error
  /// state rather than silently treating failure as an empty list.
  /// Handles both response shapes:
  ///   • admin token → { "orders": [...], "total": N }
  ///   • user token  → plain array  OR  { "_list": [...] }
  Future<(List<OrderModel>, String?)> getOrders({int page = 0, int limit = 10}) async {
    final res = await ApiClient.get('/api/orders');
    if (!res.isSuccess) {
      return (const <OrderModel>[], res.error ?? 'Failed to load orders');
    }
    try {
      final data = res.data;
      List rawList;
      // ApiClient wraps list responses as { '_list': [...] }
      // Admin token returns { 'orders': [...], 'total': N }
      // Fall back to empty if neither key present
      rawList = (data?['orders'] as List?)
          ?? (data?['_list'] as List?)
          ?? [];
      final orders = rawList
          .skip(page * limit)
          .take(limit)
          .map((o) => OrderModel.fromJson(o as Map<String, dynamic>))
          .toList();
      return (orders, null);
    } catch (e) {
      return (const <OrderModel>[], 'Failed to parse orders: $e');
    }
  }

  Future<OrderModel?> getOrderById(String orderId) async {
    final res = await ApiClient.get('/api/orders/$orderId');
    if (!res.isSuccess || res.data == null) return null;
    try {
      return OrderModel.fromJson(res.data!);
    } catch (_) {
      return null;
    }
  }

  /// Used by OrderProvider — accepts CartItemModel list + PaymentMethod enum
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
    final items = cartItems.map((i) => {
      'product_id': i.productId,
      if (i.variantId != null) 'variant_id': i.variantId,
      'quantity':   i.quantity,
      'price':      i.unitPrice,  // uses variant price override if set
    }).toList();

    final res = await ApiClient.post('/api/orders', {
      'items':          items,
      'address_id':     addressId,
      if (couponCode != null) 'coupon_code': couponCode,
      'subtotal':       subtotal,
      'discount':       discount,
      'shipping':       shipping,
      'total':          total,
      'payment_method': paymentMethod.value,
      if (paymentReference != null) 'payment_reference': paymentReference,
    });

    if (!res.isSuccess) return (null, res.error ?? 'Failed to place order');
    try {
      return (OrderModel.fromJson(res.data!), null);
    } catch (_) {
      return (null, 'Order placed but failed to parse response');
    }
  }

  Future<String?> cancelOrder(String orderId) async {
    // Uses the user-facing cancel route (verifyToken, not verifyAdmin)
    final res = await ApiClient.put('/api/orders/$orderId/cancel', {});
    return res.isSuccess ? null : res.error;
  }
}
