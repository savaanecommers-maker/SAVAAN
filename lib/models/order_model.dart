import 'order_item_model.dart';
export 'order_item_model.dart';

class OrderModel {
  final String id;
  final String orderNumber;
  final String userId;
  final String? addressId;
  final OrderStatus status;
  final double subtotal;
  final double discount;
  final double shipping;
  final double total;
  final String? couponCode;
  final PaymentMethod? paymentMethod;
  final String? paymentId;
  final PaymentStatus paymentStatus;
  final DateTime? createdAt;

  // Joined data
  final List<OrderItemModel> items;
  final OrderAddress? address;

  OrderModel({
    required this.id,
    required this.orderNumber,
    required this.userId,
    this.addressId,
    this.status = OrderStatus.processing,
    required this.subtotal,
    this.discount = 0,
    this.shipping = 0,
    required this.total,
    this.couponCode,
    this.paymentMethod,
    this.paymentId,
    this.paymentStatus = PaymentStatus.pending,
    this.createdAt,
    this.items = const [],
    this.address,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    // Parse order items if included
    List<OrderItemModel> itemList = [];
    final rawItems = json['items'] ?? json['order_items'];
    if (rawItems != null && rawItems is List) {
      itemList = rawItems
          .map((i) => OrderItemModel.fromJson(i as Map<String, dynamic>))
          .toList();
    }

    // Parse address if included
    OrderAddress? addr;
    if (json['addresses'] != null && json['addresses'] is Map) {
      addr = OrderAddress.fromJson(json['addresses'] as Map<String, dynamic>);
    }

    return OrderModel(
      id:            json['id']?.toString() ?? '',
      orderNumber:   json['order_number']?.toString() ?? '',
      userId:        json['user_id']?.toString() ?? '',
      addressId:     json['address_id']?.toString(),
      status:        OrderStatus.fromString(json['status']?.toString() ?? ''),
      subtotal:      double.tryParse(json['subtotal']?.toString() ?? '0') ?? 0,
      discount:      double.tryParse(json['discount']?.toString() ?? '0') ?? 0,
      shipping:      double.tryParse(json['shipping']?.toString() ?? '0') ?? 0,
      total:         double.tryParse(json['total']?.toString() ?? '0') ?? 0,
      couponCode:    json['coupon_code']?.toString(),
      paymentMethod:  PaymentMethod.fromString(json['payment_method']?.toString() ?? ''),
      paymentId:      json['payment_id']?.toString(),
      paymentStatus:  PaymentStatus.fromString(json['payment_status']?.toString() ?? ''),
      createdAt:     json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      items:         itemList,
      address:       addr,
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id':        userId,
    'address_id':     addressId,
    'status':         status.value,
    'subtotal':       subtotal,
    'discount':       discount,
    'shipping':       shipping,
    'total':          total,
    'coupon_code':    couponCode,
    'payment_method':  paymentMethod?.value,
    'payment_id':      paymentId,
    'payment_status':  paymentStatus.value,
  };

  // ── Computed helpers ─────────────────────────────────────────

  String get formattedTotal => _formatPrice(total);
  String get formattedSubtotal => _formatPrice(subtotal);
  String get formattedDiscount => _formatPrice(discount);

  // Formatted date e.g. "15 May 2024, 09:41 AM"
  String get formattedDate {
    if (createdAt == null) return '';
    final months = ['Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'];
    final h = createdAt!.hour;
    final m = createdAt!.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final hour = (h % 12 == 0 ? 12 : h % 12).toString().padLeft(2, '0');
    return '${createdAt!.day} ${months[createdAt!.month - 1]} ${createdAt!.year}, $hour:$m $period';
  }

  String _formatPrice(double amount) {
    final str = amount.toStringAsFixed(0);
    final result = StringBuffer('₹');
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      if (count == 3 || (count > 3 && (count - 3) % 2 == 0)) {
        result.write(',');
      }
      result.write(str[i]);
      count++;
    }
    return result.toString().split('').reversed.join();
  }

  OrderModel copyWith({
    String? id,
    String? orderNumber,
    String? userId,
    String? addressId,
    OrderStatus? status,
    double? subtotal,
    double? discount,
    double? shipping,
    double? total,
    String? couponCode,
    PaymentMethod? paymentMethod,
    String? paymentId,
    PaymentStatus? paymentStatus,
    DateTime? createdAt,
    List<OrderItemModel>? items,
    OrderAddress? address,
  }) {
    return OrderModel(
      id:            id ?? this.id,
      orderNumber:   orderNumber ?? this.orderNumber,
      userId:        userId ?? this.userId,
      addressId:     addressId ?? this.addressId,
      status:        status ?? this.status,
      subtotal:      subtotal ?? this.subtotal,
      discount:      discount ?? this.discount,
      shipping:      shipping ?? this.shipping,
      total:         total ?? this.total,
      couponCode:    couponCode ?? this.couponCode,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentId:     paymentId ?? this.paymentId,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      createdAt:     createdAt ?? this.createdAt,
      items:         items ?? this.items,
      address:       address ?? this.address,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is OrderModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'OrderModel(id: $id, orderNumber: $orderNumber, total: $total)';
}


// ── Order Address (snapshot) ─────────────────────────────────────────────────
class OrderAddress {
  final String id;
  final String fullName;
  final String phone;
  final String street;
  final String city;
  final String state;
  final String pincode;

  OrderAddress({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.street,
    required this.city,
    required this.state,
    required this.pincode,
  });

  factory OrderAddress.fromJson(Map<String, dynamic> json) {
    return OrderAddress(
      id:       json['id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      phone:    json['phone']?.toString() ?? '',
      street:   json['line1']?.toString() ?? json['street']?.toString() ?? '',
      city:     json['city']?.toString() ?? '',
      state:    json['state']?.toString() ?? '',
      pincode:  json['pincode']?.toString() ?? '',
    );
  }

  // Full address as single string
  String get fullAddress => '$street, $city, $state - $pincode';
}


// ── Order Status Enum ────────────────────────────────────────────────────────
enum OrderStatus {
  processing,
  confirmed,
  packed,
  shipped,
  outForDelivery,
  delivered,
  cancelled,
  returnRequested,
  returned;

  static OrderStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'confirmed':        return OrderStatus.confirmed;
      case 'packed':           return OrderStatus.packed;
      case 'shipped':          return OrderStatus.shipped;
      case 'out_for_delivery': return OrderStatus.outForDelivery;
      case 'delivered':        return OrderStatus.delivered;
      case 'cancelled':        return OrderStatus.cancelled;
      case 'return_requested':  return OrderStatus.returnRequested;
      case 'returned':          return OrderStatus.returned;
      default:                  return OrderStatus.processing;
    }
  }

  String get value {
    switch (this) {
      case OrderStatus.processing:      return 'processing';
      case OrderStatus.confirmed:       return 'confirmed';
      case OrderStatus.packed:          return 'packed';
      case OrderStatus.shipped:         return 'shipped';
      case OrderStatus.outForDelivery:  return 'out_for_delivery';
      case OrderStatus.delivered:       return 'delivered';
      case OrderStatus.cancelled:       return 'cancelled';
      case OrderStatus.returnRequested: return 'return_requested';
      case OrderStatus.returned:        return 'returned';
    }
  }

  String get displayLabel {
    switch (this) {
      case OrderStatus.processing:      return 'Processing';
      case OrderStatus.confirmed:       return 'Confirmed';
      case OrderStatus.packed:          return 'Packed';
      case OrderStatus.shipped:         return 'Shipped';
      case OrderStatus.outForDelivery:  return 'Out for Delivery';
      case OrderStatus.delivered:       return 'Delivered';
      case OrderStatus.cancelled:       return 'Cancelled';
      case OrderStatus.returnRequested: return 'Return Requested';
      case OrderStatus.returned:        return 'Returned';
    }
  }

  String get colorHex {
    switch (this) {
      case OrderStatus.processing:      return '#F59E0B';
      case OrderStatus.confirmed:       return '#3B82F6';
      case OrderStatus.packed:          return '#6366F1';
      case OrderStatus.shipped:         return '#8B5CF6';
      case OrderStatus.outForDelivery:  return '#06B6D4';
      case OrderStatus.delivered:       return '#10B981';
      case OrderStatus.cancelled:       return '#EF4444';
      case OrderStatus.returnRequested: return '#F97316';
      case OrderStatus.returned:        return '#64748B';
    }
  }

  int get trackingStep {
    switch (this) {
      case OrderStatus.processing:      return 0;
      case OrderStatus.confirmed:       return 1;
      case OrderStatus.packed:          return 2;
      case OrderStatus.shipped:         return 3;
      case OrderStatus.outForDelivery:  return 4;
      case OrderStatus.delivered:       return 5;
      case OrderStatus.returnRequested: return 5;
      case OrderStatus.returned:        return 5;
      default:                          return 0;
    }
  }
}

// ── Payment Status Enum ──────────────────────────────────────────────────────
enum PaymentStatus {
  pending,
  success,
  failed,
  refunded;

  static PaymentStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'success':  return PaymentStatus.success;
      case 'failed':   return PaymentStatus.failed;
      case 'refunded': return PaymentStatus.refunded;
      default:         return PaymentStatus.pending;
    }
  }

