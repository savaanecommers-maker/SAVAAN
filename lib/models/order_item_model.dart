class OrderItemModel {
  final String id;
  final String orderId;
  final String? productId;
  final String productName;
  final String? productImage;
  final double price;
  final int quantity;
  final DateTime? createdAt;

  OrderItemModel({
    required this.id,
    required this.orderId,
    this.productId,
    required this.productName,
    this.productImage,
    required this.price,
    required this.quantity,
    this.createdAt,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      id:           json['id']?.toString() ?? '',
      orderId:      json['order_id']?.toString() ?? '',
      productId:    json['product_id']?.toString(),
      productName:  json['product_name']?.toString() ?? json['name']?.toString() ?? '',
      productImage: json['product_image']?.toString() ?? json['image_url']?.toString(),
      price:        double.tryParse(json['price']?.toString() ?? '0') ?? 0,
      quantity:     int.tryParse(json['quantity']?.toString() ?? '1') ?? 1,
      createdAt:    json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'order_id':      orderId,
    'product_id':    productId,
    'product_name':  productName,
    'product_image': productImage,
    'price':         price,
    'quantity':      quantity,
  };

  double get totalPrice => price * quantity;

  String get formattedPrice {
    final str = price.toStringAsFixed(0);
    final buf = StringBuffer('₹');
    int c = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      if (c == 3 || (c > 3 && (c - 3) % 2 == 0)) buf.write(',');
      buf.write(str[i]);
      c++;
    }
    return buf.toString().split('').reversed.join();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is OrderItemModel &&
              runtimeType == other.runtimeType &&
              id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'OrderItemModel(id: $id, productName: $productName, quantity: $quantity)';
}
