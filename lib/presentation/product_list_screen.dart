import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../data/product_service.dart';
import '../models/product_model.dart';
import '../models/category_model.dart';
import 'product_detail_screen.dart';
import 'cart_screen.dart';

class ProductListScreen extends StatefulWidget {
  final CategoryModel? category;
  final String? title;
  final bool showFlashDeals;
  final bool showFeatured;
  // Section-specific navigation params
  final String? sectionKey;      // e.g. 'best_sellers', 'new_arrivals', 'staff_picks', 'trending_now'
  final String? brandName;       // filter by brand (ILIKE)
  final double? maxPriceFilter;  // for under_800 / under_1500 sections
  final String? collectionId;    // luxury collection id → fetch by category_slug
  final bool staffPicksOnly;     // force is_staff_pick=true query
  final String? searchQuery;     // full-text search from SearchScreen
  final CategoryModel? parentCategory; // parent of category (for subcategory attr matching)

  const ProductListScreen({
    super.key,
    this.category,
    this.parentCategory,
    this.title,
    this.showFlashDeals = false,
    this.showFeatured = false,
    this.sectionKey,
    this.brandName,
    this.maxPriceFilter,
    this.collectionId,
    this.staffPicksOnly = false,
    this.searchQuery,
  });

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final _productService = ProductService();

  List<ProductModel> _products = [];
  List<ProductModel> _filtered = [];
  bool _isLoading = true;
  bool _isGridView = true;

  // Filter state
  String _sortBy = 'popular';
  RangeValues _priceRange = const RangeValues(0, 100000);
  double _maxPrice = 100000;
  Set<String> _selectedBrands = {};
  bool _inStockOnly = false;
  Set<String> _selectedSizes = {};
  Set<String> _selectedColors = {};
  Set<String> _selectedAttributes = {};

  // Active filter count
  int get _activeFilters =>
      (_inStockOnly ? 1 : 0) +
      (_selectedBrands.isNotEmpty ? 1 : 0) +
      (_priceRange.start > 0 || _priceRange.end < _maxPrice ? 1 : 0) +
      (_selectedSizes.isNotEmpty ? 1 : 0) +
      (_selectedColors.isNotEmpty ? 1 : 0) +
      (_selectedAttributes.isNotEmpty ? 1 : 0);

  static const Color _ink     = Color(0xFF0F172A);
  static const Color _teal    = Color(0xFF0D9488);
  static const Color _green   = Color(0xFF10B981);
  static const Color _slate   = Color(0xFF64748B);
  static const Color _border  = Color(0xFFE2E8F0);
  static const Color _surface = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      List<ProductModel> products;
      if (widget.searchQuery != null && widget.searchQuery!.isNotEmpty) {
        products = await _productService.searchProducts(widget.searchQuery!, limit: 200);
      } else if (widget.showFlashDeals) {
        products = await _productService.getFlashDeals(limit: 100);
      } else if (widget.category != null) {
        products = await _productService.getProductsByCategory(
          widget.category!.id, sortBy: 'newest',
        );
      } else if (widget.staffPicksOnly || widget.sectionKey == 'staff_picks') {
        products = await _productService.getStaffPicks(limit: 100);
      } else if (widget.brandName != null && widget.brandName!.isNotEmpty) {
        products = await _productService.getByBrand(widget.brandName!, limit: 100);
      } else if (widget.maxPriceFilter != null) {
        products = await _productService.getUnderPrice(widget.maxPriceFilter!, limit: 100);
      } else if (widget.collectionId != null) {
        products = await _productService.getCollectionProducts(widget.collectionId!, limit: 100);
      } else {
        // Dispatch by sectionKey
        switch (widget.sectionKey) {
          case 'best_sellers':
          case 'quick_selling':
          case 'selling_out_soon':
            products = await _productService.getBestSellers(limit: 100);
            break;
          case 'new_arrivals':
            products = await _productService.getNewArrivals(limit: 100);
            break;
          case 'trending_now':
            products = await _productService.getBestSellers(limit: 100);
            break;
          case 'top_rated':
            products = await _productService.getProducts(sortBy: 'rating', limit: 100);
            break;
          default:
            products = await _productService.getProducts(sortBy: 'newest', limit: 100);
        }
      }

