import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/api_client.dart';
import '../models/order_model.dart';
import '../providers/order_provider.dart';
import 'track_order_screen.dart';
import 'return_request_screen.dart';

class OrderDetailScreen extends StatefulWidget {
  final OrderModel order;

  const OrderDetailScreen({super.key, required this.order});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  static const Color _ink     = Color(0xFF0F172A);
  static const Color _teal    = Color(0xFF0D9488);
  static const Color _green   = Color(0xFF10B981);
  static const Color _slate   = Color(0xFF64748B);
  static const Color _border  = Color(0xFFE2E8F0);
  static const Color _surface = Color(0xFFF8FAFC);

  late OrderModel _order;
  bool _loadingDetail = false;

  // Track which product IDs have already been reviewed in this session
  final Set<String> _reviewed = {};

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    setState(() => _loadingDetail = true);
    final res = await ApiClient.get('/api/orders/${_order.id}');
    if (res.isSuccess && res.data != null && mounted) {
      try {
        final fetched = OrderModel.fromJson(res.data!);
        setState(() {
          _order = fetched;
          _loadingDetail = false;
        });
        return;
      } catch (_) {}
    }
    if (mounted) setState(() => _loadingDetail = false);
  }

  Color _hexToColor(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _hexToColor(_order.status.colorHex);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          _buildTopBar(context),
          Expanded(
            child: _loadingDetail
                ? const Center(child: CircularProgressIndicator(color: _teal))
                : SingleChildScrollView(
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
                            _metaRow('Order ID', _order.orderNumber,
                                valueStyle: const TextStyle(fontSize: 13,
                                    fontWeight: FontWeight.w600, color: _teal)),
                            const Divider(height: 16),
                            _metaRow('Placed on', _order.formattedDate),
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
                                  child: Text(_order.status.displayLabel,
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

                        if (_order.items.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _border),
                            ),
                            child: Center(
                              child: Text('No item details available',
                                  style: TextStyle(fontSize: 13, color: _slate)),
                            ),
                          ),

                        ..._order.items.map((item) => Container(
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
                                  ? CachedNetworkImage(
                                      imageUrl: item.productImage!,
                                      width: 60, height: 60, fit: BoxFit.cover,
                                      placeholder: (_, url) => _imgPlaceholder(60),
                                      errorWidget: (_, url, err) => _imgPlaceholder(60))
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
                                  if (item.variantLabel != null) ...[
                                    const SizedBox(height: 2),
                                    Text(item.variantLabel!,
                                        style: const TextStyle(fontSize: 11,
                                            color: _teal,
                                            fontWeight: FontWeight.w500)),
                                  ],
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
                            _priceRow('Subtotal', _order.formattedSubtotal),
                            if (_order.discount > 0) ...[
                              const SizedBox(height: 8),
                              _priceRow(
                                'Discount${_order.couponCode != null ? ' (${_order.couponCode})' : ''}',
                                '-${_order.formattedDiscount}',
                                valueColor: _green,
                              ),
                            ],
                            const SizedBox(height: 8),
                            _priceRow(
                              'Shipping',
                              _order.shipping == 0
                                  ? 'FREE'
                                  : '₹${_order.shipping.toStringAsFixed(0)}',
                              valueColor: _order.shipping == 0 ? _green : null,
                            ),
                            Divider(color: _border, height: 20),
                            _priceRow('Total', _order.formattedTotal, bold: true),
                          ]),
                        ),

                        // Delivery address
                        if (_order.address != null) ...[
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
                                child: const Icon(Icons.location_on_outlined,
                                    size: 18, color: _teal),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_order.address!.fullName,
                                      style: const TextStyle(fontSize: 13,
                                          fontWeight: FontWeight.w600, color: _ink)),
                                  const SizedBox(height: 2),
                                  Text(_order.address!.fullAddress,
                                      style: TextStyle(fontSize: 12,
                                          color: _slate, height: 1.4)),
                                  const SizedBox(height: 2),
                                  Text(_order.address!.phone,
                                      style: TextStyle(fontSize: 12, color: _slate)),
                                ],
                              )),
                            ]),
                          ),
                        ],

                        // ── Rate & Review section (delivered orders only) ──────
                        if (_order.status == OrderStatus.delivered &&
                            _order.items.isNotEmpty) ...[
                          const SizedBox(height: 28),
                          const Text('Rate & Review',
                              style: TextStyle(fontSize: 15,
                                  fontWeight: FontWeight.bold, color: _ink)),
                          const SizedBox(height: 4),
                          Text('Share your experience with the products you received.',
                              style: TextStyle(fontSize: 12, color: _slate)),
                          const SizedBox(height: 12),
                          ..._order.items.map((item) {
                            final alreadyReviewed =
                                _reviewed.contains(item.productId ?? item.id);
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                              decoration: BoxDecoration(
                                color: alreadyReviewed
                                    ? _green.withValues(alpha: 0.06)
                                    : _surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: alreadyReviewed ? _green : _border,
                                ),
                              ),
                              child: Row(children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: item.productImage != null
                                      ? CachedNetworkImage(
                                          imageUrl: item.productImage!,
                                          width: 40, height: 40, fit: BoxFit.cover,
                                          placeholder: (_, url) =>
                                              _imgPlaceholder(40),
                                          errorWidget: (_, url, err) =>
                                              _imgPlaceholder(40))
                                      : _imgPlaceholder(40),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(item.productName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: _ink)),
                                ),
                                const SizedBox(width: 8),
                                if (alreadyReviewed)
                                  Row(children: [
                                    const Icon(Icons.check_circle,
                                        color: _green, size: 16),
                                    const SizedBox(width: 4),
                                    Text('Reviewed',
                                        style: TextStyle(
                                            fontSize: 11, color: _green,
                                            fontWeight: FontWeight.w600)),
                                  ])
                                else
                                  GestureDetector(
                                    onTap: () => _openReviewSheet(item),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: _teal,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text('Write Review',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600)),
                                    ),
                                  ),
                              ]),
                            );
                          }),
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
              if (_order.status != OrderStatus.cancelled &&
                  _order.status != OrderStatus.returned &&
                  _order.status != OrderStatus.returnRequested &&
                  _order.status != OrderStatus.delivered)
                _buildTrackButton(context),

              // Cancel button — only for pending/confirmed orders
              if (_order.status == OrderStatus.processing ||
                  _order.status == OrderStatus.confirmed) ...[
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Cancel Order'),
                        content: const Text(
                            'Are you sure you want to cancel this order?'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('No')),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Yes, Cancel',
                                style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true && context.mounted) {
                      final err = await context
                          .read<OrderProvider>()
                          .cancelOrder(_order.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content:
                              Text(err ?? 'Order cancelled successfully'),
                          backgroundColor: err != null
                              ? Colors.red
                              : const Color(0xFF0D9488),
                        ));
                        if (err == null) Navigator.pop(context);
                      }
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.red.shade300),
                    ),
                    child: Center(
                      child: Text('Cancel Order',
                          style: TextStyle(
                              color: Colors.red.shade600,
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                    ),
                  ),
                ),
              ],

              // Return button — only for delivered orders
              if (_order.status == OrderStatus.delivered) ...[
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              ReturnRequestScreen(order: _order))),
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

  // ── Review bottom sheet ────────────────────────────────────────────────────

  void _openReviewSheet(OrderItemModel item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReviewSheet(
        item: item,
        orderId: _order.id,
        onSubmitted: () {
          setState(() {
            _reviewed.add(item.productId ?? item.id);
          });
        },
      ),
    );
  }

  // ── Helper widgets ─────────────────────────────────────────────────────────

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
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: _ink)),
        ),
      ]),
    );
  }

  Widget _buildTrackButton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -3),
          )
        ],
      ),
      child: GestureDetector(
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => TrackOrderScreen(order: _order))),
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_teal, _green]),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: _teal.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: const Center(
            child: Text('TRACK ORDER',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 1)),
          ),
        ),
      ),
    );
  }

  Widget _metaRow(String label, String value, {TextStyle? valueStyle}) =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: 13, color: _slate)),
        Text(value,
            style: valueStyle ??
                const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _ink)),
      ]);

  Widget _priceRow(String label, String value,
          {bool bold = false, Color? valueColor}) =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label,
            style: TextStyle(
                fontSize: bold ? 14 : 13,
                color: bold ? _ink : _slate,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        Text(value,
            style: TextStyle(
                fontSize: bold ? 14 : 13,
                color: valueColor ?? (bold ? _ink : _slate),
                fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
      ]);

  Widget _imgPlaceholder(double size) => Container(
        width: size,
        height: size,
        color: _surface,
        child: Icon(Icons.image_outlined, size: size * 0.4, color: _border),
      );
}

