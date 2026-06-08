import 'package:flutter/material.dart';
import '../models/order_model.dart';

class TrackOrderScreen extends StatelessWidget {
  final OrderModel order;
  const TrackOrderScreen({super.key, required this.order});

  static const Color _ink     = Color(0xFF0F172A);
  static const Color _teal    = Color(0xFF0D9488);
  static const Color _green   = Color(0xFF10B981);
  static const Color _slate   = Color(0xFF64748B);
  static const Color _border  = Color(0xFFE2E8F0);
  static const Color _surface = Color(0xFFF8FAFC);

  @override
  Widget build(BuildContext context) {
    final steps = _buildSteps();
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          // Top bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
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
                child: Text('Track Order',
                    style: TextStyle(fontSize: 20,
                        fontWeight: FontWeight.bold, color: _ink)),
              ),
            ]),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Order number
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _border),
                    ),
                    child: Row(children: [
                      Icon(Icons.receipt_outlined, size: 18, color: _teal),
                      const SizedBox(width: 10),
                      Text(order.orderNumber,
                          style: const TextStyle(fontSize: 14,
                              fontWeight: FontWeight.bold, color: _ink)),
                    ]),
                  ),
                  const SizedBox(height: 24),

                  // Timeline
                  ...List.generate(steps.length, (i) {
                    final step = steps[i];
                    final isDone = step['done'] as bool;
                    final isLast = i == steps.length - 1;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Dot + line
                        Column(children: [
                          Container(
                            width: 22, height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDone ? _teal : Colors.white,
                              border: Border.all(
                                  color: isDone ? _teal : _border, width: 2),
                            ),
                            child: isDone
                                ? const Icon(Icons.check, color: Colors.white, size: 13)
                                : null,
                          ),
                          if (!isLast)
                            Container(
                              width: 2, height: 52,
                              color: isDone ? _teal : _border,
                            ),
                        ]),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(step['label'] as String,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isDone
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                      color: isDone ? _ink : _slate,
                                    )),
                                const SizedBox(height: 3),
                                Text(step['date'] as String,
                                    style: TextStyle(fontSize: 12, color: _slate)),
                                if (!isLast) const SizedBox(height: 30),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  }),

                  const SizedBox(height: 24),

                  // Help button
                  Center(
                    child: GestureDetector(
                      onTap: () => showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.white,
                        shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                                top: Radius.circular(24))),
                        builder: (_) => _TrackHelpSheet(),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _border),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.help_outline_rounded,
                              size: 16, color: _slate),
                          const SizedBox(width: 6),
                          Text('NEED HELP?',
                              style: TextStyle(
                                  fontSize: 12, color: _slate,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.8)),
                        ]),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  List<Map<String, dynamic>> _buildSteps() {
    final currentStep = order.status.trackingStep;
    final createdAt = order.createdAt;
    String dateFmt(DateTime? dt, {int addDays = 0}) {
      if (dt == null) return '';
      final d = dt.add(Duration(days: addDays));
      final months = ['Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'];
      final h = d.hour; final m = d.minute.toString().padLeft(2, '0');
      final period = h >= 12 ? 'PM' : 'AM';
      final hour = (h % 12 == 0 ? 12 : h % 12).toString().padLeft(2, '0');
      return '${d.day} ${months[d.month - 1]} ${d.year}, $hour:$m $period';
    }

    return [
      {
        'label': 'Order Placed',
        'date': dateFmt(createdAt),
        'done': currentStep >= 0,
      },
      {
        'label': 'Payment Confirmed',
        'date': currentStep >= 1 ? dateFmt(createdAt, addDays: 0) : 'Pending',
        'done': currentStep >= 1,
      },
      {
        'label': 'Order Processing',
        'date': currentStep >= 1 ? dateFmt(createdAt, addDays: 1) : 'Pending',
        'done': currentStep >= 1,
      },
      {
        'label': 'Shipped',
        'date': currentStep >= 2 ? dateFmt(createdAt, addDays: 2) : 'Pending',
        'done': currentStep >= 2,
      },
      {
        'label': 'Out for Delivery',
        'date': currentStep >= 3 ? dateFmt(createdAt, addDays: 3) : 'Pending',
        'done': currentStep >= 3,
      },
      {
        'label': 'Delivered',
        'date': currentStep >= 4
            ? dateFmt(createdAt, addDays: 4)
            : createdAt != null
                ? 'Expected on ${dateFmt(createdAt, addDays: 5)}'
                : 'Pending',
        'done': currentStep >= 4,
      },
    ];
  }
}

// ── Inline help sheet for track order ───────────────────────────────────────
class _TrackHelpSheet extends StatelessWidget {
  static const Color _ink    = Color(0xFF0F172A);
  static const Color _slate  = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);

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
          child: Text('Help & Support',
              style: TextStyle(fontSize: 18,
                  fontWeight: FontWeight.bold, color: _ink)),
        ),
        const SizedBox(height: 16),
        _tile(Icons.email_outlined,    'Email Us',
            'support@savaan.in',    const Color(0xFF6366F1)),
        const SizedBox(height: 10),
        _tile(Icons.phone_outlined,    'Call Us',
            '+91 98765 43210',      const Color(0xFF10B981)),
        const SizedBox(height: 10),
        _tile(Icons.chat_bubble_outline_rounded, 'Live Chat',
            'Available 9 AM – 9 PM', const Color(0xFF0EA5E9)),
      ]),
    );
  }

  Widget _tile(IconData icon, String title, String sub, Color color) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: _ink)),
            const SizedBox(height: 2),
            Text(sub, style: TextStyle(fontSize: 12, color: _slate)),
          ]),
        ]),
      );
}
