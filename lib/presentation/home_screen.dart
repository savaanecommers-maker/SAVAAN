import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/api_client.dart';
import '../models/brand_model.dart';
import '../models/category_model.dart';
import '../models/homepage_section.dart';
import '../models/luxury_collection_model.dart';
import '../models/product_model.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/homepage_provider.dart';
import '../providers/order_provider.dart';
import '../providers/product_provider.dart';
import '../providers/wishlist_provider.dart';
import '../providers/settings_provider.dart';
import 'auth_screens.dart';
import 'cart_screen.dart';
import 'categories_screen.dart';
import 'notification_screen.dart';
import 'orders_screen.dart';
import 'product_detail_screen.dart';
import 'product_list_screen.dart';
import 'subcategory_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'wishlist_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver, TickerProviderStateMixin {
  // ── State ────────────────────────────────────────────────────
  int  _currentIndex      = 0;
  int  _unreadNotifCount  = 0;
  int  _currentBannerPage = 0;

  // Per-row scroll-guard flags (no setState needed — only read by timers)
  bool _userScrollingRow1 = false;
  bool _userScrollingRow2 = false;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Controllers
  late PageController   _bannerController;
  late ScrollController _catRow1Controller;   // row 1 → scrolls right-to-left
  late ScrollController _catRow2Controller;   // row 2 → scrolls left-to-right
  // Note: brand controller is managed by _AutoScrollCarousel widget

  // Timers / Tickers
  Timer?  _bannerTimer;
  Ticker? _catRow1Ticker;
  Ticker? _catRow2Ticker;

  // Category infinite-scroll constants
  static const double _catItemW    = 88.0;  // item width + margin
  static const int    _catRepeat   = 999;   // virtual repeat count for seamless loop
  static const int    _catMid      = 499;   // start at midpoint of the virtual list
  static const double _catRow1Speed = 50.0; // px/s  ← change this to tune Row 1

  // ── Colors ───────────────────────────────────────────────────
  static const Color _ink     = Color(0xFF0F172A);
  static const Color _teal    = Color(0xFF0D9488);
  static const Color _green   = Color(0xFF10B981);
  static const Color _slate   = Color(0xFF64748B);
  static const Color _border  = Color(0xFFE2E8F0);
  static const Color _surface = Color(0xFFF8FAFC);

  // ── Nav ──────────────────────────────────────────────────────
  final List<Map<String, dynamic>> _navItems = [
    {'icon': Icons.home_outlined,         'active': Icons.home_rounded,          'label': 'Home'},
    {'icon': Icons.grid_view_outlined,    'active': Icons.grid_view_rounded,     'label': 'Categories'},
    {'icon': Icons.shopping_cart_outlined,'active': Icons.shopping_cart_rounded, 'label': 'Cart'},
    {'icon': Icons.favorite_outline,      'active': Icons.favorite_rounded,      'label': 'Wishlist'},
    {'icon': Icons.person_outline_rounded,'active': Icons.person_rounded,        'label': 'Profile'},
  ];

  final List<Map<String, dynamic>> _drawerItems = [
    {'icon': Icons.home_outlined,         'label': 'Home',          'badge': 0},
    {'icon': Icons.grid_view_outlined,    'label': 'Categories',    'badge': 0},
    {'icon': Icons.favorite_outline,      'label': 'Wishlist',      'badge': 0},
    {'icon': Icons.receipt_long_outlined, 'label': 'My Orders',     'badge': 0},
    {'icon': Icons.local_offer_outlined,  'label': 'Coupons',       'badge': 0},
    {'icon': Icons.notifications_outlined,'label': 'Notifications', 'badge': 0},
    {'icon': Icons.help_outline_rounded,  'label': 'Help & Support','badge': 0},
    {'icon': Icons.settings_outlined,     'label': 'Settings',      'badge': 0},
  ];

  // ── Category icon map ─────────────────────────────────────────
  final Map<String, IconData> _catIcons = {
    'fashion': Icons.checkroom_outlined, 'watches': Icons.watch_outlined,
    'beauty-personal-care': Icons.spa_outlined, 'electronics': Icons.devices_outlined,
    'home-decor': Icons.chair_outlined, 'jewelry-accessories': Icons.diamond_outlined,
    'bags-luggage': Icons.luggage_outlined, 'footwear': Icons.directions_walk_outlined,
    'gifts-luxury-collections': Icons.card_giftcard_outlined,
    'health-wellness': Icons.favorite_outline, 'mobiles-accessories': Icons.smartphone_outlined,
    'seasonal-collections': Icons.event_outlined, 'featured-categories': Icons.star_outline,
    'perfumes': Icons.local_florist_outlined, 'skincare': Icons.face_outlined,
    'makeup': Icons.brush_outlined, 'mens-clothing': Icons.man_outlined,
    'womens-clothing': Icons.woman_outlined, 'kids-wear': Icons.child_care_outlined,
    'luxury-watches': Icons.watch_outlined, 'smart-watches': Icons.watch_outlined,
    'necklaces': Icons.diamond_outlined, 'earrings': Icons.diamond_outlined,
    'rings': Icons.circle_outlined, 'bracelets': Icons.diamond_outlined,
    'sunglasses': Icons.wb_sunny_outlined, 'handbags': Icons.shopping_bag_outlined,
    'backpacks': Icons.backpack_outlined, 'sneakers': Icons.directions_run_outlined,
    'fitness-equipment': Icons.fitness_center_outlined,
  };

  // ── Lifecycle ─────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bannerController  = PageController();
    _catRow1Controller = ScrollController();
    _catRow2Controller = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bannerTimer?.cancel();
    _catRow1Ticker?.dispose();
    _catRow2Ticker?.dispose();
    _bannerController.dispose();
    _catRow1Controller.dispose();
    _catRow2Controller.dispose();
    super.dispose();
  }

  // ── Init ──────────────────────────────────────────────────────
  Future<void> _init() async {
    if (!mounted) return;
    final hp   = context.read<HomepageProvider>();
    final sets = context.read<SettingsProvider>();

    // Fire non-blocking
    context.read<AuthProvider>().loadUser();
    context.read<CartProvider>().loadCart();
    context.read<WishlistProvider>().loadIds();
    _fetchNotifCount();

    await Future.wait([sets.load(), hp.load()]);

    if (!mounted) return;
    context.read<CartProvider>().updateShippingSettings(
      sets.shippingCharge, sets.freeShippingAbove);

    final bannerCount = hp.banners.length;
    _startBannerSlide(bannerCount);

    // Both rows carry the full category list; Row 2 starts half a cycle
    // ahead so its visible items are different from Row 1 at any moment.
    final cats = hp.categories;
    if (cats.isNotEmpty) {
      _startRow1Scroll(cats.length);
      _startRow2Scroll(cats.length);
    }
  }

  // ── Timers ────────────────────────────────────────────────────
  void _startBannerSlide(int count) {
    if (count < 2) return;
    _bannerTimer?.cancel();
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_bannerController.hasClients) return;
      final next = (_currentBannerPage + 1) % count;
      _bannerController.animateToPage(
        next,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    });
  }

  // Row 1 — scrolls right-to-left (offset increases), continuous
  void _startRow1Scroll(int count) {
    if (count == 0) return;
    final initialOffset = _catItemW * count * _catMid;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _catRow1Controller.hasClients) {
        _catRow1Controller.jumpTo(initialOffset);
      }
    });
    _catRow1Ticker?.dispose();
    Duration lastTick = Duration.zero;
    double carry = 0.0; // pixel accumulator — only call jumpTo when ≥1 pixel ready
    _catRow1Ticker = createTicker((elapsed) {
      final dt = elapsed - lastTick;
      lastTick = elapsed;
      if (!mounted || _userScrollingRow1 || !_catRow1Controller.hasClients) return;
      carry += _catRow1Speed * dt.inMicroseconds / 1_000_000.0;
      if (carry < 1.0) return; // skip frame — not even 1 pixel accumulated yet
      final pixels = carry.floorToDouble();
      carry -= pixels;
      final newOffset = _catRow1Controller.offset + pixels;
      _catRow1Controller.jumpTo(
        newOffset < _catItemW * count * (_catRepeat - 50) ? newOffset : initialOffset,
      );
    });
    _catRow1Ticker!.start();
  }

  // Row 2 — scrolls left-to-right (offset decreases), continuous 60fps.
  // Starts half a cycle ahead of Row 1 so visible items are always different.
  void _startRow2Scroll(int count) {
    if (count == 0) return;
    // Half-cycle offset: shift by ⌊count/2⌋ items so the two rows always
    // show opposite halves of the full list at any given instant.
    final halfCycle = _catItemW * (count ~/ 2);
    final initialOffset = _catItemW * count * _catMid + halfCycle;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _catRow2Controller.hasClients) {
        _catRow2Controller.jumpTo(initialOffset);
      }
    });
    _catRow2Ticker?.dispose();
    Duration lastTick = Duration.zero;
    double carry2 = 0.0; // pixel accumulator — prevents sub-pixel jitter
    _catRow2Ticker = createTicker((elapsed) {
      final dt = elapsed - lastTick;
      lastTick = elapsed;
      if (!mounted || _userScrollingRow2 || !_catRow2Controller.hasClients) return;
      carry2 += 35.0 * dt.inMicroseconds / 1000000.0;
      if (carry2 < 1.0) return;
      final pixels = carry2.floorToDouble();
      carry2 -= pixels;
      final newOffset = _catRow2Controller.offset - pixels;
      // When approaching the start of the virtual list, jump back to initialOffset —
      // same visual content (i % count) so there's no visible discontinuity.
      if (newOffset < _catItemW * count * 50) {
        _catRow2Controller.jumpTo(initialOffset);
        return;
      }
      _catRow2Controller.jumpTo(newOffset);
    });
    _catRow2Ticker!.start();
  }

  Future<void> _fetchNotifCount() async {
    try {
      if (!await ApiClient.isLoggedIn || !mounted) return;
      final res = await ApiClient.get('/api/notifications');
      if (res.isSuccess && mounted) {
        final list = res.data!['_list'] as List? ?? [];
        final count = list.where((n) => n is Map && n['is_read'] != true).length;
        setState(() => _unreadNotifCount = count);
      }
    } catch (_) {}
  }

  Future<void> _loadData() async {
    final homepageProvider = context.read<HomepageProvider>();
    final cartProvider     = context.read<CartProvider>();
    final wishlistProvider = context.read<WishlistProvider>();
    await homepageProvider.refresh();
    await cartProvider.loadCart();
    await wishlistProvider.loadIds();
    _fetchNotifCount();
  }

  Future<void> _logout() async {
    final authProvider     = context.read<AuthProvider>();
    final cartProvider     = context.read<CartProvider>();
    final wishlistProvider = context.read<WishlistProvider>();
    final productProvider  = context.read<ProductProvider>();
    final homepageProvider = context.read<HomepageProvider>();
    final orderProvider    = context.read<OrderProvider>();
    final nav              = Navigator.of(context);
    await authProvider.signOut();
    cartProvider.clear();
    wishlistProvider.clear();
    productProvider.clear();
    homepageProvider.clear();
    orderProvider.clear();
    if (mounted) {
      nav.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthParentPage()), (_) => false);
    }
  }

  // ── BUILD ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final hp = context.watch<HomepageProvider>();

    // Separate special section types from product sections
    final productSections  = <HomepageSection>[];
    HomepageSection? discountSection;
    for (final s in hp.sections) {
      if (s.type == 'discount_banner') {
        discountSection ??= s;
      } else {
        productSections.add(s);
      }
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      drawer: _buildDrawer(),
      body: SafeArea(
        child: hp.isLoading
            ? _buildSkeleton()
            : RefreshIndicator(
                color: _teal,
                onRefresh: _loadData,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // 1. Top bar + search
                    SliverToBoxAdapter(child: _buildTopBar()),
                    SliverToBoxAdapter(child: _buildSearchBar()),
                    // 2. Hero banner
                    SliverToBoxAdapter(child: _buildBannerSection(hp.banners)),
                    // 3. Auto-scrolling categories
                    SliverToBoxAdapter(child: _buildCategoryRow(hp.categories)),
                    // 4. Trust strip
                    SliverToBoxAdapter(child: _buildTrustStrip()),
                    // 5–19. Dynamic product sections (flash deals, new arrivals …)
                    ...productSections.map((s) =>
                        SliverToBoxAdapter(child: RepaintBoundary(child: _buildSection(s)))),
                    // 20. Featured brands
                    if (hp.brands.isNotEmpty)
                      SliverToBoxAdapter(child: RepaintBoundary(child: _buildBrandStrip(hp.brands))),
                    // 21. Extra discount banner (admin-configurable via HomepageSections admin)
                    if (discountSection != null)
                      SliverToBoxAdapter(child: RepaintBoundary(child: _buildDiscountBannerCard(discountSection))),
                    // 22. Luxury Edit — curated luxury collections (admin via Luxury Edit page)
                    if (hp.luxuryCollections.isNotEmpty)
                      SliverToBoxAdapter(child: RepaintBoundary(child: _buildLuxuryEditSection(hp.luxuryCollections))),
                    // 23. Customer reviews (real, from DB)
                    if (hp.featuredReviews.isNotEmpty)
                      SliverToBoxAdapter(child: _buildReviewsSection(hp.featuredReviews)),
                    // 24. Follow us
                    SliverToBoxAdapter(child: _buildFollowUsSection(hp.socialLinks)),


                  ],
                ),
              ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── TOP BAR ──────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(children: [
        _iconBox(Icons.menu_rounded, onTap: () => _scaffoldKey.currentState?.openDrawer()),
        const SizedBox(width: 12),
        Expanded(child: Row(children: [
          Image.asset('assets/logo.png', height: 32,
              errorBuilder: (_, _, _) => Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_teal, _green]),
                  borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.diamond_outlined, size: 18, color: Colors.white))),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ShaderMask(
              shaderCallback: (b) => const LinearGradient(
                colors: [Color(0xFF0D9488), Color(0xFF22C55E)],
                begin: Alignment.centerLeft, end: Alignment.centerRight)
                  .createShader(b),
              blendMode: BlendMode.srcIn,
              child: const Text('SAVAAN',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                      letterSpacing: 3, color: Colors.white))),
            Text('Luxury & Trust',
                style: TextStyle(fontSize: 9, color: _slate, letterSpacing: 1.5)),
          ]),
        ])),
        // Notification bell
        GestureDetector(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const NotificationsScreen()))
              .then((_) { if (mounted) _fetchNotifCount(); }),
          child: Stack(children: [
            _iconBox(Icons.notifications_outlined),
            if (_unreadNotifCount > 0)
              Positioned(right: 6, top: 6,
                child: Container(width: 7, height: 7,
                    decoration: const BoxDecoration(
                        color: Colors.redAccent, shape: BoxShape.circle))),
          ])),
        const SizedBox(width: 8),
        // Cart
        GestureDetector(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const CartScreen()))
              .then((_) {
            // CartScreen reloads the cart in its own initState;
            // no redundant loadCart() needed here.
            if (mounted) setState(() => _currentIndex = 0);
          }),
          child: Stack(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: _surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border)),
              child: const Icon(Icons.shopping_bag_outlined, size: 22, color: _ink)),
            Consumer<CartProvider>(builder: (_, cart, _) {
              if (cart.itemCount == 0) return const SizedBox.shrink();
              return Positioned(right: 2, top: 2,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                      color: Colors.redAccent, shape: BoxShape.circle),
                  child: Text(cart.itemCount > 9 ? '9+' : '${cart.itemCount}',
                      style: const TextStyle(color: Colors.white,
                          fontSize: 8, fontWeight: FontWeight.bold))));
            }),
          ])),
      ]),
    );
  }

  Widget _iconBox(IconData icon, {VoidCallback? onTap}) => GestureDetector(
    onTap: onTap ?? () {},
    child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: _surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _border)),
      child: Icon(icon, size: 22, color: _ink)));

  // ── SEARCH BAR ───────────────────────────────────────────────
  Widget _buildSearchBar() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
    child: GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const SearchScreen())),
      child: Container(
        height: 48,
        decoration: BoxDecoration(color: _surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border)),
        child: Row(children: [
          const SizedBox(width: 14),
          Icon(Icons.search_rounded, color: _slate, size: 20),
          const SizedBox(width: 10),
          Text('Search products, brands...',
              style: TextStyle(color: _slate.withValues(alpha: 0.5), fontSize: 14)),
          const Spacer(),
          Container(
            margin: const EdgeInsets.all(6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_teal, _green]),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.tune_rounded, color: Colors.white, size: 16)),
        ]))));

  // ── BANNER CAROUSEL ──────────────────────────────────────────
  Widget _buildBannerSection(List<Map<String, dynamic>> banners) {
    if (banners.isEmpty) return _buildHeroBanner();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(children: [
        SizedBox(
          height: 190,
          child: PageView.builder(
            controller: _bannerController,
            itemCount: banners.length,
            onPageChanged: (i) => setState(() => _currentBannerPage = i),
            itemBuilder: (ctx, i) => _buildBannerCard(banners[i]),
          )),
        if (banners.length > 1) ...[
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(banners.length, (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width:  i == _currentBannerPage ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: i == _currentBannerPage ? _teal : _border,
                borderRadius: BorderRadius.circular(3))))),
        ],
      ]));
  }

  Widget _buildBannerCard(Map<String, dynamic> banner) {
    return GestureDetector(
      onTap: () {
        // Track banner click
        ApiClient.post('/api/homepage/analytics',
            {'event_type': 'banner_click', 'metadata': {'banner_id': banner['id']}})
            .catchError((_) => const ApiResponse(data: null, error: 'ignored'));

        final linkType  = banner['link_type']?.toString() ?? 'none';
        final linkValue = banner['link_value']?.toString() ?? '';

        switch (linkType) {
          case 'flash_deals':
            Navigator.push(context, MaterialPageRoute(
                builder: (_) => const ProductListScreen(
                  title: 'Flash Deals', showFlashDeals: true)));
            break;
          case 'category':
          case 'subcategory':
            if (linkValue.isNotEmpty) {
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ProductListScreen(title: linkValue)));
            }
            break;
          case 'brand':
            if (linkValue.isNotEmpty) {
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ProductListScreen(title: linkValue, brandName: linkValue)));
            }
            break;
          case 'luxury_collection':
            if (linkValue.isNotEmpty) {
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ProductListScreen(title: 'Luxury Collection', collectionId: linkValue)));
            }
            break;
          case 'product':
            if (linkValue.isNotEmpty) {
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ProductDetailScreen(productId: linkValue)));
            }
            break;
          case 'all_products':
            Navigator.push(context, MaterialPageRoute(
                builder: (_) => const ProductListScreen(title: 'All Products')));
            break;
          case 'categories':
            Navigator.push(context, MaterialPageRoute(
                builder: (_) => const CategoriesScreen()));
            break;
          // 'none' or unknown — no navigation
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(fit: StackFit.expand, children: [
          banner['image_url'] != null
              ? CachedNetworkImage(
                  imageUrl: ApiClient.fixImageUrl(banner['image_url'].toString()) ?? '',
                  fit: BoxFit.cover,
                  placeholder: (_, _) => _bannerGradient(),
                  errorWidget: (_, _, _) => _bannerGradient())
              : _bannerGradient(),
          if (banner['title'] != null)
            Positioned(bottom: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 32, 16, 14),
                decoration: const BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.black87, Colors.transparent])),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(banner['title'].toString(),
                      style: const TextStyle(color: Colors.white,
                          fontSize: 16, fontWeight: FontWeight.w800)),
                  if (banner['subtitle'] != null)
                    Text(banner['subtitle'].toString(),
                        style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ]))),
        ])));
  }

  Widget _bannerGradient() => Container(
    decoration: const BoxDecoration(
        gradient: LinearGradient(
            colors: [Color(0xFF0B1426), Color(0xFF1A2744)],
            begin: Alignment.topLeft, end: Alignment.bottomRight)));

  Widget _buildHeroBanner() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    child: Container(
      height: 190,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF0B1426), Color(0xFF1A2744)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20, offset: const Offset(0, 8))]),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Row(children: [
          Expanded(child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 0, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: _teal.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _teal.withValues(alpha: 0.5))),
                child: const Text('NEW ARRIVAL',
                    style: TextStyle(color: Color(0xFF5EEAD4),
                        fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.5))),
              const SizedBox(height: 8),
              const Text('LUXURY\nTHAT DEFINES\nYOU',
                  style: TextStyle(color: Colors.white, fontSize: 17,
                      fontWeight: FontWeight.w800, height: 1.2)),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const CategoriesScreen())),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [_teal, _green]),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Text('SHOP NOW',
                      style: TextStyle(color: Colors.white, fontSize: 11,
                          fontWeight: FontWeight.w800, letterSpacing: 1.5)))),
            ]))),
          SizedBox(
            width: 140, height: 190,
            child: CachedNetworkImage(
              imageUrl: 'https://images.unsplash.com/photo-1509631179647-0177331693ae?w=300&h=400&fit=crop&crop=top',
              fit: BoxFit.cover,
              placeholder: (_, _) => Container(color: const Color(0xFF1E293B)),
              errorWidget: (_, _, _) => Container(
                color: const Color(0xFF1E293B),
                child: Icon(Icons.person_outline, size: 48,
                    color: Colors.white.withValues(alpha: 0.3))))),
        ]))));

  // ── CATEGORY DUAL-ROW CAROUSEL ───────────────────────────────
  // Both rows carry every category. Row 1 scrolls right→left; Row 2
  // scrolls left→right and starts half a cycle ahead — so at any moment
  // the two rows are showing DIFFERENT parts of the same full list.
  // The 44px left-pad on Row 2 adds a visual zig-zag stagger.
  Widget _buildCategoryRow(List<CategoryModel> cats) {
    if (cats.isEmpty) return const SizedBox.shrink();

    // Need at least 2 categories for the dual-row to be meaningful
    if (cats.length < 2) return _buildSingleCategoryRow(cats);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionHeader('Categories', onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const CategoriesScreen()))),

      // ── Row 1: right → left (all categories) ─────────────────
      RepaintBoundary(
        child: _buildCatScrollRow(
          cats:       cats,
          controller: _catRow1Controller,
          onStart:    () => _userScrollingRow1 = true,
          onEnd:      () => Future.delayed(const Duration(seconds: 2),
                              () { if (mounted) _userScrollingRow1 = false; }),
          leftPad:    16.0,
        )),

      const SizedBox(height: 10),

      // ── Row 2: left → right, half-cycle offset (all categories)
      RepaintBoundary(
        child: _buildCatScrollRow(
          cats:       cats,
          controller: _catRow2Controller,
          onStart:    () => _userScrollingRow2 = true,
          onEnd:      () => Future.delayed(const Duration(seconds: 2),
                              () { if (mounted) _userScrollingRow2 = false; }),
          leftPad:    44.0,   // half-item stagger for zig-zag look
        )),

      const SizedBox(height: 8),
    ]);
  }

  // Single-row fallback (used when there are < 2 items for row2)
  Widget _buildSingleCategoryRow(List<CategoryModel> cats) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionHeader('Categories', onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const CategoriesScreen()))),
      RepaintBoundary(
        child: _buildCatScrollRow(
          cats:       cats,
          controller: _catRow1Controller,
          onStart:    () => _userScrollingRow1 = true,
          onEnd:      () => Future.delayed(const Duration(seconds: 2),
                              () { if (mounted) _userScrollingRow1 = false; }),
          leftPad:    16.0,
        )),
      const SizedBox(height: 8),
    ]);
  }

  // Shared scroll-row builder used by both rows
  Widget _buildCatScrollRow({
    required List<CategoryModel> cats,
    required ScrollController    controller,
    required VoidCallback         onStart,
    required VoidCallback         onEnd,
    required double               leftPad,
  }) {
    return SizedBox(
      height: 104,
      // Listener fires only on real finger events, never on programmatic jumpTo()
      child: Listener(
        onPointerDown:   (_) => onStart(),
        onPointerUp:     (_) => onEnd(),
        onPointerCancel: (_) => onEnd(),
        child: ListView.builder(
          controller:      controller,
          scrollDirection: Axis.horizontal,
          physics:         const ClampingScrollPhysics(),
          padding:         EdgeInsets.only(left: leftPad, right: 16),
          itemCount:       cats.length * _catRepeat,
          itemExtent:      _catItemW, // O(1) extent math — no per-item layout needed
          itemBuilder:     (_, i) => _buildCategoryItem(cats[i % cats.length]),
        )));
  }

  Widget _buildCategoryItem(CategoryModel cat) {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => SubcategoryScreen(parent: cat))),
      child: Container(
        width: 72,
        margin: const EdgeInsets.only(right: 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 62, height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle, color: _surface,
              border: Border.all(color: _border),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6, offset: const Offset(0, 2))]),
            child: cat.imageUrl != null && cat.imageUrl!.isNotEmpty
                ? ClipOval(child: CachedNetworkImage(
                    imageUrl: ApiClient.fixImageUrl(cat.imageUrl) ?? '',
                    width: 62, height: 62, fit: BoxFit.cover,
                    memCacheWidth: 124,   // 62dp × 2x pixel ratio
                    memCacheHeight: 124,
                    placeholder: (_, _) => const SizedBox.shrink(),
                    errorWidget: (_, _, _) => Icon(
                        _catIcons[cat.slug] ?? Icons.category_outlined,
                        size: 26, color: _slate)))
                : Icon(_catIcons[cat.slug] ?? Icons.category_outlined,
                    size: 26, color: _slate)),
          const SizedBox(height: 6),
          Text(cat.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: _ink,
                fontWeight: FontWeight.w500, height: 1.3)),
        ])));
  }

  // ── TRUST STRIP ──────────────────────────────────────────────
  static const _trustItems = [
    {'icon': Icons.verified_outlined,      'label': '100% Authentic'},
    {'icon': Icons.security_outlined,      'label': 'Secure Pay'},
    {'icon': Icons.replay_outlined,        'label': 'Easy Returns'},
    {'icon': Icons.local_shipping_outlined,'label': 'Fast Delivery'},
  ];

  Widget _buildTrustStrip() {
    final items = _trustItems;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: items.map((item) => Column(children: [
          Icon((item['icon'] as IconData), size: 20, color: _teal),
          const SizedBox(height: 5),
          Text(item['label'] as String,
              style: TextStyle(fontSize: 9, color: _slate, fontWeight: FontWeight.w500)),
        ])).toList()));
  }

  // ── PRODUCT SECTION (generic for all sections) ───────────────
  Widget _buildSection(HomepageSection section) {
    if (section.isEmpty) return const SizedBox.shrink();

    // Flash Deals promotional banner — renders as full-width card, not carousel
    if (section.type == 'flash_deals_banner') {
      return _buildFlashDealsBanner(section);
    }

    final color = _sectionColor(section.key);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionHeaderFull(
        title:    section.title,
        subtitle: section.subtitle,
        color:    color,
        onTap:    () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => ProductListScreen(
              title:           section.title,
              sectionKey:      section.key,
              showFlashDeals:  section.key == 'flash_deals',
              staffPicksOnly:  section.key == 'staff_picks',
              maxPriceFilter:  section.key == 'under_800'  ? 800.0
                             : section.key == 'under_1500' ? 1500.0
                             : null,
            ))),
      ),
      // Auto-advancing carousel (timer-based, lightweight — not ticker)
      _AutoScrollCarousel(
        itemCount:   section.products.length,
        itemWidth:   169.0,  // 155px card + 14px right margin
        height:      246,    // was 240 — matches card height 244 + 2px margin
        itemBuilder: (_, i) => _buildProductCard(section.products[i], section.key),
      ),
      const SizedBox(height: 8),
    ]);
  }

  // ── FLASH DEALS PROMOTIONAL BANNER ───────────────────────────
  // Config keys: cta_text, cta_color, badge_text, discount_text,
  //              bg_color_from, bg_color_to, accent_color, image_url
  Widget _buildFlashDealsBanner(HomepageSection section) {
    final cfg          = section.config;
    final ctaText      = cfg['cta_text']?.toString()      ?? 'SHOP NOW';
    final badgeText    = cfg['badge_text']?.toString()    ?? '⚡ FLASH SALE';
    final discountText = cfg['discount_text']?.toString() ?? 'Up to 70% OFF';
    final imageUrl     = cfg['image_url']?.toString()     ?? '';
    final hasImage     = imageUrl.isNotEmpty;

    // Parse admin-configured hex colours with safe fallback
    Color parseHex(String key, Color fallback) {
      final val = cfg[key]?.toString() ?? '';
      if (val.isEmpty) return fallback;
      try {
        final hex = val.replaceAll('#', '');
        return Color(int.parse('FF$hex', radix: 16));
      } catch (_) { return fallback; }
    }

    final bgFrom     = parseHex('bg_color_from', const Color(0xFF0F172A));
    final bgTo       = parseHex('bg_color_to',   const Color(0xFF1E293B));
    final accentColor= parseHex('accent_color',  Colors.redAccent);
    final ctaColor   = parseHex('cta_color',     Colors.redAccent);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: GestureDetector(
        onTap: () {
          // Track banner click analytics
          ApiClient.post('/api/homepage/analytics', {
            'event_type':  'banner_click',
            'section_key': section.key,
            'metadata':    {'banner_type': 'flash_deals_banner'},
          }).catchError((_) => const ApiResponse(data: null, error: 'ignored'));
          // Navigate exclusively to flash deals products
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => ProductListScreen(
              title:          section.title.isNotEmpty ? section.title : 'Flash Deals',
              sectionKey:     'flash_deals',
              showFlashDeals: true,
            ),
          ));
        },
        child: Container(
          height: 156,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [bgFrom, bgTo],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(
              color: accentColor.withValues(alpha: 0.35),
              blurRadius: 20, offset: const Offset(0, 8),
            )],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(fit: StackFit.expand, children: [
              // Background image if configured
              if (hasImage)
                CachedNetworkImage(
                    imageUrl: ApiClient.fixImageUrl(imageUrl) ?? '',
                    fit: BoxFit.cover,
                    placeholder: (_, _) => const SizedBox.shrink(),
                    errorWidget: (_, _, _) => const SizedBox.shrink()),
              // Dark overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: hasImage
                        ? [Colors.black.withValues(alpha: 0.72), Colors.black.withValues(alpha: 0.30)]
                        : [Colors.transparent, Colors.transparent],
                  ),
                ),
              ),
              // Decorative lightning bolt circles
              Positioned(right: -24, top: -24,
                child: Container(width: 130, height: 130,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                        color: accentColor.withValues(alpha: 0.10)))),
              Positioned(right: 50, bottom: -40,
                child: Container(width: 80, height: 80,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.04)))),
              // Content
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 16, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Left: badge + title + subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment:  MainAxisAlignment.center,
                        children: [
                          // Badge chip
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color:  accentColor.withValues(alpha: 0.20),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: accentColor.withValues(alpha: 0.50)),
                            ),
                            child: Text(badgeText,
                                style: TextStyle(
                                  color: accentColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                )),
                          ),
                          const SizedBox(height: 8),
                          // Discount headline
                          Text(discountText,
                              style: const TextStyle(
                                color: Colors.white, fontSize: 26,
                                fontWeight: FontWeight.w900, height: 1.1,
                                letterSpacing: -0.5,
                              )),
                          const SizedBox(height: 4),
                          // Section subtitle
                          Text(
                            section.subtitle.isNotEmpty
                                ? section.subtitle
                                : 'Limited Time Offers',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Right: CTA button + lightning icon
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color:  accentColor.withValues(alpha: 0.15),
                            shape:  BoxShape.circle,
                            border: Border.all(color: accentColor.withValues(alpha: 0.40)),
                          ),
                          child: Icon(Icons.bolt_rounded, color: accentColor, size: 28),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                          decoration: BoxDecoration(
                            color:  ctaColor,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [BoxShadow(
                              color: ctaColor.withValues(alpha: 0.45),
                              blurRadius: 10, offset: const Offset(0, 4),
                            )],
                          ),
                          child: Text(ctaText,
                              style: const TextStyle(
                                color:      Colors.white,
                                fontSize:   11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              )),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Color _sectionColor(String key) {
    const map = {
      'flash_deals':       Colors.redAccent,
      'selling_out_soon':  Colors.orange,
      'quick_selling':     Colors.deepOrange,
      'new_arrivals':      Color(0xFF0D9488),
      'premium_collection':Color(0xFF7C3AED),
      'exclusive':         Color(0xFF7C3AED),
      'top_rated':         Colors.amber,
      'staff_picks':       Color(0xFF0D9488),
    };
    return map[key] ?? _teal;
  }

  Widget _buildProductCard(ProductModel p, String sectionKey) {
    final isFlashDeal = p.isFlashDealActive;
    final displayPrice = p.effectivePrice;
    final discount = p.discountPercent > 0 ? p.discountPercent
        : (isFlashDeal && p.originalPrice != null
            ? (((p.originalPrice! - displayPrice) / p.originalPrice!) * 100).round()
            : 0);

    return GestureDetector(
      onTap: () {
        // Track view + click
        context.read<HomepageProvider>().trackView(p.id);
        context.read<HomepageProvider>().trackClick(
            sectionKey: sectionKey, productId: p.id);
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: p.id)));
      },
      child: SizedBox(
        width: 155,
        height: 244,   // was 238 — extra 6px prevents 1px overflow from font metric rounding
        child: Container(
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10, offset: const Offset(0, 4))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Image
          Stack(children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: p.primaryImage != null
                  ? Container(
                      height: 130, width: 155, color: _surface,
                      child: CachedNetworkImage(
                          imageUrl: p.primaryImage!,
                          fit: BoxFit.contain,
                          memCacheWidth: 310,
                          placeholder: (_, _) => _imgPlaceholder(),
                          errorWidget: (_, _, _) => _imgPlaceholder()))
                  : _imgPlaceholder()),
            if (discount > 0)
              Positioned(top: 8, left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(6)),
                  child: Text('-$discount%',
                      style: const TextStyle(color: Colors.white,
                          fontSize: 10, fontWeight: FontWeight.bold)))),
            if (p.stock > 0 && p.stock <= 5)
              Positioned(top: 8, right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(color: Colors.orange.shade700,
                      borderRadius: BorderRadius.circular(6)),
                  child: Text('Only ${p.stock}',
                      style: const TextStyle(color: Colors.white,
                          fontSize: 9, fontWeight: FontWeight.w700)))),
            // Wishlist
            Positioned(bottom: 6, right: 6,
              child: GestureDetector(
                onTap: () async {
                  try { await context.read<WishlistProvider>().toggleWishlist(p.id); }
                  catch (_) {}
                },
                child: Consumer<WishlistProvider>(builder: (_, wish, _) =>
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9),
                        shape: BoxShape.circle),
                    child: Icon(
                      wish.isWishlisted(p.id) ? Icons.favorite : Icons.favorite_outline,
                      size: 14,
                      color: wish.isWishlisted(p.id) ? Colors.redAccent : _slate))))),
          ]),
          // Info — SingleChildScrollView suppresses any overflow debug message
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12,
                          fontWeight: FontWeight.w600, color: _ink, height: 1.3)),
                  if (p.brand != null) ...[
                    const SizedBox(height: 2),
                    Text(p.brand!, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10, color: _slate.withValues(alpha: 0.7))),
                  ],
                  const SizedBox(height: 5),
                  Row(children: [
                    const Icon(Icons.star_rounded, size: 11, color: Colors.amber),
                    const SizedBox(width: 2),
                    Text(p.rating > 0 ? p.rating.toStringAsFixed(1) : "New",
                        style: const TextStyle(fontSize: 10, color: _slate)),
                  ]),
                  const SizedBox(height: 5),
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Flexible(
                      child: Text('₹${displayPrice.toStringAsFixed(0)}',
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13,
                              fontWeight: FontWeight.bold, color: _ink)),
                    ),
                    if (p.originalPrice != null && p.originalPrice! > displayPrice) ...[
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text('₹${p.originalPrice!.toStringAsFixed(0)}',
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 10,
                                color: _slate.withValues(alpha: 0.6),
                                decoration: TextDecoration.lineThrough)),
                      ),
                    ],
                  ]),
                ],
              ),
              ),  // SingleChildScrollView
            ),
          ),
        ]))));  // Column, Container, SizedBox, GestureDetector
  }

  Widget _imgPlaceholder() => Container(
    height: 130, width: 155, color: _surface,
    child: Icon(Icons.image_outlined, size: 36, color: _border));

  // ── BRAND STRIP ──────────────────────────────────────────────
  Widget _buildBrandStrip(List<BrandModel> brands) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionHeader('Featured Brands', onTap: null),
      _AutoScrollCarousel(
        itemCount:        brands.length,
        itemWidth:        130.0,  // fixed brand card width
        height:           52,
        padding:          const EdgeInsets.symmetric(horizontal: 16),
        advanceInterval:  const Duration(milliseconds: 2800),
        itemBuilder: (_, i) {
          final brand = brands[i];
          return GestureDetector(
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) =>
                    ProductListScreen(title: brand.name, brandName: brand.name))),
            child: Container(
              width:  120,
              height: 52,
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border)),
              child: brand.logoUrl != null && brand.logoUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: ApiClient.fixImageUrl(brand.logoUrl) ?? '',
                      height: 28, fit: BoxFit.contain,
                      placeholder: (_, _) => const SizedBox.shrink(),
                      errorWidget: (_, _, _) => _brandText(brand.name))
                  : Center(child: _brandText(brand.name))));
        }),
      const SizedBox(height: 8),
    ]);
  }

  Widget _brandText(String name) => Text(name, textAlign: TextAlign.center,
      maxLines: 1, overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _ink));

  // ── SECTION HEADERS ───────────────────────────────────────────
  Widget _sectionHeader(String title, {VoidCallback? onTap}) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 22, 16, 12),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(title, style: const TextStyle(fontSize: 17,
          fontWeight: FontWeight.bold, color: _ink)),
      if (onTap != null)
        GestureDetector(onTap: onTap,
          child: const Text('See All', style: TextStyle(fontSize: 13,
              color: _teal, fontWeight: FontWeight.w600))),
    ]));

  Widget _sectionHeaderFull({
    required String title,
    String subtitle = '',
    Color color = _teal,
    VoidCallback? onTap,
  }) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 22, 16, 12),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 17,
            fontWeight: FontWeight.bold, color: _ink)),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(fontSize: 11, color: _slate)),
        ],
      ])),
      if (onTap != null)
        GestureDetector(onTap: onTap,
          child: Text('See All', style: TextStyle(fontSize: 13,
              color: color, fontWeight: FontWeight.w600))),
    ]));

  // ── EXTRA DISCOUNT BANNER (admin-configurable via HomepageSections admin) ───
  // Config fields: image_url, coupon_code, cta_text, cta_destination, bg_from, bg_to
  Widget _buildDiscountBannerCard(HomepageSection section) {
    final cfg         = section.config;
    final imageUrl    = cfg['image_url']?.toString()       ?? '';
    final couponCode  = cfg['coupon_code']?.toString()     ?? '';
    final ctaText     = cfg['cta_text']?.toString()        ?? 'Shop Now';
    final ctaDest     = cfg['cta_destination']?.toString() ?? 'categories';
    final hasImage    = imageUrl.isNotEmpty;
    final bannerH     = hasImage ? 200.0 : 160.0;

    void onTap() {
      switch (ctaDest) {
        case 'flash_deals':
          Navigator.push(context, MaterialPageRoute(
              builder: (_) => const ProductListScreen(title: 'Flash Deals', showFlashDeals: true)));
          break;
        case 'products':
          Navigator.push(context, MaterialPageRoute(
              builder: (_) => const ProductListScreen(title: 'All Products')));
          break;
        default:
          Navigator.push(context, MaterialPageRoute(
              builder: (_) => const CategoriesScreen()));
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: bannerH,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF7C3AED), Color(0xFF4C1D95)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
              blurRadius: 20, offset: const Offset(0, 8),
            )],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(fit: StackFit.expand, children: [
              // Background: network image OR decorative circles
              if (hasImage)
                CachedNetworkImage(
                  imageUrl: ApiClient.fixImageUrl(imageUrl) ?? '',
                  fit: BoxFit.cover,
                  placeholder: (_, _) => const SizedBox.shrink(),
                  errorWidget: (_, _, _) => const SizedBox.shrink(),
                ),
              // Dark overlay (heavier when image is present so text stays legible)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: hasImage
                        ? [
                            Colors.black.withValues(alpha: 0.70),
                            Colors.black.withValues(alpha: 0.35),
                          ]
                        : [
                            const Color(0xFF7C3AED).withValues(alpha: 0.0),
                            const Color(0xFF4C1D95).withValues(alpha: 0.0),
                          ],
                  ),
                ),
              ),
              // Decorative circles (only when no image)
              if (!hasImage) ...[
                Positioned(right: -30, top: -30,
                  child: Container(width: 160, height: 160,
                      decoration: BoxDecoration(shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.06)))),
                Positioned(right: 60, bottom: -50,
                  child: Container(width: 110, height: 110,
                      decoration: BoxDecoration(shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.04)))),
                Positioned(left: -20, bottom: -20,
                  child: Container(width: 80, height: 80,
                      decoration: BoxDecoration(shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.05)))),
              ],
              // Content overlay
              Padding(
                padding: EdgeInsets.fromLTRB(22, hasImage ? 20 : 18, 22, hasImage ? 20 : 18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Left: badge + title + subtitle + coupon chip
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment:  MainAxisAlignment.center,
                        children: [
                          // "EXCLUSIVE DEAL" badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color:  Colors.white.withValues(alpha: 0.20),
                              borderRadius: BorderRadius.circular(20)),
                            child: const Text('EXCLUSIVE DEAL',
                                style: TextStyle(color: Colors.white, fontSize: 8,
                                    fontWeight: FontWeight.w800, letterSpacing: 1.5))),
                          const SizedBox(height: 8),
                          // Heading
                          Text(section.title.isEmpty ? 'Extra 10% Off' : section.title,
                              style: TextStyle(
                                color: Colors.white, fontSize: hasImage ? 22 : 20,
                                fontWeight: FontWeight.w800, height: 1.15)),
                          if (section.subtitle.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(section.subtitle,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.80),
                                  fontSize: 11)),
                          ],
                          // Coupon code chip
                          if (couponCode.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.50),
                                    width: 1.0,
                                    // Dashed border via a custom approach is complex in Flutter;
                                    // solid border with higher opacity looks premium too.
                                    style: BorderStyle.solid)),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.local_offer_outlined,
                                    size: 12, color: Colors.white.withValues(alpha: 0.85)),
                                const SizedBox(width: 5),
                                Text('USE CODE: $couponCode',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8,
                                    )),
                              ]),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Right: CTA button
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 8, offset: const Offset(0, 3),
                        )],
                      ),
                      child: Text(ctaText,
                          style: const TextStyle(
                            color: Color(0xFF7C3AED),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ))),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ── LUXURY EDIT — curated luxury collections grid ────────────────────────
  Widget _buildLuxuryEditSection(List<LuxuryCollectionModel> collections) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionHeaderFull(
        title:    'Luxury Edit',
        subtitle: 'Curated for You',
        color:    const Color(0xFFF59E0B), // amber
        onTap:    null,
      ),
      SizedBox(
        height: 210,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding:  const EdgeInsets.fromLTRB(16, 0, 16, 0),
          itemCount: collections.length,
          itemExtent: 175.0, // fixed width per card incl. right margin
          itemBuilder: (_, i) => _buildLuxuryCard(collections[i]),
        ),
      ),
      const SizedBox(height: 12),
    ]);
  }

  Widget _buildLuxuryCard(LuxuryCollectionModel col) {
    // Gradient background colours per category — makes cards visually distinct
    const cardGradients = <String, List<Color>>{
      'watches':               [Color(0xFF1E293B), Color(0xFF334155)],
      'bags-luggage':          [Color(0xFF1C1917), Color(0xFF44403C)],
      'perfumes':              [Color(0xFF1E1B4B), Color(0xFF3730A3)],
      'beauty-personal-care':  [Color(0xFF500724), Color(0xFF9F1239)],
      'jewelry-accessories':   [Color(0xFF1C1917), Color(0xFF78350F)],
      'fashion':               [Color(0xFF0C4A6E), Color(0xFF0369A1)],
      'electronics':           [Color(0xFF0F2027), Color(0xFF203A43)],
    };

    final gradColors = cardGradients[col.categorySlug]
        ?? [const Color(0xFF1E293B), const Color(0xFF374151)];

    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => ProductListScreen(
            title:        col.title,
            collectionId: col.id,
          ))),
      child: Container(
        width: 161, // 175 itemExtent - 14 right margin
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 14, offset: const Offset(0, 6),
          )],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(fit: StackFit.expand, children: [
            // Background: network image OR gradient
            if (col.imageUrl != null && col.imageUrl!.isNotEmpty)
              CachedNetworkImage(
                imageUrl: ApiClient.fixImageUrl(col.imageUrl) ?? '',
                fit: BoxFit.cover,
                placeholder: (_, _) => const SizedBox.shrink(),
                errorWidget: (ctx, err, st) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  )),
              )
            else
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            // Bottom gradient overlay for text legibility
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    stops: const [0.0, 0.55, 1.0],
                    colors: [
                      Colors.black.withValues(alpha: 0.85),
                      Colors.black.withValues(alpha: 0.30),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Top-left shimmer accent
            Positioned(top: -20, right: -20,
              child: Container(
                width: 70, height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            // Content pinned at bottom
            Positioned(bottom: 0, left: 0, right: 0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(col.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        )),
                    if (col.description.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(col.description,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 9,
                            height: 1.35,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ],
                    const SizedBox(height: 9),
                    // CTA chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(col.ctaText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            )),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_ios_rounded,
                            size: 8, color: Colors.white),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── CUSTOMER REVIEWS ──────────────────────────────────────────
  Widget _buildReviewsSection(List<Map<String, dynamic>> reviews) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionHeader('Customer Reviews', onTap: null),
      SizedBox(
        height: 170,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: reviews.length,
          itemExtent: 240,
          itemBuilder: (_, i) => _buildReviewCard(reviews[i]),
        )),
      const SizedBox(height: 8),
    ]);
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final rating = (review['rating'] as num?)?.toDouble() ?? 5.0;
    final name   = review['user_name']?.toString() ?? 'Customer';
    final body   = review['body']?.toString()  ?? review['title']?.toString() ?? '';
    final title  = review['title']?.toString() ?? '';
    return Container(
      width:  226,
      margin: const EdgeInsets.only(right: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8, offset: const Offset(0, 3))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Row(children: List.generate(5, (i) => Icon(
            i < rating.round()
                ? Icons.star_rounded
                : Icons.star_outline_rounded,
            size: 13, color: Colors.amber))),
          const Spacer(),
          Text(name, style: TextStyle(fontSize: 10, color: _slate,
              fontWeight: FontWeight.w600)),
        ]),
        if (title.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: _ink),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
        const SizedBox(height: 5),
        Expanded(child: Text(body,
            style: TextStyle(fontSize: 11, color: _slate, height: 1.45),
            maxLines: 4, overflow: TextOverflow.ellipsis)),
        const SizedBox(height: 6),
        Row(children: [
          Icon(Icons.verified_rounded, size: 11, color: _teal),
          const SizedBox(width: 3),
          Text('Verified Purchase', style: TextStyle(fontSize: 9, color: _teal)),
        ]),
      ]),
    );
  }

  // ── FOLLOW US ─────────────────────────────────────────────────
  Widget _buildFollowUsSection(Map<String, String> links) {
    final socials = <_SocialEntry>[
      _SocialEntry(Icons.camera_alt_outlined, 'Instagram', links['instagram_url'] ?? ''),
      _SocialEntry(Icons.facebook_outlined,   'Facebook',  links['facebook_url']  ?? ''),
      _SocialEntry(Icons.play_circle_outline, 'YouTube',   links['youtube_url']   ?? ''),
      _SocialEntry(Icons.alternate_email,     'Twitter',   links['twitter_url']   ?? ''),
    ].where((s) => s.url.isNotEmpty).toList();
    if (socials.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 22, 16, 0),
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(children: [
        const Text('Follow Us',
            style: TextStyle(color: Colors.white, fontSize: 18,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 3),
        const Text('Stay updated with our latest collections',
            style: TextStyle(color: Colors.white70, fontSize: 11)),
        const SizedBox(height: 18),
        Row(mainAxisAlignment: MainAxisAlignment.center,
          children: socials.map((s) => GestureDetector(
            onTap: () => _launchUrl(s.url),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle),
              child: Icon(s.icon, color: Colors.white, size: 22)),
          )).toList()),
        const SizedBox(height: 12),
        Text('@savaan',
            style: const TextStyle(color: Colors.white60, fontSize: 12,
                letterSpacing: 1.2)),
      ]),
    );
  }

  // ── URL launcher helper ────────────────────────────────────────
  Future<void> _launchUrl(String url) async {
    if (url.isEmpty) return;
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  // ── SKELETON LOADER ───────────────────────────────────────────
  Widget _buildSkeleton() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(children: [
        // Top bar shimmer
        Container(margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            height: 44, color: _surface),
        const SizedBox(height: 14),
        // Search bar shimmer
        Container(margin: const EdgeInsets.symmetric(horizontal: 16),
            height: 48, decoration: BoxDecoration(color: _surface,
                borderRadius: BorderRadius.circular(14))),
        const SizedBox(height: 16),
        // Banner shimmer
        Container(margin: const EdgeInsets.symmetric(horizontal: 16),
            height: 190, decoration: BoxDecoration(color: _surface,
                borderRadius: BorderRadius.circular(20))),
        const SizedBox(height: 22),
        // Category dual-row shimmer
        _buildCategoryShimmer(),
        // Section shimmer x3
        ...List.generate(3, (_) => Column(children: [
          Container(margin: const EdgeInsets.fromLTRB(16, 22, 16, 12),
              width: 160, height: 20, decoration: BoxDecoration(
                  color: _surface, borderRadius: BorderRadius.circular(6))),
          SizedBox(height: 246,  // matches live carousel height
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 4,
              itemBuilder: (_, _) => Container(
                width: 155, margin: const EdgeInsets.only(right: 14),
                decoration: BoxDecoration(color: _surface,
                    borderRadius: BorderRadius.circular(16))))),
        ])),
      ]));
  }

  // ── CATEGORY SHIMMER (skeleton) ───────────────────────────────
  Widget _buildCategoryShimmer() {
    Widget row(double leftPad, int count) => SizedBox(
      height: 104,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.only(left: leftPad, right: 16),
        itemCount: count,
        itemBuilder: (_, _) => Container(
          margin: const EdgeInsets.only(right: 16),
          child: Column(children: [
            Container(width: 62, height: 62,
                decoration: BoxDecoration(
                    shape: BoxShape.circle, color: _surface,
                    border: Border.all(color: _border))),
            const SizedBox(height: 8),
            Container(width: 44, height: 10,
                decoration: BoxDecoration(color: _surface,
                    borderRadius: BorderRadius.circular(4))),
          ]))));
    return Column(children: [
      row(16, 5),
      const SizedBox(height: 10),
      row(44, 4),   // offset matches live row 2
      const SizedBox(height: 8),
    ]);
  }

  // ── DRAWER ───────────────────────────────────────────────────
  Widget _buildDrawer() {
    // Use Consumer so wishlist/notif badge updates don't rebuild the whole screen.
    return Consumer<WishlistProvider>(builder: (_, wishProv, _) {
    final wishCount = wishProv.count;
    return Drawer(
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(24))),
      child: SafeArea(child: Column(children: [
        // Header
        Padding(padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Row(children: [
            Image.asset('assets/logo.png', height: 48,
                errorBuilder: (_, _, _) => Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [_teal, _green]),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.diamond_outlined,
                      size: 26, color: Colors.white))),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                  colors: [Color(0xFF0D9488), Color(0xFF22C55E)],
                  begin: Alignment.centerLeft, end: Alignment.centerRight)
                    .createShader(b),
                blendMode: BlendMode.srcIn,
                child: const Text('SAVAAN',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                        letterSpacing: 3, color: Colors.white))),
              Text('Luxury & Trust',
                  style: TextStyle(fontSize: 11, color: _slate, letterSpacing: 1.2)),
            ]),
          ])),
        Divider(color: _border, height: 1),
        const SizedBox(height: 8),
        // Menu
        Expanded(child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          itemCount: _drawerItems.length,
          itemBuilder: (ctx, i) {
            final item  = _drawerItems[i];
            final label = item['label'] as String;
            int badge = item['badge'] as int;
            if (label == 'Wishlist')       badge = wishCount;
            if (label == 'Notifications')  badge = _unreadNotifCount;
            return ListTile(
              dense: true,
              leading: Icon((item['icon'] as IconData), size: 22, color: _slate),
              title: Text(label, style: const TextStyle(fontSize: 14,
                  fontWeight: FontWeight.w500, color: _ink)),
              trailing: badge > 0
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [_teal, _green]),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text('$badge', style: const TextStyle(color: Colors.white,
                          fontSize: 11, fontWeight: FontWeight.bold)))
                  : const Icon(Icons.chevron_right, size: 18, color: Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () {
                Navigator.pop(context);
                if (label == 'Home') return;
                if (label == 'Categories') {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoriesScreen()));
                } else if (label == 'Wishlist') {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const WishlistScreen()));
                } else if (label == 'My Orders') {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersScreen()));
                } else if (label == 'Notifications') {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                } else if (label == 'Settings') {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                } else if (label == 'Coupons') {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    isScrollControlled: true,
                    builder: (_) => DraggableScrollableSheet(
                      initialChildSize: 0.6,
                      maxChildSize: 0.9,
                      minChildSize: 0.3,
                      builder: (_, controller) => ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                        child: ColoredBox(
                          color: Colors.white,
                          child: _CouponsDrawerSheet(scrollController: controller),
                        ),
                      ),
                    ),
                  );
                } else if (label == 'Help & Support') {
                  _showHelpSheet(context);
                }
              });
          })),
        Divider(color: _border, height: 1),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          leading: const Icon(Icons.logout_rounded, size: 22, color: Colors.redAccent),
          title: const Text('Logout', style: TextStyle(fontSize: 14,
              fontWeight: FontWeight.w600, color: Colors.redAccent)),
          onTap: _logout),
        const SizedBox(height: 8),
      ])));
    }); // Consumer<WishlistProvider>
  }

  void _showHelpSheet(BuildContext ctx) {
    showModalBottomSheet(context: ctx, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(2))),
          const Text('Help & Support', style: TextStyle(fontSize: 17,
              fontWeight: FontWeight.bold, color: _ink)),
          const SizedBox(height: 16),
          _helpTile(Icons.email_outlined, 'Email Us', 'customer@savaan.in'),
          _helpTile(Icons.phone_outlined, 'Call Us', '+91 91105 81825'),
          _helpTile(Icons.chat_outlined, 'Live Chat', 'Coming Soon'),
        ])));
  }

  Widget _helpTile(IconData icon, String label, String value) => ListTile(
    leading: Icon(icon, color: _teal),
    title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
    subtitle: Text(value, style: TextStyle(color: _slate, fontSize: 12)));

  // ── BOTTOM NAV ───────────────────────────────────────────────
  Widget _buildBottomNav() => Container(
    decoration: BoxDecoration(color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16, offset: const Offset(0, -4))]),
    child: SafeArea(top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(_navItems.length, (i) {
            final isActive = _currentIndex == i;
            return GestureDetector(
              onTap: () {
                if (i == 0) { setState(() => _currentIndex = 0); return; }
                setState(() => _currentIndex = i);
                Widget screen;
                if (i == 1) {
                  screen = const CategoriesScreen();
                } else if (i == 2) {
                  screen = const CartScreen();
                } else if (i == 3) {
                  screen = const WishlistScreen();
                } else {
                  screen = const ProfileScreen();
                }
                Navigator.push(context, MaterialPageRoute(builder: (_) => screen))
                    .then((_) {
                  if (mounted) {
                    setState(() => _currentIndex = 0);
                    // Only reload cart after visiting the cart screen —
                    // CartScreen modifies quantities so a refresh is needed.
                    // Wishlist IDs are updated optimistically in WishlistProvider,
                    // so loadIds() on every return is redundant.
                    if (i == 2) context.read<CartProvider>().loadCart();
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                    color: isActive ? _teal.withValues(alpha: 0.08) : Colors.transparent,
                    borderRadius: BorderRadius.circular(14)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(isActive
                      ? (_navItems[i]['active'] as IconData)
                      : (_navItems[i]['icon'] as IconData),
                      size: 24,
                      color: isActive ? _teal : _slate.withValues(alpha: 0.6)),
                  const SizedBox(height: 3),
                  Text(_navItems[i]['label'] as String,
                      style: TextStyle(fontSize: 10,
                          color: isActive ? _teal : _slate.withValues(alpha: 0.6),
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal)),
                ])));
          })))));
}

