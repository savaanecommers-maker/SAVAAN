import 'package:flutter/material.dart';
import '../data/api_client.dart';

/// Generic screen that fetches and renders any legal document by slug.
/// Supports basic markdown-style rendering (##, ###, **, bullet -).
class LegalDocScreen extends StatefulWidget {
  final String slug;
  const LegalDocScreen({super.key, required this.slug});

  @override
  State<LegalDocScreen> createState() => _LegalDocScreenState();
}

class _LegalDocScreenState extends State<LegalDocScreen> {
  static const Color _ink     = Color(0xFF0F172A);
  static const Color _teal    = Color(0xFF0D9488);
  static const Color _slate   = Color(0xFF64748B);
  static const Color _border  = Color(0xFFE2E8F0);
  static const Color _surface = Color(0xFFF8FAFC);

  String  _title   = '';
  String  _content = '';
  String  _updated = '';
  bool    _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiClient.get(
          '/api/content/legal/${widget.slug}', auth: false);
      if (!mounted) return;
      if (res.isSuccess && res.data != null) {
        final d = res.data!;
        setState(() {
          _title   = d['title']?.toString()   ?? '';
          _content = d['content']?.toString() ?? '';
          _updated = _formatDate(d['updated_at']?.toString() ?? '');
          _loading = false;
        });
      } else {
        setState(() {
          _error   = res.error ?? 'Failed to load document';
          _loading = false;
        });
      }
    } on Exception catch (e) {
      if (mounted) setState(() {
        _error = 'Network error: ${e.toString()}';
        _loading = false;
      });
    }
  }

  String _formatDate(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      const months = ['Jan','Feb','Mar','Apr','May','Jun',
                      'Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          _buildTopBar(),
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
        Expanded(
          child: Text(
            _loading ? 'Loading...' : (_title.isNotEmpty ? _title : 'Document'),
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 18,
                fontWeight: FontWeight.bold, color: _ink),
          ),
        ),
      ]),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(
          color: _teal, strokeWidth: 2));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.error_outline_rounded, size: 48,
                color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(_error!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: _slate)),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () { setState(() { _loading = true; _error = null; }); _load(); },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [_teal, Color(0xFF10B981)]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('Retry',
                    style: TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0D9488), Color(0xFF10B981)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(_title,
                  style: const TextStyle(fontSize: 20,
                      fontWeight: FontWeight.bold, color: Colors.white)),
              if (_updated.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('Last updated: $_updated',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.8))),
              ],
            ]),
          ),
          const SizedBox(height: 20),

          // Rendered content
          _renderContent(_content),
        ],
      ),
    );
  }

  /// Simple markdown-like renderer for the content.
  Widget _renderContent(String content) {
    final lines = content.split('\n');
    final widgets = <Widget>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trimRight();

      if (line.startsWith('## ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 8),
          child: Text(line.substring(3),
              style: const TextStyle(fontSize: 17,
                  fontWeight: FontWeight.bold, color: _ink, height: 1.3)),
        ));
        widgets.add(Container(
            height: 2,
            width: 40,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: _teal,
              borderRadius: BorderRadius.circular(1),
            )));
      } else if (line.startsWith('### ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 6),
          child: Text(line.substring(4),
              style: const TextStyle(fontSize: 15,
                  fontWeight: FontWeight.bold, color: _ink)),
        ));
      } else if (line.startsWith('- ') || line.startsWith('* ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 5),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              margin: const EdgeInsets.only(top: 7),
              width: 5, height: 5,
              decoration: const BoxDecoration(
                  color: _teal, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _richText(line.substring(2),
                  const TextStyle(fontSize: 13, color: _ink, height: 1.6)),
            ),
          ]),
        ));
      } else if (line.startsWith('**') && line.endsWith('**') &&
          line.length > 4) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(line.replaceAll('**', ''),
              style: const TextStyle(fontSize: 13,
                  fontWeight: FontWeight.bold, color: _ink)),
        ));
      } else if (line.contains('|') && line.contains('---')) {
        // Skip table separator lines
        continue;
      } else if (line.contains('|')) {
        // Simple table row
        final cells = line.split('|').where((c) => c.trim().isNotEmpty).toList();
        widgets.add(Container(
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: cells.length >= 2 && cells[0].trim().isNotEmpty
                ? _surface : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _border, width: 0.5),
          ),
          child: Row(children: cells.map((c) => Expanded(
            child: Text(c.trim(),
                style: TextStyle(fontSize: 12, color: _ink,
                    fontWeight: cells.indexOf(c) == 0
                        ? FontWeight.w600 : FontWeight.normal)),
          )).toList()),
        ));
      } else if (line.isEmpty) {
        widgets.add(const SizedBox(height: 6));
      } else {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: _richText(line,
              const TextStyle(fontSize: 13, color: _ink, height: 1.6)),
        ));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  /// Renders inline **bold** text.
  Widget _richText(String text, TextStyle baseStyle) {
    if (!text.contains('**')) {
      return Text(text, style: baseStyle);
    }
    final spans = <TextSpan>[];
    final parts  = text.split('**');
    for (int i = 0; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;
      if (i.isOdd) {
        spans.add(TextSpan(text: parts[i],
            style: baseStyle.copyWith(fontWeight: FontWeight.bold)));
      } else {
        spans.add(TextSpan(text: parts[i], style: baseStyle));
      }
    }
    return RichText(text: TextSpan(children: spans));
  }
}
