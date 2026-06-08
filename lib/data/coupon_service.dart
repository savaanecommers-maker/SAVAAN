import 'api_client.dart';
import '../models/coupon_model.dart';

class CouponResult {
  final CouponModel? coupon;
  final double discount;
  final String? error;

  const CouponResult({this.coupon, this.discount = 0, this.error});
}

class CouponService {
  /// Returns (discount, errorMessage) — used by CartProvider
  Future<(double, String?)> applyCoupon(String code, double orderTotal) async {
    final result = await verifyCoupon(code, orderTotal: orderTotal);
    if (result.error != null) return (0.0, result.error);
    return (result.discount, null);
  }

  Future<CouponResult> verifyCoupon(String code, {double orderTotal = 0}) async {
    final res = await ApiClient.post('/api/coupons/verify', {
      'code': code,
      'order_total': orderTotal,
    });
    if (!res.isSuccess) return CouponResult(error: res.error ?? 'Invalid coupon');
    try {
      final coupon   = CouponModel.fromJson(res.data!['coupon'] as Map<String, dynamic>);
      final discount = double.tryParse(res.data!['discount'].toString()) ?? 0.0;
      return CouponResult(coupon: coupon, discount: discount);
    } catch (_) {
      return CouponResult(error: 'Failed to parse coupon');
    }
  }
}
