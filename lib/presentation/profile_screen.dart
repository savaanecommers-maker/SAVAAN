import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../data/api_client.dart';
import '../data/user_service.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/order_provider.dart';
import '../providers/product_provider.dart';
import '../providers/wishlist_provider.dart';
import 'address_screen.dart';
import 'auth_screens.dart';
import 'notification_screen.dart';
import 'orders_screen.dart';
import 'help_support_screen.dart';
import 'settings_screen.dart';
import 'wishlist_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _userService = UserService();

  UserModel? _user;
  bool _isLoading       = true;
  bool _isSaving        = false;
  bool _isUploadingPhoto = false;

  final _nameController  = TextEditingController();
  final _phoneController = TextEditingController();
  late final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  static const Color _ink     = Color(0xFF0F172A);
  static const Color _teal    = Color(0xFF0D9488);
  static const Color _green   = Color(0xFF10B981);
  static const Color _slate   = Color(0xFF64748B);
  static const Color _border  = Color(0xFFE2E8F0);
  static const Color _surface = Color(0xFFF8FAFC);

  final List<Map<String, dynamic>> _menuItems = [
    {'icon': Icons.receipt_long_outlined,  'label': 'My Orders',      'badge': 0, 'color': Color(0xFF6366F1)},
    {'icon': Icons.favorite_outline,       'label': 'Wishlist',       'badge': 0, 'color': Color(0xFFEC4899)},
    {'icon': Icons.location_on_outlined,   'label': 'Address Book',   'badge': 0, 'color': Color(0xFF0EA5E9)},
    {'icon': Icons.local_offer_outlined,   'label': 'Coupons',        'badge': 0, 'color': Color(0xFFF59E0B)},
    {'icon': Icons.notifications_outlined, 'label': 'Notifications',  'badge': 0, 'color': Color(0xFFEF4444)},
    {'icon': Icons.help_outline_rounded,   'label': 'Help & Support', 'badge': 0, 'color': Color(0xFF8B5CF6)},
    {'icon': Icons.settings_outlined,      'label': 'Settings',       'badge': 0, 'color': Color(0xFF64748B)},
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      // Re-use the already-loaded user from AuthProvider to avoid a duplicate
      // network call to /api/auth/profile (AuthProvider.loadUser() already
      // fetches it on app start).
      final authProvider = context.read<AuthProvider>();
      await authProvider.loadUser(); // no-op if already loaded; force=false
      if (mounted) {
        final user = authProvider.user;
        setState(() {
          _user = user;
          _nameController.text  = user?.fullName ?? '';
          _phoneController.text = user?.phone    ?? '';
          _emailController.text = user?.email    ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final error = await _userService.updateProfile(
      fullName: _nameController.text.trim(),
      phone:    _phoneController.text.trim(),
    );
    if (mounted) {
      if (error == null) {
        setState(() {
          _user = _user?.copyWith(
            fullName: _nameController.text.trim(),
            phone:    _phoneController.text.trim(),
          );
          _isSaving = false;
        });
        _showSnackBar('Profile updated!', _teal);
      } else {
        setState(() => _isSaving = false);
        _showSnackBar('Failed to save', Colors.redAccent);
      }
    }
  }

  /// Pick a photo from gallery or camera, upload to /api/upload,
  /// then save the returned URL via PUT /api/auth/profile.
  Future<void> _pickAndUploadPhoto() async {
    // Let user choose source
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Center(child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(color: _border,
                  borderRadius: BorderRadius.circular(2)),
            )),
            const SizedBox(height: 16),
            const Align(alignment: Alignment.centerLeft,
              child: Text('Choose Photo',
                  style: TextStyle(fontSize: 16,
                      fontWeight: FontWeight.bold, color: _ink)),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _teal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.photo_library_outlined, color: _teal),
              ),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _teal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.camera_alt_outlined, color: _teal),
              ),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
    if (source == null) return;

    // Pick image
    final picker = ImagePicker();
    final XFile? picked;
    try {
      picked = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
    } catch (e) {
      if (mounted) _showSnackBar('Could not access camera/gallery', Colors.redAccent);
      return;
    }
    if (picked == null) return;

    setState(() => _isUploadingPhoto = true);
    try {
      // Upload via multipart POST /api/upload
      final uploadRes = await ApiClient.uploadFile(
        '/api/upload',
        File(picked.path),
        field: 'file',
      );
      if (!uploadRes.isSuccess || uploadRes.data == null) {
        throw Exception(uploadRes.error ?? 'Upload failed');
      }
      final avatarUrl = uploadRes.data!['url']?.toString()
          ?? uploadRes.data!['file_url']?.toString()
          ?? uploadRes.data!['path']?.toString();
      if (avatarUrl == null || avatarUrl.isEmpty) {
        throw Exception('Server returned no URL');
      }

      // Save URL to profile
      final profileRes = await ApiClient.put('/api/auth/profile', {
        'avatar_url': avatarUrl,
      });
      if (!profileRes.isSuccess) {
        throw Exception(profileRes.error ?? 'Failed to save avatar');
      }

      if (mounted) {
        setState(() {
          _user = _user?.copyWith(avatarUrl: avatarUrl);
          _isUploadingPhoto = false;
        });
        _showSnackBar('Photo updated!', _teal);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        _showSnackBar('Upload failed: ${e.toString()}', Colors.redAccent);
      }
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Logout',
            style: TextStyle(fontWeight: FontWeight.bold, color: _ink)),
        content: const Text('Are you sure you want to logout?',
            style: TextStyle(color: _slate)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: _slate)),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context, true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(10)),
              child: const Text('Logout',
                  style: TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final authProvider    = context.read<AuthProvider>();
      final cartProvider    = context.read<CartProvider>();
      final wishlistProvider= context.read<WishlistProvider>();
      final productProvider = context.read<ProductProvider>();
      final orderProvider   = context.read<OrderProvider>();
      final nav             = Navigator.of(context);
      await authProvider.signOut();
      cartProvider.clear();
      wishlistProvider.clear();
      productProvider.clear();
      orderProvider.clear();
      if (mounted) {
        nav.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthParentPage()),
          (_) => false,
        );
      }
    }
  }

  // ── Coupons bottom sheet ─────────────────────────────────────
  void _showCoupons() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _CouponsSheet(),
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

  void _handleMenuTap(String label) {
    switch (label) {
      case 'My Orders':
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const OrdersScreen()));
        break;
      case 'Wishlist':
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const WishlistScreen()));
        break;
      case 'Address Book':
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AddressScreen()));
        break;
      case 'Coupons':
        _showCoupons();
        break;
      case 'Notifications':
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const NotificationsScreen()));
        break;
      case 'Help & Support':
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const HelpSupportScreen()));
        break;
      case 'Settings':
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: _teal))
            : SingleChildScrollView(
          child: Column(children: [
            _buildTopBar(),
            _buildProfileHeader(),
            _buildEditForm(),
            const SizedBox(height: 8),
            _buildMenuSection(),
            _buildLogoutButton(),
            const SizedBox(height: 30),
          ]),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(children: [
        if (Navigator.canPop(context))
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: _surface, borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _border),
              ),
              child: const Icon(Icons.arrow_back, size: 20, color: _ink),
            ),
          ),
        const Expanded(
          child: Text('My Account',
              style: TextStyle(fontSize: 20,
                  fontWeight: FontWeight.bold, color: _ink)),
        ),
      ]),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Row(children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_teal, _green],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(
                color: _teal.withValues(alpha: 0.4), blurRadius: 12)],
          ),
          child: Center(
            child: Text(_user?.initials ?? 'G',
                style: const TextStyle(color: Colors.white,
                    fontSize: 24, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_user?.displayName ?? 'Guest',
                style: const TextStyle(color: Colors.white,
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(_user?.email ?? '',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
                overflow: TextOverflow.ellipsis),
            if (_user?.phone != null && _user!.phone!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(_user!.phone!,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
            ],
          ],
        )),
        GestureDetector(
          onTap: _isUploadingPhoto ? null : _pickAndUploadPhoto,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: _isUploadingPhoto
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.camera_alt_outlined,
                    color: Colors.white, size: 18),
          ),
        ),
      ]),
    );
  }

  Widget _buildEditForm() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)],
      ),
      child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Personal Information',
              style: TextStyle(fontSize: 15,
                  fontWeight: FontWeight.bold, color: _ink)),
          const SizedBox(height: 14),
          _field(_nameController, 'Full Name', Icons.person_outline_rounded,
              validator: (v) =>
              v == null || v.isEmpty ? 'Enter your name' : null),
          const SizedBox(height: 12),
          _field(_emailController, 'Email Address', Icons.email_outlined,
              readOnly: true),
          const SizedBox(height: 12),
          _field(_phoneController, 'Phone Number', Icons.phone_outlined,
              keyboardType: TextInputType.phone),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _isSaving ? null : _saveProfile,
            child: Container(
              width: double.infinity, height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_teal, _green]),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(
                    color: _teal.withValues(alpha: 0.25),
                    blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Center(
                child: _isSaving
                    ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                    : const Text('SAVE CHANGES',
                    style: TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14, letterSpacing: 1)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {bool readOnly = false,
      TextInputType? keyboardType,
      String? Function(String?)? validator}) {
    return TextFormField(
      controller: ctrl,
      readOnly: readOnly,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(fontSize: 14, color: readOnly ? _slate : _ink),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 13, color: _slate),
        prefixIcon: Icon(icon, size: 20, color: _slate),
        filled: true,
        fillColor: readOnly ? _surface : Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _teal, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 14),
      ),
    );
  }

  Widget _buildMenuSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)],
      ),
      child: Column(
        children: List.generate(_menuItems.length, (i) {
          final item   = _menuItems[i];
          final isLast = i == _menuItems.length - 1;
          return Column(children: [
            ListTile(
              leading: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: (item['color'] as Color).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item['icon'] as IconData,
                    size: 20, color: item['color'] as Color),
              ),
              title: Text(item['label'] as String,
                  style: const TextStyle(fontSize: 14,
                      fontWeight: FontWeight.w500, color: _ink)),
              trailing: Icon(Icons.chevron_right_rounded,
                  size: 20, color: _slate.withValues(alpha: 0.5)),
              onTap: () => _handleMenuTap(item['label'] as String),
            ),
            if (!isLast) Divider(height: 1, indent: 66, color: _border),
          ]);
        }),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: GestureDetector(
        onTap: _logout,
        child: Container(
          width: double.infinity, height: 50,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: Colors.redAccent.withValues(alpha: 0.3)),
            boxShadow: [BoxShadow(
                color: Colors.redAccent.withValues(alpha: 0.05),
                blurRadius: 8)],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.logout_rounded,
                color: Colors.redAccent, size: 20),
            const SizedBox(width: 8),
            const Text('Logout',
                style: TextStyle(color: Colors.redAccent,
                    fontWeight: FontWeight.w600, fontSize: 15)),
          ]),
        ),
      ),
    );
  }
}

