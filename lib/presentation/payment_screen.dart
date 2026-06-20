import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/api_client.dart';
import '../models/cart_item_model.dart';
import '../models/order_model.dart';
import '../providers/cart_provider.dart';
import '../providers/order_provider.dart';
import 'cashfree_webview_screen.dart';
import 'order_success_screen.dart';

class PaymentScreen extends StatefulWidget {
  final List<CartItemModel> cartItems;
  final double subtotal;
  final double discount;
  final double shipping;
  final double total;
  final String? couponCode;
  final String selectedAddressId;

  const PaymentScreen({
    super.key,
    required this.cartItems,
    required this.subtotal,
    required this.discount,
    required this.shipping,
    required this.total,
    this.couponCode,
    required this.selectedAddressId,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {

  bool _useCod     = false;
  bool _isPlacing  = false;

  static const Color _ink     = Color(0xFF0F172A);
  static const Color _teal    = Color(0xFF0D9488);
  static const Color _green   = Color(0xFF10B981);
  static const Color _slate   = Color(0xFF64748B);
  static const Color _border  = Color(0xFFE2E8F0);
  static const Color _surface = Color(0xFFF8FAFC);

  // ─────────────────────────────────────────────────────────────
  // Online payment — create order → open Cashfree hosted checkout
  // (shows UPI/QR, Cards, Net Banking, Wallets — whatever Cashfree
  // has enabled for the merchant account)
  // ─────────────────────────────────────────────────────────────

  Future<void> _payOnline() async {
    setState(() => _isPlacing = true);
    try {
      final res = await ApiClient.post('/api/payments/cashfree/create-order', {
        'items': widget.cartItems.map((i) => {
          'product_id': i.productId,
          'variant_id': i.variantId,
          'quantity':   i.quantity,
        }).toList(),
        'address_id':  widget.selectedAddressId,
        'coupon_code': widget.couponCode,
        'shipping':    widget.shipping,
        'subtotal':    widget.subtotal,
        'discount':    widget.discount,
        'total':       widget.total,
      }, timeout: const Duration(seconds: 45));
      if (!res.isSuccess || res.data == null) {
        throw Exception(res.error ?? 'Failed to create payment order');
      }
      final sessionId   = res.data!['payment_session_id'] as String;
      final orderNumber = res.data!['order_number'] as String;

      if (!mounted) return;
      setState(() => _isPlacing = false);

      final result = await Navigator.push<String>(context,
        MaterialPageRoute(builder: (_) => CashfreeWebViewScreen(
          paymentSessionId: sessionId,
          orderNumber:      orderNumber,
          total:            widget.total,
        )),
      );

      if (!mounted) return;
      if (result == 'success') {
        context.read<CartProvider>().clear();
        Navigator.pushAndRemoveUntil(context,
          MaterialPageRoute(builder: (_) => OrderSuccessScreen(
            orderNumber: orderNumber,
            orderDate:   DateTime.now().toIso8601String(),
            total:       widget.total,
          )),
          (r) => r.isFirst,
        );
      } else if (result == 'failed') {
        _snack('Payment failed. Please try again.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPlacing = false);
        _snack(e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  // ─────────────────────────────────────────────────────────────
  // COD
  // ─────────────────────────────────────────────────────────────

  Future<void> _placeCodOrder() async {
    final cartProvider  = context.read<CartProvider>();
    final orderProvider = context.read<OrderProvider>();
    setState(() => _isPlacing = true);
    try {
      final (order, error) = await orderProvider.placeOrder(
        cartItems:     widget.cartItems,
        addressId:     widget.selectedAddressId,
        paymentMethod: PaymentMethod.cod,
        subtotal:      widget.subtotal,
        discount:      widget.discount,
        shipping:      widget.shipping,
        total:         widget.total,
        couponCode:    widget.couponCode,
      );
      if (error != null) throw Exception(error);
      cartProvider.clear();
      if (mounted && order != null) {
        Navigator.pushAndRemoveUntil(context,
          MaterialPageRoute(builder: (_) => OrderSuccessScreen(
            orderNumber: order.orderNumber,
            orderDate:   order.formattedDate,
            total:       widget.total,
          )),
          (r) => r.isFirst,
        );
      }
    } catch (_) {
      if (mounted) _snack('Failed to place order. Please try again.');
    } finally {
      if (mounted) setState(() => _isPlacing = false);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────

  String _fmt(double v) {
    final s = v.toStringAsFixed(0);
    final b = StringBuffer('₹');
    int c = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      if (c == 3 || (c > 3 && (c - 3) % 2 == 0)) b.write(',');
      b.write(s[i]); c++;
    }
    return b.toString().split('').reversed.join();
  }

  void _snack(String msg, {Color color = Colors.redAccent}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ══════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          _buildTopBar(),
          _buildStepIndicator(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // ── Payment methods badge row ─────────────────
                _buildPaymentMethodsBadges(),
                const SizedBox(height: 20),

                // ── Order summary ─────────────────────────────
                _buildSummary(),
                const SizedBox(height: 16),

                // ── COD toggle ────────────────────────────────
                _buildCodToggle(),
                if (_useCod) ...[
                  const SizedBox(height: 10),
                  _buildCodInfo(),
                ],
              ]),
            ),
          ),
          _buildPayBar(),
        ]),
      ),
    );
  }

  // ── Payment methods badge row (purely informational) ──────────
  Widget _buildPaymentMethodsBadges() {
    final methods = [
      (Icons.currency_rupee,            'UPI',         const Color(0xFF5C2E7E)),
      (Icons.credit_card_outlined,      'Cards',       const Color(0xFF1A1A2E)),
      (Icons.account_balance_outlined,  'Net Banking', const Color(0xFF0369A1)),
      (Icons.account_balance_wallet_outlined, 'Wallets', const Color(0xFF7C3AED)),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Accepted Payment Methods',
        style: TextStyle(fontSize: 12, color: _slate, fontWeight: FontWeight.w600)),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8, runSpacing: 8,
        children: methods.map((m) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: m.$3.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: m.$3.withValues(alpha: 0.25)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(m.$1, size: 13, color: m.$3),
            const SizedBox(width: 5),
            Text(m.$2, style: TextStyle(fontSize: 12, color: m.$3, fontWeight: FontWeight.w600)),
          ]),
        )).toList(),
      ),
      const SizedBox(height: 6),
      Row(children: [
        Icon(Icons.lock_outline, size: 12, color: _slate),
        const SizedBox(width: 4),
        Text('Secured by Cashfree · 256-bit SSL encryption',
          style: TextStyle(fontSize: 11, color: _slate)),
      ]),
    ]);
  }

  // ── COD toggle ────────────────────────────────────────────────
  Widget _buildCodToggle() {
    return GestureDetector(
      onTap: () => setState(() => _useCod = !_useCod),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: _useCod ? Colors.orange.withValues(alpha: 0.05) : Colors.white,
          borderRadius: _useCod
              ? const BorderRadius.vertical(top: Radius.circular(12))
              : BorderRadius.circular(12),
          border: Border.all(
            color: _useCod ? Colors.orange.shade600 : _border,
            width: _useCod ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          Container(
            width: 22, height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _useCod ? Colors.orange.shade600 : _slate, width: 1.5),
              color: _useCod ? Colors.orange.shade600 : Colors.transparent,
            ),
            child: _useCod
                ? Container(margin: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle))
                : null,
          ),
          const SizedBox(width: 12),
          Icon(Icons.money_outlined, size: 20,
            color: _useCod ? Colors.orange.shade700 : _slate),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Cash on Delivery', style: TextStyle(
              fontSize: 14, color: _ink,
              fontWeight: _useCod ? FontWeight.w700 : FontWeight.w500,
            )),
            Text('Pay when your order arrives',
              style: TextStyle(fontSize: 11, color: _slate)),
          ])),
          Icon(_useCod ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
            size: 18, color: _useCod ? Colors.orange.shade700 : _slate),
        ]),
      ),
    );
  }

  Widget _buildCodInfo() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.04),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12),
        ),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.info_outline, size: 14, color: Colors.orange),
        const SizedBox(width: 8),
        Expanded(child: Text(
          'Keep exact change ready. Our delivery partner will collect '
          '${_fmt(widget.total)} at the time of delivery.',
          style: const TextStyle(fontSize: 12, color: _slate, height: 1.5),
        )),
      ]),
    );
  }

  // ── Order summary ─────────────────────────────────────────────
  Widget _buildSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Order Summary', style: TextStyle(
          fontSize: 13, color: _slate, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        _summaryRow('Subtotal', _fmt(widget.subtotal)),
        if (widget.discount > 0) ...[
          const SizedBox(height: 8),
          _summaryRow(
            widget.couponCode != null ? 'Discount (${widget.couponCode})' : 'Discount',
            '-${_fmt(widget.discount)}', valueColor: _green,
          ),
        ],
        const SizedBox(height: 8),
        _summaryRow('Shipping',
          widget.shipping == 0 ? 'FREE' : _fmt(widget.shipping),
          valueColor: widget.shipping == 0 ? _green : null),
        Divider(color: _border, height: 20),
        _summaryRow('Total', _fmt(widget.total), bold: true),
      ]),
    );
  }

  Widget _summaryRow(String label, String value, {bool bold = false, Color? valueColor}) =>
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(
        fontSize: bold ? 15 : 13, color: bold ? _ink : _slate,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
      Text(value, style: TextStyle(
        fontSize: bold ? 15 : 13,
        color: valueColor ?? (bold ? _ink : _slate),
        fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
    ]);

  // ── Top bar ───────────────────────────────────────────────────
  Widget _buildTopBar() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
    child: Row(children: [
      GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _surface, borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _border),
          ),
          child: const Icon(Icons.arrow_back, size: 20, color: _ink),
        ),
      ),
      const SizedBox(width: 14),
      const Expanded(child: Text('Checkout',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _ink))),
    ]),
  );

  // ── Step indicator ────────────────────────────────────────────
  Widget _buildStepIndicator() {
    const steps  = ['Delivery\nAddress', 'Payment', 'Confirm'];
    const active = 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            return Expanded(child: Container(
              height: 2, margin: const EdgeInsets.only(bottom: 16),
              color: (i ~/ 2) < active ? _teal : _border,
            ));
          }
          final si   = i ~/ 2;
          final done = si < active;
          final act  = si == active;
          return Column(children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done || act ? _teal : Colors.white,
                border: Border.all(color: done || act ? _teal : _border, width: 2),
              ),
              child: Center(child: done
                ? const Icon(Icons.check, color: Colors.white, size: 14)
                : Text('${si + 1}', style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold,
                    color: act ? Colors.white : _slate))),
            ),
            const SizedBox(height: 4),
            Text(steps[si], textAlign: TextAlign.center, style: TextStyle(
              fontSize: 10, height: 1.2,
              color: done || act ? _teal : _slate,
              fontWeight: act ? FontWeight.w600 : FontWeight.normal)),
          ]);
        }),
      ),
    );
  }

  // ── Bottom pay bar ────────────────────────────────────────────
  Widget _buildPayBar() {
    final Color  bg     = _useCod ? Colors.orange.shade700 : _teal;
    final String label  = _useCod ? 'PLACE ORDER — COD' : 'PAY ${_fmt(widget.total)}';
    final VoidCallback? action = _isPlacing
        ? null
        : (_useCod ? _placeCodOrder : _payOnline);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 16, offset: const Offset(0, -4),
        )],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        GestureDetector(
          onTap: action,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 54,
            decoration: BoxDecoration(
              color: action == null ? Colors.grey.shade300 : bg,
              borderRadius: BorderRadius.circular(14),
              boxShadow: action == null ? [] : [BoxShadow(
                color: bg.withValues(alpha: 0.35),
                blurRadius: 12, offset: const Offset(0, 4),
              )],
            ),
            child: Center(
              child: _isPlacing
                ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    if (!_useCod) ...[
                      const Icon(Icons.lock_outline, size: 16, color: Colors.white),
                      const SizedBox(width: 8),
                    ],
                    Text(label, style: TextStyle(
                      color: action == null ? _slate : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15, letterSpacing: 0.5,
                    )),
                  ]),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.verified_user_outlined, size: 13, color: _slate),
          SizedBox(width: 5),
          Text('Secured by Cashfree · 256-bit SSL',
            style: TextStyle(fontSize: 12, color: _slate)),
        ]),
      ]),
    );
  }
}
