import 'api_client.dart';

class SettingsService {
  Future<Map<String, String>> getSettings() async {
    final res = await ApiClient.get('/api/settings', auth: false); // public endpoint
    if (!res.isSuccess) return _defaults;
    try {
      return Map<String, String>.from(
        (res.data! as Map<String, dynamic>).map((k, v) => MapEntry(k, v.toString()))
      );
    } catch (_) {
      return _defaults;
    }
  }

  Future<List<Map<String, dynamic>>> getBanners() async {
    final res = await ApiClient.get('/api/banners', auth: false);
    if (!res.isSuccess) return [];
    try {
      final list = res.data!['_list'] as List? ?? [];
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  static const Map<String, String> _defaults = {
    'app_name':            'Savaan',
    'tagline':             'Luxury & Trust',
    'primary_color':       '#0d9488',
    'currency_symbol':     '₹',
    'free_shipping_above': '999',
    'shipping_charge':     '99',
    'support_email':       'support@savaan.com',
    'support_phone':       '+91 9999999999',
  };
}
