import 'package:flutter/material.dart';
import '../data/api_client.dart';

class AddressScreen extends StatefulWidget {
  /// If true, shows a "Use this address" button — used when navigating from checkout
  final bool selectionMode;
  final String? selectedAddressId;

  const AddressScreen({
    super.key,
    this.selectionMode = false,
    this.selectedAddressId,
  });

  @override
  State<AddressScreen> createState() => _AddressScreenState();
}

class _AddressScreenState extends State<AddressScreen> {
  List<Map<String, dynamic>> _addresses = [];
  bool _isLoading = true;
  String? _selectedId;

  static const Color _ink     = Color(0xFF0F172A);
  static const Color _teal    = Color(0xFF0D9488);
  static const Color _green   = Color(0xFF10B981);
  static const Color _slate   = Color(0xFF64748B);
  static const Color _border  = Color(0xFFE2E8F0);
  static const Color _surface = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _selectedId = widget.selectedAddressId;
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    setState(() => _isLoading = true);
    try {
      final payload = await ApiClient.getTokenPayload();
      final uid = payload?['id'] as String?;
      if (uid == null) { setState(() => _isLoading = false); return; }

      final res = await ApiClient.get('/api/users/$uid/addresses');
      if (mounted) {
        setState(() {
          if (res.isSuccess && res.data != null) {
            final list = res.data!['_list'] as List? ?? [];
            _addresses = List<Map<String, dynamic>>.from(list);
          }
          _isLoading = false;
          if (widget.selectionMode && _selectedId == null) {
            final def = _addresses.where((a) => a['is_default'] == true).toList();
            if (def.isNotEmpty) _selectedId = def.first['id']?.toString();
          }
        });
      }
    } catch (e) {
      debugPrint('Addresses error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _setDefault(String addressId) async {
    try {
      await ApiClient.put('/api/addresses/$addressId', {'is_default': true});
      _loadAddresses();
      _showSnackBar('Default address updated', _teal);
    } catch (e) {
      _showSnackBar('Failed to update', Colors.redAccent);
    }
  }

  Future<void> _deleteAddress(String addressId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Address',
            style: TextStyle(fontWeight: FontWeight.bold, color: _ink)),
        content: const Text('Are you sure you want to delete this address?',
            style: TextStyle(color: _slate)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: _slate)),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context, true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(10)),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiClient.delete('/api/addresses/$addressId');
      _loadAddresses();
      _showSnackBar('Address deleted', _slate);
    } catch (e) {
      _showSnackBar('Failed to delete', Colors.redAccent);
    }
  }

  void _showAddEditSheet({Map<String, dynamic>? address}) {
    final isEdit = address != null;
    final nameCtrl   = TextEditingController(text: address?['full_name'] ?? '');
    final phoneCtrl  = TextEditingController(text: address?['phone'] ?? '');
    final streetCtrl = TextEditingController(text: address?['line1'] ?? address?['street'] ?? '');
    final cityCtrl   = TextEditingController(text: address?['city'] ?? '');
    final stateCtrl  = TextEditingController(text: address?['state'] ?? '');
    final pinCtrl    = TextEditingController(text: address?['pincode'] ?? '');
    bool isDefault   = address?['is_default'] ?? false;
    bool isSaving    = false;
    final formKey    = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: DraggableScrollableSheet(
            initialChildSize: 0.85,
            maxChildSize: 0.95,
            minChildSize: 0.6,
            expand: false,
            builder: (_, scrollCtrl) => Column(children: [
              // Handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Center(
                  child: Container(width: 36, height: 4,
                      decoration: BoxDecoration(color: _border,
                          borderRadius: BorderRadius.circular(2))),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Row(children: [
                  Expanded(child: Text(isEdit ? 'Edit Address' : 'New Address',
                      style: const TextStyle(fontSize: 18,
                          fontWeight: FontWeight.bold, color: _ink))),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                          color: _surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: _border)),
                      child: const Icon(Icons.close, size: 18, color: _ink),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Form(
                  key: formKey,
                  child: ListView(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    children: [
                      _formField(nameCtrl, 'Full Name',
                          Icons.person_outline_rounded,
                          validator: (v) => v == null || v.isEmpty
                              ? 'Enter full name' : null),
                      const SizedBox(height: 12),
                      _formField(phoneCtrl, 'Phone Number',
                          Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          validator: (v) => v == null || v.length < 10
                              ? 'Enter valid phone' : null),
                      const SizedBox(height: 12),
                      _formField(streetCtrl, 'Street / Flat / Area',
                          Icons.home_outlined, maxLines: 2,
                          validator: (v) => v == null || v.isEmpty
                              ? 'Enter street address' : null),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: _formField(cityCtrl, 'City',
                            Icons.location_city_outlined,
                            validator: (v) => v == null || v.isEmpty
                                ? 'Enter city' : null)),
                        const SizedBox(width: 12),
                        Expanded(child: _formField(stateCtrl, 'State',
                            Icons.map_outlined,
                            validator: (v) => v == null || v.isEmpty
                                ? 'Enter state' : null)),
                      ]),
                      const SizedBox(height: 12),
                      _formField(pinCtrl, 'Pincode',
                          Icons.pin_drop_outlined,
                          keyboardType: TextInputType.number,
                          validator: (v) => v == null || v.length != 6
                              ? 'Enter 6-digit pincode' : null),
                      const SizedBox(height: 16),
                      // Default toggle
                      GestureDetector(
                        onTap: () => setS(() => isDefault = !isDefault),
                        child: Row(children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 22, height: 22,
                            decoration: BoxDecoration(
                              color: isDefault ? _teal : Colors.white,
                              border: Border.all(
                                  color: isDefault ? _teal : _border,
                                  width: 1.5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: isDefault
                                ? const Icon(Icons.check_rounded,
                                color: Colors.white, size: 14)
                                : null,
                          ),
                          const SizedBox(width: 10),
                          const Text('Set as default address',
                              style: TextStyle(fontSize: 14, color: _ink,
                                  fontWeight: FontWeight.w500)),
                        ]),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // Save button
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                child: GestureDetector(
                  onTap: isSaving ? null : () async {
                    if (!formKey.currentState!.validate()) return;
                    setS(() => isSaving = true);
                    try {
                      final body = {
                        'full_name':  nameCtrl.text.trim(),
                        'phone':      phoneCtrl.text.trim(),
                        'line1':      streetCtrl.text.trim(),
                        'city':       cityCtrl.text.trim(),
                        'state':      stateCtrl.text.trim(),
                        'pincode':    pinCtrl.text.trim(),
                        'is_default': isDefault,
                      };

                      ApiResponse res;
                      if (isEdit) {
                        res = await ApiClient.put(
                            '/api/addresses/${address!['id']}', body);
                      } else {
                        res = await ApiClient.post('/api/addresses', body);
                      }

                      if (!res.isSuccess) {
                        setS(() => isSaving = false);
                        _showSnackBar(
                            res.error ?? 'Failed to save address',
                            Colors.redAccent);
                        return;
                      }

                      if (ctx.mounted) Navigator.pop(ctx);
                      _loadAddresses();
                      _showSnackBar(
                          isEdit ? 'Address updated!' : 'Address added!', _teal);
                    } catch (e) {
                      debugPrint('Save address error: $e');
                      setS(() => isSaving = false);
                      _showSnackBar('Failed to save address', Colors.redAccent);
                    }
                  },
                  child: Container(
                    width: double.infinity,
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
                      child: isSaving
                          ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                          : Text(isEdit ? 'SAVE CHANGES' : 'ADD ADDRESS',
                          style: const TextStyle(color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14, letterSpacing: 1)),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _formField(
      TextEditingController ctrl,
      String label,
      IconData icon, {
        TextInputType? keyboardType,
        int maxLines = 1,
        String? Function(String?)? validator,
      }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(fontSize: 14, color: _ink),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 13, color: _slate),
        prefixIcon: Icon(icon, size: 20, color: _slate),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _teal, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.redAccent)),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 14),
      ),
    );
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
      body: SafeArea(
        child: Column(children: [
          _buildTopBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _teal))
                : _addresses.isEmpty
                ? _buildEmpty()
                : RefreshIndicator(
              color: _teal,
              onRefresh: _loadAddresses,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                itemCount: _addresses.length,
                itemBuilder: (_, i) =>
                    _buildAddressCard(_addresses[i]),
              ),
            ),
          ),
        ]),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditSheet(),
        backgroundColor: _teal,
        icon: const Icon(Icons.add_location_alt_outlined,
            color: Colors.white),
        label: const Text('Add Address',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      bottomNavigationBar: widget.selectionMode && _selectedId != null
          ? _buildSelectButton()
          : null,
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
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
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Address Book',
                style: TextStyle(fontSize: 20,
                    fontWeight: FontWeight.bold, color: _ink)),
            if (!_isLoading && _addresses.isNotEmpty)
              Text('${_addresses.length} saved address${_addresses.length > 1 ? 'es' : ''}',
                  style: TextStyle(fontSize: 12, color: _slate)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildAddressCard(Map<String, dynamic> addr) {
    final id = addr['id']?.toString() ?? '';
    final isDefault = addr['is_default'] == true;
    final isSelected = _selectedId == id;

    return GestureDetector(
      onTap: widget.selectionMode
          ? () => setState(() => _selectedId = id)
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? _teal : (isDefault ? _teal.withValues(alpha: 0.3) : _border),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8, offset: const Offset(0, 3),
          )],
        ),
        child: Column(children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(children: [
              // Selection radio (selection mode) or location icon
              if (widget.selectionMode)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 20, height: 20,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? _teal : Colors.white,
                    border: Border.all(
                        color: isSelected ? _teal : _border, width: 2),
                  ),
                  child: isSelected
                      ? const Icon(Icons.circle,
                      color: Colors.white, size: 8) : null,
                )
              else
                Container(
                  padding: const EdgeInsets.all(6),
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                      color: _teal.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.location_on_outlined,
                      size: 16, color: _teal),
                ),
              Expanded(
                child: Text(addr['full_name']?.toString() ?? '',
                    style: const TextStyle(fontSize: 14,
                        fontWeight: FontWeight.bold, color: _ink)),
              ),
              if (isDefault)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _teal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _teal.withValues(alpha: 0.3)),
                  ),
                  child: const Text('Default',
                      style: TextStyle(fontSize: 10, color: _teal,
                          fontWeight: FontWeight.w600)),
                ),
            ]),
          ),

          // Address body
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              _addrLine(Icons.phone_outlined,
                  addr['phone']?.toString() ?? ''),
              const SizedBox(height: 4),
              _addrLine(Icons.home_outlined,
                  [
                    addr['line1'] ?? addr['street'],
                    addr['city'],
                    addr['state'],
                    addr['pincode'],
                  ].where((s) => s != null && s.toString().isNotEmpty)
                      .map((s) => s.toString())
                      .join(', ')),
            ]),
          ),

          // Action row
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: Row(children: [
              if (!isDefault)
                TextButton.icon(
                  onPressed: () => _setDefault(id),
                  icon: const Icon(Icons.check_circle_outline,
                      size: 14, color: _teal),
                  label: const Text('Set Default',
                      style: TextStyle(fontSize: 12, color: _teal)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                  ),
                ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.edit_outlined,
                    size: 18, color: _slate),
                onPressed: () => _showAddEditSheet(address: addr),
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(),
                tooltip: 'Edit',
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: Colors.redAccent),
                onPressed: () => _deleteAddress(id),
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(),
                tooltip: 'Delete',
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _addrLine(IconData icon, String text) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 13, color: _slate),
      const SizedBox(width: 6),
      Expanded(child: Text(text,
          style: TextStyle(fontSize: 12, color: _slate, height: 1.4))),
    ],
  );

  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.location_off_outlined, size: 64,
            color: _slate.withValues(alpha: 0.25)),
        const SizedBox(height: 16),
        const Text('No saved addresses',
            style: TextStyle(fontSize: 17,
                fontWeight: FontWeight.w600, color: _ink)),
        const SizedBox(height: 8),
        Text('Add a delivery address to get started',
            style: TextStyle(fontSize: 13, color: _slate)),
        const SizedBox(height: 28),
        GestureDetector(
          onTap: () => _showAddEditSheet(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_teal, _green]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('Add Address',
                style: TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w600, fontSize: 14)),
          ),
        ),
      ]),
    );
  }

  Widget _buildSelectButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 12, offset: const Offset(0, -3),
        )],
      ),
      child: GestureDetector(
        onTap: () {
          final selected = _addresses.firstWhere(
                  (a) => a['id']?.toString() == _selectedId,
              orElse: () => {});
          Navigator.pop(context, selected.isNotEmpty ? selected : null);
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
            child: Text('USE THIS ADDRESS',
                style: TextStyle(color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14, letterSpacing: 1)),
          ),
        ),
      ),
    );
  }
}