// ── Review Sheet ───────────────────────────────────────────────────────────────

class _ReviewSheet extends StatefulWidget {
  final OrderItemModel item;
  final String orderId;
  final VoidCallback onSubmitted;

  const _ReviewSheet({
    required this.item,
    required this.orderId,
    required this.onSubmitted,
  });

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  static const Color _ink    = Color(0xFF0F172A);
  static const Color _teal   = Color(0xFF0D9488);
  static const Color _slate  = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _surface = Color(0xFFF8FAFC);

  int _rating = 0;
  final _titleCtrl   = TextEditingController();
  final _commentCtrl = TextEditingController();
  bool _submitting   = false;
  String? _error;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      setState(() => _error = 'Please select a star rating');
      return;
    }
    setState(() { _submitting = true; _error = null; });

    final productId = widget.item.productId ?? '';
    final res = await ApiClient.post('/api/reviews', {
      'product_id': productId,
      'order_id':   widget.orderId,
      'rating':     _rating,
      if (_titleCtrl.text.trim().isNotEmpty) 'title': _titleCtrl.text.trim(),
      if (_commentCtrl.text.trim().isNotEmpty) 'body': _commentCtrl.text.trim(),
    });

    if (!mounted) return;
    if (res.isSuccess) {
      Navigator.pop(context);
      widget.onSubmitted();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Review submitted! Thank you.'),
        backgroundColor: Color(0xFF0D9488),
      ));
    } else {
      setState(() {
        _submitting = false;
        _error = res.error ?? 'Failed to submit review';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: _border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              const Text('Write a Review',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: _ink)),
              const SizedBox(height: 4),
              Text(widget.item.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: _slate)),

              const SizedBox(height: 20),

              // Star rating
              const Text('Your Rating',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _ink)),
              const SizedBox(height: 8),
              Row(
                children: List.generate(5, (i) {
                  final star = i + 1;
                  return GestureDetector(
                    onTap: () => setState(() => _rating = star),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(
                        _rating >= star ? Icons.star : Icons.star_border,
                        color: _rating >= star
                            ? const Color(0xFFF59E0B)
                            : _slate,
                        size: 34,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),

              // Title field
              const Text('Title (optional)',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _ink)),
              const SizedBox(height: 6),
              TextField(
                controller: _titleCtrl,
                decoration: InputDecoration(
                  hintText: 'e.g. Great quality!',
                  hintStyle: TextStyle(color: _slate, fontSize: 13),
                  filled: true,
                  fillColor: _surface,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: _border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: _border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _teal),
                  ),
                ),
                style: const TextStyle(fontSize: 13, color: _ink),
              ),
              const SizedBox(height: 12),

              // Comment field
              const Text('Review (optional)',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _ink)),
              const SizedBox(height: 6),
              TextField(
                controller: _commentCtrl,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Share your experience with this product...',
                  hintStyle: TextStyle(color: _slate, fontSize: 13),
                  filled: true,
                  fillColor: _surface,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: _border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: _border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _teal),
                  ),
                ),
                style: const TextStyle(fontSize: 13, color: _ink),
              ),

              // Error message
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.red)),
              ],

              const SizedBox(height: 20),

              // Submit button
              GestureDetector(
                onTap: _submitting ? null : _submit,
                child: Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: _submitting
                        ? null
                        : const LinearGradient(
                            colors: [_teal, Color(0xFF10B981)]),
                    color: _submitting ? _border : null,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white))
                        : const Text('Submit Review',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
