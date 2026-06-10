import 'package:cached_network_image/cached_network_image.dart';
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
  String? _selectedColor;  // selected color (step 1 when product has both)
  String? _selectedSize;   // selected size  (step 2 when product has both)
  bool _variantRequired = false; // turns true when user tries to add-to-cart without selecting
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
    if (_product == null || _product!.variants.isEmpty) return;
    final variants = _product!.variants;

    final hasColors = variants.any((v) => v.color != null);
    final hasSizes  = variants.any((v) => v.size  != null);

    if (!hasColors && hasSizes) {
      // Size-only product: pre-select first in-stock size, or first size
      final first = variants.firstWhere((v) => v.isInStock, orElse: () => variants.first);
      setState(() {
        _selectedSize    = first.size;
        _selectedVariant = first;
      });
    } else if (hasColors && !hasSizes) {
      // Color-only product: pre-select first in-stock color
      final first = variants.firstWhere((v) => v.isInStock, orElse: () => variants.first);
      setState(() {
        _selectedColor   = first.color;
        _selectedVariant = first;
      });
    }
    // Color+size: don't pre-select — user must choose both
  }

  /// Called whenever color or size chip is tapped. Finds matching variant.
  void _onColorSelected(String color) {
    final variants = _product!.variants;
    setState(() {
      _selectedColor   = color;
      _selectedVariant = null; // reset until size is also chosen
      // If no sizes exist, resolve variant immediately
      final hasSizes = variants.any((v) => v.size != null);
      if (!hasSizes) {
        _selectedVariant = variants.firstWhere(
          (v) => v.color == color,
          orElse: () => variants.first,
        );
      } else if (_selectedSize != null) {
        // Try to keep same size in new color
        final match = variants.where(
          (v) => v.color == color && v.size == _selectedSize,
        );
        if (match.isNotEmpty) _selectedVariant = match.first;
        // else leave null so user knows to pick size again
      }
    });
  }

  void _onSizeSelected(String size) {
    final variants = _product!.variants;
    setState(() {
      _selectedSize = size;
      final hasColors = variants.any((v) => v.color != null);
      if (!hasColors) {
        _selectedVariant = variants.firstWhere(
          (v) => v.size == size,
          orElse: () => variants.first,
        );
      } else if (_selectedColor != null) {
        final match = variants.where(
          (v) => v.color == _selectedColor && v.size == size,
        );
        _selectedVariant = match.isNotEmpty ? match.first : null;
      }
    });
  }

  Future<void> _toggleWishlist() async {
    await context.read<WishlistProvider>().toggleWishlist(
      widget.productId,
      product: _product,
    );
  }

  Future<void> _addToCart() async {
    if (_addingToCart) return;

    // Enforce variant selection for variant products
    if (_product!.hasVariants && _selectedVariant == null) {
      setState(() => _variantRequired = true);
      final hasSizes = _product!.variants.any((v) => v.size != null && v.size!.isNotEmpty);
      final hasColors = _product!.variants.any((v) => v.color != null && v.color!.isNotEmpty);
      String msg = 'Please select ';
      if (hasSizes && hasColors) {
        msg += 'color and size';
      } else if (hasSizes) {
        msg += 'a size';
      } else {
        msg += 'a color';
      }
      msg += ' first';
      _showSnackBar(msg, Colors.orange);
      return;
    }

    setState(() => _addingToCart = true);
    try {
      final error = await context.read<CartProvider>().addToCart(
        productId: widget.productId,
        variantId: _selectedVariant?.id,
        quantity:  _quantity,
      );
      if (mounted) {
        setState(() => _variantRequired = false);
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
    // Capture context-dependent objects before any await
    final cart = context.read<CartProvider>();
    final nav  = Navigator.of(context);
    // Do NOT add to cart — Buy Now goes directly to checkout without touching cart
    final userId = await ApiClient.getTokenPayload().then((p) => p?['id'] as String? ?? '');
    if (!mounted) return;
    // Build a single-item cart for checkout
    final cartItem = CartItemModel(
      id:        'buynow_${widget.productId}_${_selectedVariant?.id ?? ""}',
      userId:    userId,
      productId: widget.productId,
      variantId: _selectedVariant?.id,
      quantity:  _quantity,
      product:   p,
      variant:   _selectedVariant,
    );
    // Use CartProvider shipping settings so admin-configurable free-shipping threshold is respected
    // Use variant price override if set, else product effective price
    final unitPrice   = _selectedVariant?.priceOverride ?? p.effectivePrice;
    final subtotal    = unitPrice * _quantity;
    final shippingAmt = subtotal >= cart.freeShippingAbove ? 0.0 : cart.shippingCharge;
    nav.push(
        MaterialPageRoute(builder: (_) => CheckoutScreen(
          cartItems: [cartItem],
          subtotal:  subtotal,
          shipping:  shippingAmt,
          total:     subtotal + shippingAmt,
        )));
  }

  void _showSnackBar(String msg, Color color) {
    if (!mounted) return;
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
            ? CachedNetworkImage(imageUrl: images[_selectedImageIndex],
            fit: BoxFit.cover,
            placeholder: (_, __) => _imagePlaceholder(),
            errorWidget: (_, __, ___) => _imagePlaceholder())
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
                  child: CachedNetworkImage(imageUrl: images[i],
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const SizedBox.shrink(),
                      errorWidget: (_, __, ___) =>
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

        // Stock status — for variant products show "Select size for availability"
        if (!p.hasVariants) ...[
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
        ] else ...[
          Text('${p.variants.where((v) => v.isInStock).length} sizes available',
              style: TextStyle(fontSize: 13, color: _teal,
                  fontWeight: FontWeight.w500)),
        ],
      ]),
    );
  }

  // ── Variant selector (sizes + colors) ───────────────────────
  Widget _buildVariantSelector(ProductModel p) {
    if (!p.hasVariants && p.variants.isEmpty) return const SizedBox.shrink();
    if (p.variants.isEmpty) return const SizedBox.shrink();

    final allColors = p.variants
        .where((v) => v.color != null)
        .map((v) => v.color!)
        .toSet()
        .toList();
    final allSizes = p.variants
        .where((v) => v.size != null)
        .map((v) => v.size!)
        .toList()
      ..unique(); // preserve insertion order

    final hasColors = allColors.isNotEmpty;
    final hasSizes  = allSizes.isNotEmpty;

    // Sizes available in the selected color (or all sizes if no color filter)
    final availableSizes = hasColors && _selectedColor != null
        ? p.variants
            .where((v) => v.color == _selectedColor && v.size != null)
            .map((v) => v.size!)
            .toList()
        : allSizes;

    // Price / stock to show from selected variant
    final effectivePrice = _selectedVariant?.priceOverride ?? p.price;
    final variantStock   = _selectedVariant?.stock;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Price: update if variant has price override ───────
        if (_selectedVariant?.priceOverride != null) ...[
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Text(_fmtPrice(effectivePrice),
                style: const TextStyle(fontSize: 22,
                    fontWeight: FontWeight.bold, color: _ink)),
            if (p.price != effectivePrice) ...[
              const SizedBox(width: 8),
              Text(_fmtPrice(p.price),
                  style: TextStyle(fontSize: 14, color: _slate,
                      decoration: TextDecoration.lineThrough)),
            ],
          ]),
          const SizedBox(height: 14),
        ],

        // ── Variant stock status ──────────────────────────────
        if (variantStock != null) ...[
          Row(children: [
            Container(
              width: 7, height: 7,
              decoration: BoxDecoration(
                color: variantStock > 0 ? _green : Colors.redAccent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              variantStock == 0
                  ? 'Out of stock in this size'
                  : variantStock <= 5
                      ? 'Only $variantStock left!'
                      : 'In stock',
              style: TextStyle(
                fontSize: 12,
                color: variantStock == 0
                    ? Colors.redAccent
                    : variantStock <= 5 ? Colors.orange : _green,
                fontWeight: FontWeight.w500,
              ),
            ),
          ]),
          const SizedBox(height: 12),
        ],

        // ── Color selector ────────────────────────────────────
        if (hasColors) ...[
          Row(children: [
            const Text('Color',
                style: TextStyle(fontSize: 14,
                    fontWeight: FontWeight.w600, color: _ink)),
            const SizedBox(width: 8),
            Text(_selectedColor ?? 'Select a color',
                style: TextStyle(
                    fontSize: 13,
                    color: _selectedColor != null ? _slate : Colors.orange,
                    fontWeight: _selectedColor == null ? FontWeight.w600 : FontWeight.normal)),
          ]),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10, runSpacing: 10,
            children: allColors.map((color) {
              final isSelected = _selectedColor == color;
              // Check if any variant of this color is in stock
              final hasStock = p.variants.any((v) => v.color == color && v.stock > 0);
              return GestureDetector(
                onTap: () => _onColorSelected(color),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 38, height: 38,
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
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (isSelected)
                        const Icon(Icons.check, color: Colors.white, size: 18),
                      if (!hasStock)
                        // Diagonal line = out of stock in all sizes of this color
                        CustomPaint(painter: _StrikethroughPainter()),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],

        // ── Size selector ─────────────────────────────────────
        if (hasSizes) ...[
          Row(children: [
            Text(availableSizes.isNotEmpty ? 'Size' : 'Size',
                style: const TextStyle(fontSize: 14,
                    fontWeight: FontWeight.w600, color: _ink)),
            const SizedBox(width: 8),
            Text(
              _selectedSize ?? (hasColors && _selectedColor == null
                  ? 'Choose color first'
                  : 'Select a size'),
              style: TextStyle(
                fontSize: 13,
                color: _selectedSize != null ? _slate
                    : (_variantRequired ? Colors.redAccent : Colors.orange),
                fontWeight: FontWeight.w500,
              ),
            ),
          ]),
          if (_variantRequired && _selectedVariant == null) ...[
            const SizedBox(height: 4),
            Text('⚠ Please select a size to continue',
                style: const TextStyle(
                    fontSize: 12, color: Colors.redAccent,
                    fontWeight: FontWeight.w500)),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: allSizes.map((size) {
              // Find matching variant for this size (and selected color if applicable)
              final matchingVariant = hasColors && _selectedColor != null
                  ? p.variants.where(
                      (v) => v.color == _selectedColor && v.size == size
                    ).firstOrNull
                  : p.variants.where((v) => v.size == size).firstOrNull;

              final isSelected = _selectedSize == size && _selectedVariant != null;
              final isAvailable = availableSizes.contains(size);
              final hasStock = matchingVariant?.stock != null
                  ? matchingVariant!.stock > 0
                  : true; // if no match yet, don't gray it out

              return GestureDetector(
                onTap: isAvailable ? () => _onSizeSelected(size) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _teal
                        : !isAvailable || !hasStock
                            ? _surface
                            : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? _teal
                          : _variantRequired && !isSelected
                              ? Colors.redAccent.withValues(alpha: 0.4)
                              : _border,
                      width: isSelected ? 2 : 1.5,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Text(size,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : !isAvailable || !hasStock
                                    ? _border
                                    : _ink,
                          )),
                      // Strike-through for out-of-stock
                      if (!hasStock && isAvailable)
                        Positioned.fill(
                          child: CustomPaint(painter: _SizeStrikethroughPainter()),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ]),
    );
  }

  String _fmtPrice(double amount) {
    final str = amount.toStringAsFixed(0);
    final result = StringBuffer('₹');
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      if (count == 3 || (count > 3 && (count - 3) % 2 == 0)) result.write(',');
      result.write(str[i]);
      count++;
    }
    return result.toString().split('').reversed.join();
  }

  Color _colorFromName(String name) {
    switch (name.toLowerCase()) {
      case 'green':    return const Color(0xFF16A34A);
      case 'black':    return const Color(0xFF1E293B);
      case 'silver':   return const Color(0xFF94A3B8);
      case 'grey':
      case 'gray':     return const Color(0xFF6B7280);
      case 'gold':     return const Color(0xFFD4AF37);
      case 'white':    return const Color(0xFFE2E8F0);
      case 'red':      return const Color(0xFFEF4444);
      case 'blue':     return const Color(0xFF3B82F6);
      case 'navy':
      case 'navy blue':return const Color(0xFF1E3A5F);
      case 'brown':    return const Color(0xFF92400E);
      case 'pink':     return const Color(0xFFF472B6);
      case 'purple':   return const Color(0xFF7C3AED);
      case 'yellow':   return const Color(0xFFFBBF24);
      case 'orange':   return const Color(0xFFF97316);
      case 'maroon':   return const Color(0xFF7F1D1D);
      case 'teal':     return const Color(0xFF0D9488);
      case 'cream':
      case 'beige':    return const Color(0xFFF5F0E8);
      default:
        // Try parsing as hex color code
        try {
          final hex = name.replaceAll('#', '').trim();
          if (hex.length == 6) {
            return Color(int.parse('FF$hex', radix: 16));
          }
        } catch (_) {}
        return const Color(0xFF64748B);
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
              // Use variant stock if a variant is selected, else product stock
              final stock = _selectedVariant?.stock ?? _product?.stock ?? 999;
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
    // For variant products, only show "in stock" when a specific variant is selected
    final variantSelected = !p.hasVariants || _selectedVariant != null;
    final variantInStock  = _selectedVariant?.isInStock ?? true;
    final canAdd = p.isInStock && variantInStock && (p.hasVariants ? variantSelected : true);

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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Prompt when variant not yet selected
            if (p.hasVariants && !variantSelected) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                ),
                child: const Text('← Select a size above to continue',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.amber,
                        fontWeight: FontWeight.w600)),
              ),
            ],
            Row(children: [
              // Add to Cart
              Expanded(
                child: GestureDetector(
                  onTap: _addToCart,
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: canAdd
                          ? const LinearGradient(colors: [_teal, _green])
                          : null,
                      color: canAdd ? null : _border,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: canAdd ? [BoxShadow(
                        color: _teal.withValues(alpha: 0.3),
                        blurRadius: 12, offset: const Offset(0, 4),
                      )] : null,
                    ),
                    child: Center(
                      child: _addingToCart
                          ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                          : Text(
                              p.hasVariants && !variantSelected
                                  ? 'SELECT SIZE'
                                  : 'ADD TO CART',
                              style: const TextStyle(color: Colors.white,
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
                  onTap: canAdd ? () => _buyNow(p) : _addToCart,
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: canAdd ? _teal : _border, width: 1.5),
                    ),
                    child: Center(
                      child: Text('BUY NOW',
                          style: TextStyle(
                            color: canAdd ? _teal : _slate,
                            fontWeight: FontWeight.bold,
                            fontSize: 13, letterSpacing: 1,
                          )),
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

// ── Extension: deduplicate a list while preserving order ─────────────────────
extension _UniqueList<T> on List<T> {
  void unique() {
    final seen = <T>{};
    removeWhere((e) => !seen.add(e));
  }
}

// ── Custom painter: diagonal strike for out-of-stock color swatches ──────────
class _StrikethroughPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      const Offset(0, 0), Offset(size.width, size.height),
      Paint()..color = Colors.white.withValues(alpha: 0.627)..strokeWidth = 2,
    );
  }
  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ── Custom painter: diagonal strike for out-of-stock size chips ───────────────
class _SizeStrikethroughPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      Offset(0, size.height * 0.15),
      Offset(size.width, size.height * 0.85),
      Paint()..color = Colors.redAccent.withValues(alpha: 0.392)..strokeWidth = 1.5,
    );
  }
  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}