import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'data/api_client.dart';
import 'presentation/splash_screen.dart';
import 'presentation/categories_screen.dart';
import 'presentation/cart_screen.dart';
import 'presentation/wishlist_screen.dart';
import 'presentation/profile_screen.dart';
import 'presentation/notification_screen.dart';
import 'presentation/orders_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/order_provider.dart';
import 'providers/product_provider.dart';
import 'providers/wishlist_provider.dart';
import 'providers/homepage_provider.dart';
import 'providers/settings_provider.dart';
import 'theme.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// SECURITY NOTE (SEC-9): _TrustAllCerts disables TLS certificate validation.
// It is ONLY activated in debug builds via the kDebugMode gate below.
// ⚠️  NEVER change the condition to `true` or remove the kDebugMode guard —
//     doing so would silently expose all users to MITM attacks in production.
// This exists solely to work around Android emulator cert-store gaps during
// development. CDN/S3 images fail to load on some Android devices in debug
// because the system cert store does not include the AWS CA.
class _TrustAllCerts extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context)
        ..badCertificateCallback = (_, _, _) => true;
}

void main() async {
  // kDebugMode gate — this override MUST NOT be applied in release builds.
  if (kDebugMode) HttpOverrides.global = _TrustAllCerts();

  WidgetsFlutterBinding.ensureInitialized();

  // Prevent google_fonts from making network requests at runtime — fonts load
  // from the package's bundled assets instead, avoiding blocking DNS/TCP on startup.
  GoogleFonts.config.allowRuntimeFetching = false;

  // Cap image memory cache at 60 MB to prevent OOM crashes on mid-range devices.
  PaintingBinding.instance.imageCache.maximumSizeBytes = 60 * 1024 * 1024;

  // Pre-warm token cache before app starts so splash reads are instant
  ApiClient.getAccessToken().catchError((_) => null);

  runApp(const MyApp());
}

/// Show an in-app notification banner for order status updates.
void showInAppNotification({
  required String title,
  required String body,
  String type = 'system',
}) {
  final context = navigatorKey.currentContext;
  if (context == null) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty)
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 13)),
          if (body.isNotEmpty)
            Text(body,
                style:
                    const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
      backgroundColor: const Color(0xFF0F172A),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      action: SnackBarAction(
        label: 'View',
        textColor: const Color(0xFF0D9488),
        onPressed: () => _navigateForType(type),
      ),
    ),
  );
}

void _navigateForType(String type) {
  final nav = navigatorKey.currentState;
  if (nav == null) return;
  nav.pushNamed(type == 'order' ? '/orders' : '/notifications');
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => WishlistProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
        ChangeNotifierProvider(create: (_) => HomepageProvider()),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        home: const SplashScreen(),
        routes: {
          '/categories':    (_) => const CategoriesScreen(),
          '/cart':          (_) => const CartScreen(),
          '/wishlist':      (_) => const WishlistScreen(),
          '/profile':       (_) => const ProfileScreen(),
          '/orders':        (_) => const OrdersScreen(),
          '/notifications': (_) => const NotificationsScreen(),
        },
        onGenerateRoute: (settings) {
          // Handle deep links from push notifications.
          // Route format: /orders/<id>, /product/<id>, etc.
          final uri = Uri.tryParse(settings.name ?? '');
          if (uri == null) return null;
          final segments = uri.pathSegments;
          if (segments.isEmpty) return null;
          switch (segments[0]) {
            case 'orders':
              return MaterialPageRoute(builder: (_) => const OrdersScreen());
            case 'notifications':
              return MaterialPageRoute(builder: (_) => const NotificationsScreen());
            default:
              return null;
          }
        },
      ),
    );
  }
}
