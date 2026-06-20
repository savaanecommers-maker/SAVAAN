import '../data/api_client.dart';

class ProductModel {
  final String id;
  final String? slug;
  final String name;
  final String? description;
  final double price;
  final double? originalPrice;
  final String? categoryId;
  final String? categoryName;
  final String? brand;
  final double rating;
  final int reviewCount;
  final int stock;
  final List<String> images;
  final bool isFeatured;
  final bool isFlashDeal;
  final bool hasVariants;
  final double? flashDealPrice;     // admin-set deal price
  final DateTime? flashDealExpiry;  // when the deal expires
  final DateTime? createdAt;
  final List<ProductVariant> variants;
  final List<String> attributes;

  ProductModel({
    required this.id,
    this.slug,
    required this.name,
    this.description,
    required this.price,
    this.originalPrice,
    this.categoryId,
    this.categoryName,
    this.brand,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.stock = 0,
    this.images = const [],
    this.isFeatured = false,
    this.isFlashDeal = false,
    this.hasVariants = false,
    this.flashDealPrice,
    this.flashDealExpiry,
    this.createdAt,
    this.variants = const [],
    this.attributes = const [],
  });

  // Effective price — flash deal price if active, otherwise regular price
  double get effectivePrice {
    if (isFlashDeal && flashDealPrice != null) {
      if (flashDealExpiry == null || flashDealExpiry!.isAfter(DateTime.now().toUtc())) {
        return flashDealPrice!;
      }
    }
    return price;
  }

  bool get isFlashDealActive =>
      isFlashDeal &&
      flashDealPrice != null &&
      (flashDealExpiry == null || flashDealExpiry!.isAfter(DateTime.now().toUtc()));

  // ── From Supabase JSON ───────────────────────────────────────
  factory ProductModel.fromJson(Map<String, dynamic> json) {
    // Handle category name — backend returns flat JOIN column 'category_name'
    // Fallback to Supabase-era nested 'categories' object for compatibility
    String? catName = json['category_name'] as String?;
    if (catName == null && json['categories'] != null && json['categories'] is Map) {
      catName = json['categories']['name'] as String?;
    }

    // Handle images array — apply fixImageUrl so localhost→10.0.2.2 on emulator
    List<String> imageList = [];
    if (json['images'] != null) {
      if (json['images'] is List) {
        imageList = (json['images'] as List)
            .map((e) => ApiClient.fixImageUrl(e.toString()))
            .whereType<String>()
            .toList();
      }
    }
    // Fallback: if images JSONB array is empty, use the image_url column
    if (imageList.isEmpty && json['image_url'] != null) {
      final fixed = ApiClient.fixImageUrl(json['image_url'].toString().trim());
      if (fixed != null) imageList = [fixed];
    }

    // Handle variants if included (backend returns key 'variants')
    List<ProductVariant> variantList = [];
    final rawVariants = json['variants'] ?? json['product_variants'];
    if (rawVariants != null && rawVariants is List) {
      variantList = rawVariants
          .map((v) => ProductVariant.fromJson(v as Map<String, dynamic>))
          .toList();
    }

    return ProductModel(
      id:            json['id']?.toString() ?? '',
      slug:          json['slug']?.toString(),
      name:          json['name']?.toString() ?? '',
      description:   json['description']?.toString(),
      price:         double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      originalPrice: json['original_price'] != null
          ? double.tryParse(json['original_price'].toString())
          : null,
      categoryId:    json['category_id']?.toString(),
      categoryName:  catName,
      brand:         json['brand']?.toString(),
      rating:        double.tryParse(json['rating']?.toString() ?? '0') ?? 0.0,
      reviewCount:   int.tryParse(json['review_count']?.toString() ?? '0') ?? 0,
      stock:         int.tryParse(json['stock']?.toString() ?? '0') ?? 0,
      images:        imageList,
      isFeatured:      json['is_featured'] == true,
      isFlashDeal:     json['is_flash_deal'] == true,
      hasVariants:     json['has_variants'] == true,
      flashDealPrice:  json['flash_deal_price'] != null
          ? double.tryParse(json['flash_deal_price'].toString())
          : null,
      flashDealExpiry: json['flash_deal_expiry'] != null
          ? DateTime.tryParse(json['flash_deal_expiry'].toString())
          : null,
      createdAt:     json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      variants:      variantList,
      attributes: json['attributes'] != null && json['attributes'] is List
          ? List<String>.from((json['attributes'] as List).map((e) => e.toString()))
          : const [],
    );
  }

  // ── To JSON (for sending to Supabase) ───────────────────────
  Map<String, dynamic> toJson() {
    return {
      'id':             id,
      'name':           name,
      'description':    description,
      'price':          price,
      'original_price': originalPrice,
      'category_id':    categoryId,
      'brand':          brand,
      'rating':         rating,
      'review_count':   reviewCount,
      'stock':          stock,
      'images':         images,
      'is_featured':       isFeatured,
      'is_flash_deal':     isFlashDeal,
      'flash_deal_price':  flashDealPrice,
      'flash_deal_expiry': flashDealExpiry?.toIso8601String(),
    };
  }

  // ── Computed helpers ─────────────────────────────────────────

  // Discount percentage e.g. 25
  int get discountPercent {
    if (originalPrice == null || originalPrice == 0) return 0;
    return (((originalPrice! - price) / originalPrice!) * 100).round();
  }

  // Amount saved e.g. ₹1,500
  double get savedAmount {
    if (originalPrice == null) return 0;
    return originalPrice! - price;
  }

