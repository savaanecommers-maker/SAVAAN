// Mirrors the SQL enum: CREATE TYPE discount_type AS ENUM ('percent', 'flat')
enum DiscountType {
  percent,
  flat;

  static DiscountType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'percent': return DiscountType.percent;
      case 'flat':    return DiscountType.flat;
      default:        return DiscountType.flat;
    }
  }

  String get value {
    switch (this) {
      case DiscountType.percent: return 'percent';
      case DiscountType.flat:    return 'flat';
    }
  }

  String get displayLabel {
    switch (this) {
      case DiscountType.percent: return '% Off';
      case DiscountType.flat:    return '₹ Off';
    }
  }
}

class CouponModel {
  final String id;
  final String code;
  final DiscountType discountType;
  final double discountValue;
  final double minOrderValue;
  final int maxUses;
  final int usedCount;
  final DateTime? expiresAt;
  final bool isActive;
  final DateTime? createdAt;

  CouponModel({
    required this.id,
    required this.code,
    required this.discountType,
    required this.discountValue,
    this.minOrderValue = 0,
    this.maxUses = 100,
    this.usedCount = 0,
    this.expiresAt,
    this.isActive = true,
    this.createdAt,
  });

  factory CouponModel.fromJson(Map<String, dynamic> json) {
    return CouponModel(
      id:            json['id']?.toString() ?? '',
      code:          json['code']?.toString() ?? '',
      discountType:  DiscountType.fromString(
          json['discount_type']?.toString() ?? 'flat'),
      discountValue: double.tryParse(
          json['discount_value']?.toString() ?? '0') ?? 0,
      minOrderValue: double.tryParse(
          json['min_order_value']?.toString() ?? '0') ?? 0,
      maxUses:       int.tryParse(
          json['max_uses']?.toString() ?? '100') ?? 100,
      usedCount:     int.tryParse(
          json['used_count']?.toString() ?? '0') ?? 0,
      expiresAt:     json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'].toString())
          : null,
      isActive:      json['is_active'] == true,
      createdAt:     json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'code':            code,
    'discount_type':   discountType.value,
    'discount_value':  discountValue,
    'min_order_value': minOrderValue,
    'max_uses':        maxUses,
    'is_active':       isActive,
  };

  // Whether the coupon is still valid (not expired, not exhausted)
  bool get isValid {
    if (!isActive) return false;
    if (usedCount >= maxUses) return false;
    if (expiresAt != null && expiresAt!.isBefore(DateTime.now())) return false;
    return true;
  }

  // Whether the given order total meets the minimum
  bool canApplyTo(double orderTotal) =>
      orderTotal >= minOrderValue;

  // Compute the discount amount for a given order total
  double computeDiscount(double orderTotal) {
    if (!canApplyTo(orderTotal)) return 0;
    if (discountType == DiscountType.percent) {
      return orderTotal * discountValue / 100;
    }
    return discountValue;
  }

  // Human-readable discount label e.g. "20% OFF" or "₹200 OFF"
  String get discountLabel {
    if (discountType == DiscountType.percent) {
      return '${discountValue.toInt()}% OFF';
    }
    return '₹${discountValue.toInt()} OFF';
  }

  // Expiry display
  String get expiryLabel {
    if (expiresAt == null) return 'No expiry';
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'];
    return 'Valid till ${expiresAt!.day} ${months[expiresAt!.month - 1]} ${expiresAt!.year}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is CouponModel &&
              runtimeType == other.runtimeType &&
              id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'CouponModel(code: $code, discount: $discountLabel)';
}
