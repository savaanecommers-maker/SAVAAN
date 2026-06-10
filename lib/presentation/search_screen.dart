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
  bool _isSearching = false;
  String _query = '';
  Timer? _debounce;

  static const Color _ink     = Color(0xFF0F172A);
  static const Color _teal    = Color(0xFF0D9488);
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
      final products = await _productService.searchProducts(query, limit: 20);
      if (mounted) setState(() { _results = products; _isSearching = false; });
    } catch (e) {
      debugPrint('Search error: $e');
      if (mounted) setState(() => _isSearching = false);
    }
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
                    setState(() { _results = []; _query = ''; });
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(Icons.close, size: 18, color: _slate),
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
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: RichText(
          text: TextSpan(
            style: TextStyle(fontSize: 13, color: _slate),
            children: [
              const TextSpan(text: 'Results for  '),
              TextSpan(
                text: '"$_query"',
                style: const TextStyle(
                    color: _ink, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          itemCount: _results.length,
          itemBuilder: (_, i) => _buildResultTile(_results[i]),
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
                    placeholder: (_, __) => _imgPlaceholder(),
                    errorWidget: (_, __, ___) => _imgPlaceholder())
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
