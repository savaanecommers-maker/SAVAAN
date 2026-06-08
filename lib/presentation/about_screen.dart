import 'package:flutter/material.dart';
import '../data/api_client.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
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
          child: Text('About SAVAAN',
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
    return SingleChildScrollView(
      child: Column(children: [
        // Hero brand section
        _buildHero(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
          child: Column(children: [
            const SizedBox(height: 24),
            _buildStorySection(),
            const SizedBox(height: 20),
            _buildMissionVision(),
            const SizedBox(height: 20),
            _buildWhyChooseUs(),
            const SizedBox(height: 20),
            _buildCompanyInfo(),
          ]),
        ),
      ]),
    );
  }

  Widget _buildHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0F3D38)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(children: [
        // Brand logo
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [_teal, _green],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(
              color: _teal.withValues(alpha: 0.4),
              blurRadius: 20, offset: const Offset(0, 8),
            )],
          ),
          child: const Center(
            child: Text('SV',
                style: TextStyle(color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 24, letterSpacing: 2)),
          ),
        ),
        const SizedBox(height: 16),
        const Text('SAVAAN',
            style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 6)),
        const SizedBox(height: 6),
        Text('Luxury & Trust',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
                letterSpacing: 2)),
        const SizedBox(height: 20),
        // Stats row
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _statItem('10K+', 'Happy\nCustomers'),
          _statDivider(),
          _statItem('500+', 'Premium\nBrands'),
          _statDivider(),
          _statItem('50K+', 'Products\nListed'),
          _statDivider(),
          _statItem('4.8★', 'App\nRating'),
        ]),
      ]),
    );
  }

  Widget _statItem(String value, String label) {
    return Expanded(
      child: Column(children: [
        Text(value,
            style: const TextStyle(
                color: _teal, fontSize: 16,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 10, height: 1.3)),
      ]),
    );
  }

  Widget _statDivider() => Container(
      width: 1, height: 32,
      color: Colors.white.withValues(alpha: 0.1));

  Widget _buildStorySection() {
    final story = _info['about_story'] ??
        'SAVAAN was born from a simple belief — that style should not be a privilege.';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _teal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.auto_stories_outlined, size: 18, color: _teal),
          ),
          const SizedBox(width: 10),
          const Text('Our Story',
              style: TextStyle(fontSize: 15,
                  fontWeight: FontWeight.bold, color: _ink)),
        ]),
        const SizedBox(height: 14),
        Text(story,
            style: TextStyle(fontSize: 13.5,
                color: _slate, height: 1.7)),
      ]),
    );
  }

  Widget _buildMissionVision() {
    final mission = _info['about_mission'] ??
        'To make premium fashion accessible to everyone.';
    final vision  = _info['about_vision'] ??
        'To become India\'s most trusted fashion destination.';

    return Row(children: [
      Expanded(child: _infoCard(
        Icons.track_changes_rounded,
        'Our Mission',
        mission,
        const Color(0xFF6366F1),
      )),
      const SizedBox(width: 12),
      Expanded(child: _infoCard(
        Icons.visibility_outlined,
        'Our Vision',
        vision,
        const Color(0xFFEC4899),
      )),
    ]);
  }

  Widget _infoCard(IconData icon, String title, String body, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(height: 10),
        Text(title,
            style: TextStyle(fontSize: 13,
                fontWeight: FontWeight.bold, color: _ink)),
        const SizedBox(height: 6),
        Text(body,
            style: TextStyle(fontSize: 12, color: _slate, height: 1.5)),
      ]),
    );
  }

  Widget _buildWhyChooseUs() {
    const features = [
      _Feature(Icons.local_shipping_outlined, 'Fast Delivery',
          'Express shipping across India',         Color(0xFF0EA5E9)),
      _Feature(Icons.verified_outlined,        'Authentic Products',
          '100% genuine brands guaranteed',       Color(0xFF10B981)),
      _Feature(Icons.lock_outline_rounded,      'Secure Payments',
          'Bank-grade encryption on all transactions', Color(0xFF6366F1)),
      _Feature(Icons.assignment_return_outlined,'Easy Returns',
          'Hassle-free 7-day return policy',      Color(0xFFEC4899)),
      _Feature(Icons.thumb_up_alt_outlined,     'Customer First',
          'Dedicated support 7 days a week',      Color(0xFFF59E0B)),
      _Feature(Icons.star_border_rounded,       'Premium Quality',
          'Curated from the finest brands',       Color(0xFF8B5CF6)),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Why Choose SAVAAN',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _ink)),
      const SizedBox(height: 12),
      ...features.map((f) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
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
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: f.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(f.icon, size: 18, color: f.color),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(f.title, style: const TextStyle(fontSize: 13,
                fontWeight: FontWeight.w600, color: _ink)),
            const SizedBox(height: 2),
            Text(f.subtitle,
                style: TextStyle(fontSize: 11.5, color: _slate)),
          ])),
          Icon(Icons.check_circle_outline_rounded,
              size: 16, color: f.color.withValues(alpha: 0.6)),
        ]),
      )),
    ]);
  }

  Widget _buildCompanyInfo() {
    final email   = _info['email']          ?? 'support@savaan.in';
    final phone   = _info['phone']          ?? '+91 98765 43210';
    final address = _info['address']        ?? 'Mumbai, India';
    final hours   = _info['business_hours'] ?? 'Mon–Sat: 9 AM – 9 PM';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Get In Touch',
            style: TextStyle(fontSize: 16,
                fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 16),
        _contactRow(Icons.email_outlined,      email,   Colors.white),
        _contactRow(Icons.phone_outlined,       phone,   Colors.white),
        _contactRow(Icons.location_on_outlined, address, Colors.white),
        _contactRow(Icons.schedule_outlined,    hours,   Colors.white),
      ]),
    );
  }

  Widget _contactRow(IconData icon, String text, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 16, color: _teal),
        const SizedBox(width: 10),
        Expanded(child: Text(text,
            style: TextStyle(fontSize: 13, color: textColor.withValues(alpha: 0.8),
                height: 1.4))),
      ]),
    );
  }
}

class _Feature {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color  color;
  const _Feature(this.icon, this.title, this.subtitle, this.color);
}
