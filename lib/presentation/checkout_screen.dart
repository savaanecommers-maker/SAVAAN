import 'package:flutter/material.dart';
import '../data/api_client.dart';
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
    _loadAddresses();
  }

  @override
  void dispose() {
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
              _selectedAddressId = _addresses.first['id']?.toString();
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

  void _continueToPayment() {
    if (_selectedAddressId == null) {
      _showSnackBar('Please select a delivery address', Colors.orange);
      return;
    }
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => PaymentScreen(
        cartItems:          widget.cartItems,
        subtotal:           widget.subtotal,
        discount:           widget.discount,
        shipping:           widget.shipping,
        total:              widget.total,
        couponCode:         widget.couponCode,
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
          _field(_phoneCtrl, 'Phone',       Icons.phone_outlined,
              type: TextInputType.phone),
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
              type: TextInputType.number),
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
      {TextInputType? type}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: type,
      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
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

  // ── ORDER SUMMARY ────────────────────────────────────────────
  Widget _buildOrderSummary() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(children: [
        ...widget.cartItems.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: item.displayImage != null
                  ? Image.network(item.displayImage!,
                      width: 48, height: 48, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                          width: 48, height: 48, color: _border))
                  : Container(width: 48, height: 48, color: _border),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(item.displayName,
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12,
                      fontWeight: FontWeight.w500, color: _ink)),
            ),
            const SizedBox(width: 8),
            Text('x${item.quantity}  ${_fmt((item.product?.price ?? 0) * item.quantity)}',
                style: TextStyle(fontSize: 12, color: _slate)),
          ]),
        )),
        Divider(color: _border, height: 16),
        _row('Subtotal', _fmt(widget.subtotal)),
        const SizedBox(height: 6),
        _row('Shipping', widget.shipping == 0 ? 'FREE' : _fmt(widget.shipping),
            valueColor: widget.shipping == 0 ? _green : null),
        Divider(color: _border, height: 16),
        _row('Total', _fmt(widget.total), bold: true),
      ]),
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
          child: const Center(
            child: Text('CONTINUE TO PAYMENT',
                style: TextStyle(color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14, letterSpacing: 0.8)),
          ),
        ),
      ),
    );
  }
}