// ── Social entry helper ───────────────────────────────────────────────────────
class _SocialEntry {
  final IconData icon;
  final String   label;
  final String   url;
  const _SocialEntry(this.icon, this.label, this.url);
}

// ── Auto-Scroll Carousel ──────────────────────────────────────────────────────
/// Lightweight horizontal carousel that:
///  • repeats its items virtually (infinite loop)
///  • auto-advances by one card every [advanceInterval]  (Timer, not Ticker)
///  • pauses on finger touch, resumes 2 s after release
///  • uses itemExtent for O(1) scroll extent math
class _AutoScrollCarousel extends StatefulWidget {
  final int                              itemCount;
  final double                           itemWidth;
  final double                           height;
  final EdgeInsetsGeometry               padding;
  final Duration                         advanceInterval;
  final Widget Function(BuildContext, int) itemBuilder;

  const _AutoScrollCarousel({
    required this.itemCount,
    required this.itemWidth,
    required this.height,
    required this.itemBuilder,
    this.padding         = const EdgeInsets.symmetric(horizontal: 16),
    this.advanceInterval = const Duration(milliseconds: 3500),
  });

  @override
  State<_AutoScrollCarousel> createState() => _AutoScrollCarouselState();
}

class _AutoScrollCarouselState extends State<_AutoScrollCarousel> {
  // Virtual list: repeat 80× so the user can scroll freely for a very long time
  static const int _repeat = 80;
  static const int _mid    = 39; // start index (near middle of virtual list)

