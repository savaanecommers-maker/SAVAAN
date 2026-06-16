class CategoryModel {
  final String id;
  final String name;
  final String? imageUrl;
  final String slug;
  final int itemCount;
  final String? parentId;
  final String? description;
  final bool isFeatured;
  final int displayOrder;
  final bool isActive;
  final DateTime? createdAt;

  bool get isParent => parentId == null;

  CategoryModel({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.slug,
    this.itemCount = 0,
    this.parentId,
    this.description,
    this.isFeatured = false,
    this.displayOrder = 0,
    this.isActive = true,
    this.createdAt,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id:           json['id']?.toString() ?? '',
      name:         json['name']?.toString() ?? '',
      imageUrl:     json['image_url']?.toString(),
      slug:         json['slug']?.toString() ?? '',
      itemCount:    int.tryParse((json['product_count'] ?? json['item_count'])?.toString() ?? '0') ?? 0,
      parentId:     json['parent_id']?.toString(),
      description:  json['description']?.toString(),
      isFeatured:   json['is_featured'] == true,
      displayOrder: int.tryParse(json['display_order']?.toString() ?? '0') ?? 0,
      isActive:     json['is_active'] != false,
      createdAt:    json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id':            id,
    'name':          name,
    'image_url':     imageUrl,
    'slug':          slug,
    'item_count':    itemCount,
    'parent_id':     parentId,
    'description':   description,
    'is_featured':   isFeatured,
    'display_order': displayOrder,
    'is_active':     isActive,
  };

  CategoryModel copyWith({
    String? id,
    String? name,
    String? imageUrl,
    String? slug,
    int? itemCount,
    String? parentId,
    String? description,
    bool? isFeatured,
    int? displayOrder,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return CategoryModel(
      id:           id ?? this.id,
      name:         name ?? this.name,
      imageUrl:     imageUrl ?? this.imageUrl,
      slug:         slug ?? this.slug,
      itemCount:    itemCount ?? this.itemCount,
      parentId:     parentId ?? this.parentId,
      description:  description ?? this.description,
      isFeatured:   isFeatured ?? this.isFeatured,
      displayOrder: displayOrder ?? this.displayOrder,
      isActive:     isActive ?? this.isActive,
      createdAt:    createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'CategoryModel(id: $id, name: $name, slug: $slug)';
}