  String get value {
    switch (this) {
      case PaymentStatus.pending:  return 'pending';
      case PaymentStatus.success:  return 'success';
      case PaymentStatus.failed:   return 'failed';
      case PaymentStatus.refunded: return 'refunded';
    }
  }
}


// ── Payment Method Enum ──────────────────────────────────────────────────────
enum PaymentMethod {
  upi,
  creditCard,
  debitCard,
  netBanking,
  wallet,
  cod,
  cashfree;

  static PaymentMethod? fromString(String value) {
    switch (value.toLowerCase()) {
      case 'upi':          return PaymentMethod.upi;
      case 'credit_card':  return PaymentMethod.creditCard;
      case 'debit_card':   return PaymentMethod.debitCard;
      case 'net_banking':  return PaymentMethod.netBanking;
      case 'wallet':       return PaymentMethod.wallet;
      case 'cod':          return PaymentMethod.cod;
      case 'cashfree':     return PaymentMethod.cashfree;
      default:             return null;
    }
  }

  String get value {
    switch (this) {
      case PaymentMethod.upi:        return 'upi';
      case PaymentMethod.creditCard: return 'credit_card';
      case PaymentMethod.debitCard:  return 'debit_card';
      case PaymentMethod.netBanking: return 'net_banking';
      case PaymentMethod.wallet:     return 'wallet';
      case PaymentMethod.cod:        return 'cod';
      case PaymentMethod.cashfree:   return 'cashfree';
    }
  }

  String get displayLabel {
    switch (this) {
      case PaymentMethod.upi:        return 'UPI / GPay / PhonePe';
      case PaymentMethod.creditCard: return 'Credit Card';
      case PaymentMethod.debitCard:  return 'Debit Card';
      case PaymentMethod.netBanking: return 'Net Banking';
      case PaymentMethod.wallet:     return 'Wallet';
      case PaymentMethod.cod:        return 'Cash on Delivery';
      case PaymentMethod.cashfree:   return 'Online Payment';
    }
  }
}