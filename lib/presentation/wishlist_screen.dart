import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../providers/wishlist_provider.dart';
import 'product_detail_screen.dart';
import 'bottom_nav.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  bool _isEditing = false;

  static const Color _ink     = Color(0xFF0F172A);
  static const Color _teal    = Color(0xFF0D9488);
  static const Color _green   = Color(0xFF10B981);
  static const Color _slate   = Color(0xFF64748B);
  static const Color _border  = Color(0xFFE2E8F0);
  static const Color _surface = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WishlistProvider>().loadWishlist();
    });
  }

  void _addToCart(BuildContext context, dynamic product) {
    if (product.hasVariants == true) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ProductDetailScreen(productId: product.id)));
      return;
    }
    // Non-variant products: add directly
    final messenger = ScaffoldMessenger.of(context);
    context.read<CartProvider>().addToCart(
      productId: product.id,
      quantity: 1,
    ).then((error) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(
          content: Text(
            error == null ? '${product.name} added to cart!' : 'Failed to add to cart',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: error == null ? _teal : Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final wishlist = context.watch<WishlistProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          _buildTopBar(wishlist),
          Expanded(
            child: wishlist.isLoading
                ? const Center(child: CircularProgressIndicator(color: _teal))
                : wishlist.products.isEmpty
                    ? _buildEmpty()
                    : RefreshIndicator(
                        color: _teal,
                        onRefresh: () =>
                            context.read<WishlistProvider>().loadWishlist(),
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          itemCount: wishlist.products.length,
                          itemBuilder: (_, i) =>
                              _buildItem(wishlist.products[i], wishlist),
                        ),
                      ),
          ),
          buildBottomNav(context, 3),
        ]),
      ),
    );
  }

  Widget _buildTopBar(WishlistProvider wishlist) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back, size: 24, color: _ink),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text('Wishlist (${wishlist.count})',
              style: const TextStyle(fontSize: 20,
                  fontWeight: FontWeight.bold, color: _ink)),
        ),
        if (wishlist.products.isNotEmpty)
          GestureDetector(
            onTap: () => setState(() => _isEditing = !_isEditing),
            child: Text(
              _isEditing ? 'Done' : 'Edit',
              style: TextStyle(fontSize: 14, color: _teal,
                  fontWeight: FontWeight.w600),
            ),
          ),
      ]),
    );
  }

  Widget _buildItem(dynamic product, WishlistProvider wishlist) {
    return Dismissible(
      key: Key(product.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline_rounded,
            color: Colors.redAccent, size: 26),
      ),
      onDismissed: (_) => wishlist.removeFromWishlist(product.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8, offset: const Offset(0, 3),
          )],
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Product image
          GestureDetector(
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => ProductDetailScreen(
                    productId: product.id, product: product))),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: product.primaryImage != null
                  ? CachedNetworkImage(imageUrl: product.primaryImage!,
                      width: 90, height: 90, fit: BoxFit.contain,
                      memCacheWidth: 180,
                      placeholder: (_, _) => _imgPlaceholder(),
                      errorWidget: (_, _, _) => _imgPlaceholder())
                  : _imgPlaceholder(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Text(product.name,
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13,
                          fontWeight: FontWeight.w600, color: _ink,
                          height: 1.3)),
                ),
                GestureDetector(
                  onTap: () => wishlist.removeFromWishlist(product.id),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _isEditing ? Icons.close : Icons.delete_outline_rounded,
                      size: 18, color: Colors.redAccent),
                  ),
                ),
              ]),
              const SizedBox(height: 4),
              Row(children: [
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
              const SizedBox(height: 6),
              Row(children: [
                Container(
                  width: 7, height: 7,
                  decoration: BoxDecoration(
                    color: product.isInStock ? _green : Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  product.isInStock ? 'In Stock' : 'Out of Stock',
                  style: TextStyle(fontSize: 11,
                    color: product.isInStock ? _green : Colors.redAccent,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: product.isInStock
                    ? () => _addToCart(context, product)
                    : null,
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: product.isInStock
                        ? const LinearGradient(colors: [_teal, _green])
                        : null,
                    color: product.isInStock ? null : _border,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text('ADD TO CART',
                        style: TextStyle(
                          color: product.isInStock ? Colors.white : _slate,
                          fontWeight: FontWeight.bold,
                          fontSize: 11, letterSpacing: 0.8,
                        )),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _imgPlaceholder() => Container(
    width: 90, height: 90, color: _surface,
    child: Icon(Icons.image_outlined, size: 28, color: _border),
  );

  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.favorite_outline, size: 64,
            color: _slate.withValues(alpha: 0.25)),
        const SizedBox(height: 16),
        const Text('Your wishlist is empty',
            style: TextStyle(fontSize: 17,
                fontWeight: FontWeight.w600, color: _ink)),
        const SizedBox(height: 8),
        Text('Save items you love',
            style: TextStyle(fontSize: 13, color: _slate)),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 28, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_teal, _green]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('Explore Products',
                style: TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w600, fontSize: 14)),
          ),
        ),
      ]),
    );
  }

}
