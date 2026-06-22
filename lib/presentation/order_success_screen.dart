import 'package:flutter/material.dart';
import 'orders_screen.dart';

class OrderSuccessScreen extends StatefulWidget {
  final String orderNumber;
  final String orderDate;
  final double total;
  final bool awaitingVerification;

  const OrderSuccessScreen({
    super.key,
    required this.orderNumber,
    required this.orderDate,
    required this.total,
    this.awaitingVerification = false,
  });

  @override
  State<OrderSuccessScreen> createState() => _OrderSuccessScreenState();
}

class _OrderSuccessScreenState extends State<OrderSuccessScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  static const Color _ink   = Color(0xFF0F172A);
  static const Color _teal  = Color(0xFF0D9488);
  static const Color _green = Color(0xFF10B981);
  static const Color _slate = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _surface = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _scaleAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl,
            curve: const Interval(0.3, 1.0, curve: Curves.easeIn)));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _fmt(double v) {
    final str = v.toStringAsFixed(0);
    final buf = StringBuffer('₹');
    int c = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      if (c == 3 || (c > 3 && (c - 3) % 2 == 0)) buf.write(',');
      buf.write(str[i]);
      c++;
    }
    return buf.toString().split('').reversed.join();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // Animated checkmark
              AnimatedBuilder(
                animation: _ctrl,
                builder: (_, _) => Transform.scale(
                  scale: _scaleAnim.value,
                  child: Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [_teal, _green],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight),
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(
                        color: _teal.withValues(alpha: 0.3),
                        blurRadius: 24, offset: const Offset(0, 8),
                      )],
                    ),
                    child: const Icon(Icons.check_rounded,
                        color: Colors.white, size: 52),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Title
              FadeTransition(
                opacity: _fadeAnim,
                child: Column(children: [
                  Text(
                    widget.awaitingVerification
                        ? 'Order Received!'
                        : 'Order Placed Successfully!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22,
                        fontWeight: FontWeight.bold, color: _ink)),
                  const SizedBox(height: 10),
                  Text(
                    widget.awaitingVerification
                        ? 'Your UPI payment is being verified.\nWe\'ll confirm your order within a few hours.'
                        : 'Thank you for shopping with Savaan.\nYour order has been placed.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: _slate, height: 1.5),
                  ),
                  if (widget.awaitingVerification) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.hourglass_top_rounded,
                              size: 16, color: Colors.amber),
                          const SizedBox(width: 8),
                          Text('Pending UPI verification',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.amber.shade800,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ]),
              ),

              const SizedBox(height: 32),

              // Order details card
              FadeTransition(
                opacity: _fadeAnim,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _border),
                  ),
                  child: Column(children: [
                    _detailRow(Icons.receipt_outlined, 'Order ID', widget.orderNumber),
                    Divider(color: _border, height: 20),
                    _detailRow(Icons.calendar_today_outlined, 'Order Date', widget.orderDate),
                    Divider(color: _border, height: 20),
                    _detailRow(Icons.currency_rupee_outlined, 'Total Amount',
                        _fmt(widget.total),
                        valueColor: _teal),
                  ]),
                ),
              ),

              const Spacer(),

              // Buttons
              FadeTransition(
                opacity: _fadeAnim,
                child: Column(children: [
                  // Track Order
                  GestureDetector(
                    onTap: () => Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const OrdersScreen()),
                      (route) => route.isFirst,
                    ),
                    child: Container(
                      width: double.infinity, height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _border, width: 1.5),
                      ),
                      child: Center(
                        child: Text('TRACK ORDER',
                            style: TextStyle(color: _ink,
                                fontWeight: FontWeight.bold,
                                fontSize: 14, letterSpacing: 1)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Continue Shopping
                  GestureDetector(
                    onTap: () => Navigator.of(context)
                        .popUntil((route) => route.isFirst),
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
                        child: Text('CONTINUE SHOPPING',
                            style: TextStyle(color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14, letterSpacing: 1)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value,
      {Color? valueColor}) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _teal.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: _teal),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Text(label,
            style: TextStyle(fontSize: 13, color: _slate)),
      ),
      Text(value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: valueColor ?? _ink,
          )),
    ]);
  }
}
