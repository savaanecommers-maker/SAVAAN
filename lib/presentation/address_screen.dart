import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import '../data/api_client.dart';
import 'map_picker_screen.dart';

// ── Address type config ───────────────────────────────────────────────────────
const _kTypes = [
  _AddrType('Home',    Icons.home_outlined),
  _AddrType('Work',    Icons.work_outline_rounded),
  _AddrType('Office',  Icons.business_outlined),
  _AddrType('Parents', Icons.people_outline_rounded),
  _AddrType('Other',   Icons.location_on_outlined),
];

class _AddrType {
  final String  label;
  final IconData icon;
  const _AddrType(this.label, this.icon);
}

// ─────────────────────────────────────────────────────────────────────────────
class AddressScreen extends StatefulWidget {
  final bool    selectionMode;
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
  bool    _isLoading = true;
  String? _selectedId;

  static const Color _teal    = Color(0xFF0D9488);
  static const Color _green   = Color(0xFF10B981);
  static const Color _ink     = Color(0xFF0F172A);
  static const Color _slate   = Color(0xFF64748B);
  static const Color _border  = Color(0xFFE2E8F0);
  static const Color _surface = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _selectedId = widget.selectedAddressId;
    _loadAddresses();
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> _loadAddresses() async {
    setState(() => _isLoading = true);
    try {
      // Try new self-auth endpoint first, fall back to /:uid/addresses
      var res = await ApiClient.get('/api/addresses');
      if (!res.isSuccess) {
        final payload = await ApiClient.getTokenPayload();
        final uid = payload?['id'] as String?;
        if (uid != null) res = await ApiClient.get('/api/users/$uid/addresses');
      }
      if (mounted) {
        setState(() {
          if (res.isSuccess && res.data != null) {
            final raw = res.data!;
            final list = (raw['_list'] ?? raw['addresses'] ?? raw['data'] ?? []) as List? ?? [];
            _addresses = List<Map<String, dynamic>>.from(list);
          }
          _isLoading = false;
          if (widget.selectionMode && _selectedId == null) {
            final def = _addresses.where((a) => a['is_default'] == true);
            if (def.isNotEmpty) _selectedId = def.first['id']?.toString();
          }
        });
      }
    } catch (e) {
      debugPrint('Addresses load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _setDefault(String id) async {
    final res = await ApiClient.patch('/api/addresses/$id/set-default', {});
    if (res.isSuccess) {
      _loadAddresses();
      _snack('Default address updated', _teal);
    } else {
      _snack('Failed to update', Colors.redAccent);
    }
  }

  Future<void> _deleteAddress(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Address',
            style: TextStyle(fontWeight: FontWeight.bold, color: _ink)),
        content: const Text('Remove this delivery address?',
            style: TextStyle(color: _slate)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: _slate)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ApiClient.delete('/api/addresses/$id');
    _loadAddresses();
    _snack('Address removed', _slate);
  }

  // ── Entry point: show choice dialog ───────────────────────────────────────
  void _showAddChoice() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                  color: _border, borderRadius: BorderRadius.circular(2))),
          const Text('Add Delivery Address',
              style: TextStyle(fontSize: 18,
                  fontWeight: FontWeight.bold, color: _ink)),
          const SizedBox(height: 6),
          Text('How would you like to add your address?',
              style: TextStyle(fontSize: 13, color: _slate)),
          const SizedBox(height: 24),

          // Option 1 — Manual
          _choiceTile(
            icon: Icons.edit_note_rounded,
            color: _teal,
            title: 'Enter Manually',
            subtitle: 'Type in your full address details',
            onTap: () {
              Navigator.pop(context);
              _showAddEditSheet();
            },
          ),
          const SizedBox(height: 12),

          // Option 2 — Map
          _choiceTile(
            icon: Icons.map_outlined,
            color: Colors.deepPurple,
            title: 'Choose From Map',
            subtitle: 'Pin your location on the map',
            onTap: () async {
              Navigator.pop(context);
              await _openMap();
            },
          ),
        ]),
      ),
    );
  }

  Widget _choiceTile({
    required IconData icon,
    required Color    color,
    required String   title,
    required String   subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.20)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(title, style: TextStyle(fontSize: 15,
                  fontWeight: FontWeight.bold, color: _ink)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontSize: 12, color: _slate)),
            ]),
          ),
          Icon(Icons.chevron_right_rounded, color: _slate.withValues(alpha: 0.5)),
        ]),
      ),
    );
  }

  // ── Show saved location on map (view-only) ───────────────────────────────
  void _showOnMap({required double lat, required double lon, required String label}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(
          initialPosition: LatLng(lat, lon),
          viewOnly: true,
          viewLabel: label,
        ),
      ),
    );
  }

  // ── Open map picker ───────────────────────────────────────────────────────
  Future<void> _openMap({Map<String, dynamic>? existingAddress}) async {
    final result = await Navigator.push<MapPickedAddress>(
      context,
      MaterialPageRoute(builder: (_) => const MapPickerScreen()),
    );
    if (result == null || !mounted) return;

    // Pre-fill form from map result
    _showAddEditSheet(
      address: existingAddress,
      prefill: {
        'house_number': result.houseNumber ?? '',
        'line1':        result.street ?? '',
        'area':         result.area ?? '',
        'city':         result.city ?? '',
        'state':        result.state ?? '',
        'pincode':      result.pincode ?? '',
        'latitude':     result.latitude,
        'longitude':    result.longitude,
      },
    );
  }

  // ── Add / Edit bottom sheet ───────────────────────────────────────────────
  void _showAddEditSheet({
    Map<String, dynamic>? address,
    Map<String, dynamic>? prefill,
  }) {
    final isEdit = address != null;

    // Merge existing address + prefill (prefill wins for map-sourced fields)
    String get(String key) {
      if (prefill != null && prefill.containsKey(key) &&
          prefill[key] != null && prefill[key].toString().isNotEmpty) {
        return prefill[key].toString();
      }
      return address?[key]?.toString() ?? '';
    }

    final nameCtrl  = TextEditingController(text: get('full_name'));
    final phoneCtrl = TextEditingController(text: get('phone'));
    final houseCtrl = TextEditingController(text: get('house_number'));
    final streetCtrl= TextEditingController(text:
        get('line1').isNotEmpty ? get('line1') : get('street'));
    final areaCtrl  = TextEditingController(text: get('area'));
    final landCtrl  = TextEditingController(text: get('landmark'));
    final cityCtrl  = TextEditingController(text: get('city'));
    final stateCtrl = TextEditingController(text: get('state'));
    final pinCtrl   = TextEditingController(text: get('pincode'));

    String  addrType  = get('address_type').isNotEmpty ? get('address_type') : 'Home';
    bool    isDefault = address?['is_default'] ?? false;
    double? latitude  = (prefill?['latitude']  as num?)?.toDouble()
        ?? (address?['latitude']  as num?)?.toDouble();
    double? longitude = (prefill?['longitude'] as num?)?.toDouble()
        ?? (address?['longitude'] as num?)?.toDouble();

    bool    isSaving  = false;
    String? pincodeMsg;
    bool    pinOk     = true;
    final   formKey   = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) {
          // ── Pincode validation ──────────────────────────────────────
          Future<void> validatePincode(String pin) async {
            if (pin.length != 6) return;
            try {
              final res = await ApiClient.get('/api/addresses/pincode/$pin');
              if (!ctx.mounted) return;
              if (res.isSuccess && res.data != null) {
                final serviceable = res.data!['serviceable'] as bool? ?? true;
                final msg = res.data!['message']?.toString() ?? '';
                setS(() { pincodeMsg = msg; pinOk = serviceable; });
              }
            } catch (_) {}
          }

          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: DraggableScrollableSheet(
              initialChildSize: 0.92,
              maxChildSize:     0.97,
              minChildSize:     0.60,
              expand: false,
              builder: (_, scrollCtrl) => Column(children: [
                // Handle + header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: Column(children: [
                    Container(width: 36, height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                            color: _border,
                            borderRadius: BorderRadius.circular(2))),
                    Row(children: [
                      Expanded(
                        child: Text(
                          isEdit ? 'Edit Address' : 'New Address',
                          style: const TextStyle(fontSize: 18,
                              fontWeight: FontWeight.bold, color: _ink),
                        ),
                      ),
                      // Switch to map (only for non-edit add flow)
                      if (!isEdit)
                        TextButton.icon(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await _openMap();
                          },
                          icon: const Icon(Icons.map_outlined,
                              size: 16, color: _teal),
                          label: const Text('Use Map',
                              style: TextStyle(fontSize: 12, color: _teal)),
                          style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4)),
                        ),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                              color: _surface,
                              shape: BoxShape.circle,
                              border: Border.all(color: _border)),
                          child: const Icon(Icons.close,
                              size: 18, color: _ink),
                        ),
                      ),
                    ]),
                  ]),
                ),

                // Map-sourced indicator
                if (latitude != null && longitude != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Colors.deepPurple.withValues(alpha: 0.2)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.location_on,
                            color: Colors.deepPurple, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Location from map · '
                            '${latitude.toStringAsFixed(4)}, '
                            '${longitude.toStringAsFixed(4)}',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.deepPurple),
                          ),
                        ),
                      ]),
                    ),
                  ),

                // Form
                Expanded(
                  child: Form(
                    key: formKey,
                    child: ListView(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                      children: [

                        // ── Address Type chips ───────────────────────────
                        const Text('Address Type',
                            style: TextStyle(fontSize: 12,
                                fontWeight: FontWeight.w600, color: _slate)),
                        const SizedBox(height: 8),
                        Wrap(spacing: 8, runSpacing: 8,
                          children: _kTypes.map((t) {
                            final sel = addrType == t.label;
                            return GestureDetector(
                              onTap: () => setS(() => addrType = t.label),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  color: sel
                                      ? _teal.withValues(alpha: 0.10)
                                      : _surface,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: sel ? _teal : _border,
                                    width: sel ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(mainAxisSize: MainAxisSize.min,
                                    children: [
                                  Icon(t.icon, size: 14,
                                      color: sel ? _teal : _slate),
                                  const SizedBox(width: 5),
                                  Text(t.label,
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: sel
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: sel ? _teal : _slate)),
                                ]),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),

                        // ── Contact details ──────────────────────────────
                        _field(nameCtrl, 'Full Name *',
                            Icons.person_outline_rounded,
                            validator: (v) => (v?.isEmpty ?? true)
                                ? 'Required' : null),
                        const SizedBox(height: 12),
                        _field(phoneCtrl, 'Mobile Number *',
                            Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10),
                            ],
                            validator: (v) =>
                                (v?.length ?? 0) < 10 ? 'Enter 10-digit number' : null),
                        const SizedBox(height: 16),

                        // ── Address details ──────────────────────────────
                        const Text('Address Details',
                            style: TextStyle(fontSize: 12,
                                fontWeight: FontWeight.w600, color: _slate)),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(
                            child: _field(houseCtrl,
                                'House / Flat No.',
                                Icons.home_outlined),
                          ),
                        ]),
                        const SizedBox(height: 12),
                        _field(streetCtrl, 'Street / Road *',
                            Icons.fork_right_outlined,
                            validator: (v) => (v?.isEmpty ?? true)
                                ? 'Required' : null),
                        const SizedBox(height: 12),
                        _field(areaCtrl, 'Area / Locality',
                            Icons.location_city_outlined),
                        const SizedBox(height: 12),
                        _field(landCtrl, 'Landmark',
                            Icons.place_outlined),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(
                            child: _field(cityCtrl, 'City *',
                                Icons.apartment_outlined,
                                validator: (v) => (v?.isEmpty ?? true)
                                    ? 'Required' : null),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _field(stateCtrl, 'State *',
                                Icons.map_outlined,
                                validator: (v) => (v?.isEmpty ?? true)
                                    ? 'Required' : null),
                          ),
                        ]),
                        const SizedBox(height: 12),
                        // Pincode with validation feedback
                        _field(pinCtrl, 'Pincode *',
                            Icons.pin_drop_outlined,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(6),
                            ],
                            onEditingComplete: () =>
                                validatePincode(pinCtrl.text.trim()),
                            validator: (v) =>
                                (v?.length ?? 0) != 6
                                    ? 'Enter 6-digit pincode' : null),
                        if (pincodeMsg != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Row(children: [
                              Icon(
                                pinOk
                                    ? Icons.check_circle_outline
                                    : Icons.warning_amber_rounded,
                                size: 14,
                                color: pinOk ? _green : Colors.orange,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(pincodeMsg!,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: pinOk
                                            ? _green
                                            : Colors.orange.shade700)),
                              ),
                            ]),
                          ),
                        if (pincodeMsg != null && !pinOk)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'You can still save this address but delivery\n'
                              'may not be available at checkout.',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: _slate.withValues(alpha: 0.7)),
                            ),
                          ),

                        const SizedBox(height: 16),

                        // ── Default toggle ───────────────────────────────
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
                                style: TextStyle(fontSize: 14,
                                    color: _ink,
                                    fontWeight: FontWeight.w500)),
                          ]),
                        ),
                        const SizedBox(height: 28),
                      ],
                    ),
                  ),
                ),

                // ── Save button ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  child: GestureDetector(
                    onTap: isSaving ? null : () async {
                      if (!formKey.currentState!.validate()) return;
                      // Warn (don't block) if pincode not serviceable
                      if (!pinOk && pincodeMsg != null) {
                        final cont = await showDialog<bool>(
                          context: ctx,
                          builder: (_) => AlertDialog(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18)),
                            title: const Text('Delivery Notice',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            content: const Text(
                                'This pincode may not be serviceable. '
                                'You can save the address and try placing '
                                'an order — the checkout will confirm delivery.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Go Back'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: _teal),
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Save Anyway',
                                    style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        );
                        if (cont != true) return;
                      }

                      setS(() => isSaving = true);
                      try {
                        final body = <String, dynamic>{
                          'full_name':    nameCtrl.text.trim(),
                          'phone':        phoneCtrl.text.trim(),
                          'house_number': houseCtrl.text.trim(),
                          'line1':        streetCtrl.text.trim(),
                          'area':         areaCtrl.text.trim(),
                          'landmark':     landCtrl.text.trim(),
                          'city':         cityCtrl.text.trim(),
                          'state':        stateCtrl.text.trim(),
                          'pincode':      pinCtrl.text.trim(),
                          'address_type': addrType,
                          'label':        addrType,
                          'is_default':   isDefault,
                          if (latitude  != null) 'latitude':  latitude,
                          if (longitude != null) 'longitude': longitude,
                        };

                        final ApiResponse res = isEdit
                            ? await ApiClient.put(
                                '/api/addresses/${address['id']}', body)
                            : await ApiClient.post('/api/addresses', body);

                        if (!res.isSuccess) {
                          setS(() => isSaving = false);
                          _snack(res.error ?? 'Failed to save', Colors.redAccent);
                          return;
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                        _loadAddresses();
                        _snack(isEdit ? 'Address updated!' : 'Address added!', _teal);
                      } catch (e) {
                        setS(() => isSaving = false);
                        _snack('Failed to save address', Colors.redAccent);
                      }
                    },
                    child: Container(
                      width: double.infinity, height: 52,
                      decoration: BoxDecoration(
                        gradient: isSaving
                            ? null
                            : const LinearGradient(colors: [_teal, _green]),
                        color: isSaving ? _border : null,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: isSaving ? null : [BoxShadow(
                          color: _teal.withValues(alpha: 0.3),
                          blurRadius: 12, offset: const Offset(0, 4),
                        )],
                      ),
                      child: Center(
                        child: isSaving
                            ? const SizedBox(width: 22, height: 22,
                                child: CircularProgressIndicator(
                                    color: _teal, strokeWidth: 2))
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
          );
        },
      ),
    );
  }

  // ── Form field builder ────────────────────────────────────────────────────

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    int maxLines = 1,
    List<TextInputFormatter>? inputFormatters,
    VoidCallback? onEditingComplete,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller:         ctrl,
      keyboardType:       keyboardType,
      maxLines:           maxLines,
      inputFormatters:    inputFormatters,
      onEditingComplete:  onEditingComplete,
      validator:          validator,
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

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          _buildTopBar(),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: _teal))
                : _addresses.isEmpty
                    ? _buildEmpty()
                    : RefreshIndicator(
                        color: _teal,
                        onRefresh: _loadAddresses,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                          itemCount: _addresses.length,
                          itemBuilder: (_, i) =>
                              _buildAddressCard(_addresses[i]),
                        ),
                      ),
          ),
        ]),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddChoice,
        backgroundColor: _teal,
        icon: const Icon(Icons.add_location_alt_outlined,
            color: Colors.white),
        label: const Text('Add Address',
            style: TextStyle(color: Colors.white,
                fontWeight: FontWeight.w600)),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
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
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            const Text('Address Book',
                style: TextStyle(fontSize: 20,
                    fontWeight: FontWeight.bold, color: _ink)),
            if (!_isLoading && _addresses.isNotEmpty)
              Text(
                '${_addresses.length} saved '
                'address${_addresses.length > 1 ? 'es' : ''}',
                style: TextStyle(fontSize: 12, color: _slate),
              ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildAddressCard(Map<String, dynamic> addr) {
    final id        = addr['id']?.toString() ?? '';
    final isDefault = addr['is_default'] == true;
    final isSelected= _selectedId == id;
    final addrType  = addr['address_type']?.toString()
        ?? addr['label']?.toString() ?? 'Home';
    final hasCoords = addr['latitude'] != null;

    // Build readable address string
    final parts = <String>[
      if ((addr['house_number']?.toString() ?? '').isNotEmpty)
        addr['house_number'].toString(),
      if ((addr['line1']?.toString() ?? '').isNotEmpty)
        addr['line1'].toString()
      else if ((addr['street']?.toString() ?? '').isNotEmpty)
        addr['street'].toString(),
      if ((addr['area']?.toString() ?? '').isNotEmpty)
        addr['area'].toString(),
      if ((addr['landmark']?.toString() ?? '').isNotEmpty)
        addr['landmark'].toString(),
      addr['city']?.toString() ?? '',
      addr['state']?.toString() ?? '',
      addr['pincode']?.toString() ?? '',
    ].where((s) => s.isNotEmpty).toList();

    final typeConfig = _kTypes.firstWhere(
      (t) => t.label == addrType,
      orElse: () => _kTypes.last,
    );

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
            color: isSelected
                ? _teal
                : isDefault
                    ? _teal.withValues(alpha: 0.3)
                    : _border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8, offset: const Offset(0, 3),
          )],
        ),
        child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(children: [
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
                      ? const Icon(Icons.circle, color: Colors.white, size: 8)
                      : null,
                )
              else
                Container(
                  padding: const EdgeInsets.all(6),
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                      color: _teal.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8)),
                  child: Icon(typeConfig.icon, size: 16, color: _teal),
                ),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(addr['full_name']?.toString() ?? '',
                        style: const TextStyle(fontSize: 14,
                            fontWeight: FontWeight.bold, color: _ink)),
                    const SizedBox(height: 2),
                    Row(children: [
                      // Address type badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: _teal.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(addrType,
                            style: const TextStyle(fontSize: 10,
                                color: _teal, fontWeight: FontWeight.w600)),
                      ),
                      if (hasCoords) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.location_on,
                                  size: 9, color: Colors.deepPurple),
                              SizedBox(width: 2),
                              Text('Map',
                                  style: TextStyle(fontSize: 9,
                                      color: Colors.deepPurple,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
                    ]),
                  ],
                ),
              ),

              if (isDefault)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _teal.withValues(alpha: 0.10),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              _addrLine(Icons.phone_outlined,
                  addr['phone']?.toString() ?? ''),
              const SizedBox(height: 4),
              _addrLine(Icons.home_outlined, parts.join(', ')),
            ]),
          ),

          // Action row
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
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
                          horizontal: 8, vertical: 4)),
                ),
              if (hasCoords)
                TextButton.icon(
                  onPressed: () => _showOnMap(
                    lat: (addr['latitude'] as num).toDouble(),
                    lon: (addr['longitude'] as num).toDouble(),
                    label: addr['full_name']?.toString() ?? '',
                  ),
                  icon: const Icon(Icons.map_outlined,
                      size: 14, color: Colors.deepPurple),
                  label: const Text('Show on Map',
                      style: TextStyle(fontSize: 12,
                          color: Colors.deepPurple)),
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4)),
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
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
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
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            GestureDetector(
              onTap: _showAddChoice,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [_teal, _green]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('Add Address',
                    style: TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w600, fontSize: 14)),
              ),
            ),
          ]),
        ]),
      ),
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
          Navigator.pop(
              context, selected.isNotEmpty ? selected : null);
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
