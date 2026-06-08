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
  static const Color _surface = Color(0xFFF8FAFC);

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
      return Image.network(
        ApiClient.fixImageUrl(url),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _gradientBox(),
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
          childAspectRatio: 0.88,
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
  Widget _buildSubCard(CategoryModel sub) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductListScreen(title: sub.name, category: sub),
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
          // Image / icon area
          Expanded(
            flex: 5,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: sub.imageUrl != null && sub.imageUrl!.isNotEmpty
                  ? Image.network(
                      ApiClient.fixImageUrl(sub.imageUrl!),
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _iconArea(sub),
                    )
                  : _iconArea(sub),
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
