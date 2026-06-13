import 'package:flutter/material.dart';
import '../data/api_client.dart';

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  static const Color _ink     = Color(0xFF0F172A);
  static const Color _teal    = Color(0xFF0D9488);
  static const Color _green   = Color(0xFF10B981);
  static const Color _slate   = Color(0xFF64748B);
  static const Color _border  = Color(0xFFE2E8F0);
  static const Color _surface = Color(0xFFF8FAFC);

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _faqs       = [];
  List<Map<String, dynamic>> _filtered   = [];

  bool    _loading  = true;
  String? _error;
  String  _search   = '';
  String? _selectedCat; // null = All
  final Set<String> _expanded = {};
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await ApiClient.get('/api/content/faqs', auth: false);
      if (!mounted) return;
      if (res.isSuccess && res.data != null) {
        final d = res.data!;
        final cats  = List<Map<String, dynamic>>.from(d['categories'] as List? ?? []);
        final faqs  = List<Map<String, dynamic>>.from(d['faqs']       as List? ?? []);
        setState(() {
          _categories = cats;
          _faqs       = faqs;
          _filtered   = faqs;
          _loading    = false;
        });
      } else {
        setState(() { _error = res.error ?? 'Failed to load FAQs'; _loading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _error = 'Network error'; _loading = false; });
    }
  }

  void _applyFilter() {
    final q   = _search.toLowerCase().trim();
    final cat = _selectedCat;
    setState(() {
      _filtered = _faqs.where((f) {
        final matchCat = cat == null ||
            f['category_id']?.toString() == cat;
        final matchQ = q.isEmpty ||
            (f['question']?.toString() ?? '').toLowerCase().contains(q) ||
            (f['answer']?.toString()   ?? '').toLowerCase().contains(q);
        return matchCat && matchQ;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          _buildTopBar(),
          if (!_loading && _error == null) _buildSearchBar(),
          Expanded(child: _buildBody()),
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
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Help Center', style: TextStyle(fontSize: 20,
                fontWeight: FontWeight.bold, color: _ink)),
            Text('Frequently Asked Questions',
                style: TextStyle(fontSize: 11, color: _slate)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: Row(children: [
          Icon(Icons.search_rounded, size: 18,
              color: _slate.withValues(alpha: 0.6)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(fontSize: 14, color: _ink),
              decoration: const InputDecoration(
                hintText: 'Search FAQs...',
                hintStyle: TextStyle(fontSize: 13, color: _slate),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (v) { _search = v; _applyFilter(); },
            ),
          ),
          if (_search.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchCtrl.clear();
                _search = '';
                _applyFilter();
              },
              child: Icon(Icons.close_rounded, size: 16,
                  color: _slate.withValues(alpha: 0.7)),
            ),
        ]),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(
          color: _teal, strokeWidth: 2));
    }
    if (_error != null) {
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
              child: const Text('Retry', style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      );
    }

    return CustomScrollView(
      slivers: [
        // Category chips
        if (_categories.isNotEmpty)
          SliverToBoxAdapter(child: _buildCategoryChips()),
        // FAQ count
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              '${_filtered.length} question${_filtered.length == 1 ? '' : 's'}',
              style: TextStyle(fontSize: 12, color: _slate),
            ),
          ),
        ),
        // FAQ list grouped by category
        if (_filtered.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.search_off_rounded, size: 48,
                    color: _slate.withValues(alpha: 0.3)),
                const SizedBox(height: 12),
                Text('No results found',
                    style: TextStyle(fontSize: 14, color: _slate)),
              ]),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                  _buildGroupedFaqs()),
            ),
          ),
      ],
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        children: [
          // All chip
          _chip(null, 'All'),
          ..._categories.map((cat) => _chip(
              cat['id']?.toString(),
              cat['name']?.toString() ?? '')),
        ],
      ),
    );
  }

  Widget _chip(String? catId, String label) {
    final isSelected = _selectedCat == catId;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedCat = catId);
        _applyFilter();
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? _teal : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSelected ? _teal : _border),
          boxShadow: isSelected ? [BoxShadow(
            color: _teal.withValues(alpha: 0.2),
            blurRadius: 6, offset: const Offset(0, 2),
          )] : null,
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : _slate)),
      ),
    );
  }

  List<Widget> _buildGroupedFaqs() {
    if (_search.isNotEmpty || _selectedCat != null) {
      // Flat list when filtering
      return _filtered.map((f) => _buildFaqTile(f)).toList();
    }

    // Grouped by category
    final List<Widget> widgets = [];
    for (final cat in _categories) {
      final catFaqs = _filtered
          .where((f) => f['category_id']?.toString() == cat['id']?.toString())
          .toList();
      if (catFaqs.isEmpty) continue;
      widgets.add(_buildCategoryHeader(cat));
      widgets.addAll(catFaqs.map((f) => _buildFaqTile(f)));
      widgets.add(const SizedBox(height: 8));
    }
    // Uncategorized
    final uncategorized = _filtered
        .where((f) => f['category_id'] == null).toList();
    if (uncategorized.isNotEmpty) {
      widgets.add(_buildCategoryHeader({'name': 'General'}));
      widgets.addAll(uncategorized.map((f) => _buildFaqTile(f)));
    }
    return widgets;
  }

  Widget _buildCategoryHeader(Map<String, dynamic> cat) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Row(children: [
        Container(
          width: 4, height: 16,
          decoration: BoxDecoration(
            color: _teal, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 8),
        Text(cat['name']?.toString() ?? '',
            style: const TextStyle(fontSize: 13,
                fontWeight: FontWeight.bold, color: _ink)),
      ]),
    );
  }

  Widget _buildFaqTile(Map<String, dynamic> faq) {
    final id       = faq['id']?.toString() ?? '';
    final question = faq['question']?.toString() ?? '';
    final answer   = faq['answer']?.toString()   ?? '';
    final isOpen   = _expanded.contains(id);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isOpen
            ? _teal.withValues(alpha: 0.03)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isOpen ? _teal.withValues(alpha: 0.3) : _border),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.02),
          blurRadius: 6, offset: const Offset(0, 2),
        )],
      ),
      child: Column(children: [
        // Question row
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            setState(() {
              if (isOpen) {
                _expanded.remove(id);
              } else {
                _expanded.add(id);
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              Expanded(
                child: Text(question,
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: isOpen ? FontWeight.w700 : FontWeight.w500,
                        color: isOpen ? _ink : const Color(0xFF334155),
                        height: 1.4)),
              ),
              const SizedBox(width: 8),
              AnimatedRotation(
                turns: isOpen ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: isOpen ? _teal : _slate,
                ),
              ),
            ]),
          ),
        ),
        // Answer (animated)
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 220),
          crossFadeState: isOpen
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Divider(height: 1, color: _teal.withValues(alpha: 0.2)),
                const SizedBox(height: 12),
                Text(answer,
                    style: TextStyle(fontSize: 13, color: _slate, height: 1.6)),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}
