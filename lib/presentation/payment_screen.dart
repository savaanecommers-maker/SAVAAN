import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../data/api_client.dart';
import 'cashfree_webview_screen.dart';
import '../models/cart_item_model.dart';
import '../models/order_model.dart';
import '../providers/cart_provider.dart';
import '../providers/order_provider.dart';
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
  PaymentMethod _selected   = PaymentMethod.cashfree;
  bool          _isPlacing  = false;

  // ── Cashfree state ────────────────────────────────────────────
  final _phoneCtrl    = TextEditingController();

  // ── Merchant UPI config — loaded from backend at init ─────────
  String? _merchantUpi;
  String? _merchantName;
  bool    _merchantLoading = true;
  String? _merchantError;

  static const Color _ink     = Color(0xFF0F172A);
  static const Color _teal    = Color(0xFF0D9488);
  static const Color _green   = Color(0xFF10B981);
  static const Color _slate   = Color(0xFF64748B);
  static const Color _border  = Color(0xFFE2E8F0);
  static const Color _surface = Color(0xFFF8FAFC);
  static const Color _upiGreen = Color(0xFF097939);

  @override
  void initState() {
    super.initState();
    _fetchMerchantConfig();
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  /// Fetches UPI VPA and merchant name from the backend contact/settings API.
  /// Falls back to an error state if the call fails — never uses hardcoded values.
  Future<void> _fetchMerchantConfig() async {
    try {
      final res = await ApiClient.get('/api/content/contact', auth: false);
      if (!mounted) return;
      if (res.isSuccess && res.data != null) {
        final d = res.data!;
        final upi  = d['upi_vpa']?.toString()       ??
                     d['upi']?.toString()            ??
                     d['payment_upi']?.toString();
        final name = d['merchant_name']?.toString()  ??
                     d['business_name']?.toString()  ??
                     d['name']?.toString();
        if (upi != null && upi.isNotEmpty) {
          setState(() {
            _merchantUpi  = upi;
            _merchantName = name ?? 'Savaan';
            _merchantLoading = false;
          });
          return;
        }
      }
      // Second try: admin settings endpoint
      final settingsRes = await ApiClient.get('/api/admin/settings');
      if (!mounted) return;
      if (settingsRes.isSuccess && settingsRes.data != null) {
        final d = settingsRes.data!;
        final upi  = d['upi_vpa']?.toString()      ??
                     d['payment_upi']?.toString();
        final name = d['merchant_name']?.toString() ??
                     d['business_name']?.toString();
        if (upi != null && upi.isNotEmpty) {
          setState(() {
            _merchantUpi  = upi;
            _merchantName = name ?? 'Savaan';
            _merchantLoading = false;
          });
          return;
        }
      }
      // Both endpoints failed or returned no UPI
      if (mounted) {
        setState(() {
          _merchantError   = 'UPI payment details unavailable. Please use Cash on Delivery.';
          _merchantLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _merchantError   = 'Failed to load payment details. Please try again.';
          _merchantLoading = false;
        });
      }
    }
  }

  // ── COD: place immediately ────────────────────────────────────
  Future<void> _placeCodOrder() async {
    final cartProvider = context.read<CartProvider>();
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
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => OrderSuccessScreen(
            orderNumber: order.orderNumber,
            orderDate:   order.formattedDate,
            total:       widget.total,
          )),
          (route) => route.isFirst,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to place order. Please try again.', Colors.redAccent);
      }
    } finally {
      if (mounted) setState(() => _isPlacing = false);
    }
  }

  // ── Cashfree: create order on backend, launch SDK ────────────
  Future<void> _launchCashfree() async {
    final phone = _phoneCtrl.text.trim().replaceAll(RegExp(r'\D'), '');
    if (phone.length < 10) {
      _showSnackBar('Enter a valid 10-digit mobile number', Colors.orange);
      return;
    }
    setState(() => _isPlacing = true);
    try {
      final res = await ApiClient.post('/api/payments/cashfree/create-order', {
        'items':          widget.cartItems.map((i) => {
          'product_id': i.productId,
          'variant_id': i.variantId,
          'quantity':   i.quantity,
        }).toList(),
        'address_id':     widget.selectedAddressId,
        'coupon_code':    widget.couponCode,
        'shipping':       widget.shipping,
        'subtotal':       widget.subtotal,
        'discount':       widget.discount,
        'total':          widget.total,
        'customer_phone': phone,
      });

      if (!res.isSuccess || res.data == null) {
        throw Exception(res.error ?? 'Failed to initiate payment');
      }

      final sessionId   = res.data!['payment_session_id'] as String;
      final orderNumber = res.data!['order_number'] as String;

      setState(() => _isPlacing = false);
      if (!mounted) return;

      // Open Cashfree JS checkout in a WebView
      final result = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => CashfreeWebViewScreen(
          paymentSessionId: sessionId,
          orderNumber:      orderNumber,
          total:            widget.total,
        )),
      );

      if (!mounted) return;
      if (result == 'success') {
        context.read<CartProvider>().clear();
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => OrderSuccessScreen(
            orderNumber: orderNumber,
            orderDate:   DateTime.now().toString(),
            total:       widget.total,
          )),
          (route) => route.isFirst,
        );
      } else if (result == 'failed') {
        _showSnackBar('Payment failed. Please try again.', Colors.redAccent);
      }
      // 'cancelled' — user closed, do nothing
    } catch (e) {
      if (mounted) {
        setState(() => _isPlacing = false);
        _showSnackBar(e.toString().replaceFirst('Exception: ', ''), Colors.redAccent);
      }
    }
  }

  // ── UPI: show UTR dialog, then place ─────────────────────────
  Future<void> _confirmUpiPayment() async {
    final cartProvider  = context.read<CartProvider>();
    final orderProvider = context.read<OrderProvider>();
    final utr = await _showUtrDialog();
    if (utr == null) return; // user cancelled
    setState(() => _isPlacing = true);
    try {
      final (order, error) = await orderProvider.placeOrder(
        cartItems:        widget.cartItems,
        addressId:        widget.selectedAddressId,
        paymentMethod:    PaymentMethod.upi,
        subtotal:         widget.subtotal,
        discount:         widget.discount,
        shipping:         widget.shipping,
        total:            widget.total,
        couponCode:       widget.couponCode,
        paymentReference: utr,
      );
      if (error != null) throw Exception(error);
      cartProvider.clear();
      if (mounted && order != null) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => OrderSuccessScreen(
            orderNumber:        order.orderNumber,
            orderDate:          order.formattedDate,
            total:              widget.total,
            awaitingVerification: true,
          )),
          (route) => route.isFirst,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to place order. Please try again.', Colors.redAccent);
      }
    } finally {
      if (mounted) setState(() => _isPlacing = false);
    }
  }

  // ── UTR input dialog ──────────────────────────────────────────
  Future<String?> _showUtrDialog() async {
    final ctrl   = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Form(
            key: formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: _border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Icon + title
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _upiGreen.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.receipt_long_outlined,
                    size: 28, color: _upiGreen),
              ),
              const SizedBox(height: 14),
              const Text('Enter UPI Transaction ID',
                  style: TextStyle(fontSize: 17,
                      fontWeight: FontWeight.bold, color: _ink)),
              const SizedBox(height: 6),
              Text(
                'Open your UPI app → Recent transactions\n'
                '→ Copy the 12-digit Transaction / UTR ID',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: _slate, height: 1.5),
              ),
              const SizedBox(height: 20),

              // UTR field
              TextFormField(
                controller: ctrl,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600,
                    color: _ink, letterSpacing: 1.5),
                decoration: InputDecoration(
                  hintText: 'e.g. 123456789012',
                  hintStyle: TextStyle(color: _slate,
                      fontWeight: FontWeight.normal, letterSpacing: 0),
                  prefixIcon: Icon(Icons.tag, color: _upiGreen),
                  filled: true,
                  fillColor: _surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _upiGreen, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Please enter the transaction ID from your UPI app';
                  }
                  if (v.trim().length < 10) {
                    return 'Transaction ID must be at least 10 characters';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 8),

              // Where to find it hint
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.lightbulb_outline,
                      size: 14, color: Colors.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'GPay: Tap the transaction → "Transaction ID"\n'
                      'PhonePe: History → transaction → "UPI Ref No"\n'
                      'Paytm: Passbook → transaction details',
                      style: TextStyle(
                          fontSize: 11, color: _slate, height: 1.5),
                    ),
                  ),
                ]),
              ),

              const SizedBox(height: 20),

              // Confirm button
              StatefulBuilder(builder: (ctx2, setSt) => GestureDetector(
                onTap: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(ctx, ctrl.text.trim().toUpperCase());
                  }
                },
                child: Container(
                  width: double.infinity, height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_teal, _green]),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(
                      color: _teal.withValues(alpha: 0.3),
                      blurRadius: 12, offset: const Offset(0, 4),
                    )],
                  ),
                  child: const Center(
                    child: Text('Confirm Order',
                        style: TextStyle(color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15, letterSpacing: 0.5)),
                  ),
                ),
              )),

              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => Navigator.pop(ctx, null),
                child: Center(
                  child: Text('Cancel',
                      style: TextStyle(fontSize: 13, color: _slate)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ── UPI deep link ─────────────────────────────────────────────
  // Opens the user's preferred UPI app (GPay, PhonePe, BHIM, Paytm, etc.)
  Future<void> _launchUpi() async {
    if (_merchantUpi == null) {
      _showSnackBar('Payment details not available. Please try again.', Colors.orange);
      return;
    }
    final amount = widget.total.toStringAsFixed(2);
    final note   = Uri.encodeComponent('Savaan order payment');
    final upiUri = Uri.parse(
      'upi://pay?pa=$_merchantUpi&pn=${Uri.encodeComponent(_merchantName ?? 'Savaan')}'
      '&am=$amount&cu=INR&tn=$note',
    );
    if (await canLaunchUrl(upiUri)) {
      await launchUrl(upiUri, mode: LaunchMode.externalApplication);
    } else {
      _showSnackBar(
        'No UPI app found. Please install GPay, PhonePe or BHIM.',
        Colors.orange,
      );
    }
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

  // ── Build ─────────────────────────────────────────────────────
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
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Payment Method',
                    style: TextStyle(fontSize: 15,
                        fontWeight: FontWeight.bold, color: _ink)),
                const SizedBox(height: 14),

                // ── Cashfree option ────────────────────────────
                _buildMethod(
                  value:    PaymentMethod.cashfree,
                  title:    'Pay Online',
                  subtitle: 'Cards · UPI · Net Banking · Wallets',
                  badge:    _cashfreeBadge(),
                ),

                if (_selected == PaymentMethod.cashfree) _buildCashfreePanel(),

                const SizedBox(height: 4),

                // ── UPI option ─────────────────────────────────
                _buildMethod(
                  value:    PaymentMethod.upi,
                  title:    'Pay via UPI (Manual)',
                  subtitle: 'GPay · PhonePe · BHIM · Paytm & more',
                  badge:    _upiBadge(),
                ),

                // UPI detail panel — shown when UPI is selected
                if (_selected == PaymentMethod.upi) _buildUpiPanel(),

                const SizedBox(height: 4),

                // ── COD option ─────────────────────────────────
                _buildMethod(
                  value:    PaymentMethod.cod,
                  title:    'Cash on Delivery',
                  subtitle: 'Pay cash when your order arrives',
                  badge:    Icon(Icons.money_outlined, size: 22, color: _slate),
                ),

                if (_selected == PaymentMethod.cod) _buildCodNote(),

                const SizedBox(height: 24),

                // ── Order total summary ────────────────────────
                _buildSummary(),
              ]),
            ),
          ),

          _buildPayBar(),
        ]),
      ),
    );
  }

  // ── Payment method tile ───────────────────────────────────────
  Widget _buildMethod({
    required PaymentMethod value,
    required String title,
    required String subtitle,
    required Widget badge,
  }) {
    final isSelected = _selected == value;
    return GestureDetector(
      onTap: () => setState(() => _selected = value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: isSelected ? _teal.withValues(alpha: 0.04) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isSelected ? _teal : _border,
              width: isSelected ? 1.5 : 1),
        ),
        child: Row(children: [
          // Radio dot
          Container(
            width: 20, height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: isSelected ? _teal : _slate, width: 1.5),
              color: isSelected ? _teal : Colors.transparent,
            ),
            child: isSelected
                ? Container(
                    margin: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle))
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(
                  fontSize: 13, color: _ink,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontSize: 11, color: _slate)),
            ],
          )),
          badge,
        ]),
      ),
    );
  }

  // ── UPI detail panel ──────────────────────────────────────────
  Widget _buildUpiPanel() {
    // Show loading spinner while fetching merchant config
    if (_merchantLoading) {
      return Container(
        margin: const EdgeInsets.fromLTRB(0, 0, 0, 10),
        padding: const EdgeInsets.symmetric(vertical: 32),
        decoration: BoxDecoration(
          color: _upiGreen.withValues(alpha: 0.03),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(12),
            bottomRight: Radius.circular(12),
          ),
          border: Border.all(color: _upiGreen.withValues(alpha: 0.2)),
        ),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    // Show error if merchant config could not be loaded
    if (_merchantError != null) {
      return Container(
        margin: const EdgeInsets.fromLTRB(0, 0, 0, 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.05),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(12),
            bottomRight: Radius.circular(12),
          ),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.25)),
        ),
        child: Column(children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.warning_amber_rounded,
                size: 16, color: Colors.orange),
            const SizedBox(width: 8),
            Expanded(
              child: Text(_merchantError!,
                  style: TextStyle(fontSize: 12, color: _slate, height: 1.5)),
            ),
          ]),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              setState(() { _merchantLoading = true; _merchantError = null; });
              _fetchMerchantConfig();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: _teal),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Retry', style: TextStyle(color: _teal,
                  fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ),
        ]),
      );
    }

    // QR encodes the exact amount so the user just scans & pays
    final upiQrData =
        'upi://pay?pa=$_merchantUpi&pn=${Uri.encodeComponent(_merchantName ?? 'Savaan')}'
        '&am=${widget.total.toStringAsFixed(2)}&cu=INR'
        '&tn=${Uri.encodeComponent('Savaan order payment')}';

    return Container(
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _upiGreen.withValues(alpha: 0.03),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        border: Border.all(color: _upiGreen.withValues(alpha: 0.2)),
      ),
      child: Column(children: [

        // ── QR code card ──────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
            boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12, offset: const Offset(0, 3),
            )],
          ),
          child: Column(children: [
            // Merchant name + verified badge
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(_merchantName ?? 'Savaan',
                  style: const TextStyle(fontSize: 16,
                      fontWeight: FontWeight.w700, color: _ink)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                    color: Color(0xFF1DA1F2), shape: BoxShape.circle),
                child: const Icon(Icons.check, size: 10, color: Colors.white),
              ),
            ]),
            const SizedBox(height: 12),

            // QR code
            QrImageView(
              data: upiQrData,
              version: QrVersions.auto,
              size: 200,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: _ink,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: _ink,
              ),
            ),

            const SizedBox(height: 12),

            // UPI ID row with copy
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _border),
              ),
              child: Row(children: [
                Container(
                  width: 20, height: 20,
                  decoration: const BoxDecoration(
                    color: Color(0xFF00B9F1), shape: BoxShape.circle),
                  child: const Icon(Icons.flash_on,
                      size: 12, color: Colors.white),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_merchantUpi ?? '',
                      style: const TextStyle(fontSize: 13,
                          fontWeight: FontWeight.w600, color: _ink,
                          letterSpacing: 0.3)),
                ),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: _merchantUpi ?? ''));
                    _showSnackBar('UPI ID copied!', _teal);
                  },
                  child: Icon(Icons.copy, size: 16, color: _teal),
                ),
              ]),
            ),

            const SizedBox(height: 10),
            Text('Scan with any UPI app  ·  Paytm · GPay · PhonePe · BHIM',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: _slate)),
          ]),
        ),

        const SizedBox(height: 14),

        // ── OR: open UPI app directly ─────────────────────────
        Row(children: [
          Expanded(child: Divider(color: _border)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('OR', style: TextStyle(fontSize: 11, color: _slate)),
          ),
          Expanded(child: Divider(color: _border)),
        ]),

        const SizedBox(height: 14),

        GestureDetector(
          onTap: _launchUpi,
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              color: _upiGreen,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.open_in_new, size: 16, color: Colors.white),
                const SizedBox(width: 8),
                Text('Open UPI App — Pay ${_fmt(widget.total)}',
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold, fontSize: 13)),
              ]),
            ),
          ),
        ),

        const SizedBox(height: 10),

        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.info_outline, size: 13, color: _slate),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Scan the QR above or tap "Open UPI App". '
              'After payment, come back and tap "I\'ve Paid" to confirm your order.',
              style: TextStyle(fontSize: 11, color: _slate, height: 1.5),
            ),
          ),
        ]),

        // ── I've Paid button (always visible — user may have scanned QR) ──
        const SizedBox(height: 14),
        GestureDetector(
          onTap: _isPlacing ? null : _confirmUpiPayment,
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_teal, _green]),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(
                color: _teal.withValues(alpha: 0.3),
                blurRadius: 10, offset: const Offset(0, 3),
              )],
            ),
            child: Center(
              child: _isPlacing
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text("✓  I've Paid — Confirm Order",
                      style: TextStyle(color: Colors.white,
                          fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text('Tap only after your UPI payment is successful',
              style: TextStyle(fontSize: 10, color: _slate)),
        ),
      ]),
    );
  }

  // ── COD note ──────────────────────────────────────────────────
  Widget _buildCodNote() {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.05),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.25)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.info_outline, size: 14, color: Colors.orange),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Keep exact change ready. Our delivery partner will collect '
            '${_fmt(widget.total)} at the time of delivery.',
            style: TextStyle(fontSize: 12, color: _slate, height: 1.5),
          ),
        ),
      ]),
    );
  }

  // ── Summary ───────────────────────────────────────────────────
  Widget _buildSummary() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(children: [
        _summaryRow('Subtotal', _fmt(widget.subtotal)),
        if (widget.discount > 0) ...[
          const SizedBox(height: 6),
          _summaryRow(
            widget.couponCode != null
                ? 'Discount (${widget.couponCode})'
                : 'Discount',
            '-${_fmt(widget.discount)}',
            valueColor: _green,
          ),
        ],
        const SizedBox(height: 6),
        _summaryRow(
          'Shipping',
          widget.shipping == 0 ? 'FREE' : _fmt(widget.shipping),
          valueColor: widget.shipping == 0 ? _green : null,
        ),
        Divider(color: _border, height: 16),
        _summaryRow('Total', _fmt(widget.total), bold: true),
      ]),
    );
  }

  Widget _summaryRow(String label, String value,
      {bool bold = false, Color? valueColor}) =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(
            fontSize: bold ? 14 : 13,
            color: bold ? _ink : _slate,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        Text(value, style: TextStyle(
            fontSize: bold ? 14 : 13,
            color: valueColor ?? (bold ? _ink : _slate),
            fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
      ]);

  // ── Top bar ───────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
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
        const Expanded(
          child: Text('Checkout',
              style: TextStyle(fontSize: 20,
                  fontWeight: FontWeight.bold, color: _ink)),
        ),
      ]),
    );
  }

  // ── Step indicator ────────────────────────────────────────────
  Widget _buildStepIndicator() {
    const steps = ['Delivery\nAddress', 'Payment', 'Confirm'];
    const active = 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            final leftDone = (i ~/ 2) < active;
            return Expanded(child: Container(
              height: 2,
              color: leftDone ? _teal : _border,
              margin: const EdgeInsets.only(bottom: 16),
            ));
          }
          final stepIndex = i ~/ 2;
          final isDone    = stepIndex < active;
          final isActive  = stepIndex == active;
          return Column(children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDone || isActive ? _teal : Colors.white,
                border: Border.all(
                    color: isDone || isActive ? _teal : _border, width: 2),
              ),
              child: Center(
                child: isDone
                    ? const Icon(Icons.check, color: Colors.white, size: 14)
                    : Text('${stepIndex + 1}',
                        style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold,
                          color: isActive ? Colors.white : _slate,
                        )),
              ),
            ),
            const SizedBox(height: 4),
            Text(steps[stepIndex],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10, height: 1.2,
                  color: isDone || isActive ? _teal : _slate,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                )),
          ]);
        }),
      ),
    );
  }

  // ── Cashfree badge ────────────────────────────────────────────
  Widget _cashfreeBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFF1A1A2E).withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(6),
    ),
    child: const Text('SECURE', style: TextStyle(
        fontSize: 10, color: Color(0xFF1A1A2E),
        fontWeight: FontWeight.w800, letterSpacing: 1)),
  );

  // ── Cashfree panel — phone number input ───────────────────────
  Widget _buildCashfreePanel() {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E).withValues(alpha: 0.03),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        border: Border.all(color: const Color(0xFF1A1A2E).withValues(alpha: 0.12)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Payment icons row
        Row(children: [
          const Icon(Icons.credit_card_outlined, size: 18, color: Color(0xFF1A1A2E)),
          const SizedBox(width: 6),
          Text('Cards · UPI · Net Banking · Wallets',
              style: TextStyle(fontSize: 12, color: _slate, fontWeight: FontWeight.w500)),
        ]),
        const SizedBox(height: 14),
        // Phone field (required by Cashfree)
        TextField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            labelText: 'Mobile Number',
            hintText: '10-digit number',
            counterText: '',
            prefixIcon: const Icon(Icons.phone_outlined, size: 18),
            prefixText: '+91  ',
            filled: true,
            fillColor: _surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: _border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: _border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF1A1A2E), width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Icon(Icons.lock_outline, size: 13, color: _slate),
          const SizedBox(width: 6),
          Text('Your payment is secured by Cashfree',
              style: TextStyle(fontSize: 11, color: _slate)),
        ]),
      ]),
    );
  }

  // ── UPI badge ─────────────────────────────────────────────────
  Widget _upiBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: _upiGreen.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(6),
    ),
    child: const Text('UPI', style: TextStyle(
        fontSize: 11, color: _upiGreen,
        fontWeight: FontWeight.w800, letterSpacing: 1)),
  );

  // ── Bottom pay bar ────────────────────────────────────────────
  Widget _buildPayBar() {
    // Cashfree: pay button launches the SDK
    if (_selected == PaymentMethod.cashfree) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16, offset: const Offset(0, -4),
          )],
        ),
        child: Column(children: [
          GestureDetector(
            onTap: _isPlacing ? null : _launchCashfree,
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF1A1A2E), Color(0xFF16213E)]),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 12, offset: const Offset(0, 4),
                )],
              ),
              child: Center(
                child: _isPlacing
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.lock_outline, size: 16, color: Colors.white),
                        const SizedBox(width: 8),
                        Text('PAY ${_fmt(widget.total)} SECURELY',
                            style: const TextStyle(color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15, letterSpacing: 0.5)),
                      ]),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.verified_user_outlined, size: 13, color: _slate),
            const SizedBox(width: 5),
            Text('Secured by Cashfree · 256-bit SSL',
                style: TextStyle(fontSize: 12, color: _slate)),
          ]),
        ]),
      );
    }

    // For UPI: the "I've Paid" button is inside the UPI panel.
    if (_selected == PaymentMethod.upi) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16, offset: const Offset(0, -4),
          )],
        ),
        child: Column(children: [
          GestureDetector(
            onTap: _launchUpi,
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: _upiGreen,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(
                  color: _upiGreen.withValues(alpha: 0.35),
                  blurRadius: 12, offset: const Offset(0, 4),
                )],
              ),
              child: Center(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.open_in_new, size: 16, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('Pay ${_fmt(widget.total)} via UPI',
                      style: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15, letterSpacing: 0.5)),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.lock_outline, size: 13, color: _slate),
            const SizedBox(width: 5),
            Text('Instant transfer · No gateway fees',
                style: TextStyle(fontSize: 12, color: _slate)),
          ]),
        ]),
      );
    }

    // COD
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 16, offset: const Offset(0, -4),
        )],
      ),
      child: Column(children: [
        GestureDetector(
          onTap: _isPlacing ? null : _placeCodOrder,
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
            child: Center(
              child: _isPlacing
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text('PLACE ORDER — ${_fmt(widget.total)} COD',
                      style: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15, letterSpacing: 0.5)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.money_outlined, size: 13, color: _slate),
          const SizedBox(width: 5),
          Text('Pay cash on delivery',
              style: TextStyle(fontSize: 12, color: _slate)),
        ]),
      ]),
    );
  }
}
