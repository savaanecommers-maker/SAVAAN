import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/api_client.dart';
import '../data/product_service.dart';
import '../models/cart_item_model.dart';
import '../models/product_model.dart';
import '../providers/cart_provider.dart';
import '../providers/wishlist_provider.dart';
import 'checkout_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final String productId;
  final ProductModel? product; // optional pre-loaded product

  const ProductDetailScreen({
    super.key,
    required this.productId,
    this.product,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final _productService = ProductService();

  ProductModel? _product;
  bool _isLoading = true;
  int _selectedImageIndex = 0;
  ProductVariant? _selectedVariant;
  int _quantity = 1;
  bool _addingToCart = false;
  List<Map<String, dynamic>> _reviews = [];
  bool _reviewsLoading = true;

  static const Color _ink     = Color(0xFF0F172A);
  static const Color _teal    = Color(0xFF0D9488);
  static const Color _green   = Color(0xFF10B981);
  static const Color _slate   = Color(0xFF64748B);
  static const Color _border  = Color(0xFFE2E8F0);
  static const Color _surface = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      _product = widget.product;
      _isLoading = false;
      _preselectVariant();
    } else {
      _loadProduct();
    }
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    try {
      final res = await ApiClient.get(
        '/api/reviews?product_id=${widget.productId}',
        auth: false,
      );
      if (mounted) {
        setState(() {
          _reviews = res.isSuccess && res.data != null
              ? (res.data!['_list'] as List? ?? [])
                  .map((r) => Map<String, dynamic>.from(r as Map))
                  .toList()
              : [];
          _reviewsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _reviewsLoading = false);
    }
  }

  // Log this product view to recently_viewed table
  Future<void> _logRecentlyViewed(String productId) async {
    // Silently log — not critical
    try {
      await ApiClient.post('/api/homepage/view', {'product_id': productId});
    } catch (_) {}
  }

  Future<void> _loadProduct() async {
    try {
      final product = await _productService.getProductById(widget.productId);
      if (mounted) {
        setState(() {
          _product = product;
          _isLoading = false;
          _preselectVariant();
        });
        _logRecentlyViewed(widget.productId);
      }
    } catch (e) {
      debugPrint('Error loading product: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _preselectVariant() {
    if (_product != null && _product!.variants.isNotEmpty) {
      _selectedVariant = _product!.variants.first;
    }
  }

  Future<void> _toggleWishlist() async {
    await context.read<WishlistProvider>().toggleWishlist(
      widget.productId,
      product: _product,
    );
  }

  Future<void> _addToCart() async {
    if (_addingToCart) return;
    setState(() => _addingToCart = true);
    try {
      final error = await context.read<CartProvider>().addToCart(
        productId: widget.productId,
        variantId: _selectedVariant?.id,
        quantity:  _quantity,
      );
      if (mounted) {
        _showSnackBar(error == null ? 'Added to cart!' : 'Failed to add to cart',
            error == null ? _teal : Colors.redAccent);
      }
    } catch (_) {
      if (mounted) _showSnackBar('Failed to add to cart', Colors.redAccent);
    } finally {
      if (mounted) setState(() => _addingToCart = false);
    }
  }

  Future<void> _buyNow(ProductModel p) async {
    // Add to cart first, then go straight to checkout
    await _addToCart();
    if (!mounted) return;
    final userId = await ApiClient.getTokenPayload().then((p) => p?['id'] as String? ?? '');
    // Build a single-item cart for checkout
    final cartItem = CartItemModel(
      id:        'buynow_${widget.productId}',
      userId:    userId,
      productId: widget.productId,
      variantId: _selectedVariant?.id,
      quantity:  _quantity,
      product:   p,
      variant:   _selectedVariant,
    );
    // Use CartProvider shipping settings so admin-configurable free-shipping threshold is respected
    final cart        = context.read<CartProvider>();
    final subtotal    = p.effectivePrice * _quantity;
    final shippingAmt = subtotal >= cart.freeShippingAbove ? 0.0 : cart.shippingCharge;
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => CheckoutScreen(
          cartItems: [cartItem],
          subtotal:  subtotal,
          shipping:  shippingAmt,
          total:     subtotal + shippingAmt,
        )));
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _teal))
          : _product == null
          ? _buildErrorState()
          : Stack(children: [
        _buildContent(),
        _buildTopOverlay(),
        _buildBottomBar(),
      ]),
    );
  }

  Widget _buildContent() {
    final p = _product!;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 100),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildImageGallery(p),
        _buildProductInfo(p),
        _buildVariantSelector(p),
        _buildQuantitySelector(),
        _buildTrustBadges(),
        _buildDescription(p),
        _buildReviewsPreview(),
      ]),
    );
  }

  // ── Image gallery ────────────────────────────────────────────
  Widget _buildImageGallery(ProductModel p) {
    final images = p.images.isNotEmpty ? p.images : <String>[];
    return Column(children: [
      // Main image
      Container(
        height: 320,
        width: double.infinity,
        color: _surface,
        child: images.isNotEmpty
            ? Image.network(images[_selectedImageIndex],
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _imagePlaceholder())
            : _imagePlaceholder(),
      ),

      // Thumbnail strip
      if (images.length > 1) ...[
        const SizedBox(height: 10),
        SizedBox(
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: images.length,
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => setState(() => _selectedImageIndex = i),
              child: Container(
                width: 60, height: 60,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _selectedImageIndex == i ? _teal : _border,
                    width: _selectedImageIndex == i ? 2 : 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Image.network(images[i],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Icon(Icons.image_outlined, color: _border)),
                ),
              ),
            ),
          ),
        ),
      ],
    ]);
  }

  Widget _imagePlaceholder() => Container(
    color: _surface,
    child: Icon(Icons.image_outlined, size: 64, color: _border),
  );

  // ── Product info ─────────────────────────────────────────────
  Widget _buildProductInfo(ProductModel p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Category
        if (p.categoryName != null)
          Text(p.categoryName!.toUpperCase(),
              style: TextStyle(fontSize: 11, color: _teal,
                  fontWeight: FontWeight.w600, letterSpacing: 1.5)),
        const SizedBox(height: 6),

        // Name
        Text(p.name,
            style: const TextStyle(fontSize: 20,
                fontWeight: FontWeight.bold, color: _ink, height: 1.3)),
        const SizedBox(height: 10),

        // Rating + reviews
        Row(children: [
          ...List.generate(5, (i) => Icon(
            i < p.rating.floor()
                ? Icons.star_rounded
                : (i < p.rating ? Icons.star_half_rounded : Icons.star_outline_rounded),
            size: 18, color: Colors.amber,
          )),
          const SizedBox(width: 8),
          Text('${p.rating}',
              style: const TextStyle(fontWeight: FontWeight.w600,
                  fontSize: 14, color: _ink)),
          Text(' (${p.reviewCount} reviews)',
              style: TextStyle(fontSize: 13, color: _slate)),
        ]),
        const SizedBox(height: 14),

        // Price row
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Text(p.formattedPrice,
              style: const TextStyle(fontSize: 24,
                  fontWeight: FontWeight.bold, color: _ink)),
          if (p.formattedOriginalPrice != null) ...[
            const SizedBox(width: 10),
            Text(p.formattedOriginalPrice!,
                style: TextStyle(fontSize: 16, color: _slate,
                    decoration: TextDecoration.lineThrough)),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('-${p.discountPercent}%',
                  style: const TextStyle(color: Colors.redAccent,
                      fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ],
        ]),
        const SizedBox(height: 6),

        // Stock status
        Row(children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              color: p.isInStock ? _green : Colors.redAccent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            p.isLowStock
                ? 'Only ${p.stock} left!'
                : p.isInStock ? 'In Stock' : 'Out of Stock',
            style: TextStyle(
              fontSize: 13,
              color: p.isLowStock
                  ? Colors.orange
                  : p.isInStock ? _green : Colors.redAccent,
              fontWeight: FontWeight.w500,
            ),
          ),
        ]),
      ]),
    );
  }

  // ── Variant selector (colors) ────────────────────────────────
  Widget _buildVariantSelector(ProductModel p) {
    if (p.variants.isEmpty) return const SizedBox.shrink();
    final colors = p.variants
        .where((v) => v.color != null)
        .map((v) => v.color!)
        .toSet()
        .toList();
    if (colors.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Color',
              style: TextStyle(fontSize: 14,
                  fontWeight: FontWeight.w600, color: _ink)),
          const SizedBox(width: 8),
          Text(_selectedVariant?.color ?? '',
              style: TextStyle(fontSize: 13, color: _slate)),
        ]),
        const SizedBox(height: 10),
        Row(children: colors.map((color) {
          final variant = p.variants.firstWhere(
                  (v) => v.color == color, orElse: () => p.variants.first);
          final isSelected = _selectedVariant?.color == color;
          return GestureDetector(
            onTap: () => setState(() => _selectedVariant = variant),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 38, height: 38,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: _colorFromName(color),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? _teal : Colors.transparent,
                  width: 2.5,
                ),
                boxShadow: isSelected ? [BoxShadow(
                    color: _teal.withValues(alpha: 0.3), blurRadius: 8)] : null,
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                  : null,
            ),
          );
        }).toList()),
      ]),
    );
  }

  Color _colorFromName(String name) {
    switch (name.toLowerCase()) {
      case 'green':  return const Color(0xFF0D9488);
      case 'black':  return const Color(0xFF1E293B);
      case 'silver': return const Color(0xFF94A3B8);
      case 'gold':   return const Color(0xFFD4AF37);
      case 'white':  return const Color(0xFFF1F5F9);
      case 'red':    return const Color(0xFFEF4444);
      case 'blue':   return const Color(0xFF3B82F6);
      case 'brown':  return const Color(0xFF92400E);
      default:       return const Color(0xFF64748B);
    }
  }

  // ── Quantity selector ────────────────────────────────────────
  Widget _buildQuantitySelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(children: [
        const Text('Quantity',
            style: TextStyle(fontSize: 14,
                fontWeight: FontWeight.w600, color: _ink)),
        const Spacer(),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: _border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            _qtyButton(Icons.remove, () {
              if (_quantity > 1) setState(() => _quantity--);
            }),
            SizedBox(
              width: 40,
              child: Center(
                child: Text('$_quantity',
                    style: const TextStyle(fontSize: 15,
                        fontWeight: FontWeight.bold, color: _ink)),
              ),
            ),
            _qtyButton(Icons.add, () {
              final stock = _product?.stock ?? 999;
              if (_quantity < stock) setState(() => _quantity++);
            }),
          ]),
        ),
      ]),
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 18, color: _ink),
    ),
  );

  // ── Trust badges ─────────────────────────────────────────────
  Widget _buildTrustBadges() {
    final badges = [
      {'icon': Icons.verified_outlined,       'label': '100% Authentic\nProducts'},
      {'icon': Icons.workspace_premium_outlined,'label': '1 Year\nWarranty'},
      {'icon': Icons.replay_outlined,          'label': 'Easy Returns\n& Refunds'},
      {'icon': Icons.local_shipping_outlined,  'label': 'Secure\nPackaging'},
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: badges.map((b) => Column(children: [
          Icon(b['icon'] as IconData, size: 22, color: _teal),
          const SizedBox(height: 6),
          Text(b['label'] as String,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: _slate,
                  fontWeight: FontWeight.w500, height: 1.4)),
        ])).toList(),
      ),
    );
  }

  // ── Description ──────────────────────────────────────────────
  Widget _buildDescription(ProductModel p) {
    if (p.description == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Description',
            style: TextStyle(fontSize: 16,
                fontWeight: FontWeight.bold, color: _ink)),
        const SizedBox(height: 10),
        Text(p.description!,
            style: TextStyle(fontSize: 14, color: _slate,
                height: 1.6)),
      ]),
    );
  }

  // ── Reviews preview ──────────────────────────────────────────
  Widget _buildReviewsPreview() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Reviews${_reviews.isNotEmpty ? ' (${_reviews.length})' : ''}',
              style: const TextStyle(fontSize: 16,
                  fontWeight: FontWeight.bold, color: _ink)),
          if (_reviews.isNotEmpty)
            const Text('See All',
                style: TextStyle(fontSize: 13, color: _teal,
                    fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 12),
        if (_reviewsLoading)
          const Center(child: Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(strokeWidth: 2),
          ))
        else if (_reviews.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: Center(
              child: Text('No reviews yet. Be the first to review!',
                  style: TextStyle(fontSize: 13, color: _slate)),
            ),
          )
        else
          Column(
            children: _reviews.take(3).map((r) => _buildReviewCard(r)).toList(),
          ),
      ]),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> r) {
    final rating = (r['rating'] as num?)?.toInt() ?? 0;
    final name   = r['user_name'] as String? ?? 'User';
    final title  = r['title'] as String?;
    final body   = r['body'] as String?;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Row(
            children: List.generate(5, (i) => Icon(
              i < rating ? Icons.star : Icons.star_border,
              size: 14,
              color: const Color(0xFFF59E0B),
            )),
          ),
          const SizedBox(width: 8),
          Text(name, style: TextStyle(fontSize: 12, color: _slate,
              fontWeight: FontWeight.w600)),
        ]),
        if (title != null && title.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(title, style: const TextStyle(fontSize: 13,
              fontWeight: FontWeight.w600, color: _ink)),
        ],
        if (body != null && body.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(body, style: TextStyle(fontSize: 13, color: _slate, height: 1.4),
              maxLines: 3, overflow: TextOverflow.ellipsis),
        ],
      ]),
    );
  }

  // ── Top overlay (back + wishlist) ────────────────────────────
  Widget _buildTopOverlay() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
                ),
                child: const Icon(Icons.arrow_back, size: 20, color: _ink),
              ),
            ),
            Row(children: [
              GestureDetector(
                onTap: () {},
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
                  ),
                  child: const Icon(Icons.ios_share_outlined,
                      size: 20, color: _ink),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _toggleWishlist,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
                  ),
                  child: Consumer<WishlistProvider>(
                    builder: (_, wish, __) => Icon(
                      wish.isWishlisted(widget.productId)
                          ? Icons.favorite_rounded
                          : Icons.favorite_outline,
                      size: 20,
                      color: wish.isWishlisted(widget.productId)
                          ? Colors.redAccent
                          : _ink,
                    ),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  // ── Bottom bar (Add to Cart + Buy Now) ───────────────────────
  Widget _buildBottomBar() {
    final p = _product!;
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16, offset: const Offset(0, -4),
          )],
        ),
        child: Row(children: [
          // Add to Cart
          Expanded(
            child: GestureDetector(
              onTap: p.isInStock ? _addToCart : null,
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  gradient: p.isInStock
                      ? const LinearGradient(colors: [_teal, _green])
                      : null,
                  color: p.isInStock ? null : _border,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: p.isInStock ? [BoxShadow(
                    color: _teal.withValues(alpha: 0.3),
                    blurRadius: 12, offset: const Offset(0, 4),
                  )] : null,
                ),
                child: Center(
                  child: _addingToCart
                      ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                      : const Text('ADD TO CART',
                      style: TextStyle(color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13, letterSpacing: 1)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Buy Now
          Expanded(
            child: GestureDetector(
              onTap: p.isInStock ? () => _buyNow(p) : null,
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: p.isInStock ? _teal : _border, width: 1.5),
                ),
                child: Center(
                  child: Text('BUY NOW',
                      style: TextStyle(
                        color: p.isInStock ? _teal : _slate,
                        fontWeight: FontWeight.bold,
                        fontSize: 13, letterSpacing: 1,
                      )),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildErrorState() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.error_outline, size: 48, color: _slate.withValues(alpha: 0.3)),
      const SizedBox(height: 12),
      Text('Product not found',
          style: TextStyle(fontSize: 15, color: _slate)),
      const SizedBox(height: 16),
      GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_teal, _green]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text('Go Back',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ),
      ),
    ]),
  );
}