  late ScrollController _ctrl;
  Timer? _timer;
  bool   _paused = false;

  double get _initialOffset =>
      widget.itemWidth * widget.itemCount * _mid;

  double get _safeMax =>
      widget.itemWidth * widget.itemCount * (_repeat - 10);

  @override
  void initState() {
    super.initState();
    _ctrl = ScrollController();
    // Jump to mid-point after first frame so the list appears infinite both ways
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _ctrl.hasClients) _ctrl.jumpTo(_initialOffset);
    });
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    if (widget.itemCount < 2) return; // nothing to advance
    _timer = Timer.periodic(widget.advanceInterval, (_) {
      if (!mounted || _paused || !_ctrl.hasClients) return;
      double target = _ctrl.offset + widget.itemWidth;
      if (target > _safeMax) target = _initialOffset;
      _ctrl.animateTo(target,
          duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
    });
  }

  void _onUserStart() {
    _paused = true;
    _timer?.cancel();
  }

  void _onUserEnd() {
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) { _paused = false; _startTimer(); }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.itemCount == 0) return const SizedBox.shrink();
    return SizedBox(
      height: widget.height,
      child: Listener(
        onPointerDown:   (_) => _onUserStart(),
        onPointerUp:     (_) => _onUserEnd(),
        onPointerCancel: (_) => _onUserEnd(),
        child: ListView.builder(
          controller:      _ctrl,
          scrollDirection: Axis.horizontal,
          physics:         const ClampingScrollPhysics(),
          padding:         widget.padding,
          itemCount:       widget.itemCount * _repeat,
          itemExtent:      widget.itemWidth,  // O(1) scroll extent math
          itemBuilder:     (ctx, i) =>
              widget.itemBuilder(ctx, i % widget.itemCount),
        ),
      ),
    );
  }
}