  // Whether product is in stock
  bool get isInStock => stock > 0;

  // Whether product is low stock (5 or fewer)
  bool get isLowStock => stock > 0 && stock <= 5;

  // Deep-link share URL — custom scheme that opens the app directly
  String get shareUrl => 'savaan://product/$id';

  // First image or null
  String? get primaryImage => images.isNotEmpty ? images[0] : null;

  // Formatted price string e.g. ₹4,499
  String get formattedPrice => _formatPrice(price);

  // Formatted original price string
  String? get formattedOriginalPrice =>
      originalPrice != null ? _formatPrice(originalPrice!) : null;

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

  // ── CopyWith ────────────────────────────────────────────────
  ProductModel copyWith({
    String? id,
    String? slug,
    String? name,
    String? description,
    double? price,
    double? originalPrice,
    String? categoryId,
    String? categoryName,
    String? brand,
    double? rating,
    int? reviewCount,
    int? stock,
    List<String>? images,
    bool? isFeatured,
    bool? isFlashDeal,
    bool? hasVariants,
    double? flashDealPrice,
    DateTime? flashDealExpiry,
    DateTime? createdAt,
    List<ProductVariant>? variants,
    List<String>? attributes,
  }) {
    return ProductModel(
      id:              id ?? this.id,
      slug:            slug ?? this.slug,
      name:            name ?? this.name,
      description:     description ?? this.description,
      price:           price ?? this.price,
      originalPrice:   originalPrice ?? this.originalPrice,
      categoryId:      categoryId ?? this.categoryId,
      categoryName:    categoryName ?? this.categoryName,
      brand:           brand ?? this.brand,
      rating:          rating ?? this.rating,
      reviewCount:     reviewCount ?? this.reviewCount,
      stock:           stock ?? this.stock,
      images:          images ?? this.images,
      isFeatured:      isFeatured ?? this.isFeatured,
      isFlashDeal:     isFlashDeal ?? this.isFlashDeal,
      hasVariants:     hasVariants ?? this.hasVariants,
      flashDealPrice:  flashDealPrice ?? this.flashDealPrice,
      flashDealExpiry: flashDealExpiry ?? this.flashDealExpiry,
      createdAt:       createdAt ?? this.createdAt,
      variants:        variants ?? this.variants,
      attributes:      attributes ?? this.attributes,
    );
  }

  @override
  String toString() => 'ProductModel(id: $id, name: $name, price: $price)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is ProductModel &&
              runtimeType == other.runtimeType &&
              id == other.id;

  @override
  int get hashCode => id.hashCode;
}


// ── Product Variant ──────────────────────────────────────────────────────────
class ProductVariant {
  final String id;
  final String productId;
  final String? color;
  final String? size;
  final int stock;
  final double? priceOverride;
  final double? salePrice;
  final String? sku;
  final String? variantName;
  final String status;
  final List<String> images;
  final Map<String, String> attributes;

  ProductVariant({
    required this.id,
    required this.productId,
    this.color,
    this.size,
    this.stock = 0,
    this.priceOverride,
    this.salePrice,
    this.sku,
    this.variantName,
    this.status = 'active',
    this.images = const [],
    this.attributes = const {},
  });

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    final rawPrice    = json['price']      ?? json['variant_price'];
    final rawSale     = json['sale_price'] ?? json['variant_sale_price'];

    List<String> imgs = [];
    final rawImgs = json['images'] ?? json['variant_images'];
    if (rawImgs is List) {
      imgs = rawImgs
          .map((e) => ApiClient.fixImageUrl(e.toString()))
          .whereType<String>()
          .toList();
    }

    Map<String, String> attrs = {};
    final rawAttrs = json['attributes'] ?? json['variant_attributes'];
    if (rawAttrs is Map) {
      attrs = rawAttrs.map((k, v) => MapEntry(k.toString(), v.toString()));
    }

    return ProductVariant(
      id:           json['id']?.toString() ?? '',
      productId:    json['product_id']?.toString() ?? '',
      color:        json['color']?.toString() ?? json['variant_color']?.toString(),
      size:         json['size']?.toString()  ?? json['variant_size']?.toString(),
      stock:        int.tryParse(
                      (json['stock'] ?? json['variant_stock'] ?? '0').toString()
                    ) ?? 0,
      priceOverride: rawPrice != null ? double.tryParse(rawPrice.toString()) : null,
      salePrice:     rawSale  != null ? double.tryParse(rawSale.toString())  : null,
      sku:          json['sku']?.toString() ?? json['variant_sku']?.toString(),
      variantName:  json['variant_name']?.toString(),
      status:       json['status']?.toString() ?? 'active',
      images:       imgs,
      attributes:   attrs,
    );
  }

  Map<String, dynamic> toJson() => {
    'id':             id,
    'product_id':     productId,
    'color':          color,
    'size':           size,
    'stock':          stock,
    'price_override': priceOverride,
    'sale_price':     salePrice,
    'sku':            sku,
    'variant_name':   variantName,
    'status':         status,
    'images':         images,
    'attributes':     attributes,
  };

  bool get isInStock => stock > 0;
  bool get isActive  => status == 'active';

  double? get effectivePrice => salePrice ?? priceOverride;

  String get displayName {
    if (variantName != null && variantName!.isNotEmpty) return variantName!;
    final parts = [
      if (color != null) color!,
      if (size != null) size!,
      ...attributes.values,
    ];
    return parts.join(' / ');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is ProductVariant &&
              runtimeType == other.runtimeType &&
              id == other.id;

  @override
  int get hashCode => id.hashCode;
}