      if (mounted) {
        // Compute max price for slider
        double maxP = 100000;
        if (products.isNotEmpty) {
          maxP = products.map((p) => p.price).reduce((a, b) => a > b ? a : b);
          maxP = (maxP / 1000).ceil() * 1000;
        }
        setState(() {
          _products = products;
          _maxPrice = maxP;
          _priceRange = RangeValues(0, maxP);
          _isLoading = false;
        });
        _applyFilters();
      }
    } catch (e) {
      debugPrint('ProductList error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    var list = List<ProductModel>.from(_products);

    // Price filter
    list = list.where((p) =>
    p.price >= _priceRange.start && p.price <= _priceRange.end).toList();

    // Brand filter
    if (_selectedBrands.isNotEmpty) {
      list = list.where((p) =>
      p.brand != null && _selectedBrands.contains(p.brand)).toList();
    }

    // In stock
    if (_inStockOnly) {
      list = list.where((p) => p.isInStock).toList();
    }

    // Size filter (from variants)
    if (_selectedSizes.isNotEmpty) {
      list = list.where((p) => p.variants.any(
          (v) => v.size != null && _selectedSizes.contains(v.size))).toList();
    }

    // Color filter (from variants, fallback to name/description)
    if (_selectedColors.isNotEmpty) {
      list = list.where((p) {
        if (p.variants.any((v) => v.color != null)) {
          return p.variants.any((v) => v.color != null && _selectedColors.contains(v.color));
        }
        final text = '${p.name} ${p.description ?? ''}'.toLowerCase();
        return _selectedColors.any((c) => text.contains(c.toLowerCase()));
      }).toList();
    }

    // Attribute filter — use attributes array if tagged, else keyword fallback for untagged products
    if (_selectedAttributes.isNotEmpty) {
      list = list.where((p) {
        if (p.attributes.isNotEmpty) {
          return p.attributes.any((a) => _selectedAttributes.contains(a));
        }
        // Legacy untagged products: keyword match in name/brand/description
        final text = '${p.name} ${p.brand ?? ''} ${p.description ?? ''}'.toLowerCase();
        return _selectedAttributes.any((a) => text.contains(a.toLowerCase()));
      }).toList();
    }

    // Sort
    switch (_sortBy) {
      case 'price_low':
        list.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'price_high':
        list.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'newest':
        list.sort((a, b) =>
            (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
        break;
      case 'rating':
        list.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      default:
        list.sort((a, b) => b.reviewCount.compareTo(a.reviewCount));
    }

    setState(() => _filtered = list);
  }

  List<String> get _allBrands => _products
      .where((p) => p.brand != null && p.brand!.isNotEmpty)
      .map((p) => p.brand!).toSet().toList()..sort();

  List<String> get _allSizes => _products
      .expand((p) => p.variants
          .where((v) => v.size != null && v.size!.isNotEmpty)
          .map((v) => v.size!))
      .toSet().toList();

  List<String> get _allColors => _products
      .expand((p) => p.variants
          .where((v) => v.color != null && v.color!.isNotEmpty)
          .map((v) => v.color!))
      .toSet().toList()..sort();

  // Match a DB slug to an attr key — mirrors admin panel's slugToAttrKey
  String? _slugToAttrKey(String slug) {
    final s = slug.toLowerCase();
    if (s.startsWith('fashion') || s.contains('clothing') || s.contains('shirts') ||
        s.contains('dresses') || s.contains('kurta') || s.contains('saree') ||
        s.contains('trousers') || s.contains('tops') || s.contains('jeans') ||
        s.contains('mens-') || s.contains('womens-') || s.contains('kids-fashion') ||
        s.contains('boys-') || s.contains('girls-')) return 'fashion';
    if (s.startsWith('footwear') || s.contains('shoes') || s.contains('sneakers') ||
        s.contains('boots') || s.contains('sandals') || s.contains('slippers') ||
        s.contains('heels') || s.contains('loafers')) return 'footwear';
    if (s.startsWith('watches') || s.contains('watch')) return 'watches';
    if (s.startsWith('perfumes') || s.contains('fragrance') || s.contains('cologne') ||
        s.contains('attar') || s.contains('deodorant')) return 'perfumes';
    if (s.startsWith('jewelry') || s.contains('rings') || s.contains('necklace') ||
        s.contains('bracelet') || s.contains('earring') || s.contains('pendant') ||
        s.contains('bangles') || s.contains('chains') || s.contains('wallets') ||
        s.contains('belts')) return 'jewelry';
    if (s.startsWith('bags') || s.contains('luggage') || s.contains('handbag') ||
        s.contains('backpack') || s.contains('trolley') || s.contains('travel-bag') ||
        s.contains('laptop-bag')) return 'bags';
    if (s.startsWith('beauty') || s.contains('skincare') || s.contains('makeup') ||
        s.contains('hair-care') || s.contains('personal-care')) return 'beauty';
    if (s.startsWith('mobiles') || s.contains('mobile-phones') || s.contains('smartphones') ||
        s.contains('chargers') || s.contains('power-bank') || s.contains('cases-covers')) return 'mobiles';
    if (s.startsWith('electronics') || s.contains('laptops') || s.contains('headphones') ||
        s.contains('tablets') || s.contains('cameras') || s.contains('speakers')) return 'electronics';
    if (s.startsWith('home-decor') || s.contains('furniture') || s.contains('decorative') ||
        s.contains('clocks') || s.contains('lighting')) return 'home-decor';
    if (s.startsWith('health') || s.contains('wellness') || s.contains('vitamins') ||
        s.contains('supplements') || s.contains('nutrition') || s.contains('fitness')) return 'health';
    if (s.startsWith('seasonal') || s.contains('festival') || s.contains('festive') ||
        s.contains('monsoon')) return 'seasonal';
    return null;
  }

  String get _categorySlug {
    final catSlug    = widget.category?.slug ?? '';
    final parentSlug = widget.parentCategory?.slug ?? '';
    return _slugToAttrKey(catSlug) ?? _slugToAttrKey(parentSlug) ?? 'general';
  }

  static const Map<String, Map<String, List<String>>> _categoryAttrs = {
    'fashion': {
      'Gender':   ['Men', 'Women', 'Unisex', 'Boys', 'Girls'],
      'Material': ['Cotton', 'Polyester', 'Silk', 'Linen', 'Denim', 'Leather', 'Wool'],
    },
    'footwear': {
      'Gender':   ['Men', 'Women', 'Unisex', 'Boys', 'Girls'],
      'Material': ['Leather', 'Canvas', 'Synthetic', 'Rubber', 'Suede'],
      'Closure':  ['Lace-up', 'Slip-on', 'Velcro', 'Buckle'],
    },
    'watches': {
      'Gender':         ['Men', 'Women', 'Unisex'],
      'Strap Material': ['Leather', 'Metal', 'Rubber', 'Silicone', 'Mesh'],
      'Dial Shape':     ['Round', 'Square', 'Rectangle', 'Oval'],
      'Features':       ['Water Resistant', 'Chronograph', 'Automatic', 'Smart', 'Quartz'],
    },
    'perfumes': {
      'Gender':           ['Men', 'Women', 'Unisex'],
      'Fragrance Family': ['Floral', 'Woody', 'Oriental', 'Fresh', 'Citrus', 'Aquatic', 'Musky'],
      'Volume':           ['30ml', '50ml', '75ml', '100ml', '200ml'],
    },
    'electronics': {
      'Storage':  ['64GB', '128GB', '256GB', '512GB'],
      'RAM':      ['4GB', '6GB', '8GB', '12GB', '16GB'],
      'Features': ['Wireless', 'Bluetooth', 'WiFi', 'Fast Charging', 'USB-C'],
    },
    'beauty': {
      'Skin Type':   ['Oily', 'Dry', 'Combination', 'Sensitive', 'All'],
      'Formulation': ['Cream', 'Serum', 'Gel', 'Oil', 'Powder'],
    },
    'home-decor': {
      'Style': ['Modern', 'Traditional', 'Bohemian', 'Minimalist', 'Rustic'],
      'Room':  ['Living Room', 'Bedroom', 'Kitchen', 'Bathroom', 'Office'],
    },
    'jewelry': {
      'Gender':     ['Men', 'Women', 'Unisex'],
      'Metal Type': ['Gold', 'Silver', 'Rose Gold', 'Platinum', 'Brass'],
      'Stone':      ['Diamond', 'Ruby', 'Emerald', 'Sapphire', 'Pearl', 'None'],
    },
    'bags': {
      'Gender':   ['Men', 'Women', 'Unisex'],
      'Type':     ['Backpack', 'Handbag', 'Tote', 'Clutch', 'Wallet', 'Luggage'],
      'Material': ['Leather', 'Canvas', 'Nylon', 'Polyester'],
    },
    'health': {
      'Form':     ['Tablet', 'Capsule', 'Liquid', 'Powder', 'Cream'],
      'Benefits': ['Immunity', 'Energy', 'Sleep', 'Weight', 'Skin', 'Hair'],
    },
    'mobiles': {
      'OS':       ['Android', 'iOS', 'Other'],
      'Features': ['5G', 'Wireless Charging', 'Fast Charging', 'Foldable'],
    },
    'seasonal': {
      'Season': ['Summer', 'Winter', 'Monsoon', 'Festive'],
      'Gender': ['Men', 'Women', 'Unisex', 'Kids'],
    },
  };

  void _showSortSheet() {
    final opts = [
      {'value': 'popular',    'label': 'Most Popular',          'icon': Icons.local_fire_department_outlined},
      {'value': 'rating',     'label': 'Highest Rated',         'icon': Icons.star_outline_rounded},
      {'value': 'price_low',  'label': 'Price: Low to High',    'icon': Icons.arrow_upward_rounded},
      {'value': 'price_high', 'label': 'Price: High to Low',    'icon': Icons.arrow_downward_rounded},
      {'value': 'newest',     'label': 'Newest First',          'icon': Icons.fiber_new_outlined},
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4,
              decoration: BoxDecoration(color: _border,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Sort By',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _ink)),
          ),
          const SizedBox(height: 12),
          ...opts.map((o) => ListTile(
            dense: true,
            leading: Icon(o['icon'] as IconData,
                size: 20, color: _sortBy == o['value'] ? _teal : _slate),
            title: Text(o['label'] as String,
                style: TextStyle(
                  fontSize: 14,
                  color: _sortBy == o['value'] ? _teal : _ink,
                  fontWeight: _sortBy == o['value'] ? FontWeight.w600 : FontWeight.normal,
                )),
            trailing: _sortBy == o['value']
                ? const Icon(Icons.check_circle_rounded, color: _teal, size: 20)
                : null,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            onTap: () {
              setState(() => _sortBy = o['value'] as String);
              _applyFilters();
              Navigator.pop(context);
            },
          )),
        ]),
      ),
    );
  }

  void _showFilterSheet() {
    RangeValues tempPrice  = _priceRange;
    Set<String> tempBrands = Set.from(_selectedBrands);
    bool        tempStock  = _inStockOnly;
    Set<String> tempSizes  = Set.from(_selectedSizes);
    Set<String> tempColors = Set.from(_selectedColors);
    Set<String> tempAttrs  = Set.from(_selectedAttributes);

    final catAttrs = _categoryAttrs[_categorySlug] ?? {};

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => DraggableScrollableSheet(
          initialChildSize: 0.78,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (_, scrollCtrl) => Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(children: [
                Container(width: 36, height: 4,
                    decoration: BoxDecoration(color: _border,
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                Row(children: [
                  const Expanded(
                    child: Text('Filters',
                        style: TextStyle(fontSize: 17,
                            fontWeight: FontWeight.bold, color: _ink)),
                  ),
                  GestureDetector(
                    onTap: () => setS(() {
                      tempPrice  = RangeValues(0, _maxPrice);
                      tempBrands = {};
                      tempStock  = false;
                      tempSizes  = {};
                      tempColors = {};
                      tempAttrs  = {};
                    }),
                    child: const Text('Reset All',
                        style: TextStyle(fontSize: 13, color: _teal,
                            fontWeight: FontWeight.w600)),
                  ),
                ]),
              ]),
            ),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                children: [
                  // Availability
                  _filterSection('Availability', child: Row(children: [
                    const Expanded(child: Text('In Stock Only',
                        style: TextStyle(fontSize: 14, color: _ink))),
                    Switch(value: tempStock,
                        onChanged: (v) => setS(() => tempStock = v),
                        activeThumbColor: _teal),
                  ])),

                  const SizedBox(height: 20),

                  // Price Range
                  _filterSection('Price Range', child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                        _priceChip('₹${tempPrice.start.toInt()}'),
                        Text('to', style: TextStyle(color: _slate, fontSize: 13)),
                        _priceChip('₹${tempPrice.end.toInt()}'),
                      ]),
                      const SizedBox(height: 8),
                      RangeSlider(
                        values: tempPrice, min: 0, max: _maxPrice, divisions: 20,
                        activeColor: _teal, inactiveColor: _border,
                        onChanged: (v) => setS(() => tempPrice = v),
                      ),
                    ],
                  )),

                  // Brand
                  if (_allBrands.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _filterSection('Brand', child: _chipWrap(
                      items: _allBrands,
                      selected: tempBrands,
                      onToggle: (b) => setS(() {
                        if (tempBrands.contains(b)) { tempBrands.remove(b); }
                        else { tempBrands.add(b); }
                      }),
                    )),
                  ],

                  // Size (from variants)
                  if (_allSizes.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _filterSection(
                      _categorySlug == 'footwear' ? 'Shoe Size' : 'Size',
                      child: _chipWrap(
                        items: _allSizes,
                        selected: tempSizes,
                        onToggle: (s) => setS(() {
                          if (tempSizes.contains(s)) { tempSizes.remove(s); }
                          else { tempSizes.add(s); }
                        }),
                      ),
                    ),
                  ],

                  // Color (from variants)
                  if (_allColors.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _filterSection('Color', child: _chipWrap(
                      items: _allColors,
                      selected: tempColors,
                      onToggle: (c) => setS(() {
                        if (tempColors.contains(c)) { tempColors.remove(c); }
                        else { tempColors.add(c); }
                      }),
                    )),
                  ],

                  // Category-specific attribute sections
                  for (final entry in catAttrs.entries) ...[
                    const SizedBox(height: 20),
                    _filterSection(entry.key, child: _chipWrap(
                      items: entry.value,
                      selected: tempAttrs,
                      onToggle: (a) => setS(() {
                        if (tempAttrs.contains(a)) { tempAttrs.remove(a); }
                        else { tempAttrs.add(a); }
                      }),
                    )),
                  ],

                  const SizedBox(height: 32),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _priceRange         = tempPrice;
                    _selectedBrands     = tempBrands;
                    _inStockOnly        = tempStock;
                    _selectedSizes      = tempSizes;
                    _selectedColors     = tempColors;
                    _selectedAttributes = tempAttrs;
                  });
                  _applyFilters();
                  Navigator.pop(context);
                },
                child: Container(
                  width: double.infinity, height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_teal, _green]),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(
                        color: _teal.withValues(alpha: 0.3),
                        blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: const Center(
                    child: Text('Apply Filters',
                        style: TextStyle(color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15, letterSpacing: 0.5)),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _chipWrap({
    required List<String> items,
    required Set<String> selected,
    required void Function(String) onToggle,
  }) {
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: items.map((item) {
        final sel = selected.contains(item);
        return GestureDetector(
          onTap: () => onToggle(item),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: sel ? _teal.withValues(alpha: 0.1) : Colors.white,
              border: Border.all(color: sel ? _teal : _border, width: sel ? 1.5 : 1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(item,
                style: TextStyle(fontSize: 13,
                    color: sel ? _teal : _ink,
                    fontWeight: sel ? FontWeight.w600 : FontWeight.normal)),
          ),
        );
      }).toList(),
    );
  }

  Widget _filterSection(String label, {required Widget child}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(fontSize: 15,
              fontWeight: FontWeight.bold, color: _ink)),
      const SizedBox(height: 12),
      child,
    ]);
  }

  Widget _priceChip(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
    decoration: BoxDecoration(
      color: _surface,
      border: Border.all(color: _border),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(text, style: const TextStyle(fontSize: 13, color: _ink,
        fontWeight: FontWeight.w600)),
  );

  @override
  Widget build(BuildContext context) {
    final title = widget.title ??
        widget.category?.name ??
        (widget.showFlashDeals ? 'Flash Deals' : 'Featured');

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          _buildTopBar(title),
          _buildFilterBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _teal))
                : _filtered.isEmpty
                ? _buildEmpty()
                : RefreshIndicator(
              color: _teal,
              onRefresh: _loadProducts,
              child: _isGridView
                  ? _buildGrid()
                  : _buildList(),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildTopBar(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border),
            ),
            child: const Icon(Icons.arrow_back, size: 20, color: _ink),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(fontSize: 18,
                    fontWeight: FontWeight.bold, color: _ink)),
            if (!_isLoading)
              Text('${_filtered.length} items',
                  style: TextStyle(fontSize: 12, color: _slate)),
          ]),
        ),
        GestureDetector(
          onTap: () => setState(() => _isGridView = !_isGridView),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border),
            ),
            child: Icon(
              _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
              size: 20, color: _ink,
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const CartScreen())),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border),
            ),
            child: const Icon(Icons.shopping_bag_outlined, size: 20, color: _ink),
          ),
        ),
      ]),
    );
  }

  Widget _buildFilterBar() {
    final sortLabels = {
      'popular': 'Popular',
      'rating': 'Top Rated',
      'price_low': 'Price ↑',
      'price_high': 'Price ↓',
      'newest': 'Newest',
    };
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // Filter button
          _chipButton(
            icon: Icons.tune_rounded,
            label: 'Filter${_activeFilters > 0 ? ' ($_activeFilters)' : ''}',
            isActive: _activeFilters > 0,
            onTap: _showFilterSheet,
          ),
          const SizedBox(width: 8),
          // Sort button
          _chipButton(
            icon: Icons.sort_rounded,
            label: sortLabels[_sortBy] ?? 'Sort',
            isActive: _sortBy != 'popular',
            onTap: _showSortSheet,
          ),
          const SizedBox(width: 8),
          // Quick: In stock
          _chipButton(
            label: 'In Stock',
            isActive: _inStockOnly,
            onTap: () {
              setState(() => _inStockOnly = !_inStockOnly);
              _applyFilters();
            },
          ),
          if (_activeFilters > 0) ...[
            const SizedBox(width: 8),
            _chipButton(
              icon: Icons.close_rounded,
              label: 'Clear',
              isActive: false,
              onTap: () {
                setState(() {
                  _priceRange         = RangeValues(0, _maxPrice);
                  _selectedBrands     = {};
                  _inStockOnly        = false;
                  _sortBy             = 'popular';
                  _selectedSizes      = {};
                  _selectedColors     = {};
                  _selectedAttributes = {};
                });
                _applyFilters();
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _chipButton({
    IconData? icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? _teal.withValues(alpha: 0.1) : _surface,
          border: Border.all(
              color: isActive ? _teal : _border,
              width: isActive ? 1.5 : 1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: isActive ? _teal : _slate),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: TextStyle(
                fontSize: 12,
                color: isActive ? _teal : _slate,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              )),
        ]),
      ),
    );
  }

  Widget _buildGrid() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 262,   // fixed height — never overflows regardless of screen width
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _filtered.length,
      itemBuilder: (_, i) => _buildGridCard(_filtered[i]),
    );
  }

  Widget _buildGridCard(ProductModel product) {
    final discount = product.discountPercent;
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => ProductDetailScreen(
              productId: product.id, product: product))),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8, offset: const Offset(0, 3),
          )],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: Container(
                height: 140,
                width: double.infinity,
                color: const Color(0xFFF8FAFC),
                child: product.primaryImage != null
                    ? CachedNetworkImage(imageUrl: product.primaryImage!,
                        filterQuality: FilterQuality.high,
                    fit: BoxFit.contain,
                    memCacheWidth: 280,
                    placeholder: (_, _) => _imgPlaceholder(140),
                    errorWidget: (_, _, _) => _imgPlaceholder(140))
                    : _imgPlaceholder(140),
              ),
            ),
            if (discount > 0)
              Positioned(top: 8, left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(6)),
                    child: Text('-$discount%',
                        style: const TextStyle(color: Colors.white,
                            fontSize: 10, fontWeight: FontWeight.bold)),
                  )),
            Positioned(top: 6, right: 6,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.favorite_outline,
                      size: 14, color: _slate),
                )),
            if (!product.isInStock)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.45),
                    child: const Center(
                      child: Text('Out of Stock',
                          style: TextStyle(color: Colors.white,
                              fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                  ),
                ),
              ),
          ]),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (product.brand != null)
                    Text(product.brand!,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10, color: _teal,
                            fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                  const SizedBox(height: 2),
                  Text(product.name,
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12,
                          fontWeight: FontWeight.w600, color: _ink, height: 1.3)),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.star_rounded, size: 12, color: Colors.amber),
                    const SizedBox(width: 3),
                    Text(product.rating > 0 ? product.rating.toStringAsFixed(1) : "New",
                        style: const TextStyle(fontSize: 11, color: _slate)),
                  ]),
                  const SizedBox(height: 4),
                  Text(product.formattedPrice,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13,
                          fontWeight: FontWeight.bold, color: _ink)),
                  if (product.formattedOriginalPrice != null)
                    Text(product.formattedOriginalPrice!,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10,
                            color: _slate.withValues(alpha: 0.6),
                            decoration: TextDecoration.lineThrough)),
                ],
              ),
              ),  // SingleChildScrollView
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildList() {
    // itemExtent eliminates per-item layout passes and enables O(1) scroll offset math.
    // The card's height is actually driven by its text column, not the 90px
    // image: brand line + up to 2 name lines + rating row + price row + stock
    // row, plus 20px container padding and 10px bottom margin, comes to ~145px.
    // (Previously set to 110 using only the image height, which overflowed
    // by ~30-35px on every card with a 2-line product name.)
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: _filtered.length,
      itemExtent: 145,
      itemBuilder: (_, i) => _buildListCard(_filtered[i]),
    );
  }

  Widget _buildListCard(ProductModel product) {
    final discount = product.discountPercent;
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => ProductDetailScreen(
              productId: product.id, product: product))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8, offset: const Offset(0, 2),
          )],
        ),
        child: Row(children: [
          Stack(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: product.primaryImage != null
                  ? CachedNetworkImage(imageUrl: product.primaryImage!,
                      filterQuality: FilterQuality.high,
                  width: 90, height: 90, fit: BoxFit.contain,
                  memCacheWidth: 180,
                  placeholder: (_, _) => _imgPlaceholder(90, width: 90),
                  errorWidget: (_, _, _) => _imgPlaceholder(90, width: 90))
                  : _imgPlaceholder(90, width: 90),
            ),
            if (discount > 0)
              Positioned(top: 4, left: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(5)),
                    child: Text('-$discount%',
                        style: const TextStyle(color: Colors.white,
                            fontSize: 9, fontWeight: FontWeight.bold)),
                  )),
          ]),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (product.brand != null)
                Text(product.brand!,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: _teal,
                        fontWeight: FontWeight.w600)),
              Text(product.name,
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13,
                      fontWeight: FontWeight.w600, color: _ink, height: 1.3)),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.star_rounded, size: 12, color: Colors.amber),
                const SizedBox(width: 3),
                Text('${product.rating}',
                    style: TextStyle(fontSize: 11, color: _slate)),
                Text(' (${product.reviewCount})',
                    style: TextStyle(fontSize: 10,
                        color: _slate.withValues(alpha: 0.5))),
              ]),
              const SizedBox(height: 4),
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Text(product.formattedPrice,
                    style: const TextStyle(fontSize: 14,
                        fontWeight: FontWeight.bold, color: _ink)),
                if (product.formattedOriginalPrice != null) ...[
                  const SizedBox(width: 6),
                  Text(product.formattedOriginalPrice!,
                      style: TextStyle(fontSize: 11,
                          color: _slate.withValues(alpha: 0.6),
                          decoration: TextDecoration.lineThrough)),
                ],
              ]),
              const SizedBox(height: 4),
              Row(children: [
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    color: product.isInStock ? _green : Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(product.isInStock ? 'In Stock' : 'Out of Stock',
                    style: TextStyle(
                      fontSize: 11,
                      color: product.isInStock ? _green : Colors.redAccent,
                      fontWeight: FontWeight.w500,
                    )),
              ]),
            ],
          )),
          const Icon(Icons.chevron_right_rounded,
              size: 20, color: Color(0xFFCBD5E1)),
        ]),
      ),
    );
  }

  Widget _imgPlaceholder(double height, {double? width}) => Container(
    height: height,
    width: width,
    color: _surface,
    child: Icon(Icons.image_outlined,
        size: height * 0.3, color: _border),
  );

  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.inventory_2_outlined, size: 56,
            color: _slate.withValues(alpha: 0.25)),
        const SizedBox(height: 16),
        const Text('No products found',
            style: TextStyle(fontSize: 16,
                fontWeight: FontWeight.w600, color: _ink)),
        const SizedBox(height: 8),
        Text('Try adjusting your filters',
            style: TextStyle(fontSize: 13, color: _slate)),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: () {
            setState(() {
              _priceRange         = RangeValues(0, _maxPrice);
              _selectedBrands     = {};
              _inStockOnly        = false;
              _sortBy             = 'popular';
              _selectedSizes      = {};
              _selectedColors     = {};
              _selectedAttributes = {};
            });
            _applyFilters();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_teal, _green]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('Clear Filters',
                style: TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w600, fontSize: 14)),
          ),
        ),
      ]),
    );
  }
}