import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/order_provider.dart';
import '../providers/product_provider.dart';
import '../providers/wishlist_provider.dart';
import 'auth_screens.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {

  // Preferences
  bool _notificationsEnabled = true;
  bool _orderUpdates         = true;
  bool _promoAlerts          = true;
  bool _priceDropAlerts      = true;
  bool _emailNewsletters     = false;
  bool _biometricLogin       = false;
  String _currency           = 'INR';
  String _language           = 'English';

  static const Color _ink     = Color(0xFF0F172A);
  static const Color _teal    = Color(0xFF0D9488);
  static const Color _slate   = Color(0xFF64748B);
  static const Color _border  = Color(0xFFE2E8F0);
  static const Color _surface = Color(0xFFF8FAFC);

  Future<void> _showDeleteAccountDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Account',
            style: TextStyle(fontWeight: FontWeight.bold, color: _ink)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Colors.redAccent, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'This will permanently delete your account and all data. This cannot be undone.',
                  style: TextStyle(fontSize: 13, color: Colors.redAccent, height: 1.4),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          const Text('Are you sure you want to continue?',
              style: TextStyle(color: _slate, fontSize: 13)),
        ]),
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
              child: const Text('Delete Account',
                  style: TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      // Sign out and show auth
      await context.read<AuthProvider>().signOut();
      context.read<CartProvider>().clear();
      context.read<WishlistProvider>().clear();
      context.read<ProductProvider>().clear();
      context.read<OrderProvider>().clear();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AuthParentPage()),
              (_) => false,
        );
      }
    }
  }

  Future<void> _logout() async {
    await context.read<AuthProvider>().signOut();
      context.read<CartProvider>().clear();
      context.read<WishlistProvider>().clear();
      context.read<ProductProvider>().clear();
      context.read<OrderProvider>().clear();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthParentPage()),
            (_) => false,
      );
    }
  }

  void _showCurrencyPicker() {
    final currencies = ['INR (₹)', 'USD (\$)', 'EUR (€)', 'GBP (£)', 'AED (د.إ)'];
    _showPickerSheet('Currency', currencies, (v) {
      setState(() => _currency = v.split(' ').first);
    });
  }

  void _showLanguagePicker() {
    final langs = ['English', 'हिंदी', 'தமிழ்', 'తెలుగు', 'मराठी', 'বাংলা'];
    _showPickerSheet('Language', langs, (v) {
      setState(() => _language = v);
    });
  }

  void _showPickerSheet(String title, List<String> options,
      void Function(String) onSelect) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Handle
            Center(
              child: Container(width: 36, height: 4,
                  decoration: BoxDecoration(color: _border,
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(title,
                  style: const TextStyle(fontSize: 17,
                      fontWeight: FontWeight.bold, color: _ink)),
            ),
            const SizedBox(height: 8),
            // Scrollable options list
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: options.length,
              itemBuilder: (_, i) {
                final opt = options[i];
                final currentVal = title == 'Currency' ? _currency : _language;
                final isSelected = opt.startsWith(currentVal);
                return ListTile(
                  dense: true,
                  title: Text(opt,
                      style: TextStyle(
                        fontSize: 14,
                        color: isSelected ? _teal : _ink,
                        fontWeight: isSelected
                            ? FontWeight.w600 : FontWeight.normal,
                      )),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle_rounded,
                          color: _teal, size: 20)
                      : null,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  onTap: () {
                    onSelect(opt);
                    Navigator.pop(context);
                  },
                );
              },
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: SafeArea(
        child: Column(children: [
          _buildTopBar(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                // ── Notifications ─────────────────────────────
                _sectionHeader('Notifications'),
                _settingsCard([
                  _switchTile(
                    icon: Icons.notifications_outlined,
                    iconColor: const Color(0xFF6366F1),
                    label: 'Push Notifications',
                    subtitle: 'Enable all app notifications',
                    value: _notificationsEnabled,
                    onChanged: (v) => setState(() {
                      _notificationsEnabled = v;
                      if (!v) {
                        _orderUpdates = false;
                        _promoAlerts = false;
                        _priceDropAlerts = false;
                      }
                    }),
                  ),
                  _divider(),
                  _switchTile(
                    icon: Icons.receipt_long_outlined,
                    iconColor: const Color(0xFF0EA5E9),
                    label: 'Order Updates',
                    subtitle: 'Shipping, delivery & status changes',
                    value: _orderUpdates && _notificationsEnabled,
                    onChanged: _notificationsEnabled
                        ? (v) => setState(() => _orderUpdates = v)
                        : null,
                  ),
                  _divider(),
                  _switchTile(
                    icon: Icons.local_offer_outlined,
                    iconColor: const Color(0xFFF59E0B),
                    label: 'Promotions & Deals',
                    subtitle: 'Flash sales, coupons & offers',
                    value: _promoAlerts && _notificationsEnabled,
                    onChanged: _notificationsEnabled
                        ? (v) => setState(() => _promoAlerts = v)
                        : null,
                  ),
                  _divider(),
                  _switchTile(
                    icon: Icons.trending_down_rounded,
                    iconColor: const Color(0xFF10B981),
                    label: 'Price Drop Alerts',
                    subtitle: 'When wishlist items go on sale',
                    value: _priceDropAlerts && _notificationsEnabled,
                    onChanged: _notificationsEnabled
                        ? (v) => setState(() => _priceDropAlerts = v)
                        : null,
                  ),
                  _divider(),
                  _switchTile(
                    icon: Icons.email_outlined,
                    iconColor: const Color(0xFF8B5CF6),
                    label: 'Email Newsletters',
                    subtitle: 'Weekly picks & new arrivals',
                    value: _emailNewsletters,
                    onChanged: (v) => setState(() => _emailNewsletters = v),
                  ),
                ]),

                const SizedBox(height: 20),

                // ── Security ──────────────────────────────────
                _sectionHeader('Security'),
                _settingsCard([
                  _switchTile(
                    icon: Icons.fingerprint_rounded,
                    iconColor: const Color(0xFF0D9488),
                    label: 'Biometric Login',
                    subtitle: 'Use fingerprint or face ID',
                    value: _biometricLogin,
                    onChanged: (v) => setState(() => _biometricLogin = v),
                  ),
                  _divider(),
                  _arrowTile(
                    icon: Icons.lock_outline_rounded,
                    iconColor: const Color(0xFF64748B),
                    label: 'Change Password',
                    subtitle: 'Update your account password',
                    onTap: () => _showSnackBar('Password reset email sent!'),
                  ),
                  _divider(),
                  _arrowTile(
                    icon: Icons.devices_outlined,
                    iconColor: const Color(0xFF6366F1),
                    label: 'Active Sessions',
                    subtitle: 'Manage devices logged into your account',
                    onTap: () => _showSnackBar('Coming soon'),
                  ),
                ]),

                const SizedBox(height: 20),

                // ── Preferences ───────────────────────────────
                _sectionHeader('Preferences'),
                _settingsCard([
                  _arrowTile(
                    icon: Icons.language_outlined,
                    iconColor: const Color(0xFF0EA5E9),
                    label: 'Language',
                    trailing: _valueChip(_language),
                    onTap: _showLanguagePicker,
                  ),
                  _divider(),
                  _arrowTile(
                    icon: Icons.currency_exchange_rounded,
                    iconColor: const Color(0xFF10B981),
                    label: 'Currency',
                    trailing: _valueChip(_currency),
                    onTap: _showCurrencyPicker,
                  ),
                ]),

                const SizedBox(height: 20),

                // ── About ─────────────────────────────────────
                _sectionHeader('About'),
                _settingsCard([
                  _arrowTile(
                    icon: Icons.info_outline_rounded,
                    iconColor: _teal,
                    label: 'App Version',
                    trailing: Text('1.0.0',
                        style: TextStyle(fontSize: 13, color: _slate)),
                    onTap: () {},
                  ),
                  _divider(),
                  _arrowTile(
                    icon: Icons.privacy_tip_outlined,
                    iconColor: const Color(0xFF6366F1),
                    label: 'Privacy Policy',
                    onTap: () => _showSnackBar('Opening privacy policy...'),
                  ),
                  _divider(),
                  _arrowTile(
                    icon: Icons.description_outlined,
                    iconColor: const Color(0xFF64748B),
                    label: 'Terms & Conditions',
                    onTap: () => _showSnackBar('Opening terms...'),
                  ),
                  _divider(),
                  _arrowTile(
                    icon: Icons.help_outline_rounded,
                    iconColor: const Color(0xFF8B5CF6),
                    label: 'Help & Support',
                    onTap: () => _showSnackBar('Opening support...'),
                  ),
                  _divider(),
                  _arrowTile(
                    icon: Icons.star_outline_rounded,
                    iconColor: const Color(0xFFF59E0B),
                    label: 'Rate the App',
                    onTap: () => _showSnackBar('Opening app store...'),
                  ),
                ]),

                const SizedBox(height: 20),

                // ── Danger zone ───────────────────────────────
                _sectionHeader('Account'),
                _settingsCard([
                  _arrowTile(
                    icon: Icons.logout_rounded,
                    iconColor: Colors.redAccent,
                    label: 'Logout',
                    labelColor: Colors.redAccent,
                    onTap: _logout,
                  ),
                  _divider(),
                  _arrowTile(
                    icon: Icons.delete_forever_outlined,
                    iconColor: Colors.redAccent,
                    label: 'Delete Account',
                    labelColor: Colors.redAccent,
                    subtitle: 'Permanently removes your account & data',
                    onTap: _showDeleteAccountDialog,
                  ),
                ]),

                const SizedBox(height: 20),

                // Version footer
                Center(
                  child: Column(children: [
                    Text('SAVAAN', style: TextStyle(
                        fontSize: 12, color: _slate.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w700, letterSpacing: 3)),
                    const SizedBox(height: 4),
                    Text('Version 1.0.0  •  Made with ❤️ in India',
                        style: TextStyle(fontSize: 11,
                            color: _slate.withValues(alpha: 0.4))),
                  ]),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
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
        const Text('Settings',
            style: TextStyle(fontSize: 20,
                fontWeight: FontWeight.bold, color: _ink)),
      ]),
    );
  }

  Widget _sectionHeader(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 4),
    child: Text(label.toUpperCase(),
        style: TextStyle(fontSize: 11, color: _slate,
            fontWeight: FontWeight.w700, letterSpacing: 1.2)),
  );

  Widget _settingsCard(List<Widget> children) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _border),
      boxShadow: [BoxShadow(
        color: Colors.black.withValues(alpha: 0.03),
        blurRadius: 8, offset: const Offset(0, 2),
      )],
    ),
    child: Column(children: children),
  );

  Widget _divider() => Divider(height: 1, indent: 62, color: _border);

  Widget _switchTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    String? subtitle,
    required bool value,
    void Function(bool)? onChanged,
  }) {
    final disabled = onChanged == null;
    return ListTile(
      leading: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: disabled ? 0.05 : 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20,
            color: disabled ? iconColor.withValues(alpha: 0.4) : iconColor),
      ),
      title: Text(label,
          style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w500,
            color: disabled ? _slate.withValues(alpha: 0.5) : _ink,
          )),
      subtitle: subtitle != null
          ? Text(subtitle,
          style: TextStyle(fontSize: 11,
              color: _slate.withValues(alpha: disabled ? 0.4 : 0.8)))
          : null,
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: _teal,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
    );
  }

  Widget _arrowTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    Color? labelColor,
    String? subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: iconColor),
      ),
      title: Text(label,
          style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w500,
            color: labelColor ?? _ink,
          )),
      subtitle: subtitle != null
          ? Text(subtitle,
          style: TextStyle(fontSize: 11, color: _slate.withValues(alpha: 0.8)))
          : null,
      trailing: trailing ??
          Icon(Icons.chevron_right_rounded,
              size: 20, color: _slate.withValues(alpha: 0.4)),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
    );
  }

  Widget _valueChip(String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _border),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(value, style: const TextStyle(fontSize: 12, color: _ink,
          fontWeight: FontWeight.w500)),
      const SizedBox(width: 4),
      Icon(Icons.keyboard_arrow_down_rounded,
          size: 14, color: _slate),
    ]),
  );

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: _teal,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    ));
  }
}