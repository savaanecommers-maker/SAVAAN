import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

/// Handles savaan://product/<id> deep links.
///
/// Cold start  — call [getInitialProductId] once from the splash screen.
/// Warm start  — call [init] once from main; the stream fires for subsequent links.
/// After login — call [pendingProductId] then [clearPending].
class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  /// Product ID waiting to be opened after login.
  String? _pendingProductId;
  String? get pendingProductId => _pendingProductId;
  void setPending(String id) => _pendingProductId = id;
  void clearPending() => _pendingProductId = null;

  /// Parse savaan://product/<id> → product id, or null if not a product link.
  String? _extractProductId(Uri uri) {
    if (uri.scheme != 'savaan') return null;
    // savaan://product/123  →  host=product, pathSegments=['123']
    if (uri.host == 'product' && uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.first;
    }
    return null;
  }

  /// Call once on cold start — returns the product ID from the launch URL, if any.
  Future<String?> getInitialProductId() async {
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri == null) return null;
      return _extractProductId(uri);
    } catch (_) {
      return null;
    }
  }

  /// Call once from main() — listens for links while the app is running.
  /// [onLink] is called with the product ID whenever a deep link arrives.
  void init({required void Function(String productId) onLink}) {
    _sub?.cancel();
    _sub = _appLinks.uriLinkStream.listen((uri) {
      final id = _extractProductId(uri);
      if (id != null) onLink(id);
    }, onError: (_) {});
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }

  /// Navigate to the product detail screen by ID.
  /// Fetches product from the API inside ProductDetailScreen's initState.
  static void openProduct(BuildContext context, String productId) {
    Navigator.of(context).pushNamed('/product', arguments: productId);
  }
}
