import 'api_client.dart';
import '../models/user_model.dart';
import '../models/address_model.dart';

class UserService {
  // ── Profile ───────────────────────────────────────────────────
  Future<UserModel?> getProfile() async {
    final res = await ApiClient.get('/api/users/me');
    if (!res.isSuccess || res.data == null) return null;
    try {
      return UserModel.fromJson(res.data!);
    } catch (_) {
      return null;
    }
  }

  Future<String?> updateProfile({
    String? fullName,
    String? phone,
    String? avatarUrl,
    String? fcmToken,
  }) async {
    final payload = <String, dynamic>{};
    if (fullName  != null) payload['full_name']  = fullName;
    if (phone     != null) payload['phone']      = phone;
    if (avatarUrl != null) payload['avatar_url'] = avatarUrl;
    if (fcmToken  != null) payload['fcm_token']  = fcmToken;
    final res = await ApiClient.put('/api/users/me', payload);
    return res.isSuccess ? null : res.error;
  }

  // ── Addresses ─────────────────────────────────────────────────
  Future<List<AddressModel>> getAddresses() async {
    final uid = await ApiClient.getTokenPayload().then((p) => p?['id'] as String?);
    if (uid == null) return [];
    final res = await ApiClient.get('/api/users/$uid/addresses');
    if (!res.isSuccess) return [];
    try {
      final list = res.data!['_list'] as List? ?? [];
      return list.map((a) => AddressModel.fromJson(a as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<String?> addAddress({
    required String fullName,
    required String phone,
    required String street,
    required String city,
    required String state,
    required String pincode,
    bool isDefault = false,
  }) async {
    final res = await ApiClient.post('/api/addresses', {
      'full_name':  fullName,
      'phone':      phone,
      'line1':      street,
      'city':       city,
      'state':      state,
      'pincode':    pincode,
      'is_default': isDefault,
    });
    return res.isSuccess ? null : res.error;
  }

  Future<String?> updateAddress({
    required String addressId,
    String? fullName,
    String? phone,
    String? street,
    String? city,
    String? state,
    String? pincode,
    bool? isDefault,
  }) async {
    final payload = <String, dynamic>{};
    if (fullName  != null) payload['full_name']  = fullName;
    if (phone     != null) payload['phone']      = phone;
    if (street    != null) payload['line1']      = street;
    if (city      != null) payload['city']       = city;
    if (state     != null) payload['state']      = state;
    if (pincode   != null) payload['pincode']    = pincode;
    if (isDefault != null) payload['is_default'] = isDefault;
    final res = await ApiClient.put('/api/addresses/$addressId', payload);
    return res.isSuccess ? null : res.error;
  }

  Future<String?> deleteAddress(String addressId) async {
    final res = await ApiClient.delete('/api/addresses/$addressId');
    return res.isSuccess ? null : res.error;
  }

  Future<String?> setDefaultAddress(String addressId) async {
    final res = await ApiClient.put('/api/addresses/$addressId', {'is_default': true});
    return res.isSuccess ? null : res.error;
  }
}
