import 'package:flutter/material.dart';
import 'legal_doc_screen.dart';
import 'about_screen.dart';
import 'help_center_screen.dart';
import 'contact_us_screen.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  static const Color _ink     = Color(0xFF0F172A);
  static const Color _teal    = Color(0xFF0D9488);
  static const Color _slate   = Color(0xFF64748B);
  static const Color _border  = Color(0xFFE2E8F0);
  static const Color _surface = Color(0xFFF8FAFC);

  // Legal document items
  static const _legalItems = [
    _HelpItem(
      icon: Icons.privacy_tip_outlined,
      title: 'Privacy Policy',
      subtitle: 'How we handle your data',
      color: Color(0xFF6366F1),
      slug: 'privacy_policy',
    ),
    _HelpItem(
      icon: Icons.gavel_rounded,
      title: 'Terms & Conditions',
      subtitle: 'Rules governing your use',
      color: Color(0xFF0EA5E9),
      slug: 'terms_conditions',
    ),
    _HelpItem(
      icon: Icons.info_outline_rounded,
      title: 'Disclaimer Policy',
      subtitle: 'Limitations & clarifications',
      color: Color(0xFF8B5CF6),
      slug: 'disclaimer',
    ),
    _HelpItem(
      icon: Icons.assignment_return_outlined,
      title: 'Return & Refund Policy',
      subtitle: 'Returns, exchanges & refunds',
      color: Color(0xFFEC4899),
      slug: 'return_refund',
    ),
    _HelpItem(
      icon: Icons.local_shipping_outlined,
      title: 'Shipping Policy',
      subtitle: 'Delivery timelines & charges',
      color: Color(0xFF10B981),
      slug: 'shipping_policy',
    ),
  ];

  // Information items
  static const _infoItems = [
    _HelpItem(
      icon: Icons.store_outlined,
      title: 'About SAVAAN',
      subtitle: 'Our story, mission & vision',
      color: Color(0xFF0D9488),
      slug: 'about',
    ),
    _HelpItem(
      icon: Icons.help_outline_rounded,
      title: 'Help Center',
      subtitle: 'Browse FAQs by category',
      color: Color(0xFFF59E0B),
      slug: 'help_center',
    ),
    _HelpItem(
      icon: Icons.contact_support_outlined,
      title: 'Contact Us',
      subtitle: 'Reach out to our team',
      color: Color(0xFFEF4444),
      slug: 'contact',
    ),
    _HelpItem(
      icon: Icons.quiz_outlined,
      title: 'FAQ',
      subtitle: 'Answers to common questions',
      color: Color(0xFF06B6D4),
      slug: 'faq',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          _buildTopBar(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hero banner
                  _buildHeroBanner(),
                  const SizedBox(height: 24),

                  // Legal Documents section
                  _buildSectionHeader(
                    Icons.shield_outlined,
                    'Legal Documents',
                    'Policies & Terms',
                  ),
                  const SizedBox(height: 12),
                  _buildItemList(context, _legalItems),

                  const SizedBox(height: 24),

                  // Information section
                  _buildSectionHeader(
                    Icons.info_outline_rounded,
                    'Information',
                    'Support & Details',
                  ),
                  const SizedBox(height: 12),
                  _buildItemList(context, _infoItems),

                  const SizedBox(height: 24),
                  _buildContactBanner(context),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
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
          child: Text('Help & Support',
              style: TextStyle(fontSize: 20,
                  fontWeight: FontWeight.bold, color: _ink)),
        ),
      ]),
    );
  }

  Widget _buildHeroBanner() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D9488), Color(0xFF10B981)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D9488).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('How can we help?',
                style: TextStyle(fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white, height: 1.2)),
            const SizedBox(height: 6),
            Text('Find answers, policies & contact info',
                style: TextStyle(fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.85))),
          ]),
        ),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.support_agent_rounded,
              size: 32, color: Colors.white),
        ),
      ]),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title, String subtitle) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: _teal.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: _teal),
      ),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(fontSize: 15,
                fontWeight: FontWeight.bold, color: _ink)),
        Text(subtitle,
            style: TextStyle(fontSize: 11, color: _slate)),
      ]),
    ]);
  }

  Widget _buildItemList(BuildContext context, List<_HelpItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12, offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: items.asMap().entries.map((e) {
          final i    = e.key;
          final item = e.value;
          return Column(children: [
            _buildTile(context, item),
            if (i < items.length - 1)
              Divider(height: 1, indent: 56, endIndent: 16,
                  color: _border),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _buildTile(BuildContext context, _HelpItem item) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _navigate(context, item),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(item.icon, size: 18, color: item.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(item.title,
                    style: const TextStyle(fontSize: 14,
                        fontWeight: FontWeight.w600, color: _ink)),
                const SizedBox(height: 2),
                Text(item.subtitle,
                    style: TextStyle(fontSize: 11, color: _slate)),
              ]),
            ),
            Icon(Icons.chevron_right_rounded, size: 20,
                color: _slate.withValues(alpha: 0.5)),
          ]),
        ),
      ),
    );
  }

  Widget _buildContactBanner(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const ContactUsScreen())),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFED7AA)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF97316).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.headset_mic_outlined,
                size: 20, color: Color(0xFFF97316)),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text('Still need help?',
                  style: TextStyle(fontSize: 14,
                      fontWeight: FontWeight.bold, color: _ink)),
              Text('Our team is ready to assist you',
                  style: TextStyle(fontSize: 12,
                      color: Color(0xFF92400E))),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFFF97316)),
        ]),
      ),
    );
  }

  void _navigate(BuildContext context, _HelpItem item) {
    switch (item.slug) {
      case 'about':
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AboutScreen()));
        break;
      case 'help_center':
      case 'faq':
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const HelpCenterScreen()));
        break;
      case 'contact':
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ContactUsScreen()));
        break;
      default:
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => LegalDocScreen(slug: item.slug)));
    }
  }
}

// ── Data class ────────────────────────────────────────────────
class _HelpItem {
  final IconData icon;
  final String   title;
  final String   subtitle;
  final Color    color;
  final String   slug;

  const _HelpItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.slug,
  });
}