// ── Coupons sheet — fetches live coupons from API ─────────────────────────────
class _CouponsDrawerSheet extends StatefulWidget {
  final ScrollController? scrollController;
  const _CouponsDrawerSheet({this.scrollController});
  @override
  State<_CouponsDrawerSheet> createState() => _CouponsDrawerSheetState();
}

class _CouponsDrawerSheetState extends State<_CouponsDrawerSheet> {
  static const Color _ink     = Color(0xFF0F172A);
  static const Color _teal    = Color(0xFF0D9488);
  static const Color _green   = Color(0xFF10B981);
  static const Color _slate   = Color(0xFF64748B);
  static const Color _border  = Color(0xFFE2E8F0);
  static const Color _surface = Color(0xFFF8FAFC);

  List<Map<String, dynamic>> _coupons = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiClient.get('/api/coupons', auth: false);
      if (mounted) {
        setState(() {
          if (res.isSuccess && res.data != null) {
            final raw  = res.data!;
            final list = raw['_list'] as List? ?? [];
            _coupons   = List<Map<String, dynamic>>.from(list);
          }
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _copy(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Coupon "$code" copied!',
          style: const TextStyle(color: Colors.white)),
      backgroundColor: _teal,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final headerSliver = [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 36, height: 4,
                decoration: BoxDecoration(color: _border,
                    borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            const Text('Available Coupons',
                style: TextStyle(fontSize: 18,
                    fontWeight: FontWeight.bold, color: _ink)),
            const SizedBox(height: 16),
          ]),
        ),
      ),
    ];

