import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Base URL — switch between emulator and physical device:
///
///   EMULATOR  : defaultValue = 'http://10.0.2.2:4000'
///   REAL PHONE: defaultValue = 'http://192.168.YOUR.IP:4000'
///               (run `ipconfig` on Windows → Wireless LAN IPv4 Address)
///
/// Or pass at build time without editing this file:
///   flutter run --dart-define=API_BASE=http://192.168.1.5:4000
///
const String kApiBase = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'https://api.savaan.in',
);

const _kAccessToken  = 'access_token';
const _kRefreshToken = 'refresh_token';

class ApiClient {
  // ── In-memory token cache ─────────────────────────────────────
  // SharedPreferences reads are fast (no Keystore), but we still cache in
  // memory to avoid repeated disk reads on every API call.
  static String? _cachedAccess;
  static String? _cachedRefresh;
  static bool _cacheLoaded = false;

  static Future<void> _ensureCacheLoaded() async {
    if (_cacheLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 2));
      _cachedAccess  = prefs.getString(_kAccessToken);
      _cachedRefresh = prefs.getString(_kRefreshToken);
    } catch (_) {
      _cachedAccess  = null;
      _cachedRefresh = null;
    }
    _cacheLoaded = true;
  }

  static Future<String?> getAccessToken() async {
    await _ensureCacheLoaded();
    return _cachedAccess;
  }

  static Future<String?> getRefreshToken() async {
    await _ensureCacheLoaded();
    return _cachedRefresh;
  }

  static Future<void> saveTokens(String access, String? refresh) async {
    _cachedAccess  = access;
    if (refresh != null) _cachedRefresh = refresh;
    _cacheLoaded = true;
    // Persist to disk in the background — don't block the caller
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_kAccessToken, access);
      if (refresh != null) prefs.setString(_kRefreshToken, refresh);
    }).catchError((_) {});
  }

  static Future<void> clearTokens() async {
    _cachedAccess  = null;
    _cachedRefresh = null;
    _cacheLoaded   = true;
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove(_kAccessToken);
      prefs.remove(_kRefreshToken);
    }).catchError((_) {});
  }

  static Future<bool> get isLoggedIn async {
    // A valid refresh token means the user is logged in.
    // The short-lived access token will be silently refreshed on the first API call.
    final refresh = await getRefreshToken();
    if (refresh == null) return false;
    try {
      final parts = refresh.split('.');
      if (parts.length != 3) return false;
      final payload = json.decode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1])))
      ) as Map<String, dynamic>;
      final exp = payload['exp'] as int?;
      if (exp == null) return false;
      return DateTime.fromMillisecondsSinceEpoch(exp * 1000).isAfter(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getTokenPayload() async {
    final token = await getAccessToken();
    if (token == null) return null;
    try {
      final parts = token.split('.');
      return json.decode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1])))
      ) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ── HTTP helpers ─────────────────────────────────────────────

  static Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = {'Content-Type': 'application/json'};
    if (auth) {
      final token = await getAccessToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<ApiResponse> _send(
    Future<http.Response> Function(Map<String, String> headers) makeReq, {
    bool auth = true,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    try {
      var headers = await _headers(auth: auth);
      var res = await makeReq(headers).timeout(timeout);

      // Try token refresh on 401
      if (res.statusCode == 401 && auth) {
        final refreshed = await _tryRefresh();
        if (refreshed) {
          headers = await _headers(auth: auth);
          res = await makeReq(headers).timeout(timeout);
        }
      }

      final decoded = json.decode(res.body);
      final body = decoded is List
          ? <String, dynamic>{'_list': decoded}
          : decoded as Map<String, dynamic>;
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return ApiResponse(data: body, error: null);
      }
      return ApiResponse(data: null, error: body['error']?.toString() ?? 'Request failed');
    } on SocketException {
      return ApiResponse(data: null, error: 'No connection to server');
    } catch (e) {
      return ApiResponse(data: null, error: e.toString());
    }
  }

  static Future<bool> _tryRefresh() async {
    final refresh = await getRefreshToken();
    if (refresh == null) return false;
    try {
      final res = await http.post(
        Uri.parse('$kApiBase/api/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'refresh_token': refresh}),
      ).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        final newToken = data['access_token'] as String;
        _cachedAccess = newToken;
        SharedPreferences.getInstance()
            .then((p) { p.setString(_kAccessToken, newToken); })
            .catchError((_) {});
        return true;
      }
    } catch (_) {}
    return false;
  }

  // ── Public methods ────────────────────────────────────────────

  static Future<ApiResponse> get(String path, {bool auth = true}) =>
      _send((h) => http.get(Uri.parse('$kApiBase$path'), headers: h), auth: auth);

  static Future<ApiResponse> post(String path, Map<String, dynamic> body, {bool auth = true, Duration timeout = const Duration(seconds: 20)}) =>
      _send((h) => http.post(Uri.parse('$kApiBase$path'), headers: h, body: json.encode(body)), auth: auth, timeout: timeout);

  static Future<ApiResponse> put(String path, Map<String, dynamic> body) =>
      _send((h) => http.put(Uri.parse('$kApiBase$path'), headers: h, body: json.encode(body)));

  static Future<ApiResponse> patch(String path, Map<String, dynamic> body) =>
      _send((h) => http.patch(Uri.parse('$kApiBase$path'), headers: h, body: json.encode(body)));

  static Future<ApiResponse> delete(String path, {Map<String, dynamic>? body}) =>
      _send((h) => http.delete(Uri.parse('$kApiBase$path'), headers: h,
          body: body != null ? json.encode(body) : null));

  // ── Image URL fixer ──────────────────────────────────────────
  /// Rewrites backend-stored localhost URLs to use the same host as [kApiBase].
  /// Uploaded images are stored as http://localhost:4000/uploads/... by the server,
  /// but the Android emulator cannot reach `localhost` — it needs `10.0.2.2`.
  /// Returns null if the URL is not a valid HTTP/HTTPS image URL (e.g. data URIs,
  /// empty strings, or local paths that can't be reached from the device).
  static String? fixImageUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    // data: URIs cannot be loaded by CachedNetworkImage — discard them
    if (url.startsWith('data:')) return null;
    // Local file paths (no scheme) — not reachable on device
    if (!url.startsWith('http://') && !url.startsWith('https://')) return null;
    // Rewrite localhost/127.0.0.1 to the device-reachable API base
    if (url.startsWith('http://localhost:') ||
        url.startsWith('http://127.0.0.1:')) {
      final uri = Uri.tryParse(url);
      if (uri == null) return null;
      return url.replaceFirst(
        '${uri.scheme}://${uri.host}:${uri.port}',
        kApiBase,
      );
    }
    return url;
  }

  static Future<ApiResponse> uploadFile(String path, File file, {String field = 'file'}) async {
    try {
      final token = await getAccessToken();
      final req = http.MultipartRequest('POST', Uri.parse('$kApiBase$path'));
      if (token != null) req.headers['Authorization'] = 'Bearer $token';
      req.files.add(await http.MultipartFile.fromPath(field, file.path));
      final streamed = await req.send().timeout(const Duration(seconds: 30));
      final res = await http.Response.fromStream(streamed);
      final body = json.decode(res.body) as Map<String, dynamic>;
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return ApiResponse(data: body, error: null);
      }
      return ApiResponse(data: null, error: body['error']?.toString() ?? 'Upload failed');
    } on SocketException {
      return ApiResponse(data: null, error: 'No connection to server');
    } catch (e) {
      return ApiResponse(data: null, error: e.toString());
    }
  }
}

class ApiResponse {
  final Map<String, dynamic>? data;
  final String? error;
  bool get isSuccess => error == null;

  const ApiResponse({required this.data, required this.error});
}
