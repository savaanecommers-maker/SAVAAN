class UserModel {
  final String id;
  final String? fullName;
  final String? email;
  final String? phone;
  final String? avatarUrl;
  final String? fcmToken;
  final DateTime? createdAt;

  UserModel({
    required this.id,
    this.fullName,
    this.email,
    this.phone,
    this.avatarUrl,
    this.fcmToken,
    this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id:        json['id']?.toString() ?? '',
      fullName:  json['full_name']?.toString(),
      email:     json['email']?.toString(),
      phone:     json['phone']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
      fcmToken:  json['fcm_token']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id':         id,
    'full_name':  fullName,
    'email':      email,
    'phone':      phone,
    'avatar_url': avatarUrl,
  };

  // Display name — fallback to email prefix if no name set
  String get displayName {
    if (fullName != null && fullName!.isNotEmpty) return fullName!;
    if (email != null) return email!.split('@')[0];
    return 'Guest';
  }

  // Initials for avatar placeholder e.g. "JD"
  String get initials {
    if (fullName != null && fullName!.isNotEmpty) {
      final parts = fullName!.trim().split(' ');
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return fullName![0].toUpperCase();
    }
    if (email != null) return email![0].toUpperCase();
    return 'G';
  }

  UserModel copyWith({
    String? id,
    String? fullName,
    String? email,
    String? phone,
    String? avatarUrl,
    DateTime? createdAt,
  }) {
    return UserModel(
      id:        id ?? this.id,
      fullName:  fullName ?? this.fullName,
      email:     email ?? this.email,
      phone:     phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is UserModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'UserModel(id: $id, email: $email)';
}