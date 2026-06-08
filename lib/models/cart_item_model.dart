import 'product_model.dart';

class CartItemModel {
  final String id;
  final String userId;
  final String productId;
  final String? variantId;
  final int quantity;
  final DateTime? addedAt;

  // Joined data
  final ProductModel? product;
  final ProductVariant? variant;

  CartItemModel({
    required this.id,
    required this.userId,
    required this.productId,
    this.variantId,
    required this.quantity,
    this.addedAt,
    this.product,
    this.variant,
  });

  factory CartItemModel.fromJson(Map<String, dynamic> json) {
    ProductModel? prod;
    if (json['products'] != null && json['products'] is Map) {
      // Nested product object (Supabase-style)
      prod = ProductModel.fromJson(json['products'] as Map<String, dynamic>);
    } else if (json['name'] != null) {
      // Flat JOIN row from backend: name/price/image_url at top level
      final imgUrl = json['image_url']?.toString();
      prod = ProductModel.fromJson({
        'id':        json['product_id']?.toString() ?? '',
        'name':      json['name'],
        'price':     json['price'],
        'images':    imgUrl != null ? [imgUrl] : <String>[],
        'stock':     json['stock'] ?? 0,
        'is_active': true,
      });
    }

    ProductVariant? vari;
    if (json['product_variants'] != null && json['product_variants'] is Map) {
      vari = ProductVariant.fromJson(
          json['product_variants'] as Map<String, dynamic>);
    }

    return CartItemModel(
      id:        json['id']?.toString() ?? '',
      userId:    json['user_id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      variantId: json['variant_id']?.toString(),
      quantity:  int.tryParse(json['quantity']?.toString() ?? '1') ?? 1,
      addedAt:   json['added_at'] != null
          ? DateTime.tryParse(json['added_at'].toString())
          : null,
      product: prod,
      variant: vari,
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id':    userId,
    'product_id': productId,
    'variant_id': variantId,
    'quantity':   quantity,
  };

  double get totalPrice => (product?.price ?? 0) * quantity;

  String get displayName => product?.name ?? '';

  String? get displayImage => product?.primaryImage;

  CartItemModel copyWith({
    String? id,
    String? userId,
    String? productId,
    String? variantId,
    int? quantity,
    DateTime? addedAt,
    ProductModel? product,
    ProductVariant? variant,
  }) {
    return CartItemModel(
      id:        id ?? this.id,
      userId:    userId ?? this.userId,
      productId: productId ?? this.productId,
      variantId: variantId ?? this.variantId,
      quantity:  quantity ?? this.quantity,
      addedAt:   addedAt ?? this.addedAt,
      product:   product ?? this.product,
      variant:   variant ?? this.variant,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is CartItemModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'CartItemModel(id: $id, productId: $productId, quantity: $quantity)';
}
