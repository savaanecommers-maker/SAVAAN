import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/api_client.dart';

class ContactUsScreen extends StatefulWidget {
  const ContactUsScreen({super.key});

  @override
  State<ContactUsScreen> createState() => _ContactUsScreenState();
}

class _ContactUsScreenState extends State<ContactUsScreen> {
  static const Color _ink     = Color(0xFF0F172A);
  static const Color _teal    = Color(0xFF0D9488);
  static const Color _green   = Color(0xFF10B981);
  static const Color _slate   = Color(0xFF64748B);
  static const Color _border  = Color(0xFFE2E8F0);
  static const Color _surface = Color(0xFFF8FAFC);

  Map<String, String> _info = {};
  bool    _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiClient.get('/api/content/contact', auth: false);
      if (!mounted) return;
      if (res.isSuccess && res.data != null) {
        final raw = res.data!;
        final map = <String, String>{};
        raw.forEach((k, v) => map[k.toString()] = v?.toString() ?? '');
        setState(() { _info = map; _loading = false; });
      } else {
        setState(() { _error = res.error ?? 'Failed to load'; _loading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _error = 'Network error'; _loading = false; });
    }
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) _showSnackBar('Could not open link', Colors.red);
    }
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    _showSnackBar('Copied to clipboard!', _teal);
  }

  void _showSnackBar(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          _buildTopBar(),
          if (_loading)
            const Expanded(child: Center(
                child: CircularProgressIndicator(color: _teal, strokeWidth: 2)))
          else if (_error != null)
            Expanded(child: _buildError())
          else
            Expanded(child: _buildContent()),
        ]),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _border)),
      ),
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
          child: Text('Contact Us',
              style: TextStyle(fontSize: 20,
                  fontWeight: FontWeight.bold, color: _ink)),
        ),
      ]),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.error_outline_rounded, size: 48, color: Colors.red.shade300),
        const SizedBox(height: 16),
        Text(_error!, style: TextStyle(fontSize: 14, color: _slate)),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: () { setState(() { _loading = true; _error = null; }); _load(); },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_teal, _green]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text('Retry',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }

  Widget _buildContent() {
    final email    = _info['email']          ?? 'customer@savaan.in';
    final phone    = _info['phone']          ?? '+91 9110581825';
    final whatsapp = _info['whatsapp']       ?? phone;
    final address  = _info['address']        ?? 'Mumbai, India';
    final hours    = _info['business_hours'] ?? 'Mon–Sat: 9 AM – 9 PM';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      child: Column(children: [
        // Header card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0D9488), Color(0xFF10B981)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(
              color: _teal.withValues(alpha: 0.3),
              blurRadius: 20, offset: const Offset(0, 8),
            )],
          ),
          child: Row(children: [
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('We\'re here to help!',
                    style: TextStyle(fontSize: 18,
                        fontWeight: FontWeight.bold, color: Colors.white)),
                SizedBox(height: 6),
                Text('Reach out through any channel',
                    style: TextStyle(fontSize: 13,
                        color: Colors.white70)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.support_agent_rounded,
                  size: 28, color: Colors.white),
            ),
          ]),
        ),
        const SizedBox(height: 24),

        // Quick action buttons
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('Reach Us',
              style: TextStyle(fontSize: 14,
                  fontWeight: FontWeight.bold, color: _ink)),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _actionBtn(
            icon: Icons.call_rounded,
            label: 'Call Us',
            color: _green,
            onTap: () => _launch('tel:${phone.replaceAll(' ', '')}'),
          )),
          const SizedBox(width: 10),
          Expanded(child: _actionBtn(
            icon: Icons.email_outlined,
            label: 'Email Us',
            color: const Color(0xFF6366F1),
            onTap: () => _launch('mailto:$email?subject=Support Request'),
          )),
          const SizedBox(width: 10),
          Expanded(child: _actionBtn(
            icon: Icons.chat_rounded,
            label: 'WhatsApp',
            color: const Color(0xFF25D366),
            onTap: () => _launch(
                'https://wa.me/${whatsapp.replaceAll(RegExp(r'[^\d]'), '')}?text=Hello%20SAVAAN%20Support'),
          )),
        ]),
        const SizedBox(height: 24),

        // Contact details cards
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('Contact Details',
              style: TextStyle(fontSize: 14,
                  fontWeight: FontWeight.bold, color: _ink)),
        ),
        const SizedBox(height: 12),

        _contactCard(
          icon: Icons.email_outlined,
          color: const Color(0xFF6366F1),
          title: 'Email Address',
          value: email,
          onCopy: () => _copy(email),
          onAction: () => _launch('mailto:$email?subject=Support Request'),
          actionLabel: 'Send Email',
        ),
        const SizedBox(height: 10),
        _contactCard(
          icon: Icons.phone_outlined,
          color: _green,
          title: 'Phone Number',
          value: phone,
          onCopy: () => _copy(phone),
          onAction: () => _launch('tel:${phone.replaceAll(' ', '')}'),
          actionLabel: 'Call Now',
        ),
        const SizedBox(height: 10),
        _contactCard(
          icon: Icons.chat_bubble_outline_rounded,
          color: const Color(0xFF25D366),
          title: 'WhatsApp',
          value: whatsapp,
          onCopy: () => _copy(whatsapp),
          onAction: () => _launch(
              'https://wa.me/${whatsapp.replaceAll(RegExp(r'[^\d]'), '')}?text=Hello%20SAVAAN%20Support'),
          actionLabel: 'Chat Now',
        ),
        const SizedBox(height: 10),

        // Address
        _addressCard(address),
        const SizedBox(height: 10),

        // Business hours
        _hoursCard(hours),
        const SizedBox(height: 24),

        // Response time note
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFED7AA)),
          ),
          child: Row(children: [
            const Icon(Icons.schedule_outlined,
                size: 20, color: Color(0xFFF97316)),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Average Response Time',
                    style: TextStyle(fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF92400E))),
                SizedBox(height: 3),
                Text('Email: within 24 hours  •  WhatsApp: within 2 hours',
                    style: TextStyle(fontSize: 11.5,
                        color: Color(0xFF92400E))),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String   label,
    required Color    color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 5),
          Text(label,
              style: TextStyle(fontSize: 11,
                  fontWeight: FontWeight.w700, color: color)),
        ]),
      ),
    );
  }

  Widget _contactCard({
    required IconData     icon,
    required Color        color,
    required String       title,
    required String       value,
    required VoidCallback onCopy,
    required VoidCallback onAction,
    required String       actionLabel,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 8, offset: const Offset(0, 2),
        )],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: TextStyle(fontSize: 11, color: _slate,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 3),
          Text(value,
              style: const TextStyle(fontSize: 13,
                  fontWeight: FontWeight.w600, color: _ink)),
        ])),
        GestureDetector(
          onTap: onCopy,
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _border),
            ),
            child: Icon(Icons.copy_rounded, size: 14, color: _slate),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onAction,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Text(actionLabel,
                style: TextStyle(fontSize: 11,
                    fontWeight: FontWeight.w700, color: color)),
          ),
        ),
      ]),
    );
  }

  Widget _addressCard(String address) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 8, offset: const Offset(0, 2),
        )],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.location_on_outlined,
              size: 20, color: Color(0xFFEF4444)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Office Address',
              style: TextStyle(fontSize: 11, color: _slate,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 3),
          Text(address,
              style: const TextStyle(fontSize: 13,
                  fontWeight: FontWeight.w500, color: _ink, height: 1.4)),
        ])),
        GestureDetector(
          onTap: () => _copy(address),
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _border),
            ),
            child: Icon(Icons.copy_rounded, size: 14, color: _slate),
          ),
        ),
      ]),
    );
  }

  Widget _hoursCard(String hours) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _teal.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _teal.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _teal.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.schedule_outlined, size: 20, color: _teal),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Business Hours',
              style: TextStyle(fontSize: 11, color: _teal,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Text(hours,
              style: const TextStyle(fontSize: 13,
                  fontWeight: FontWeight.w500, color: _ink)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 6, height: 6,
                decoration: const BoxDecoration(
                    color: _green, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            const Text('Online', style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700, color: _green)),
          ]),
        ),
      ]),
    );
  }
}
