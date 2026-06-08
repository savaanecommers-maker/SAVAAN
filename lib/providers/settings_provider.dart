import 'package:flutter/material.dart';
import '../data/settings_service.dart';

class SettingsProvider extends ChangeNotifier {
  final SettingsService _service = SettingsService();

  Map<String, String> _settings = {};
  List<Map<String, dynamic>> _banners = [];
  bool _isLoading = false;
  bool _hasLoaded = false;

  // ── Getters ───────────────────────────────────────────────────
  List<Map<String, dynamic>> get banners    => _banners;
  bool                       get isLoading  => _isLoading;
  bool                       get hasLoaded  => _hasLoaded;

  // App settings with fallback defaults
  bool   get maintenanceMode    => _settings['maintenance_mode'] == 'true';
  double get shippingCharge     => double.tryParse(_settings['shipping_charge']     ?? '') ?? 99.0;
  double get freeShippingAbove  => double.tryParse(_settings['free_shipping_above'] ?? '') ?? 999.0;
  String get currencySymbol     => _settings['currency_symbol']  ?? '₹';
  String get appName            => _settings['app_name']          ?? 'Savaan';
  String get tagline            => _settings['tagline']           ?? 'Luxury & Trust';
  String get supportEmail       => _settings['support_email']     ?? 'support@savaan.com';
  String get supportPhone       => _settings['support_phone']     ?? '';
  String get standardDays       => _settings['standard_days']     ?? '3-5';
  String get expressDays        => _settings['express_days']      ?? '1-2';

  // ── Load settings + banners in parallel ──────────────────────
  Future<void> load({bool force = false}) async {
    if (_hasLoaded && !force) return;
    _isLoading = true;
    notifyListeners();

    try {
      final results = await Future.wait([
        _service.getSettings(),
        _service.getBanners(),
      ]);
      _settings = results[0] as Map<String, String>;
      _banners  = results[1] as List<Map<String, dynamic>>;
    } catch (_) {
      // Keep defaults
    } finally {
      _hasLoaded = true;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => load(force: true);
}
