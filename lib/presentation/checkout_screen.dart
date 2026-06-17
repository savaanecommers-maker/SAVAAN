import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../data/api_client.dart';
import '../data/cart_service.dart';
import '../data/coupon_service.dart';
import '../models/cart_item_model.dart';
import 'payment_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final List<CartItemModel> cartItems;
  final double subtotal;
  final double discount;
  final double shipping;
  final double total;
  final String? couponCode;

  const CheckoutScreen({
    super.key,
    required this.cartItems,
    required this.subtotal,
    this.discount = 0,
    required this.shipping,
    required this.total,
    this.couponCode,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  List<Map<String, dynamic>> _addresses = [];
  String? _selectedAddressId;
  bool _isLoadingAddresses = true;

  // Mutable cart items (quantities can be changed during checkout)
  late List<CartItemModel> _cartItems;
  final _cartService = CartService();
  final Map<String, bool> _updatingItem = {}; // cartItemId → loading

  // Coupon state
  final _couponService = CouponService();
  final _couponCtrl    = TextEditingController();
  String? _couponCode;
  double  _couponDiscount = 0;
  bool    _isApplyingCoupon = false;
  String? _couponError;

  // Mutable price fields (updated when coupon applied/removed or quantity changes)
  late double _currentShipping;
  late double _currentTotal;

  double get _subtotal => _cartItems.fold(0.0, (sum, item) => sum + item.unitPrice * item.quantity);

  // New address form
  bool _showAddressForm = false;
  final _nameCtrl    = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  final _streetCtrl  = TextEditingController();
  final _cityCtrl    = TextEditingController();
  final _stateCtrl   = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  final _formKey     = GlobalKey<FormState>();

  static const Color _ink     = Color(0xFF0F172A);
  static const Color _teal    = Color(0xFF0D9488);
  static const Color _green   = Color(0xFF10B981);
  static const Color _slate   = Color(0xFF64748B);
  static const Color _border  = Color(0xFFE2E8F0);
  static const Color _surface = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _cartItems       = List.from(widget.cartItems);
    _couponCode      = widget.couponCode;
    _couponDiscount  = widget.discount;
    _currentShipping = widget.shipping;
    _currentTotal    = widget.total;
    if (_couponCode != null) _couponCtrl.text = _couponCode!;
    _loadAddresses();
  }

  @override
  void dispose() {
    _couponCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _streetCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _pincodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAddresses() async {
    try {
      final payload = await ApiClient.getTokenPayload();
      final uid = payload?['id'] as String?;
      if (uid == null) {
        if (mounted) setState(() => _isLoadingAddresses = false);
        return;
      }
      final res = await ApiClient.get('/api/users/$uid/addresses');
      if (mounted) {
        setState(() {
          if (res.isSuccess && res.data != null) {
            final list = res.data!['_list'] as List? ?? [];
            _addresses = List<Map<String, dynamic>>.from(list);
            if (_addresses.isNotEmpty) {
              final defaultAddr = _addresses.firstWhere(
                (a) => a['is_default'] == true,
                orElse: () => _addresses.first,
              );
              _selectedAddressId = defaultAddr['id']?.toString();
            }
          }
          _isLoadingAddresses = false;
        });
      }
    } catch (e) {
      debugPrint('Load addresses error: $e');
      if (mounted) setState(() => _isLoadingAddresses = false);
    }
  }

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      final res = await ApiClient.post('/api/addresses', {
        'full_name':  _nameCtrl.text.trim(),
        'phone':      _phoneCtrl.text.trim(),
        'line1':      _streetCtrl.text.trim(),
        'city':       _cityCtrl.text.trim(),
        'state':      _stateCtrl.text.trim(),
        'pincode':    _pincodeCtrl.text.trim(),
        'is_default': _addresses.isEmpty,
      });
      if (res.isSuccess && res.data != null) {
        final addr = res.data!['address'] as Map<String, dynamic>? ?? res.data!;
        setState(() {
          _addresses.insert(0, addr);
          _selectedAddressId = addr['id']?.toString();
          _showAddressForm = false;
        });
        _clearAddressForm();
      } else {
        _showSnackBar(res.error ?? 'Failed to save address', Colors.redAccent);
      }
    } catch (e) {
      debugPrint('Save address error: $e');
      _showSnackBar('Failed to save address', Colors.redAccent);
    }
  }

  void _clearAddressForm() {
    _nameCtrl.clear();
    _phoneCtrl.clear();
    _streetCtrl.clear();
    _cityCtrl.clear();
    _stateCtrl.clear();
    _pincodeCtrl.clear();
  }

  Future<void> _applyCoupon() async {
    final code = _couponCtrl.text.trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() { _isApplyingCoupon = true; _couponError = null; });
    try {
      final (discount, error) = await _couponService.applyCoupon(code, _subtotal);
      if (!mounted) return;
      if (error != null) {
        setState(() {
          _couponError = error;
          _isApplyingCoupon = false;
        });
      } else {
        setState(() {
          _couponCode      = code;
          _couponDiscount  = discount;
          _currentTotal    = (_subtotal - discount + _currentShipping).clamp(0, double.infinity);
          _isApplyingCoupon = false;
          _couponError     = null;
        });
        _showSnackBar('Coupon applied! You save ${_fmt(discount)}', _green);
      }
    } catch (_) {
      if (mounted) setState(() { _couponError = 'Failed to apply coupon'; _isApplyingCoupon = false; });
    }
  }

  void _removeCoupon() {
    setState(() {
      _couponCode      = null;
      _couponDiscount  = 0;
      _currentTotal    = _subtotal + _currentShipping;
      _couponError     = null;
    });
    _couponCtrl.clear();
  }

  void _recalcTotal() {
    // If a coupon is applied, re-verify it still meets minimum order threshold
    if (_couponCode != null && _couponDiscount > 0) {
      // Re-apply coupon in background to validate min order with new subtotal
      _revalidateCoupon();
    } else {
      _currentTotal = (_subtotal + _currentShipping).clamp(0, double.infinity);
    }
  }

  Future<void> _revalidateCoupon() async {
    if (_couponCode == null) return;
    final (discount, error) = await _couponService.applyCoupon(_couponCode!, _subtotal);
    if (!mounted) return;
    setState(() {
      if (error != null) {
        // Coupon no longer valid (e.g. subtotal dropped below min order)
        _couponDiscount = 0;
        _couponCode = null;
        _couponCtrl.clear();
        _couponError = error;
      } else {
        _couponDiscount = discount;
        _couponError = null;
      }
      _currentTotal = (_subtotal - _couponDiscount + _currentShipping).clamp(0, double.infinity);
    });
  }

  Future<void> _updateQuantity(CartItemModel item, int newQty) async {
    if (newQty <= 0) {
      _confirmRemove(item);
      return;
    }
    setState(() => _updatingItem[item.id] = true);
    final error = await _cartService.updateQuantity(item.id, newQty);
    if (!mounted) return;
    if (error != null) {
      setState(() => _updatingItem[item.id] = false);
      _showSnackBar(error, Colors.redAccent);
    } else {
      setState(() {
        final idx = _cartItems.indexWhere((c) => c.id == item.id);
        if (idx != -1) _cartItems[idx] = item.copyWith(quantity: newQty);
        _updatingItem[item.id] = false;
        _recalcTotal();
      });
    }
  }

  Future<void> _confirmRemove(CartItemModel item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove item?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text('Remove "${item.displayName}" from your order?',
            style: const TextStyle(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep', style: TextStyle(color: Color(0xFF64748B)))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _updatingItem[item.id] = true);
    final error = await _cartService.removeFromCart(item.id);
    if (!mounted) return;
    setState(() {
      _updatingItem.remove(item.id);
      if (error == null) {
        _cartItems.removeWhere((c) => c.id == item.id);
        _recalcTotal();
      }
    });
    if (error != null) _showSnackBar(error, Colors.redAccent);
  }

  void _continueToPayment() {
    if (_cartItems.isEmpty) {
      _showSnackBar('Your cart is empty', Colors.orange);
      return;
    }
    if (_selectedAddressId == null) {
      _showSnackBar('Please select a delivery address', Colors.orange);
      return;
    }
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => PaymentScreen(
        cartItems:          _cartItems,
        subtotal:           _subtotal,
        discount:           _couponDiscount,
        shipping:           _currentShipping,
        total:              _currentTotal,
        couponCode:         _couponCode,
        selectedAddressId:  _selectedAddressId!,
      ),
    ));
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
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Delivery Address', Icons.location_on_outlined),
                  _buildAddressSection(),
                  _buildSectionTitle('Coupons & Offers', Icons.local_offer_outlined),
                  _buildCouponSection(),
                  _buildBackToCart(),
                  _buildSectionTitle('Order Summary', Icons.receipt_long_outlined),
                  _buildOrderSummary(),
                ],
              ),
            ),
          ),
          _buildContinueBar(),
        ]),
      ),
    );
  }

  Widget _buildStepIndicator() {
    const steps = ['Delivery\nAddress', 'Payment', 'Confirm'];
    const active = 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            return Expanded(child: Container(
              height: 2, color: _border,
              margin: const EdgeInsets.only(bottom: 16),
            ));
          }
          final stepIndex = i ~/ 2;
          final isActive  = stepIndex == active;
          return Column(children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? _teal : Colors.white,
                border: Border.all(
                    color: isActive ? _teal : _border, width: 2),
              ),
              child: Center(
                child: Text('${stepIndex + 1}',
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
                  color: isActive ? _teal : _slate,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                )),
          ]);
        }),
      ),
    );
  }

  Widget _buildTopBar() {
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
        const Expanded(
          child: Text('Checkout',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _ink)),
        ),
      ]),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Row(children: [
        Icon(icon, size: 18, color: _teal),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(fontSize: 15,
                fontWeight: FontWeight.bold, color: _ink)),
      ]),
    );
  }

  // ── ADDRESS ─────────────────────────────────────────────────
  Widget _buildAddressSection() {
    if (_isLoadingAddresses) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(color: _teal)),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Existing addresses
      ..._addresses.map((addr) {
        final id = addr['id']?.toString() ?? '';
        final isSelected = _selectedAddressId == id;
        return GestureDetector(
          onTap: () => setState(() => _selectedAddressId = id),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isSelected
                  ? _teal.withValues(alpha: 0.04)
                  : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? _teal : _border,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 20, height: 20,
                margin: const EdgeInsets.only(top: 1),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: isSelected ? _teal : _slate, width: 1.5),
                  color: isSelected ? _teal : Colors.transparent,
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 13)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(addr['full_name']?.toString() ?? '',
                        style: const TextStyle(fontSize: 13,
                            fontWeight: FontWeight.w600, color: _ink)),
                    if (addr['is_default'] == true) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _teal.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('Default',
                            style: TextStyle(fontSize: 10, color: _teal,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 3),
                  Text(
                    '${addr['line1'] ?? addr['street'] ?? ''}, ${addr['city']}, ${addr['state']} - ${addr['pincode']}',
                    style: TextStyle(fontSize: 12, color: _slate, height: 1.4),
                  ),
                  const SizedBox(height: 2),
                  Text(addr['phone']?.toString() ?? '',
                      style: TextStyle(fontSize: 12, color: _slate)),
                ],
              )),
            ]),
          ),
        );
      }),

      // Add new address toggle
      GestureDetector(
        onTap: () => setState(() => _showAddressForm = !_showAddressForm),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: _showAddressForm ? _teal : _border,
                style: BorderStyle.solid),
          ),
          child: Row(children: [
            Icon(_showAddressForm ? Icons.remove : Icons.add,
                size: 18, color: _teal),
            const SizedBox(width: 8),
            Text(_showAddressForm ? 'Cancel' : 'Add New Address',
                style: TextStyle(fontSize: 13, color: _teal,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      ),

      if (_showAddressForm) _buildAddressForm(),
    ]);
  }

  Widget _buildAddressForm() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Form(
        key: _formKey,
        child: Column(children: [
          _field(_nameCtrl,  'Full Name',   Icons.person_outline),
          const SizedBox(height: 10),
          _field(_phoneCtrl, 'Phone', Icons.phone_outlined,
              type: TextInputType.phone,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                final digits = v.replaceAll(RegExp(r'\D'), '');
                if (digits.length < 10 || digits.length > 11) return 'Enter a valid phone number (10–11 digits)';
                return null;
              }),
          const SizedBox(height: 10),
          _field(_streetCtrl,'Street Address', Icons.home_outlined),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _field(_cityCtrl,  'City',  Icons.location_city_outlined)),
            const SizedBox(width: 10),
            Expanded(child: _field(_stateCtrl, 'State', Icons.map_outlined)),
          ]),
          const SizedBox(height: 10),
          _field(_pincodeCtrl, 'Pincode', Icons.pin_drop_outlined,
              type: TextInputType.number,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                if (!RegExp(r'^\d{6}$').hasMatch(v.trim())) return 'Enter a valid 6-digit pincode';
                return null;
              }),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: _saveAddress,
            child: Container(
              width: double.infinity, height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_teal, _green]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text('SAVE ADDRESS',
                    style: TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13, letterSpacing: 0.8)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {TextInputType? type, String? Function(String?)? validator}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: type,
      validator: validator ?? (v) => v == null || v.trim().isEmpty ? 'Required' : null,
      style: const TextStyle(fontSize: 13, color: _ink),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 12, color: _slate),
        prefixIcon: Icon(icon, size: 18, color: _slate),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: _border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: _border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _teal, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 12),
      ),
    );
  }

  // ── COUPON SECTION ───────────────────────────────────────────
  Widget _buildCouponSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.discount_outlined, size: 16, color: _teal),
          const SizedBox(width: 6),
          const Text('Apply Coupon',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _ink)),
          const Spacer(),
          if (_couponCode == null)
            GestureDetector(
              onTap: () => _showCouponsSheet(),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('View Offers', style: TextStyle(fontSize: 12,
                    color: _teal, fontWeight: FontWeight.w600)),
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
                    color: _couponError != null ? Colors.redAccent : _border),
              ),
              child: Row(children: [
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _couponCtrl,
                    enabled: _couponCode == null,
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
                if (_couponCode != null)
                  GestureDetector(
                    onTap: _removeCoupon,
                    child: Padding(padding: const EdgeInsets.all(8),
                        child: Icon(Icons.close, size: 16, color: _slate)),
                  ),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _couponCode != null
                ? _removeCoupon
                : _isApplyingCoupon ? null : _applyCoupon,
            child: Container(
              height: 40, width: 72,
              decoration: BoxDecoration(
                color: _couponCode != null
                    ? Colors.redAccent.withValues(alpha: 0.1)
                    : _teal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: _couponCode != null ? Colors.redAccent : _teal,
                    width: 1.2),
              ),
              child: Center(
                child: _isApplyingCoupon
                    ? SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(color: _teal, strokeWidth: 2))
                    : Text(_couponCode != null ? 'Remove' : 'Apply',
                        style: TextStyle(
                          fontSize: 12,
                          color: _couponCode != null ? Colors.redAccent : _teal,
                          fontWeight: FontWeight.w600,
                        )),
              ),
            ),
          ),
        ]),
        if (_couponError != null) ...[
          const SizedBox(height: 6),
          Row(children: [
            Icon(Icons.error_outline, size: 13, color: Colors.redAccent),
            const SizedBox(width: 4),
            Text(_couponError!,
                style: const TextStyle(fontSize: 11, color: Colors.redAccent)),
          ]),
        ],
        if (_couponCode != null) ...[
          const SizedBox(height: 6),
          Row(children: [
            Icon(Icons.check_circle_outline, size: 13, color: _green),
            const SizedBox(width: 5),
            Text('${_couponCode!} applied! You save ${_fmt(_couponDiscount)}',
                style: TextStyle(fontSize: 11, color: _green,
                    fontWeight: FontWeight.w500)),
          ]),
        ],
      ]),
    );
  }

  void _showCouponsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _CheckoutCouponsSheet(
        onApply: (code) {
          _couponCtrl.text = code;
          _applyCoupon();
        },
      ),
    );
  }

  // ── BACK TO CART ─────────────────────────────────────────────
  Widget _buildBackToCart() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.arrow_back_ios_new_rounded, size: 12, color: _teal),
          const SizedBox(width: 4),
          Text('Back to Cart',
              style: TextStyle(fontSize: 12, color: _teal,
                  fontWeight: FontWeight.w600, decoration: TextDecoration.underline,
                  decorationColor: _teal)),
        ]),
      ),
    );
  }

  // ── ORDER SUMMARY ────────────────────────────────────────────
  Widget _buildOrderSummary() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Item cards
      ..._cartItems.map((item) => _buildItemCard(item)),
      if (_cartItems.isEmpty)
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: _surface, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: Center(child: Text('Your cart is empty',
              style: TextStyle(fontSize: 13, color: _slate))),
        ),
      // Price breakdown card
      Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        child: Column(children: [
          _row('Subtotal (${_cartItems.length} item${_cartItems.length == 1 ? '' : 's'})',
              _fmt(_subtotal)),
          if (_couponDiscount > 0) ...[
            const SizedBox(height: 8),
            _row('Discount (${_couponCode ?? ''})', '- ${_fmt(_couponDiscount)}',
                valueColor: _green),
          ],
          const SizedBox(height: 8),
          _row('Shipping', _currentShipping == 0 ? 'FREE' : _fmt(_currentShipping),
              valueColor: _currentShipping == 0 ? _green : null),
          Divider(color: _border, height: 20),
          _row('Total Payable', _fmt(_currentTotal), bold: true),
        ]),
      ),
    ]);
  }

  Widget _buildItemCard(CartItemModel item) {
    final isUpdating = _updatingItem[item.id] == true;
    // Variant label e.g. "Red · L"
    final variant = item.variant;
    final variantParts = <String>[
      if (variant?.color != null && variant!.color!.isNotEmpty) variant.color!,
      if (variant?.size != null && variant!.size!.isNotEmpty) variant.size!,
    ];
    final variantLabel = variantParts.join(' · ');

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 6, offset: const Offset(0, 2),
        )],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Product image
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: item.displayImage != null
              ? CachedNetworkImage(
                  imageUrl: item.displayImage!,
                  width: 72, height: 80, fit: BoxFit.contain,
                  memCacheWidth: 144,
                  placeholder: (_, _) => Container(width: 72, height: 80,
                      color: _border, child: Icon(Icons.image_outlined,
                          color: _slate.withValues(alpha: 0.4), size: 24)),
                  errorWidget: (_, _, _) => Container(width: 72, height: 80,
                      color: _border, child: Icon(Icons.image_outlined,
                          color: _slate.withValues(alpha: 0.4), size: 24)))
              : Container(width: 72, height: 80, color: _border,
                  child: Icon(Icons.image_outlined,
                      color: _slate.withValues(alpha: 0.4), size: 24)),
        ),
        const SizedBox(width: 12),
        // Details
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Name
            Text(item.displayName,
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w600, color: _ink, height: 1.3)),
            // Variant
            if (variantLabel.isNotEmpty) ...[
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _teal.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(variantLabel,
                    style: TextStyle(fontSize: 10, color: _teal,
                        fontWeight: FontWeight.w500)),
              ),
            ],
            const SizedBox(height: 8),
            // Unit price
            Text(_fmt(item.unitPrice),
                style: TextStyle(fontSize: 11, color: _slate)),
            const SizedBox(height: 10),
            // Bottom row: qty controls + item total + remove
            Row(children: [
              // Quantity selector
              if (isUpdating)
                SizedBox(width: 76, height: 28, child: Center(
                    child: SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(color: _teal, strokeWidth: 2))))
              else
                Container(
                  height: 28,
                  decoration: BoxDecoration(
                    border: Border.all(color: _border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    _qtyBtn(
                      icon: item.quantity == 1 ? Icons.delete_outline_rounded : Icons.remove_rounded,
                      color: item.quantity == 1 ? Colors.redAccent : _slate,
                      onTap: () => _updateQuantity(item, item.quantity - 1),
                      size: 28,
                    ),
                    Container(
                      width: 30,
                      alignment: Alignment.center,
                      child: Text('${item.quantity}',
                          style: const TextStyle(fontSize: 13,
                              fontWeight: FontWeight.bold, color: _ink)),
                    ),
                    _qtyBtn(
                      icon: Icons.add_rounded,
                      color: _teal,
                      onTap: () => _updateQuantity(item, item.quantity + 1),
                      size: 28,
                    ),
                  ]),
                ),
              const SizedBox(width: 10),
              // Item total
              Text(_fmt(item.unitPrice * item.quantity),
                  style: const TextStyle(fontSize: 13,
                      fontWeight: FontWeight.bold, color: _ink)),
              const Spacer(),
              // Remove button
              if (!isUpdating)
                GestureDetector(
                  onTap: () => _confirmRemove(item),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.25)),
                    ),
                    child: const Text('Remove',
                        style: TextStyle(fontSize: 10, color: Colors.redAccent,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _qtyBtn({required IconData icon, required Color color,
      required VoidCallback onTap, double size = 26}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.only(
            topLeft: icon == Icons.add_rounded
                ? Radius.zero : const Radius.circular(7),
            bottomLeft: icon == Icons.add_rounded
                ? Radius.zero : const Radius.circular(7),
            topRight: icon == Icons.add_rounded
                ? const Radius.circular(7) : Radius.zero,
            bottomRight: icon == Icons.add_rounded
                ? const Radius.circular(7) : Radius.zero,
          ),
        ),
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }

  Widget _row(String l, String v, {bool bold = false, Color? valueColor}) =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(l, style: TextStyle(
            fontSize: bold ? 14 : 12,
            color: bold ? _ink : _slate,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        Text(v, style: TextStyle(
            fontSize: bold ? 14 : 12,
            color: valueColor ?? (bold ? _ink : _slate),
            fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
      ]);

  Widget _buildContinueBar() {
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
        onTap: _continueToPayment,
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
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('CONTINUE TO PAYMENT',
                style: TextStyle(color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14, letterSpacing: 0.8)),
            const SizedBox(width: 10),
            Text(_fmt(_currentTotal),
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w600, fontSize: 14)),
          ]),
        ),
      ),
    );
  }
}

