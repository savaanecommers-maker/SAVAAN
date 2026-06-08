import 'package:flutter/material.dart';
import '../models/order_model.dart';
import 'track_order_screen.dart';
import 'return_request_screen.dart';

class OrderDetailScreen extends StatelessWidget {
  final OrderModel order;

  const OrderDetailScreen({super.key, required this.order});

  static const Color _ink     = Color(0xFF0F172A);
  static const Color _teal    = Color(0xFF0D9488);
  static const Color _green   = Color(0xFF10B981);
  static const Color _slate   = Color(0xFF64748B);
  static const Color _border  = Color(0xFFE2E8F0);
  static const Color _surface = Color(0xFFF8FAFC);

  Color _hexToColor(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _hexToColor(order.status.colorHex);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          _buildTopBar(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Order meta
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _border),
                    ),
                    child: Column(children: [
                      _metaRow('Order ID', order.orderNumber,
                          valueStyle: const TextStyle(fontSize: 13,
                              fontWeight: FontWeight.w600, color: _teal)),
                      const Divider(height: 16),
                      _metaRow('Placed on', order.formattedDate),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Status', style: TextStyle(
                              fontSize: 13, color: _slate)),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(order.status.displayLabel,
                                style: TextStyle(fontSize: 12,
                                    color: statusColor,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ]),
                  ),

                  const SizedBox(height: 20),

                  // Order Items
                  const Text('Order Items',
                      style: TextStyle(fontSize: 15,
                          fontWeight: FontWeight.bold, color: _ink)),
                  const SizedBox(height: 12),

                  ...order.items.map((item) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _border),
                      boxShadow: [BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 6, offset: const Offset(0, 2),
                      )],
                    ),
                    child: Row(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: item.productImage != null
                            ? Image.network(item.productImage!,
                                width: 60, height: 60, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _imgPlaceholder(60))
                            : _imgPlaceholder(60),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.productName,
                                maxLines: 2, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13,
                                    fontWeight: FontWeight.w600, color: _ink,
                                    height: 1.3)),
                            const SizedBox(height: 4),
                            Text(
                              'x${item.quantity}  •  ₹${item.price.toStringAsFixed(0)} each',
                              style: TextStyle(fontSize: 11, color: _slate),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '₹${item.totalPrice.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 14,
                            fontWeight: FontWeight.bold, color: _ink),
                      ),
                    ]),
                  )),

                  const SizedBox(height: 20),

                  // Price Breakdown
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _border),
                    ),
                    child: Column(children: [
                      _priceRow('Subtotal', order.formattedSubtotal),
                      if (order.discount > 0) ...[
                        const SizedBox(height: 8),
                        _priceRow(
                          'Discount${order.couponCode != null ? ' (${order.couponCode})' : ''}',
                          '-${order.formattedDiscount}',
                          valueColor: _green,
                        ),
                      ],
                      const SizedBox(height: 8),
                      _priceRow(
                        'Shipping',
                        order.shipping == 0
                            ? 'FREE'
                            : '₹${order.shipping.toStringAsFixed(0)}',
                        valueColor: order.shipping == 0 ? _green : null,
                      ),
                      Divider(color: _border, height: 20),
                      _priceRow('Total', order.formattedTotal, bold: true),
                    ]),
                  ),

                  // Delivery address
                  if (order.address != null) ...[
                    const SizedBox(height: 20),
                    const Text('Delivery Address',
                        style: TextStyle(fontSize: 15,
                            fontWeight: FontWeight.bold, color: _ink)),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _border),
                      ),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _teal.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.location_on_outlined,
                              size: 18, color: _teal),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(order.address!.fullName,
                                style: const TextStyle(fontSize: 13,
                                    fontWeight: FontWeight.w600, color: _ink)),
                            const SizedBox(height: 2),
                            Text(order.address!.fullAddress,
                                style: TextStyle(fontSize: 12,
                                    color: _slate, height: 1.4)),
                            const SizedBox(height: 2),
                            Text(order.address!.phone,
                                style: TextStyle(fontSize: 12, color: _slate)),
                          ],
                        )),
                      ]),
                    ),
                  ],

                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),

          // Buttons row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(children: [
              // Track button — show when in progress
              if (order.status != OrderStatus.cancelled &&
                  order.status != OrderStatus.returned &&
                  order.status != OrderStatus.returnRequested &&
                  order.status != OrderStatus.delivered)
                _buildTrackButton(context),

              // Return button — only for delivered orders
              if (order.status == OrderStatus.delivered) ...[
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => ReturnRequestScreen(order: order))),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF0D9488)),
                    ),
                    child: const Center(
                      child: Text('Request Return / Refund',
                          style: TextStyle(
                              color: Color(0xFF0D9488),
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                    ),
                  ),
                ),
              ],
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
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
        const Expanded(
          child: Text('Order Details',
              style: TextStyle(fontSize: 20,
                  fontWeight: FontWeight.bold, color: _ink)),
        ),
      ]),
    );
  }

  Widget _buildTrackButton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 12, offset: const Offset(0, -3),
        )],
      ),
      child: GestureDetector(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => TrackOrderScreen(order: order))),
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_teal, _green]),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(
              color: _teal.withValues(alpha: 0.3),
              blurRadius: 12, offset: const Offset(0, 4),
            )],
          ),
          child: const Center(
            child: Text('TRACK ORDER',
                style: TextStyle(color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14, letterSpacing: 1)),
          ),
        ),
      ),
    );
  }

  Widget _metaRow(String label, String value, {TextStyle? valueStyle}) =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: 13, color: _slate)),
        Text(value, style: valueStyle ??
            const TextStyle(fontSize: 13,
                fontWeight: FontWeight.w600, color: _ink)),
      ]);

  Widget _priceRow(String label, String value,
      {bool bold = false, Color? valueColor}) =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(
            fontSize: bold ? 14 : 13,
            color: bold ? _ink : _slate,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        Text(value, style: TextStyle(
            fontSize: bold ? 14 : 13,
            color: valueColor ?? (bold ? _ink : _slate),
            fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
      ]);

  Widget _imgPlaceholder(double size) => Container(
    width: size, height: size, color: _surface,
    child: Icon(Icons.image_outlined, size: size * 0.4, color: _border),
  );
}
