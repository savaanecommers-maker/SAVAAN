import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../data/api_client.dart';
import '../data/category_service.dart';
import '../models/category_model.dart';
import 'product_list_screen.dart';

/// Level 2 screen — subcategory card grid for a given parent category.
/// Tapping a card navigates to [ProductListScreen] (Level 3).
/// If the parent has no subcategories, automatically replaces itself with
/// [ProductListScreen] so the user never sees a blank screen.
class SubcategoryScreen extends StatefulWidget {
  final CategoryModel parent;

  const SubcategoryScreen({super.key, required this.parent});

  @override
  State<SubcategoryScreen> createState() => _SubcategoryScreenState();
}

class _SubcategoryScreenState extends State<SubcategoryScreen> {
  final _service = CategoryService();

  List<CategoryModel> _subs   = [];
  bool               _loading = true;

  static const Color _ink     = Color(0xFF0F172A);
  static const Color _teal    = Color(0xFF0D9488);
  static const Color _slate   = Color(0xFF64748B);
  static const Color _border  = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final subs = await _service.getSubcategories(widget.parent.id);
    if (!mounted) return;
    if (subs.isEmpty) {
      // No subcategories — jump straight to product listing for parent
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ProductListScreen(
            title: widget.parent.name,
            category: widget.parent,
            parentCategory: widget.parent,
          ),
        ),
      );
      return;
    }
    setState(() { _subs = subs; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _loading
          ? _buildLoadingShell()
          : CustomScrollView(
              slivers: [
                _buildSliverAppBar(),
                SliverToBoxAdapter(child: _buildSectionHeader()),
                _buildGrid(),
                const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
              ],
            ),
    );
  }

  // ── Loading shell — shows hero + spinner while data loads ─────
  Widget _buildLoadingShell() {
    return Column(children: [
      SizedBox(
        height: 220,
        child: Stack(fit: StackFit.expand, children: [
          _heroBackground(),
          Container(color: Colors.black.withValues(alpha: 0.35)),
          Positioned(
            bottom: 20, left: 20,
            child: Text(widget.parent.name,
                style: const TextStyle(
                    color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 4,
            left: 4,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ]),
      ),
      const Expanded(child: Center(child: CircularProgressIndicator(color: _teal))),
    ]);
  }

  // ── Sliver app bar with category hero image / gradient ────────
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      elevation: 0,
      backgroundColor: _teal,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(56, 0, 16, 14),
        title: Text(
          widget.parent.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        background: Stack(fit: StackFit.expand, children: [
          _heroBackground(),
          // Gradient — dark at top (status bar) and bottom (title legibility)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.4, 1.0],
                colors: [Color(0x88000000), Color(0x22000000), Color(0xCC000000)],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _heroBackground() {
    final url = widget.parent.imageUrl;
    if (url != null && url.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: ApiClient.fixImageUrl(url) ?? '',
        fit: BoxFit.cover,
        placeholder: (_, _) => _gradientBox(),
        errorWidget: (_, _, _) => _gradientBox(),
      );
    }
    return _gradientBox();
  }

  Widget _gradientBox() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
      ),
    ),
  );

  // ── Section header ────────────────────────────────────────────
  Widget _buildSectionHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Shop by Category',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _ink)),
        const SizedBox(height: 4),
        Text('${_subs.length} categories in ${widget.parent.name}',
            style: TextStyle(fontSize: 13, color: _slate)),
      ]),
    );
  }

  // ── Subcategory grid ──────────────────────────────────────────
  Widget _buildGrid() {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount:   2,
          mainAxisExtent:   192, // fixed height — never overflows on any screen size
          crossAxisSpacing: 14,
          mainAxisSpacing:  14,
        ),
        delegate: SliverChildBuilderDelegate(
          (_, i) => _buildSubCard(_subs[i]),
          childCount: _subs.length,
        ),
      ),
    );
  }

  // ── Individual subcategory card ───────────────────────────────
  // ── Curated Unsplash images per subcategory slug ─────────────
  // Used as fallback when the DB has no imageUrl set.
  static const Map<String, String> _slugImages = {
    // ── Watches ──────────────────────────────────────────────────
    'luxury-watches':   'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=400&h=300&fit=crop',
    'smart-watches':    'https://images.unsplash.com/photo-1544117519-31a4b719223d?w=400&h=300&fit=crop',
    'analog-watches':   'https://images.unsplash.com/photo-1509048191080-d2984bad6ae5?w=400&h=300&fit=crop',
    'digital-watches':  'https://images.unsplash.com/photo-1434056886845-dac89ffe9b56?w=400&h=300&fit=crop',
    'couple-watches':   'https://images.unsplash.com/photo-1547996160-81dfa63595aa?w=400&h=300&fit=crop',
    'sports-watches':   'https://images.unsplash.com/photo-1508685096489-7aacd43bd3b1?w=400&h=300&fit=crop',
    // ── Fashion ──────────────────────────────────────────────────
    'mens-clothing':    'https://images.unsplash.com/photo-1617137968427-85924c800a22?w=400&h=300&fit=crop',
    'womens-clothing':  'https://images.unsplash.com/photo-1567401893414-76b7b1e5a7a5?w=400&h=300&fit=crop',
    'kids-wear':        'https://images.unsplash.com/photo-1519457431-44ccd64a579b?w=400&h=300&fit=crop',
    'ethnic-wear':      'https://images.unsplash.com/photo-1610030469983-98e550d6193c?w=400&h=300&fit=crop',
    'western-wear':     'https://images.unsplash.com/photo-1551232864-3f0890e580d9?w=400&h=300&fit=crop',
    'fashion-footwear': 'https://images.unsplash.com/photo-1543163521-1bf539c55dd2?w=400&h=300&fit=crop',
    'fashion-handbags': 'https://images.unsplash.com/photo-1548036328-c9fa89d128fa?w=400&h=300&fit=crop',
    'wallets':          'https://images.unsplash.com/photo-1627123424574-724758594e93?w=400&h=300&fit=crop',
    'belts':            'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?w=400&h=300&fit=crop',
    // ── Beauty ───────────────────────────────────────────────────
    'perfumes':         'https://images.unsplash.com/photo-1541643600914-78b084683702?w=400&h=300&fit=crop',
    'skincare':         'https://images.unsplash.com/photo-1556228578-8c89e6adf883?w=400&h=300&fit=crop',
    'makeup':           'https://images.unsplash.com/photo-1522335789203-aabd1fc54bc9?w=400&h=300&fit=crop',
    'hair-care':        'https://images.unsplash.com/photo-1522337360788-8b13dee7a37e?w=400&h=300&fit=crop',
    'grooming-kits':    'https://images.unsplash.com/photo-1621607505329-3ec10b41b23b?w=400&h=300&fit=crop',
    'bath-body':        'https://images.unsplash.com/photo-1570194065650-d99fb4bedf0a?w=400&h=300&fit=crop',
    // ── Electronics ──────────────────────────────────────────────
    'smartphones':      'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?w=400&h=300&fit=crop',
    'laptops':          'https://images.unsplash.com/photo-1496181133206-80ce9b88a853?w=400&h=300&fit=crop',
    'tablets':          'https://images.unsplash.com/photo-1544244015-0df4b3ffc6b0?w=400&h=300&fit=crop',
    'headphones':       'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=400&h=300&fit=crop',
    'smart-gadgets':    'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=400&h=300&fit=crop',
    'accessories':      'https://images.unsplash.com/photo-1491553895911-0055eca6402d?w=400&h=300&fit=crop',
    'elec-accessories': 'https://images.unsplash.com/photo-1491553895911-0055eca6402d?w=400&h=300&fit=crop',
    // ── Home Decor ───────────────────────────────────────────────
    'wall-art':         'https://images.unsplash.com/photo-1513519245088-0e12902e5a38?w=400&h=300&fit=crop',
    'lamps-lighting':   'https://images.unsplash.com/photo-1513506003901-1e6a35549853?w=400&h=300&fit=crop',
    'decorative-items': 'https://images.unsplash.com/photo-1586023492125-27b2c045efd7?w=400&h=300&fit=crop',
    'furniture':        'https://images.unsplash.com/photo-1555041469-a586c61ea9bc?w=400&h=300&fit=crop',
    'vases':            'https://images.unsplash.com/photo-1578500494198-246f612d3b3d?w=400&h=300&fit=crop',
    'clocks':           'https://images.unsplash.com/photo-1563861826100-9cb868fdbe1c?w=400&h=300&fit=crop',
    // ── Jewelry ──────────────────────────────────────────────────
    'necklaces':           'https://images.unsplash.com/photo-1599643477877-530eb83abc8e?w=400&h=300&fit=crop',
    'earrings':            'https://images.unsplash.com/photo-1535556116002-6281ff3e9f36?w=400&h=300&fit=crop',
    'rings':               'https://images.unsplash.com/photo-1605100804763-247f67b3557e?w=400&h=300&fit=crop',
    'bracelets':           'https://images.unsplash.com/photo-1573408301185-9519f94edc26?w=400&h=300&fit=crop',
    'sunglasses':          'https://images.unsplash.com/photo-1511499767150-a48a237f0083?w=400&h=300&fit=crop',
    'fashion-accessories': 'https://images.unsplash.com/photo-1606760227091-3dd870d97f1d?w=400&h=300&fit=crop',
    // ── Bags ─────────────────────────────────────────────────────
    'travel-bags':  'https://images.unsplash.com/photo-1565026057447-bc90a3dceb87?w=400&h=300&fit=crop',
    'backpacks':    'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?w=400&h=300&fit=crop',
    'trolley-bags': 'https://images.unsplash.com/photo-1565026057447-bc90a3dceb87?w=400&h=300&fit=crop',
    'laptop-bags':  'https://images.unsplash.com/photo-1548036328-c9fa89d128fa?w=400&h=300&fit=crop',
    'bags-handbags':'https://images.unsplash.com/photo-1548036328-c9fa89d128fa?w=400&h=300&fit=crop',
    // ── Footwear ─────────────────────────────────────────────────
    'casual-shoes': 'https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=400&h=300&fit=crop',
    'formal-shoes': 'https://images.unsplash.com/photo-1614252235316-8c857d38b5f4?w=400&h=300&fit=crop',
    'sneakers':     'https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=400&h=300&fit=crop',
    'sandals':      'https://images.unsplash.com/photo-1603487742131-4160ec999306?w=400&h=300&fit=crop',
    'sports-shoes': 'https://images.unsplash.com/photo-1556906781-9a412961d28e?w=400&h=300&fit=crop',
    // ── Gifts ────────────────────────────────────────────────────
    'premium-gift-sets':   'https://images.unsplash.com/photo-1549465220-1a8b9238cd48?w=400&h=300&fit=crop',
    'corporate-gifts':     'https://images.unsplash.com/photo-1607344645866-009c320b63e0?w=400&h=300&fit=crop',
    'festival-collections':'https://images.unsplash.com/photo-1512389142860-9c449e58a543?w=400&h=300&fit=crop',
    'luxury-collections':  'https://images.unsplash.com/photo-1549465220-1a8b9238cd48?w=400&h=300&fit=crop',
    // ── Health & Fitness ─────────────────────────────────────────
    'fitness-equipment': 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=400&h=300&fit=crop',
    'yoga-accessories':  'https://images.unsplash.com/photo-1544367567-0f2fcb009e0b?w=400&h=300&fit=crop',
    'health-devices':    'https://images.unsplash.com/photo-1576091160399-112ba8d25d1d?w=400&h=300&fit=crop',
    'supplements':       'https://images.unsplash.com/photo-1584308666744-24d5c474f2ae?w=400&h=300&fit=crop',
    // ── Mobiles ──────────────────────────────────────────────────
    'mobile-phones': 'https://images.unsplash.com/photo-1598327105666-5b89351aff97?w=400&h=300&fit=crop',
    'cases-covers':  'https://images.unsplash.com/photo-1601593346740-925612772716?w=400&h=300&fit=crop',
    'chargers':      'https://images.unsplash.com/photo-1601758228041-f3b2795255f1?w=400&h=300&fit=crop',
    'power-banks':   'https://images.unsplash.com/photo-1609592806596-b8a33e92c0c6?w=400&h=300&fit=crop',
    'earbuds':       'https://images.unsplash.com/photo-1590658268037-6bf12165a8df?w=400&h=300&fit=crop',
    // ── Seasonal / Featured ──────────────────────────────────────
    'summer-collection':          'https://images.unsplash.com/photo-1473496169904-658ba7574b0d?w=400&h=300&fit=crop',
    'winter-collection':          'https://images.unsplash.com/photo-1542060748-10c28b62716f?w=400&h=300&fit=crop',
    'festival-specials':          'https://images.unsplash.com/photo-1512389142860-9c449e58a543?w=400&h=300&fit=crop',
    'new-arrivals':               'https://images.unsplash.com/photo-1483985988355-763728e1935b?w=400&h=300&fit=crop',
    'seasonal-new-arrivals':      'https://images.unsplash.com/photo-1483985988355-763728e1935b?w=400&h=300&fit=crop',
    'featured-new-arrivals':      'https://images.unsplash.com/photo-1483985988355-763728e1935b?w=400&h=300&fit=crop',
    'best-sellers':               'https://images.unsplash.com/photo-1607082348824-0a96f2a4b9da?w=400&h=300&fit=crop',
    'seasonal-best-sellers':      'https://images.unsplash.com/photo-1607082348824-0a96f2a4b9da?w=400&h=300&fit=crop',
    'trending-products':          'https://images.unsplash.com/photo-1483985988355-763728e1935b?w=400&h=300&fit=crop',
    'flash-deals':                'https://images.unsplash.com/photo-1607082348824-0a96f2a4b9da?w=400&h=300&fit=crop',
    'premium-collection':         'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=400&h=300&fit=crop',
    'luxury-collection':          'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=400&h=300&fit=crop',
    'featured-luxury-collection': 'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=400&h=300&fit=crop',
    'exclusive-offers':           'https://images.unsplash.com/photo-1607082348824-0a96f2a4b9da?w=400&h=300&fit=crop',
  };

  Widget _buildSubCard(CategoryModel sub) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductListScreen(title: sub.name, category: sub, parentCategory: widget.parent),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(children: [
          // Image / icon area — prefer DB imageUrl, fall back to slug map, then icon
          Expanded(
            flex: 5,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: _buildSubImage(sub),
            ),
          ),
          // Name + item count
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    sub.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _ink,
                      height: 1.3,
                    ),
                  ),
                  if (sub.itemCount > 0) ...[
                    const SizedBox(height: 3),
                    Text('${sub.itemCount} items',
                        style: TextStyle(fontSize: 10, color: _slate)),
                  ],
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  /// Returns a network image for [sub], trying:
  ///  1. DB imageUrl  2. curated slug map  3. icon placeholder
  Widget _buildSubImage(CategoryModel sub) {
    final dbUrl   = ApiClient.fixImageUrl(sub.imageUrl);
    final mapUrl  = _slugImages[sub.slug];
    final url     = dbUrl ?? mapUrl;

    if (url != null) {
      return CachedNetworkImage(
        imageUrl: url,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (_, _) => const SizedBox.shrink(),
        errorWidget: (_, _, _) => mapUrl != null && url != mapUrl
            ? CachedNetworkImage(imageUrl: mapUrl, width: double.infinity, fit: BoxFit.cover,
                placeholder: (_, _) => const SizedBox.shrink(),
                errorWidget: (_, _, _) => _iconArea(sub))
            : _iconArea(sub),
      );
    }
    return _iconArea(sub);
  }

  Widget _iconArea(CategoryModel sub) => Container(
    width: double.infinity,
    color: _teal.withValues(alpha: 0.07),
    child: Center(
      child: Icon(_catIcon(sub.slug), size: 44, color: _teal),
    ),
  );

  // ── Icon map for every subcategory slug ───────────────────────
  IconData _catIcon(String slug) {
    switch (slug) {
      // Fashion
      case 'mens-clothing':             return Icons.man_outlined;
      case 'womens-clothing':           return Icons.woman_outlined;
      case 'kids-wear':                 return Icons.child_care_outlined;
      case 'ethnic-wear':               return Icons.checkroom_outlined;
      case 'western-wear':              return Icons.style_outlined;
      case 'fashion-footwear':          return Icons.directions_walk_outlined;
      case 'fashion-handbags':          return Icons.shopping_bag_outlined;
      case 'wallets':                   return Icons.account_balance_wallet_outlined;
      case 'belts':                     return Icons.remove_outlined;
      // Watches
      case 'luxury-watches':            return Icons.watch_outlined;
      case 'smart-watches':             return Icons.watch_outlined;
      case 'analog-watches':            return Icons.watch_outlined;
      case 'digital-watches':           return Icons.watch_outlined;
      case 'couple-watches':            return Icons.watch_outlined;
      case 'sports-watches':            return Icons.sports_outlined;
      // Beauty
      case 'perfumes':                  return Icons.local_florist_outlined;
      case 'skincare':                  return Icons.face_outlined;
      case 'makeup':                    return Icons.brush_outlined;
      case 'hair-care':                 return Icons.content_cut_outlined;
      case 'grooming-kits':             return Icons.cut_outlined;
      case 'bath-body':                 return Icons.soap_outlined;
      // Electronics
      case 'smartphones':               return Icons.smartphone_outlined;
      case 'laptops':                   return Icons.laptop_outlined;
      case 'tablets':                   return Icons.tablet_outlined;
      case 'headphones':                return Icons.headphones_outlined;
      case 'smart-gadgets':             return Icons.devices_other_outlined;
      case 'accessories':
      case 'elec-accessories':          return Icons.cable_outlined;
      // Home Decor
      case 'wall-art':                  return Icons.image_outlined;
      case 'lamps-lighting':            return Icons.lightbulb_outline;
      case 'decorative-items':          return Icons.auto_awesome_outlined;
      case 'furniture':                 return Icons.weekend_outlined;
      case 'vases':                     return Icons.local_florist_outlined;
      case 'clocks':                    return Icons.access_time_outlined;
      // Jewelry
      case 'necklaces':                 return Icons.diamond_outlined;
      case 'earrings':                  return Icons.diamond_outlined;
      case 'rings':                     return Icons.circle_outlined;
      case 'bracelets':                 return Icons.diamond_outlined;
      case 'sunglasses':                return Icons.wb_sunny_outlined;
      case 'fashion-accessories':       return Icons.style_outlined;
      // Bags
      case 'travel-bags':               return Icons.luggage_outlined;
      case 'backpacks':                 return Icons.backpack_outlined;
      case 'trolley-bags':              return Icons.luggage_outlined;
      case 'laptop-bags':               return Icons.laptop_outlined;
      case 'bags-handbags':             return Icons.shopping_bag_outlined;
      // Footwear
      case 'casual-shoes':              return Icons.directions_walk_outlined;
      case 'formal-shoes':              return Icons.directions_walk_outlined;
      case 'sneakers':                  return Icons.directions_run_outlined;
      case 'sandals':                   return Icons.directions_walk_outlined;
      case 'sports-shoes':              return Icons.sports_outlined;
      // Gifts
      case 'premium-gift-sets':         return Icons.card_giftcard_outlined;
      case 'corporate-gifts':           return Icons.business_center_outlined;
      case 'festival-collections':      return Icons.celebration_outlined;
      case 'luxury-collections':        return Icons.workspace_premium_outlined;
      // Health
      case 'fitness-equipment':         return Icons.fitness_center_outlined;
      case 'yoga-accessories':          return Icons.self_improvement_outlined;
      case 'health-devices':            return Icons.monitor_heart_outlined;
      case 'supplements':               return Icons.medication_outlined;
      // Mobiles
      case 'mobile-phones':             return Icons.smartphone_outlined;
      case 'cases-covers':              return Icons.phone_iphone_outlined;
      case 'chargers':                  return Icons.battery_charging_full_outlined;
      case 'power-banks':               return Icons.battery_full_outlined;
      case 'earbuds':                   return Icons.headphones_outlined;
      // Seasonal
      case 'summer-collection':         return Icons.wb_sunny_outlined;
      case 'winter-collection':         return Icons.ac_unit_outlined;
      case 'festival-specials':         return Icons.celebration_outlined;
      case 'new-arrivals':
      case 'seasonal-new-arrivals':
      case 'featured-new-arrivals':     return Icons.fiber_new_outlined;
      case 'best-sellers':
      case 'seasonal-best-sellers':     return Icons.trending_up_outlined;
      // Featured
      case 'trending-products':         return Icons.trending_up_outlined;
      case 'flash-deals':               return Icons.flash_on_outlined;
      case 'premium-collection':        return Icons.workspace_premium_outlined;
      case 'luxury-collection':
      case 'featured-luxury-collection':return Icons.diamond_outlined;
      case 'exclusive-offers':          return Icons.local_offer_outlined;
      default:                          return Icons.category_outlined;
    }
  }
}