// ── Coupons Sheet ────────────────────────────────────────────────────────────
class _CouponsSheet extends StatefulWidget {
  @override
  State<_CouponsSheet> createState() => _CouponsSheetState();
}

class _CouponsSheetState extends State<_CouponsSheet> {
  List<Map<String, dynamic>> _coupons = [];
  bool _isLoading = true;

  static const Color _ink    = Color(0xFF0F172A);
  static const Color _teal   = Color(0xFF0D9488);
  static const Color _green  = Color(0xFF10B981);
  static const Color _slate  = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);

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
            final raw = res.data!;
            final list = raw['_list'] as List? ?? raw['coupons'] as List? ?? [];
            _coupons = List<Map<String, dynamic>>.from(list);
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _copy(String code) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Coupon "$code" copied!',
          style: const TextStyle(color: Colors.white)),
      backgroundColor: _teal,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    ));
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
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('Available Coupons',
              style: TextStyle(fontSize: 18,
                  fontWeight: FontWeight.bold, color: _ink)),
        ),
        const SizedBox(height: 16),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: CircularProgressIndicator(color: _teal),
          )
        else if (_coupons.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text('No active coupons right now',
                style: TextStyle(color: _slate, fontSize: 14)),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _coupons.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final c = _coupons[i];
              final code       = c['code']?.toString() ?? '';
              final type       = c['discount_type']?.toString() ?? '';
              final value      = double.tryParse(
                  c['discount_value']?.toString() ?? '0') ?? 0;
              final minOrder   = double.tryParse(
                  c['min_order_value']?.toString() ?? '0') ?? 0;
              final discount   = type == 'percent'
                  ? '${value.toInt()}% OFF'
                  : '₹${value.toInt()} OFF';

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_teal.withValues(alpha: 0.04),
                      _green.withValues(alpha: 0.02)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: _teal.withValues(alpha: 0.25)),
                ),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [_teal, _green]),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(discount,
                        style: const TextStyle(color: Colors.white,
                            fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(code,
                          style: const TextStyle(fontSize: 14,
                              fontWeight: FontWeight.bold, color: _ink,
                              letterSpacing: 1)),
                      if (minOrder > 0)
                        Text('Min order ₹${minOrder.toInt()}',
                            style: TextStyle(fontSize: 11, color: _slate)),
                    ],
                  )),
                  GestureDetector(
                    onTap: () => _copy(code),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: _teal.withValues(alpha: 0.3)),
                      ),
                      child: Text('COPY',
                          style: TextStyle(fontSize: 11,
                              color: _teal, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ]),
              );
            },
          ),
      ]),
    );
  }
}
