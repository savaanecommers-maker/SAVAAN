import 'api_client.dart';

class ReturnService {
  /// Submit a new return request for an order.
  /// Returns null on success, or an error string on failure.
  /// Only calls POST /api/returns — no fallback to avoid duplicate records
  /// on network timeout (FIX-6: removed double-call pattern).
  Future<String?> submitReturn({
    required String orderId,
    required String reason,
    String? notes,
  }) async {
    final res = await ApiClient.post('/api/returns', {
      'order_id': orderId,
      'reason': reason,
      if (notes != null && notes.isNotEmpty) 'comments': notes,
    });
    return res.isSuccess ? null : res.error ?? 'Failed to submit return request';
  }

  /// Returns the return status map if this order has a return request, else null.
  /// Tries the dedicated /api/returns/order/:id endpoint first, then falls back
  /// to reading order status from the order detail endpoint.
  Future<Map<String, dynamic>?> getReturnForOrder(String orderId) async {
    // Try dedicated endpoint (new backend with returns table)
    final res = await ApiClient.get('/api/returns/order/$orderId');
    if (res.isSuccess && res.data != null) {
      return Map<String, dynamic>.from(res.data as Map);
    }

    // Fallback: infer from order status
    final orderRes = await ApiClient.get('/api/orders/$orderId');
    if (!orderRes.isSuccess || orderRes.data == null) return null;
    final status = orderRes.data!['status']?.toString() ?? '';
    if (status == 'return_requested' || status == 'returned') {
      // Map order status to a return-style status
      return {
        'status': status == 'return_requested' ? 'requested' : 'completed',
        'reason': orderRes.data!['return_reason'] ?? '',
      };
    }
    return null;
  }

  /// Fetch all return requests for the current user (admin use-case).
  Future<List<Map<String, dynamic>>> getReturns() async {
    final res = await ApiClient.get('/api/returns');
    if (!res.isSuccess || res.data == null) return [];
    try {
      final list = (res.data as Map)['returns'] as List? ?? [];
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }
}
