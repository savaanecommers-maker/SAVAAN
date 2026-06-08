import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../data/api_client.dart';
import '../providers/cart_provider.dart';
import '../providers/settings_provider.dart';
import 'checkout_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _couponCtrl = TextEditingController();

  static const Color _ink     = Color(0xFF0F172A);
  static const Color _teal    = Color(0xFF0D9488);
  static const Color _green   = Color(0xFF10B981);
  static const Color _slate   = Color(0xFF64748B);
  static const Color _border  = Color(0xFFE2E8F0);
  static const Color _surface = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    // Refresh cart when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CartProvider>().loadCart();
    });
  }

  @override
  void dispose() {
    _couponCtrl.dispose();
    super.dispose();
  }

  String _fmt(double v) {
    final str = v.toStringAsFixed(0);
    final buf = StringBuffer('₹');
    int c = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      if (c == 3 || (c > 3 && (c - 3) % 2 == 0)) buf.write(',');
      buf.write(str[i]);
      c++;
    }
    return buf.toString().split('').reversed.join();
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          _buildTopBar(cart),
          Expanded(
            child: cart.isLoading
                ? const Center(child: CircularProgressIndicator(color: _teal))
                : cart.isEmpty
                    ? _buildEmpty()
                    : RefreshIndicator(
                        color: _teal,
                        onRefresh: () => context.read<CartProvider>().loadCart(),
                        child: ListView(children: [
                          ...cart.items.map((item) => _buildCartItem(item, cart)),
                          _buildCouponField(cart),
                          _buildSummary(cart),
                          const SizedBox(height: 16),
                        ]),
                      ),
          ),
          if (!cart.isEmpty) _buildCheckoutBar(cart),
        ]),
      ),
    );
  }

  Widget _buildTopBar(CartProvider cart) {
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
          child: Text(
            'My Cart (${cart.itemCount})',
            style: const TextStyle(fontSize: 20,
                fontWeight: FontWeight.bold, color: _ink),
          ),
        ),
        if (!cart.isEmpty)
          GestureDetector(
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  title: const Text('Clear Cart',
                      style: TextStyle(fontWeight: FontWeight.bold,
                          color: _ink)),
                  content: const Text(
                      'Remove all items from cart?',
                      style: TextStyle(color: _slate)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text('Cancel',
                          style: TextStyle(color: _slate)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Clear',
                          style: TextStyle(color: Colors.redAccent,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              );
              if (confirmed == true && mounted) {
                context.read<CartProvider>().clearCart();
              }
            },
            child: Text('Clear',
                style: TextStyle(fontSize: 13,
                    color: Colors.redAccent.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w600)),
          ),
      ]),
    );
  }

  Widget _buildCartItem(item, CartProvider cart) {
    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline_rounded,
            color: Colors.redAccent, size: 24),
      ),
      onDismissed: (_) => cart.removeFromCart(item.id),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: item.displayImage != null
                ? Image.network(item.displayImage!,
                    width: 80, height: 80, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _imgPlaceholder())
                : _imgPlaceholder(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.displayName,
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13,
                      fontWeight: FontWeight.w600, color: _ink, height: 1.3)),
              if (item.variant?.displayName.isNotEmpty == true) ...[
                const SizedBox(height: 3),
                Text(item.variant!.displayName,
                    style: TextStyle(fontSize: 11, color: _slate)),
              ],
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                Text(_fmt(item.totalPrice),
                    style: const TextStyle(fontSize: 14,
                        fontWeight: FontWeight.bold, color: _ink)),
                Container(
                  decoration: BoxDecoration(
                      border: Border.all(color: _border),
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    _qtyBtn(Icons.remove, () =>
                        cart.updateQuantity(item.id, item.quantity - 1)),
                    SizedBox(width: 32,
                        child: Center(
                          child: Text('${item.quantity}',
                              style: const TextStyle(fontSize: 13,
                                  fontWeight: FontWeight.bold, color: _ink)),
                        )),
                    _qtyBtn(Icons.add, () =>
                        cart.updateQuantity(item.id, item.quantity + 1)),
                  ]),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 30, height: 30,
      decoration: BoxDecoration(
          color: _surface, borderRadius: BorderRadius.circular(6)),
      child: Icon(icon, size: 16, color: _ink),
    ),
  );

  Widget _imgPlaceholder() => Container(
    width: 80, height: 80, color: _surface,
    child: Icon(Icons.image_outlined, size: 28, color: _border),
  );

  Widget _buildCouponField(CartProvider cart) {
    // Sync controller text with provider state
    if (cart.couponCode != null &&
        _couponCtrl.text != cart.couponCode) {
      _couponCtrl.text = cart.couponCode!;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.local_offer_outlined, size: 16, color: _teal),
          const SizedBox(width: 6),
          const Text('Apply Coupon',
              style: TextStyle(fontSize: 13,
                  fontWeight: FontWeight.w600, color: _ink)),
          const Spacer(),
          // Only show link when no coupon is applied
          if (cart.couponCode == null)
            GestureDetector(
              onTap: () => _showCouponsSheet(cart),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('View All',
                    style: TextStyle(fontSize: 12,
                        color: _teal, fontWeight: FontWeight.w600)),
                const SizedBox(width: 2),
                Icon(Icons.chevron_right_rounded, size: 15, color: _teal),
              ]),
            ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: cart.couponError != null
                        ? Colors.redAccent : _border),
              ),
              child: Row(children: [
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _couponCtrl,
                    enabled: cart.couponCode == null,
                    textCapitalization: TextCapitalization.characters,
                    style: TextStyle(fontSize: 13, color: _ink,
                        fontWeight: FontWeight.w600, letterSpacing: 1),
                    decoration: InputDecoration(
                      hintText: 'Enter coupon code',
                      hintStyle: TextStyle(fontSize: 12,
                          color: _slate.withValues(alpha: 0.5),
                          fontWeight: FontWeight.normal, letterSpacing: 0),
                      border: InputBorder.none, isDense: true,
                    ),
                  ),
                ),
                if (cart.couponCode != null)
                  GestureDetector(
                    onTap: () {
                      context.read<CartProvider>().removeCoupon();
                      _couponCtrl.clear();
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(Icons.close, size: 16, color: _slate),
                    ),
                  ),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: cart.couponCode != null
                ? () {
                    context.read<CartProvider>().removeCoupon();
                    _couponCtrl.clear();
                  }
                : cart.isApplyingCoupon
                    ? null
                    : () => context.read<CartProvider>()
                        .applyCoupon(_couponCtrl.text),
            child: Container(
              height: 40, width: 72,
              decoration: BoxDecoration(
                color: cart.couponCode != null
                    ? Colors.redAccent.withValues(alpha: 0.1)
                    : _teal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: cart.couponCode != null
                        ? Colors.redAccent : _teal, width: 1.2),
              ),
              child: Center(
                child: cart.isApplyingCoupon
                    ? SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(
                            color: _teal, strokeWidth: 2))
                    : Text(cart.couponCode != null ? 'Remove' : 'Apply',
                        style: TextStyle(
                          fontSize: 12,
                          color: cart.couponCode != null
                              ? Colors.redAccent : _teal,
                          fontWeight: FontWeight.w600,
                        )),
              ),
            ),
          ),
        ]),
        if (cart.couponError != null) ...[
          const SizedBox(height: 6),
          Text(cart.couponError!,
              style: const TextStyle(fontSize: 11,
                  color: Colors.redAccent)),
        ],
        if (cart.couponCode != null) ...[
          const SizedBox(height: 6),
          Row(children: [
            Icon(Icons.check_circle_outline, size: 13, color: _green),
            const SizedBox(width: 5),
            Text(
              '${cart.couponCode} applied! You save ${_fmt(cart.couponDiscount)}',
              style: TextStyle(fontSize: 11, color: _green,
                  fontWeight: FontWeight.w500)),
          ]),
        ],
      ]),
    );
  }

  // ── Coupons bottom sheet ─────────────────────────────────────
  void _showCouponsSheet(CartProvider cart) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _CartCouponsSheet(
        onApply: (code) {
          // Auto-fill the text field and apply the coupon
          _couponCtrl.text = code;
          cart.applyCoupon(code);
        },
      ),
    );
  }

  Widget _buildSummary(CartProvider cart) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(children: [
        _row('Subtotal (${cart.items.length} items)',
            _fmt(cart.subtotal)),
        if (cart.couponDiscount > 0) ...[
          const SizedBox(height: 8),
          _row('Discount (${cart.couponCode})',
              '-${_fmt(cart.couponDiscount)}',
              valueColor: _green),
        ],
        const SizedBox(height: 8),
        _row('Shipping',
            cart.shipping == 0 ? 'FREE' : _fmt(cart.shipping),
            valueColor: cart.shipping == 0 ? _green : null),
        if (cart.shipping > 0) ...[
          const SizedBox(height: 4),
          Builder(builder: (ctx) {
            final freeAbove = ctx.read<SettingsProvider>().freeShippingAbove;
            final needed = freeAbove - cart.subtotal;
            return Text(
              'Add ${_fmt(needed > 0 ? needed : 0)} more for free shipping',
              style: TextStyle(fontSize: 11, color: _teal),
            );
          }),
        ],
        Divider(color: _border, height: 20),
        _row('Total', _fmt(cart.total), bold: true),
      ]),
    );
  }

  Widget _row(String l, String v, {bool bold = false, Color? valueColor}) =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(l, style: TextStyle(
            fontSize: bold ? 15 : 13,
            color: bold ? _ink : _slate,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        Text(v, style: TextStyle(
            fontSize: bold ? 15 : 13,
            color: valueColor ?? (bold ? _ink : _slate),
            fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
      ]);

  Widget _buildCheckoutBar(CartProvider cart) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 16, offset: const Offset(0, -4),
        )],
      ),
      child: GestureDetector(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => CheckoutScreen(
              cartItems:  cart.items,
              subtotal:   cart.subtotal,
              discount:   cart.couponDiscount,
              shipping:   cart.shipping,
              total:      cart.total,
              couponCode: cart.couponCode,
            ))),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_teal, _green]),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(
              color: _teal.withValues(alpha: 0.3),
              blurRadius: 12, offset: const Offset(0, 4),
            )],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center,
              children: [
            const Text('PROCEED TO CHECKOUT',
                style: TextStyle(color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14, letterSpacing: 1)),
            const SizedBox(width: 10),
            Text(_fmt(cart.total),
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w600, fontSize: 14)),
          ]),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.shopping_cart_outlined, size: 64,
            color: _slate.withValues(alpha: 0.25)),
        const SizedBox(height: 16),
        const Text('Your cart is empty',
            style: TextStyle(fontSize: 17,
                fontWeight: FontWeight.w600, color: _ink)),
        const SizedBox(height: 8),
        Text('Add items to get started',
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
            child: const Text('Continue Shopping',
                style: TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w600, fontSize: 14)),
          ),
        ),
      ]),
    );
  }
}

