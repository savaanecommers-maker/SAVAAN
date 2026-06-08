import 'api_client.dart';
import '../models/cart_item_model.dart';
import '../models/order_model.dart';

class OrderService {
  Future<List<OrderModel>> getOrders({int page = 0, int limit = 10}) async {
    final res = await ApiClient.get('/api/orders');
    if (!res.isSuccess) return [];
    try {
      final list = res.data!['_list'] as List? ?? [];
      return list
          .skip(page * limit)
          .take(limit)
          .map((o) => OrderModel.fromJson(o as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
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
      'price':      i.product?.price ?? 0,
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