    if (_loading) {
      return CustomScrollView(
        controller: widget.scrollController,
        slivers: [
          ...headerSliver,
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(color: _teal, strokeWidth: 2)),
            ),
          ),
        ],
      );
    }
    if (_coupons.isEmpty) {
      return CustomScrollView(
        controller: widget.scrollController,
        slivers: [
          ...headerSliver,
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('No active coupons right now.\nCheck back soon!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _slate, fontSize: 14))),
            ),
          ),
        ],
      );
    }
    return CustomScrollView(
      controller: widget.scrollController,
      slivers: [
        ...headerSliver,
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) {
                if (i.isOdd) return const SizedBox(height: 10);
                return _buildCard(_coupons[i ~/ 2]);
              },
              childCount: _coupons.length * 2 - 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCard(Map<String, dynamic> c) {
    final code     = c['code']?.toString() ?? '';
    final type     = c['discount_type']?.toString() ?? 'flat';
    final value    = double.tryParse(
        c['discount_value']?.toString() ?? '0') ?? 0;
    final minOrder = double.tryParse(
        c['min_order_value']?.toString() ?? '0') ?? 0;
    final label    = type == 'percent'
        ? '${value.toInt()}% OFF'
        : '₹${value.toInt()} OFF';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_teal.withValues(alpha: 0.04),
                   _green.withValues(alpha: 0.02)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _teal.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_teal, _green]),
            borderRadius: BorderRadius.circular(8)),
          child: Text(label,
              style: const TextStyle(color: Colors.white,
                  fontWeight: FontWeight.bold, fontSize: 12)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(code,
              style: const TextStyle(fontSize: 14,
                  fontWeight: FontWeight.bold, color: _ink)),
          if (minOrder > 0)
            Text('Min. order ₹${minOrder.toInt()}',
                style: TextStyle(fontSize: 11, color: _slate)),
          if (c['description'] != null &&
              c['description'].toString().isNotEmpty)
            Text(c['description'].toString(),
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: _slate)),
        ])),
        GestureDetector(
          onTap: () => _copy(code),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _border)),
            child: const Text('COPY',
                style: TextStyle(fontSize: 11,
                    fontWeight: FontWeight.w700, color: _slate)),
          ),
        ),
      ]),
    );
  }
}

