import 'api_client.dart';

class ReturnService {
  Future<String?> submitReturn({
    required String orderId,
    required String reason,
    String? notes,
  }) async {
    final res = await ApiClient.post('/api/orders/$orderId/return', {
      'reason': reason,
      if (notes != null) 'notes': notes,
    });
    return res.isSuccess ? null : res.error;
  }

  /// Returns the return status map if this order has a return request, else null
  Future<Map<String, dynamic>?> getReturnForOrder(String orderId) async {
    final res = await ApiClient.get('/api/orders/$orderId');
    if (!res.isSuccess || res.data == null) return null;
    final status = res.data!['status']?.toString() ?? '';
    if (status == 'return_requested' || status == 'returned') {
      return {'status': status};
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getReturns() async {
    // Fetch both return_requested and returned orders
    final results = await Future.wait([
      ApiClient.get('/api/orders?status=return_requested'),
      ApiClient.get('/api/orders?status=returned'),
    ]);
    try {
      final all = <Map<String, dynamic>>[];
      for (final res in results) {
        if (res.isSuccess && res.data != null) {
          final list = res.data!['_list'] as List? ?? [];
          all.addAll(list.cast<Map<String, dynamic>>());
        }
      }
      return all;
    } catch (_) {
      return [];
    }
  }
}
