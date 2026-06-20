import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/settings_service.dart';

class SettingsProvider extends ChangeNotifier {
  final SettingsService _service = SettingsService();

  Map<String, String> _settings = {};
  List<Map<String, dynamic>> _banners = [];
  bool _isLoading = false;
  bool _hasLoaded = false;

  static const _kSettingsCache = 'app_settings_cache_v1';

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

    // Show cached settings instantly, then refresh in background
    final hadCache = await _loadFromCache();
    if (hadCache && !force) {
      _fetchAndCache(); // silent background refresh
      return;
    }

    _isLoading = true;
    notifyListeners();
    await _fetchAndCache();
  }

  Future<bool> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 2));
      final cached = prefs.getString(_kSettingsCache);
      if (cached == null) return false;
      final data = json.decode(cached) as Map<String, dynamic>;
      _settings = Map<String, String>.from(
          (data['settings'] as Map? ?? {}).map((k, v) => MapEntry(k.toString(), v.toString())));
      _banners  = (data['banners'] as List? ?? []).cast<Map<String, dynamic>>();
      _hasLoaded = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _fetchAndCache() async {
    try {
      final results = await Future.wait([
        _service.getSettings(),
        _service.getBanners(),
      ]);
      _settings = results[0] as Map<String, String>;
      _banners  = results[1] as List<Map<String, dynamic>>;
    } catch (_) {
      // Keep existing values / defaults
    } finally {
      _hasLoaded = true;
      _isLoading = false;
      notifyListeners();
      // Persist to cache
      SharedPreferences.getInstance().then((prefs) {
        try {
          prefs.setString(_kSettingsCache,
              json.encode({'settings': _settings, 'banners': _banners}));
        } catch (_) {}
      }).catchError((_) {});
    }
  }

  Future<void> refresh() => load(force: true);
}
