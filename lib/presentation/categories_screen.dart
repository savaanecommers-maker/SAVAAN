import 'package:flutter/material.dart';
import '../data/api_client.dart';
import '../data/category_service.dart';
import '../models/category_model.dart';
import 'subcategory_screen.dart';

/// Level 1 screen — premium parent-category card grid.
/// Tapping a card opens [SubcategoryScreen] (Level 2).
class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final _categoryService = CategoryService();

  List<CategoryModel> _parents  = [];
  bool               _isLoading = true;

  static const Color _ink     = Color(0xFF0F172A);
  static const Color _teal    = Color(0xFF0D9488);
  static const Color _slate   = Color(0xFF64748B);
  static const Color _border  = Color(0xFFE2E8F0);
  static const Color _surface = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _loadParents();
  }

  Future<void> _loadParents() async {
    setState(() => _isLoading = true);
    try {
      final list = await _categoryService.getParentCategories();
      if (mounted) setState(() { _parents = list; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          _buildTopBar(),
          Expanded(child: _buildBody()),
        ]),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back, size: 24, color: _ink),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Text('Categories',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _ink)),
        ),
      ]),
    );
  }

  // ── Body ──────────────────────────────────────────────────────
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: _teal));
    }
    if (_parents.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.category_outlined, size: 48, color: _slate.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text('No categories yet', style: TextStyle(color: _slate, fontSize: 14)),
        ]),
      );
    }
    return RefreshIndicator(
      color: _teal,
      onRefresh: _loadParents,
      child: _buildParentGrid(),
    );
  }

  // ── Level 1: parent category grid ────────────────────────────
  Widget _buildParentGrid() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:   2,
        childAspectRatio: 0.85,
        crossAxisSpacing: 14,
        mainAxisSpacing:  14,
      ),
      itemCount: _parents.length,
      itemBuilder: (_, i) => _buildParentCard(_parents[i]),
    );
  }

  Widget _buildParentCard(CategoryModel cat) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SubcategoryScreen(parent: cat)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8, offset: const Offset(0, 3),
          )],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Category image — DB url → slug map → icon placeholder
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: _catImage(cat),
            ),
          ),
          // Name + count row
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(cat.name,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700, color: _ink)),
              const SizedBox(height: 3),
              Row(children: [
                Text('${cat.itemCount} Items',
                    style: TextStyle(fontSize: 12, color: _slate)),
                const Spacer(),
                Icon(Icons.arrow_forward_ios_rounded, size: 11, color: _teal),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  // ── Curated Unsplash images for parent category slugs ────────
  static const Map<String, String> _slugImages = {
    'fashion':                  'https://images.unsplash.com/photo-1483985988355-763728e1935b?w=400&h=300&fit=crop',
    'watches':                  'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=400&h=300&fit=crop',
    'beauty-personal-care':     'https://images.unsplash.com/photo-1522335789203-aabd1fc54bc9?w=400&h=300&fit=crop',
    'electronics':              'https://images.unsplash.com/photo-1498049794561-7780e7231661?w=400&h=300&fit=crop',
    'home-decor':               'https://images.unsplash.com/photo-1555041469-a586c61ea9bc?w=400&h=300&fit=crop',
    'jewelry-accessories':      'https://images.unsplash.com/photo-1599643477877-530eb83abc8e?w=400&h=300&fit=crop',
    'bags-luggage':             'https://images.unsplash.com/photo-1548036328-c9fa89d128fa?w=400&h=300&fit=crop',
    'footwear':                 'https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=400&h=300&fit=crop',
    'gifts-luxury-collections': 'https://images.unsplash.com/photo-1549465220-1a8b9238cd48?w=400&h=300&fit=crop',
    'health-wellness':          'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=400&h=300&fit=crop',
    'mobiles-accessories':      'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?w=400&h=300&fit=crop',
    'seasonal-collections':     'https://images.unsplash.com/photo-1607082348824-0a96f2a4b9da?w=400&h=300&fit=crop',
  };

  Widget _catImage(CategoryModel cat) {
    final dbUrl  = cat.imageUrl != null && cat.imageUrl!.isNotEmpty
        ? ApiClient.fixImageUrl(cat.imageUrl!) : null;
    final mapUrl = _slugImages[cat.slug];
    final url    = dbUrl ?? mapUrl;
    if (url != null) {
      return Image.network(url,
          width: double.infinity, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              (mapUrl != null && url != mapUrl)
                  ? Image.network(mapUrl, width: double.infinity, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _catPlaceholder(cat))
                  : _catPlaceholder(cat));
    }
    return _catPlaceholder(cat);
  }

  // ── Placeholder when image is absent / fails ──────────────────
  Widget _catPlaceholder(CategoryModel cat) => Container(
    color: _surface,
    child: Center(
      child: Icon(_catIcon(cat.slug), size: 40, color: _teal.withValues(alpha: 0.4)),
    ),
  );

  IconData _catIcon(String slug) {
    switch (slug) {
      case 'fashion':                  return Icons.checkroom_outlined;
      case 'watches':                  return Icons.watch_outlined;
      case 'beauty-personal-care':     return Icons.spa_outlined;
      case 'electronics':              return Icons.devices_outlined;
      case 'home-decor':               return Icons.chair_outlined;
      case 'jewelry-accessories':      return Icons.diamond_outlined;
      case 'bags-luggage':             return Icons.luggage_outlined;
      case 'footwear':                 return Icons.directions_walk_outlined;
      case 'gifts-luxury-collections': return Icons.card_giftcard_outlined;
      case 'health-wellness':          return Icons.favorite_outline;
      case 'mobiles-accessories':      return Icons.smartphone_outlined;
      case 'seasonal-collections':     return Icons.event_outlined;
      case 'featured-categories':      return Icons.star_outline;
      default:                         return Icons.category_outlined;
    }
  }

  // ── Bottom nav ────────────────────────────────────────────────
  Widget _buildBottomNav() {
    final navItems = [
      {'icon': Icons.home_outlined,          'active': Icons.home_rounded,          'label': 'Home'},
      {'icon': Icons.grid_view_outlined,     'active': Icons.grid_view_rounded,     'label': 'Categories'},
      {'icon': Icons.shopping_cart_outlined, 'active': Icons.shopping_cart_rounded, 'label': 'Cart'},
      {'icon': Icons.favorite_outline,       'active': Icons.favorite_rounded,      'label': 'Wishlist'},
      {'icon': Icons.person_outline_rounded, 'active': Icons.person_rounded,        'label': 'Profile'},
    ];
    const activeIndex = 1;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 16, offset: const Offset(0, -4),
        )],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(navItems.length, (i) {
              final isActive = i == activeIndex;
              return GestureDetector(
                onTap: () { if (i == 0) Navigator.pop(context); },
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    isActive
                        ? (navItems[i]['active'] as IconData)
                        : (navItems[i]['icon']   as IconData),
                    size: 24,
                    color: isActive ? _teal : _slate,
                  ),
                  const SizedBox(height: 3),
                  Text(navItems[i]['label'] as String,
                      style: TextStyle(
                        fontSize: 10,
                        color: isActive ? _teal : _slate,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                      )),
                  if (isActive)
                    Container(
                      margin: const EdgeInsets.only(top: 3),
                      width: 4, height: 4,
                      decoration: const BoxDecoration(
                          color: _teal, shape: BoxShape.circle),
                    ),
                ]),
              );
            }),
          ),
        ),
      ),
    );
  }
}
