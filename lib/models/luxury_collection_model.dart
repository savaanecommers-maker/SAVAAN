class LuxuryCollectionModel {
  final String  id;
  final String  title;
  final String  description;
  final String? imageUrl;
  final String? categorySlug;
  final String  ctaText;
  final int     displayOrder;
  final bool    isActive;

  const LuxuryCollectionModel({
    required this.id,
    required this.title,
    this.description  = '',
    this.imageUrl,
    this.categorySlug,
    this.ctaText      = 'Explore',
    this.displayOrder = 0,
    this.isActive     = true,
  });

  factory LuxuryCollectionModel.fromJson(Map<String, dynamic> json) {
    return LuxuryCollectionModel(
      id:           json['id']?.toString()            ?? '',
      title:        json['title']?.toString()         ?? '',
      description:  json['description']?.toString()   ?? '',
      imageUrl:     json['image_url']?.toString(),
      categorySlug: json['category_slug']?.toString(),
      ctaText:      json['cta_text']?.toString()      ?? 'Explore',
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
      isActive:     json['is_active'] == true,
    );
  }
}
