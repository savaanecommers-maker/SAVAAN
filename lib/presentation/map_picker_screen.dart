import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

// ── Data class returned to caller ────────────────────────────────────────────
class MapPickedAddress {
  final double latitude;
  final double longitude;
  final String? houseNumber;
  final String? street;      // road / line1
  final String? area;        // suburb / neighbourhood
  final String? city;
  final String? state;
  final String? pincode;
  final String  displayName;

  const MapPickedAddress({
    required this.latitude,
    required this.longitude,
    this.houseNumber,
    this.street,
    this.area,
    this.city,
    this.state,
    this.pincode,
    required this.displayName,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
class MapPickerScreen extends StatefulWidget {
  final LatLng? initialPosition;
  final bool    viewOnly;
  final String? viewLabel;
  const MapPickerScreen({
    super.key,
    this.initialPosition,
    this.viewOnly  = false,
    this.viewLabel,
  });

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  static const Color _teal   = Color(0xFF0D9488);
  static const Color _green  = Color(0xFF10B981);
  static const Color _ink    = Color(0xFF0F172A);
  static const Color _slate  = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _surface = Color(0xFFF8FAFC);

  // Default center: India
  static const LatLng _defaultCenter = LatLng(20.5937, 78.9629);

  late final MapController _mapCtrl;
  LatLng _center = _defaultCenter;

  String _addressLabel = 'Move the map to pick your location';
  bool   _geocoding    = false;
  MapPickedAddress? _picked;

  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _searching = false;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _mapCtrl = MapController();
    if (widget.initialPosition != null) {
      _center = widget.initialPosition!;
    }
    if (widget.viewOnly && widget.viewLabel != null) {
      _addressLabel = widget.viewLabel!;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialPosition != null && !widget.viewOnly) {
        _reverseGeocode(_center);
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _mapCtrl.dispose();
    super.dispose();
  }

  // ── Map movement handler ──────────────────────────────────────────────────
  void _onMapEvent(MapEvent event) {
    if (widget.viewOnly) return;  // no geocoding in view-only mode
    if (event is MapEventMoveEnd || event is MapEventScrollWheelZoom) {
      _center = _mapCtrl.camera.center;
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 600), () {
        _reverseGeocode(_center);
      });
    }
  }

  // ── Reverse geocoding via Nominatim ──────────────────────────────────────
  Future<void> _reverseGeocode(LatLng pos) async {
    if (!mounted) return;
    setState(() => _geocoding = true);
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=${pos.latitude}&lon=${pos.longitude}'
        '&format=json&zoom=18&addressdetails=1',
      );
      final res = await http.get(uri, headers: {
        'User-Agent':       'SAVAAN-Shopping-App/1.0',
        'Accept-Language':  'en',
      }).timeout(const Duration(seconds: 8));

      if (!mounted) return;
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final addr = (json['address'] as Map<String, dynamic>?) ?? {};

        final picked = MapPickedAddress(
          latitude:    pos.latitude,
          longitude:   pos.longitude,
          houseNumber: addr['house_number']?.toString(),
          street: addr['road']?.toString()
              ?? addr['pedestrian']?.toString()
              ?? addr['street']?.toString(),
          area: addr['suburb']?.toString()
              ?? addr['neighbourhood']?.toString()
              ?? addr['quarter']?.toString()
              ?? addr['county']?.toString(),
          city: addr['city']?.toString()
              ?? addr['town']?.toString()
              ?? addr['village']?.toString()
              ?? addr['district']?.toString(),
          state:   addr['state']?.toString(),
          pincode: addr['postcode']?.toString(),
          displayName: json['display_name']?.toString() ?? 'Selected location',
        );

        setState(() {
          _picked       = picked;
          _addressLabel = _buildShortLabel(picked);
          _geocoding    = false;
        });
      } else {
        setState(() { _geocoding = false; _addressLabel = 'Location selected'; });
      }
    } catch (_) {
      if (mounted) setState(() { _geocoding = false; _addressLabel = 'Location selected'; });
    }
  }

  String _buildShortLabel(MapPickedAddress a) {
    final parts = <String>[
      if (a.street != null && a.street!.isNotEmpty) a.street!,
      if (a.area   != null && a.area!.isNotEmpty)   a.area!,
      if (a.city   != null && a.city!.isNotEmpty)   a.city!,
    ];
    if (parts.isEmpty) {
      return a.displayName.split(',').take(3).join(',').trim();
    }
    return parts.join(', ');
  }

  // ── Forward search via Nominatim ─────────────────────────────────────────
  Future<void> _doSearch(String query) async {
    final q = query.trim();
    if (q.length < 3) {
      setState(() => _results = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(q)}'
        '&format=json&countrycodes=in&limit=6&addressdetails=1',
      );
      final res = await http.get(uri, headers: {
        'User-Agent':      'SAVAAN-Shopping-App/1.0',
        'Accept-Language': 'en',
      }).timeout(const Duration(seconds: 8));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final list = (jsonDecode(res.body) as List)
            .cast<Map<String, dynamic>>();
        setState(() { _results = list; _searching = false; });
      } else {
        setState(() => _searching = false);
      }
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () => _doSearch(v));
    if (v.isEmpty) setState(() => _results = []);
  }

  void _onResultTap(Map<String, dynamic> r) {
    final lat = double.tryParse(r['lat']?.toString() ?? '') ?? 0;
    final lon = double.tryParse(r['lon']?.toString() ?? '') ?? 0;
    final ll  = LatLng(lat, lon);
    _mapCtrl.move(ll, 16);
    _center = ll;
    _searchCtrl.clear();
    setState(() => _results = []);
    _reverseGeocode(ll);
  }

  // ── Current location ──────────────────────────────────────────────────────
  Future<void> _useCurrentLocation() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (mounted) _snack('Location permission required');
        return;
      }
      if (!mounted) return;
      setState(() { _geocoding = true; _addressLabel = 'Getting your location…'; });
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(const Duration(seconds: 12));
      final ll = LatLng(pos.latitude, pos.longitude);
      _mapCtrl.move(ll, 17);
      _center = ll;
      await _reverseGeocode(ll);
    } catch (e) {
      if (mounted) {
        setState(() => _geocoding = false);
        _snack('Could not get current location');
      }
    }
  }

  void _confirm() {
    final result = _picked ?? MapPickedAddress(
      latitude:    _center.latitude,
      longitude:   _center.longitude,
      displayName: _addressLabel,
    );
    Navigator.pop(context, result);
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: _slate,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final initialZoom = widget.initialPosition != null ? 15.0 : 5.0;

    return Scaffold(
      body: Stack(children: [

        // ── OpenStreetMap tile layer ──────────────────────────────────
        FlutterMap(
          mapController: _mapCtrl,
          options: MapOptions(
            initialCenter: _center,
            initialZoom:   initialZoom,
            onMapEvent:    _onMapEvent,
          ),
          children: [
            TileLayer(
              urlTemplate:        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.savaan.app',
              maxZoom: 19,
            ),
          ],
        ),

        // ── Fixed center pin ──────────────────────────────────────────
        IgnorePointer(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pin drops 28px above center so tip aligns with center
                Transform.translate(
                  offset: const Offset(0, -24),
                  child: const Icon(
                    Icons.location_pin,
                    size: 52,
                    color: _teal,
                  ),
                ),
                // Shadow
                Transform.translate(
                  offset: const Offset(0, -48),
                  child: Container(
                    width: 14, height: 5,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Top bar: back + search ────────────────────────────────────
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Row: back + search field
                Row(children: [
                  _iconBtn(Icons.arrow_back, () => Navigator.pop(context)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _searchField(),
                  ),
                ]),
                // Search results dropdown
                if (_results.isNotEmpty)
                  _searchDropdown(),
              ],
            ),
          ),
        ),

        // ── Current location button ───────────────────────────────────
        Positioned(
          right: 16,
          bottom: 230,
          child: _iconBtn(Icons.my_location_rounded, _useCurrentLocation,
              color: _teal),
        ),

        // ── Bottom address confirmation panel ─────────────────────────
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: _bottomPanel(),
        ),
      ]),
    );
  }

  // ── Widget builders ───────────────────────────────────────────────────────

  Widget _iconBtn(IconData icon, VoidCallback onTap, {Color? color}) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 3,
      shadowColor: Colors.black26,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Icon(icon, size: 22, color: color ?? _ink),
        ),
      ),
    );
  }

  Widget _searchField() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 3,
      shadowColor: Colors.black26,
      child: TextField(
        controller: _searchCtrl,
        onChanged:  _onSearchChanged,
        style: const TextStyle(fontSize: 13, color: _ink),
        decoration: InputDecoration(
          hintText: 'Search area, street, pincode…',
          hintStyle: TextStyle(fontSize: 13, color: _slate.withValues(alpha: 0.6)),
          prefixIcon: _searching
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(color: _teal, strokeWidth: 2)))
              : const Icon(Icons.search_rounded, size: 20, color: _slate),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 16, color: _slate),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _results = []);
                  })
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 4, vertical: 14),
        ),
      ),
    );
  }

  Widget _searchDropdown() {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.10),
          blurRadius: 12, offset: const Offset(0, 4),
        )],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _results.length,
          separatorBuilder: (_, sep) =>
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
          itemBuilder: (_, i) {
            final r = _results[i];
            final name = r['display_name']?.toString() ?? '';
            return InkWell(
              onTap: () => _onResultTap(r),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                child: Row(children: [
                  const Icon(Icons.location_on_outlined,
                      size: 16, color: _teal),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(name,
                        style: const TextStyle(fontSize: 12, color: _ink),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                ]),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _bottomPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.10),
          blurRadius: 20, offset: const Offset(0, -4),
        )],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Drag handle
            Container(width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                    color: _border,
                    borderRadius: BorderRadius.circular(2))),

            // Address display row
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: _teal.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _geocoding
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(
                            color: _teal, strokeWidth: 2))
                    : const Icon(Icons.location_on, color: _teal, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Selected Location',
                        style: TextStyle(fontSize: 11, color: _slate,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 3),
                    Text(_addressLabel,
                        style: const TextStyle(fontSize: 13, color: _ink,
                            fontWeight: FontWeight.w600, height: 1.35),
                        maxLines: 3, overflow: TextOverflow.ellipsis),
                    if (_picked?.pincode != null) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _border),
                        ),
                        child: Text('PIN: ${_picked!.pincode}',
                            style: const TextStyle(
                                fontSize: 10, color: _slate,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ],
                ),
              ),
            ]),

            const SizedBox(height: 16),

            // Confirm button (or Close in view-only mode)
            GestureDetector(
              onTap: widget.viewOnly
                  ? () => Navigator.pop(context)
                  : _confirm,
              child: Container(
                width: double.infinity, height: 50,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: widget.viewOnly
                          ? [Colors.deepPurple, Colors.purple]
                          : [_teal, _green]),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(
                    color: (widget.viewOnly
                        ? Colors.deepPurple : _teal).withValues(alpha: 0.30),
                    blurRadius: 12, offset: const Offset(0, 4),
                  )],
                ),
                child: Center(
                  child: Text(
                    widget.viewOnly ? 'CLOSE MAP' : 'CONFIRM LOCATION',
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13, letterSpacing: 0.8),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
