import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'data/api_client.dart';
import 'presentation/splash_screen.dart';
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
import 'firebase_options.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Pre-warm token cache before app starts so splash reads are instant
  ApiClient.getAccessToken().catchError((_) => null);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await FirebaseMessaging.instance.requestPermission(
    alert: true, badge: true, sound: true,
  );
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true, badge: true, sound: true,
  );

  FirebaseMessaging.instance.onTokenRefresh.listen(_updateFCMToken);

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;
    _showInAppNotification(
      title: notification.title ?? '',
      body:  notification.body  ?? '',
      type:  message.data['type'] ?? 'system',
    );
  });

  FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

  final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    Future.delayed(const Duration(milliseconds: 1200), () {
      _handleNotificationTap(initialMessage);
    });
  }

  runApp(const MyApp());
}

void _showInAppNotification({
  required String title,
  required String body,
  required String type,
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
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
          if (body.isNotEmpty)
            Text(body, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
      backgroundColor: const Color(0xFF0F172A),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      action: SnackBarAction(
        label: 'View',
        textColor: const Color(0xFF0D9488),
        onPressed: () => _navigateForType(type),
      ),
    ),
  );
}

void _handleNotificationTap(RemoteMessage message) {
  _navigateForType(message.data['type'] ?? 'system');
}

void _navigateForType(String type) {
  final nav = navigatorKey.currentState;
  if (nav == null) return;
  if (type == 'order') {
    nav.push(MaterialPageRoute(builder: (_) => const OrdersScreen()));
  } else {
    nav.push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
  }
}

Future<void> _updateFCMToken(String token) async {
  try {
    await ApiClient.put('/api/users/me', {'fcm_token': token});
  } catch (_) {}
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
        navigatorKey:              navigatorKey,
        debugShowCheckedModeBanner: false,
        theme:                     AppTheme.theme,
        home:                      const SplashScreen(),
      ),
    );
  }
}
