import 'api_client.dart';
import '../models/product_model.dart';

class WishlistService {
  Future<List<ProductModel>> getWishlist() async {
    final res = await ApiClient.get('/api/wishlist');
    if (!res.isSuccess) return [];
    try {
      final list = res.data!['_list'] as List? ?? [];
      return list.map((e) {
        // Backend returns flat rows: product_id/name/price/image_url at top level
        final m = Map<String, dynamic>.from(e as Map<String, dynamic>);
        // Remap product_id → id so ProductModel.fromJson gets a valid id
        if (m['product_id'] != null) m['id'] = m['product_id'];
        // Wrap image_url into images array
        if (m['image_url'] != null && m['images'] == null) {
          m['images'] = [m['image_url']];
        }
        return ProductModel.fromJson(m);
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<Set<String>> getWishlistIds() async {
    final items = await getWishlist();
    return items.map((p) => p.id).toSet();
  }

  Future<String?> addToWishlist(String productId) async {
    final res = await ApiClient.post('/api/wishlist', {'product_id': productId});
    return res.isSuccess ? null : res.error;
  }

  Future<String?> removeFromWishlist(String productId) async {
    final res = await ApiClient.delete('/api/wishlist/$productId');
    return res.isSuccess ? null : res.error;
  }

  Future<bool> isInWishlist(String productId) async {
    final ids = await getWishlistIds();
    return ids.contains(productId);
  }
}
