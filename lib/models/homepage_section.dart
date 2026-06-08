import 'product_model.dart';

class HomepageSection {
  final String                  key;
  final String                  title;
  final String                  subtitle;
  final String                  type;
  final int                     displayOrder;
  final List<ProductModel>      products;
  final Map<String, dynamic>    config;

  HomepageSection({
    required this.key,
    required this.title,
    this.subtitle    = '',
    this.type        = 'product_carousel',
    this.displayOrder = 0,
    this.products    = const [],
    this.config      = const {},
  });

  factory HomepageSection.fromJson(Map<String, dynamic> json) {
    final rawProducts = json['products'] as List? ?? [];
    final rawConfig   = json['config'];
    return HomepageSection(
      key:          json['key']?.toString() ?? '',
      title:        json['title']?.toString() ?? '',
      subtitle:     json['subtitle']?.toString() ?? '',
      type:         json['type']?.toString() ?? 'product_carousel',
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
      products:     rawProducts
          .map((p) => ProductModel.fromJson(p as Map<String, dynamic>))
          .toList(),
      config: rawConfig is Map
          ? Map<String, dynamic>.from(rawConfig)
          : {},
    );
  }

  /// Sections with no products still render if they have a special type.
  bool get isEmpty {
    if (type == 'discount_banner')    return false;
    if (type == 'luxury_edit')        return false;
    if (type == 'flash_deals_banner') return false;
    return products.isEmpty;
  }
}
