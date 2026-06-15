import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/api_client.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/product_provider.dart';
import '../providers/wishlist_provider.dart';
import '../providers/settings_provider.dart';
import 'auth_screens.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {

  late AnimationController _logoCtrl;
  late AnimationController _textCtrl;

  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<double> _textFade;
  late Animation<Offset>  _textSlide;

  @override
  void initState() {
    super.initState();

    // Logo: elastic scale-in + fade
    _logoCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
        CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut));
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _logoCtrl,
            curve: const Interval(0.0, 0.5, curve: Curves.easeIn)));

    // Text: slide-up + fade
    _textCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _textCtrl, curve: Curves.easeIn));
    _textSlide = Tween<Offset>(
        begin: const Offset(0, 0.18), end: Offset.zero).animate(
        CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut));

    _startSequence();
  }

  Future<void> _startSequence() async {
    await Future.delayed(const Duration(milliseconds: 200));
    _logoCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 500));
    _textCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 900));
    try {
      await _navigate().timeout(const Duration(seconds: 5));
    } catch (_) {
      _forceNavigate();
    }
  }

  void _forceNavigate() {
    if (!mounted) return;
    Navigator.pushReplacement(context, PageRouteBuilder(
      pageBuilder: (_, _, _) => const AuthParentPage(),
      transitionsBuilder: (_, anim, _, child) =>
          FadeTransition(opacity: anim, child: child),
      transitionDuration: const Duration(milliseconds: 500),
    ));
  }

  Future<void> _navigate() async {
    if (!mounted) return;

    // Load settings with a short timeout — don't block splash for 10s
    final settingsProvider = context.read<SettingsProvider>();
    settingsProvider.load().timeout(
      const Duration(seconds: 3),
      onTimeout: () {},
    ).catchError((_) {});

    // Small delay to let settings come back if backend is fast
    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    // ── Maintenance mode check ────────────────────────────────────
    if (settingsProvider.maintenanceMode) {
      Navigator.pushReplacement(context, PageRouteBuilder(
        pageBuilder: (_, _, _) => const _MaintenanceScreen(),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ));
      return;
    }

    // ── Apply shipping settings to CartProvider ───────────────────
    context.read<CartProvider>().updateShippingSettings(
      settingsProvider.shippingCharge,
      settingsProvider.freeShippingAbove,
    );

    bool loggedIn = false;
    try {
      loggedIn = await ApiClient.isLoggedIn;
    } catch (_) {}

    if (!mounted) return;

    if (loggedIn) {
      context.read<AuthProvider>().loadUser();
      context.read<CartProvider>().loadCart();
      context.read<WishlistProvider>().loadIds();
      context.read<ProductProvider>().loadHomeData();
    }

    if (!mounted) return;
    Navigator.pushReplacement(context, PageRouteBuilder(
      pageBuilder: (_, _, _) =>
          loggedIn ? const HomeScreen() : const AuthParentPage(),
      transitionsBuilder: (_, anim, _, child) =>
          FadeTransition(opacity: anim, child: child),
      transitionDuration: const Duration(milliseconds: 500),
    ));
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final screenW = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [

          // ── Wave PNG — bottom of screen ───────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Image.asset(
              'assets/splashscreeenWave.png',
              width: screenW,
              fit: BoxFit.fitWidth,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),

          // ── All content on top of wave ─────────────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Top spacing: logo sits ~14% from top ────────────
              SizedBox(height: screenH * 0.14),

              // ── Logo — centered ──────────────────────────────────
              Center(
                child: AnimatedBuilder(
                  animation: _logoCtrl,
                  builder: (_, _) => Transform.scale(
                    scale: _logoScale.value,
                    child: Opacity(
                      opacity: _logoFade.value,
                      child: Image.asset(
                        'assets/logo.png',
                        height: screenH * 0.13,
                        errorBuilder: (_, _, _) => Container(
                          width: screenH * 0.13,
                          height: screenH * 0.13,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0D9488), Color(0xFF16A34A)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius:
                                BorderRadius.circular(screenH * 0.03),
                          ),
                          child: Icon(Icons.diamond_outlined,
                              size: screenH * 0.07, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              SizedBox(height: screenH * 0.022),

              // ── SAVAAN + Luxury & Trust — centered ───────────────
              FadeTransition(
                opacity: _textFade,
                child: SlideTransition(
                  position: _textSlide,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [

                      // "SAVAAN" — green gradient letters
                      Center(
                        child: ShaderMask(
                          shaderCallback: (bounds) =>
                              const LinearGradient(
                            colors: [
                              Color(0xFF0D9488), // teal (left)
                              Color(0xFF16A34A), // green (right)
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ).createShader(bounds),
                          blendMode: BlendMode.srcIn,
                          child: Text(
                            'SAVAAN',
                            style: TextStyle(
                              color: Colors.white, // ShaderMask replaces this
                              fontSize: screenH * 0.044,
                              fontWeight: FontWeight.w800,
                              letterSpacing: screenW * 0.02,
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: screenH * 0.008),

                      // "Luxury & Trust"
                      Center(
                        child: Text(
                          'Luxury & Trust',
                          style: TextStyle(
                            fontSize: screenH * 0.018,
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w400,
                            letterSpacing: screenW * 0.004,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: screenH * 0.05),

              // ── "Experience Luxury." and "Experience Trust."
              //    — centered ──────────────────────────────────────
              FadeTransition(
                opacity: _textFade,
                child: Center(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Experience Luxury.',
                        style: TextStyle(
                          fontSize: screenH * 0.019,
                          color: const Color(0xFF94A3B8),
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.2,
                        ),
                      ),
                      SizedBox(height: screenH * 0.006),
                      Text(
                        'Experience Trust.',
                        style: TextStyle(
                          fontSize: screenH * 0.019,
                          color: const Color(0xFF94A3B8),
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),


            ],
          ),

        ],
      ),
    );
  }
}

// ── Maintenance Screen ────────────────────────────────────────────────────────
class _MaintenanceScreen extends StatelessWidget {
  const _MaintenanceScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/logo.png', height: 80,
                    errorBuilder: (_, _, _) => const Icon(
                        Icons.build_outlined, size: 64, color: Color(0xFF0D9488))),
                const SizedBox(height: 24),
                const Text('SAVAAN',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                        letterSpacing: 4, color: Color(0xFF0F172A))),
                const SizedBox(height: 8),
                const Text('Luxury & Trust',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B),
                        letterSpacing: 1.5)),
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDFA),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF99F6E4)),
                  ),
                  child: const Column(children: [
                    Icon(Icons.build_outlined, size: 36, color: Color(0xFF0D9488)),
                    SizedBox(height: 12),
                    Text('Under Maintenance',
                        style: TextStyle(fontSize: 18,
                            fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                    SizedBox(height: 8),
                    Text(
                      "We're working hard to improve your experience.\nPlease check back soon.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.5),
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