// ── Cart Coupons Sheet ────────────────────────────────────────────────────────
/// Fetches active coupons; tapping one auto-fills + applies it to the cart.
class _CartCouponsSheet extends StatefulWidget {
  final void Function(String code) onApply;
  const _CartCouponsSheet({required this.onApply});

  @override
  State<_CartCouponsSheet> createState() => _CartCouponsSheetState();
}

class _CartCouponsSheetState extends State<_CartCouponsSheet> {
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
            final list = res.data!['_list'] as List? ?? [];
            _coupons = List<Map<String, dynamic>>.from(list);
          }
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle bar
        Container(width: 36, height: 4,
            decoration: BoxDecoration(color: _border,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        // Header
        Row(children: [
          const Expanded(
            child: Text('Available Coupons',
                style: TextStyle(fontSize: 18,
                    fontWeight: FontWeight.bold, color: _ink)),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                  color: _surface, shape: BoxShape.circle,
                  border: Border.all(color: _border)),
              child: const Icon(Icons.close, size: 16, color: _ink),
            ),
          ),
        ]),
        const SizedBox(height: 4),
        Text('Tap a coupon to apply it instantly',
            style: TextStyle(fontSize: 12, color: _slate)),
        const SizedBox(height: 16),
        // Body
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: CircularProgressIndicator(color: _teal, strokeWidth: 2),
          )
        else if (_coupons.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(children: [
              Icon(Icons.local_offer_outlined, size: 40,
                  color: _slate.withValues(alpha: 0.3)),
              const SizedBox(height: 12),
              Text('No active coupons right now',
                  style: TextStyle(fontSize: 14, color: _slate)),
            ]),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _coupons.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _buildCard(_coupons[i]),
          ),
      ]),
    );
  }

  Widget _buildCard(Map<String, dynamic> c) {
    final code      = c['code']?.toString() ?? '';
    final type      = c['discount_type']?.toString() ?? 'flat';
    final value     = double.tryParse(
        c['discount_value']?.toString() ?? '0') ?? 0;
    final minOrder  = double.tryParse(
        c['min_order_value']?.toString() ?? '0') ?? 0;
    final maxDisc   = double.tryParse(
        c['max_discount']?.toString() ?? '0') ?? 0;
    final desc      = c['description']?.toString() ?? '';
    final label     = type == 'percent'
        ? '${value.toInt()}% OFF'
        : '₹${value.toInt()} OFF';

    return GestureDetector(
      onTap: () {
        Navigator.pop(context);        // close sheet
        widget.onApply(code);          // fill + apply in cart
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _teal.withValues(alpha: 0.3)),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          // Discount badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_teal, _green],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(10)),
            child: Text(label,
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w800, fontSize: 13)),
          ),
          const SizedBox(width: 12),
          // Code + details
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(code,
                style: const TextStyle(fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _ink, letterSpacing: 0.5)),
            const SizedBox(height: 3),
            if (desc.isNotEmpty)
              Text(desc,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: _slate)),
            Row(children: [
              if (minOrder > 0) ...[
                Icon(Icons.info_outline_rounded,
                    size: 10, color: _slate.withValues(alpha: 0.6)),
                const SizedBox(width: 3),
                Text('Min. ₹${minOrder.toInt()}',
                    style: TextStyle(fontSize: 10,
                        color: _slate.withValues(alpha: 0.7))),
              ],
              if (minOrder > 0 && maxDisc > 0)
                Text('  ·  ', style: TextStyle(
                    fontSize: 10, color: _slate.withValues(alpha: 0.5))),
              if (maxDisc > 0)
                Text('Max. ₹${maxDisc.toInt()} off',
                    style: TextStyle(fontSize: 10,
                        color: _slate.withValues(alpha: 0.7))),
            ]),
          ])),
          // Tap indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _teal.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _teal.withValues(alpha: 0.3))),
            child: const Text('APPLY',
                style: TextStyle(fontSize: 11,
                    fontWeight: FontWeight.w800, color: _teal)),
          ),
        ]),
      ),
    );
  }
}
