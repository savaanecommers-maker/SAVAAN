class BrandModel {
  final String id;
  final String name;
  final String slug;
  final String? logoUrl;
  final bool isFeatured;
  final int displayOrder;

  BrandModel({
    required this.id,
    required this.name,
    required this.slug,
    this.logoUrl,
    this.isFeatured = false,
    this.displayOrder = 0,
  });

  factory BrandModel.fromJson(Map<String, dynamic> json) {
    return BrandModel(
      id:           json['id']?.toString() ?? '',
      name:         json['name']?.toString() ?? '',
      slug:         json['slug']?.toString() ?? '',
      logoUrl:      json['logo_url']?.toString(),
      isFeatured:   json['is_featured'] == true,
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
    );
  }
}
