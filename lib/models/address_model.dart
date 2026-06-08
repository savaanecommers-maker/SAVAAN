class AddressModel {
  final String id;
  final String userId;
  final String fullName;
  final String phone;
  final String street;
  final String city;
  final String state;
  final String pincode;
  final bool isDefault;
  final DateTime? createdAt;

  AddressModel({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.phone,
    required this.street,
    required this.city,
    required this.state,
    required this.pincode,
    this.isDefault = false,
    this.createdAt,
  });

  factory AddressModel.fromJson(Map<String, dynamic> json) {
    return AddressModel(
      id:        json['id']?.toString() ?? '',
      userId:    json['user_id']?.toString() ?? '',
      fullName:  json['full_name']?.toString() ?? '',
      phone:     json['phone']?.toString() ?? '',
      street:    json['street']?.toString() ?? json['line1']?.toString() ?? '',
      city:      json['city']?.toString() ?? '',
      state:     json['state']?.toString() ?? '',
      pincode:   json['pincode']?.toString() ?? '',
      isDefault: json['is_default'] == true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id':    userId,
    'full_name':  fullName,
    'phone':      phone,
    'street':     street,
    'city':       city,
    'state':      state,
    'pincode':    pincode,
    'is_default': isDefault,
  };

  // Single-line display e.g. "42, MG Road, Bengaluru, Karnataka - 560001"
  String get fullAddress => '$street, $city, $state - $pincode';

  // Short display e.g. "Bengaluru, Karnataka"
  String get shortAddress => '$city, $state';

  AddressModel copyWith({
    String? id,
    String? userId,
    String? fullName,
    String? phone,
    String? street,
    String? city,
    String? state,
    String? pincode,
    bool? isDefault,
    DateTime? createdAt,
  }) {
    return AddressModel(
      id:        id        ?? this.id,
      userId:    userId    ?? this.userId,
      fullName:  fullName  ?? this.fullName,
      phone:     phone     ?? this.phone,
      street:    street    ?? this.street,
      city:      city      ?? this.city,
      state:     state     ?? this.state,
      pincode:   pincode   ?? this.pincode,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is AddressModel &&
              runtimeType == other.runtimeType &&
              id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'AddressModel(id: $id, fullName: $fullName, city: $city)';
}
