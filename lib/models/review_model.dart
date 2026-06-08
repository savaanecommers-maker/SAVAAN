class ReviewModel {
  final String id;
  final String userId;
  final String productId;
  final int rating;      // 1–5
  final String? reviewText;
  final DateTime? createdAt;

  // Joined data (optional)
  final String? userName;
  final String? userAvatar;

  ReviewModel({
    required this.id,
    required this.userId,
    required this.productId,
    required this.rating,
    this.reviewText,
    this.createdAt,
    this.userName,
    this.userAvatar,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    // Optional joined user data
    String? uName;
    String? uAvatar;
    if (json['users'] != null && json['users'] is Map) {
      final u = json['users'] as Map<String, dynamic>;
      uName   = u['full_name']?.toString();
      uAvatar = u['avatar_url']?.toString();
    }

    return ReviewModel(
      id:          json['id']?.toString() ?? '',
      userId:      json['user_id']?.toString() ?? '',
      productId:   json['product_id']?.toString() ?? '',
      rating:      int.tryParse(json['rating']?.toString() ?? '5') ?? 5,
      reviewText:  json['body']?.toString() ?? json['review_text']?.toString(),
      createdAt:   json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      userName:    uName,
      userAvatar:  uAvatar,
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id':     userId,
    'product_id':  productId,
    'rating':      rating,
    'review_text': reviewText,
  };

  // Star display helper — returns filled/half/empty star counts
  // e.g. rating 4 → [4 filled, 0 half, 1 empty]
  List<int> get starCounts {
    final filled = rating.clamp(0, 5);
    final empty  = 5 - filled;
    return [filled, 0, empty];
  }

  // Formatted date e.g. "12 May 2024"
  String get formattedDate {
    if (createdAt == null) return '';
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${createdAt!.day} ${months[createdAt!.month - 1]} ${createdAt!.year}';
  }

  String get displayName => userName ?? 'Anonymous';

  ReviewModel copyWith({
    String? id,
    String? userId,
    String? productId,
    int? rating,
    String? reviewText,
    DateTime? createdAt,
    String? userName,
    String? userAvatar,
  }) {
    return ReviewModel(
      id:          id          ?? this.id,
      userId:      userId      ?? this.userId,
      productId:   productId   ?? this.productId,
      rating:      rating      ?? this.rating,
      reviewText:  reviewText  ?? this.reviewText,
      createdAt:   createdAt   ?? this.createdAt,
      userName:    userName    ?? this.userName,
      userAvatar:  userAvatar  ?? this.userAvatar,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is ReviewModel &&
              runtimeType == other.runtimeType &&
              id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'ReviewModel(id: $id, rating: $rating, userId: $userId)';
}
