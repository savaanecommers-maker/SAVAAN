import 'api_client.dart';
import '../models/cart_item_model.dart';

class CartService {
  Future<List<CartItemModel>> getCartItems() async {
    final res = await ApiClient.get('/api/cart');
    if (!res.isSuccess) return [];
    try {
      final list = res.data!['_list'] as List? ?? [];
      return list.map((e) => CartItemModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<int> getCartCount() async {
    final items = await getCartItems();
    return items.fold<int>(0, (sum, i) => sum + i.quantity);
  }

  Future<String?> addToCart({
    required String productId,
    String? variantId,
    int quantity = 1,
  }) async {
    final res = await ApiClient.post('/api/cart', {
      'product_id': productId,
      if (variantId != null) 'variant_id': variantId,
      'quantity': quantity,
    });
    return res.isSuccess ? null : res.error;
  }

  Future<String?> updateQuantity(String cartItemId, int quantity) async {
    final res = await ApiClient.put('/api/cart/$cartItemId', {'quantity': quantity});
    return res.isSuccess ? null : res.error;
  }

  Future<String?> removeFromCart(String cartItemId) async {
    final res = await ApiClient.delete('/api/cart/$cartItemId');
    return res.isSuccess ? null : res.error;
  }

  Future<String?> clearCart() async {
    final res = await ApiClient.delete('/api/cart');
    return res.isSuccess ? null : res.error;
  }
}