// ── Checkout Coupons Sheet ────────────────────────────────────────────────────
class _CheckoutCouponsSheet extends StatefulWidget {
  final void Function(String code) onApply;
  const _CheckoutCouponsSheet({required this.onApply});

  @override
  State<_CheckoutCouponsSheet> createState() => _CheckoutCouponsSheetState();
}

class _CheckoutCouponsSheetState extends State<_CheckoutCouponsSheet> {
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 36, height: 4,
            decoration: BoxDecoration(color: _border,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        Row(children: [
          const Expanded(
            child: Text('Available Coupons',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _ink)),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: _surface, shape: BoxShape.circle,
                  border: Border.all(color: _border)),
              child: const Icon(Icons.close, size: 16, color: _ink),
            ),
          ),
        ]),
        const SizedBox(height: 4),
        Text('Tap a coupon to apply it',
            style: TextStyle(fontSize: 12, color: _slate)),
        const SizedBox(height: 16),
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
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _buildCard(_coupons[i]),
          ),
      ]),
    );
  }

  Widget _buildCard(Map<String, dynamic> c) {
    final code     = c['code']?.toString() ?? '';
    final type     = c['discount_type']?.toString() ?? 'flat';
    final value    = double.tryParse(c['discount_value']?.toString() ?? '0') ?? 0;
    final minOrder = double.tryParse(c['min_order_value']?.toString() ?? '0') ?? 0;
    final maxDisc  = double.tryParse(c['max_discount']?.toString() ?? '0') ?? 0;
    final desc     = c['description']?.toString() ?? '';
    final label    = type == 'percent' ? '${value.toInt()}% OFF' : '${_fmt(value)} OFF';

    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        widget.onApply(code);
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_teal, _green],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(10)),
            child: Text(label,
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w800, fontSize: 13)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(code, style: const TextStyle(fontSize: 15,
                fontWeight: FontWeight.bold, color: _ink, letterSpacing: 0.5)),
            const SizedBox(height: 3),
            if (desc.isNotEmpty)
              Text(desc, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: _slate)),
            Row(children: [
              if (minOrder > 0) ...[
                Icon(Icons.info_outline_rounded, size: 10,
                    color: _slate.withValues(alpha: 0.6)),
                const SizedBox(width: 3),
                Text('Min. ₹${minOrder.toInt()}',
                    style: TextStyle(fontSize: 10, color: _slate.withValues(alpha: 0.7))),
              ],
              if (minOrder > 0 && maxDisc > 0)
                Text('  ·  ', style: TextStyle(fontSize: 10,
                    color: _slate.withValues(alpha: 0.5))),
              if (maxDisc > 0)
                Text('Max. ${_fmt(maxDisc)} off',
                    style: TextStyle(fontSize: 10, color: _slate.withValues(alpha: 0.7))),
            ]),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _teal.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _teal.withValues(alpha: 0.3))),
            child: const Text('APPLY',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _teal)),
          ),
        ]),
      ),
    );
  }
}
