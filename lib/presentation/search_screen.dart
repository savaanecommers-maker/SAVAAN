import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../data/product_service.dart';
import '../models/product_model.dart';
import 'product_detail_screen.dart';
import 'product_list_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _productService = ProductService();
  final _controller = TextEditingController();
  final _focusNode  = FocusNode();

  List<ProductModel> _results = [];
  List<ProductModel> _filtered = [];
  bool _isSearching = false;
  String _query = '';
  Timer? _debounce;

  // Search filters
  double _filterMaxPrice = 100000;
  RangeValues _filterPriceRange = const RangeValues(0, 100000);
  double _filterMinRating = 0;
  bool _filterInStock = false;
  Set<String> _filterCategories = {};
  Set<String> _filterBrands = {};

  bool get _hasActiveFilters =>
      _filterInStock ||
      _filterMinRating > 0 ||
      _filterCategories.isNotEmpty ||
      _filterBrands.isNotEmpty ||
      _filterPriceRange.start > 0 ||
      _filterPriceRange.end < _filterMaxPrice;

  static const Color _ink     = Color(0xFF0F172A);
  static const Color _teal    = Color(0xFF0D9488);
  static const Color _green   = Color(0xFF10B981);
  static const Color _slate   = Color(0xFF64748B);
  static const Color _border  = Color(0xFFE2E8F0);
  static const Color _surface = Color(0xFFF8FAFC);

  final List<String> _popularSearches = [
    'Watch', 'Perfume', 'Sunglasses', 'Handbag',
    'Shoes', 'Smartwatch', 'Jackets',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() { _results = []; _isSearching = false; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _search(value.trim());
    });
  }

  Future<void> _search(String query) async {
    setState(() { _isSearching = true; _query = query; });
    try {
      final products = await _productService.searchProducts(query, limit: 60);
      if (mounted) {
        // Recompute price range from new results
        double maxP = 100000;
        if (products.isNotEmpty) {
          maxP = products.map((p) => p.price).reduce((a, b) => a > b ? a : b);
          maxP = (maxP / 1000).ceil() * 1000;
        }
        setState(() {
          _results = products;
          _filterMaxPrice = maxP;
          if (_filterPriceRange.end > maxP) {
            _filterPriceRange = RangeValues(_filterPriceRange.start, maxP);
          }
          _isSearching = false;
        });
        _applySearchFilters();
      }
    } catch (e) {
      debugPrint('Search error: $e');
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _applySearchFilters() {
    var list = List<ProductModel>.from(_results);
    if (_filterInStock) list = list.where((p) => p.isInStock).toList();
    if (_filterMinRating > 0) list = list.where((p) => p.rating >= _filterMinRating).toList();
    if (_filterCategories.isNotEmpty) {
      list = list.where((p) => p.categoryName != null && _filterCategories.contains(p.categoryName)).toList();
    }
    if (_filterBrands.isNotEmpty) {
      list = list.where((p) => p.brand != null && _filterBrands.contains(p.brand)).toList();
    }
    list = list.where((p) => p.price >= _filterPriceRange.start && p.price <= _filterPriceRange.end).toList();
    setState(() => _filtered = list);
  }

  List<String> get _availableCategories => _results
      .where((p) => p.categoryName != null && p.categoryName!.isNotEmpty)
      .map((p) => p.categoryName!).toSet().toList()..sort();

  List<String> get _availableBrands => _results
      .where((p) => p.brand != null && p.brand!.isNotEmpty)
      .map((p) => p.brand!).toSet().toList()..sort();

  void _showSearchFilterSheet() {
    RangeValues tempPrice = _filterPriceRange;
    double tempRating = _filterMinRating;
    bool tempStock = _filterInStock;
    Set<String> tempCats = Set.from(_filterCategories);
    Set<String> tempBrands = Set.from(_filterBrands);

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
          builder: (_, ctrl) => Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(children: [
                Container(width: 36, height: 4,
                    decoration: BoxDecoration(color: _border,
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                Row(children: [
                  const Expanded(child: Text('Filter Results',
                      style: TextStyle(fontSize: 17,
                          fontWeight: FontWeight.bold, color: _ink))),
                  GestureDetector(
                    onTap: () => setS(() {
                      tempPrice  = RangeValues(0, _filterMaxPrice);
                      tempRating = 0;
                      tempStock  = false;
                      tempCats   = {};
                      tempBrands = {};
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
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                children: [
                  // Availability
                  _fsSection('Availability', child: Row(children: [
                    const Expanded(child: Text('In Stock Only',
                        style: TextStyle(fontSize: 14, color: _ink))),
                    Switch(value: tempStock,
                        onChanged: (v) => setS(() => tempStock = v),
                        activeThumbColor: _teal),
                  ])),
                  const SizedBox(height: 20),

                  // Price Range
                  _fsSection('Price Range', child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                        _fsChip('₹${tempPrice.start.toInt()}'),
                        Text('to', style: TextStyle(color: _slate, fontSize: 13)),
                        _fsChip('₹${tempPrice.end.toInt()}'),
                      ]),
                      const SizedBox(height: 8),
                      RangeSlider(
                        values: tempPrice, min: 0, max: _filterMaxPrice, divisions: 20,
                        activeColor: _teal, inactiveColor: _border,
                        onChanged: (v) => setS(() => tempPrice = v),
                      ),
                    ],
                  )),
                  const SizedBox(height: 20),

                  // Min Rating
                  _fsSection('Minimum Rating', child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        ...List.generate(5, (i) => GestureDetector(
                          onTap: () => setS(() => tempRating = tempRating == i + 1.0 ? 0 : (i + 1).toDouble()),
                          child: Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Icon(
                              Icons.star_rounded,
                              size: 28,
                              color: (i + 1) <= tempRating ? Colors.amber : _border,
                            ),
                          ),
                        )),
                        if (tempRating > 0) ...[
                          const SizedBox(width: 8),
                          Text('${tempRating.toInt()}+ stars',
                              style: TextStyle(fontSize: 12, color: _slate)),
                        ],
                      ]),
                    ],
                  )),

                  if (_availableCategories.length > 1) ...[
                    const SizedBox(height: 20),
                    _fsSection('Category', child: _fsChipWrap(
                      items: _availableCategories,
                      selected: tempCats,
                      onToggle: (c) => setS(() {
                        if (tempCats.contains(c)) { tempCats.remove(c); }
                        else { tempCats.add(c); }
                      }),
                    )),
                  ],

                  if (_availableBrands.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _fsSection('Brand', child: _fsChipWrap(
                      items: _availableBrands,
                      selected: tempBrands,
                      onToggle: (b) => setS(() {
                        if (tempBrands.contains(b)) { tempBrands.remove(b); }
                        else { tempBrands.add(b); }
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
                    _filterPriceRange  = tempPrice;
                    _filterMinRating   = tempRating;
                    _filterInStock     = tempStock;
                    _filterCategories  = tempCats;
                    _filterBrands      = tempBrands;
                  });
                  _applySearchFilters();
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
                  child: const Center(child: Text('Apply Filters',
                      style: TextStyle(color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15, letterSpacing: 0.5))),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _fsSection(String label, {required Widget child}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 15,
            fontWeight: FontWeight.bold, color: _ink)),
        const SizedBox(height: 12),
        child,
      ]);

  Widget _fsChip(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
    decoration: BoxDecoration(color: _surface,
        border: Border.all(color: _border), borderRadius: BorderRadius.circular(8)),
    child: Text(text, style: const TextStyle(fontSize: 13, color: _ink,
        fontWeight: FontWeight.w600)),
  );

  Widget _fsChipWrap({
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
            child: Text(item, style: TextStyle(fontSize: 13,
                color: sel ? _teal : _ink,
                fontWeight: sel ? FontWeight.w600 : FontWeight.normal)),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          _buildSearchBar(),
          Expanded(
            child: _query.isEmpty
                ? _buildPopularSearches()
                : _isSearching
                    ? const Center(child: CircularProgressIndicator(color: _teal))
                    : _results.isEmpty
                        ? _buildNoResults()
                        : _buildResults(),
          ),
        ]),
      ),
    );
  }

  int get _activeFilterCount =>
      (_filterInStock ? 1 : 0) +
      (_filterMinRating > 0 ? 1 : 0) +
      (_filterCategories.isNotEmpty ? 1 : 0) +
      (_filterBrands.isNotEmpty ? 1 : 0) +
      (_filterPriceRange.start > 0 || _filterPriceRange.end < _filterMaxPrice ? 1 : 0);

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(children: [
        Expanded(
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: Row(children: [
              const SizedBox(width: 12),
              Icon(Icons.search_rounded, color: _slate, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  onChanged: _onChanged,
                  onSubmitted: (v) { if (v.trim().isNotEmpty) _search(v.trim()); },
                  style: const TextStyle(fontSize: 14, color: _ink),
                  decoration: InputDecoration(
                    hintText: 'Search products, brands...',
                    hintStyle: TextStyle(color: _slate.withValues(alpha: 0.5), fontSize: 14),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              if (_controller.text.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _controller.clear();
                    setState(() { _results = []; _filtered = []; _query = ''; });
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(Icons.close, size: 18, color: _slate),
                  ),
                ),
              // Filter icon — only visible when there are results
              if (_results.isNotEmpty)
                GestureDetector(
                  onTap: _showSearchFilterSheet,
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: _hasActiveFilters
                          ? _teal.withValues(alpha: 0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Stack(clipBehavior: Clip.none, children: [
                      Icon(Icons.tune_rounded, size: 18,
                          color: _hasActiveFilters ? _teal : _slate),
                      if (_activeFilterCount > 0)
                        Positioned(
                          top: -5, right: -5,
                          child: Container(
                            width: 14, height: 14,
                            decoration: BoxDecoration(
                                color: _teal, shape: BoxShape.circle),
                            child: Center(
                              child: Text('$_activeFilterCount',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 8,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                    ]),
                  ),
                ),
            ]),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Text('Cancel',
              style: TextStyle(fontSize: 14, color: _teal,
                  fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }

  Widget _buildPopularSearches() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Popular Searches',
            style: TextStyle(fontSize: 15,
                fontWeight: FontWeight.bold, color: _ink)),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: _popularSearches.map((term) => GestureDetector(
            onTap: () {
              _controller.text = term;
              _search(term);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _border),
              ),
              child: Text(term,
                  style: TextStyle(fontSize: 13, color: _slate,
                      fontWeight: FontWeight.w500)),
            ),
          )).toList(),
        ),
      ]),
    );
  }

  Widget _buildResults() {
    final displayList = _hasActiveFilters ? _filtered : _results.take(20).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(children: [
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 13, color: _slate),
                children: [
                  const TextSpan(text: 'Results for  '),
                  TextSpan(text: '"$_query"',
                      style: const TextStyle(color: _ink, fontWeight: FontWeight.w600)),
                  if (_hasActiveFilters)
                    TextSpan(text: '  (${displayList.length} filtered)',
                        style: TextStyle(color: _teal, fontSize: 12)),
                ],
              ),
            ),
          ),
          if (_hasActiveFilters)
            GestureDetector(
              onTap: () {
                setState(() {
                  _filterPriceRange = RangeValues(0, _filterMaxPrice);
                  _filterMinRating  = 0;
                  _filterInStock    = false;
                  _filterCategories = {};
                  _filterBrands     = {};
                });
              },
              child: Text('Clear filters',
                  style: TextStyle(fontSize: 12, color: Colors.redAccent,
                      fontWeight: FontWeight.w600)),
            ),
        ]),
      ),
      Expanded(
        child: displayList.isEmpty
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.filter_list_off_rounded, size: 48,
                      color: _slate.withValues(alpha: 0.25)),
                  const SizedBox(height: 12),
                  const Text('No results match your filters',
                      style: TextStyle(fontSize: 14, color: _ink, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text('Try adjusting or clearing filters',
                      style: TextStyle(fontSize: 12, color: _slate)),
                ]),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: displayList.length,
                itemBuilder: (_, i) => _buildResultTile(displayList[i]),
              ),
      ),
      if (_results.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: GestureDetector(
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => ProductListScreen(
                  title: 'Results for "$_query"',
                  searchQuery: _query,
                ))),
            child: Center(
              child: Text('View all results for "$_query"',
                  style: TextStyle(fontSize: 13, color: _teal,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ),
    ]);
  }

  Widget _buildResultTile(ProductModel product) {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => ProductDetailScreen(
              productId: product.id, product: product))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6, offset: const Offset(0, 2),
          )],
        ),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: product.primaryImage != null
                ? CachedNetworkImage(imageUrl: product.primaryImage!,
                    width: 56, height: 56, fit: BoxFit.cover,
                    placeholder: (_, _) => _imgPlaceholder(),
                    errorWidget: (_, _, _) => _imgPlaceholder())
                : _imgPlaceholder(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(product.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13,
                      fontWeight: FontWeight.w600, color: _ink)),
              const SizedBox(height: 3),
              Row(children: [
                const Icon(Icons.star_rounded, size: 12, color: Colors.amber),
                const SizedBox(width: 3),
                Text('${product.rating}',
                    style: TextStyle(fontSize: 11, color: _slate)),
              ]),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(product.formattedPrice,
                style: const TextStyle(fontSize: 13,
                    fontWeight: FontWeight.bold, color: _ink)),
            if (product.discountPercent > 0) ...[
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: _teal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('-${product.discountPercent}%',
                    style: TextStyle(fontSize: 10, color: _teal,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ]),
        ]),
      ),
    );
  }

  Widget _imgPlaceholder() => Container(
    width: 56, height: 56, color: _surface,
    child: Icon(Icons.image_outlined, size: 22, color: _border),
  );

  Widget _buildNoResults() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.search_off_rounded, size: 56,
            color: _slate.withValues(alpha: 0.25)),
        const SizedBox(height: 14),
        Text('No results for "$_query"',
            style: const TextStyle(fontSize: 15,
                fontWeight: FontWeight.w600, color: _ink)),
        const SizedBox(height: 6),
        Text('Try a different keyword',
            style: TextStyle(fontSize: 13, color: _slate)),
      ]),
    );
  }
}
