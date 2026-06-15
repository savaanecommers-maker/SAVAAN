import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/order_model.dart';
import '../providers/order_provider.dart';
import 'order_detail_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  static const Color _ink     = Color(0xFF0F172A);
  static const Color _teal    = Color(0xFF0D9488);
  static const Color _green   = Color(0xFF10B981);
  static const Color _slate   = Color(0xFF64748B);
  static const Color _border  = Color(0xFFE2E8F0);
  static const Color _surface = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrderProvider>().loadOrders(force: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<OrderProvider>();
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          _buildTopBar(),
          Expanded(
            child: orderProvider.isLoading
                ? const Center(child: CircularProgressIndicator(color: _teal))
                : orderProvider.loadError != null && orderProvider.orders.isEmpty
                    ? _buildError(orderProvider.loadError!)
                    : orderProvider.orders.isEmpty
                        ? _buildEmpty()
                        : RefreshIndicator(
                            color: _teal,
                            onRefresh: () =>
                                context.read<OrderProvider>().loadOrders(force: true),
                            child: ListView.builder(
                              padding: const EdgeInsets.only(bottom: 16),
                              itemCount: orderProvider.orders.length,
                              itemBuilder: (_, i) =>
                                  _buildOrderCard(orderProvider.orders[i]),
                            ),
                          ),
          ),
        ]),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
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
          child: Text('My Orders',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _ink)),
        ),
      ]),
    );
  }

  Widget _buildOrderCard(OrderModel order) {
    final statusColor = _hexToColor(order.status.colorHex);
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => OrderDetailScreen(order: order))),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8, offset: const Offset(0, 3),
          )],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(order.orderNumber,
                      style: const TextStyle(fontSize: 13,
                          fontWeight: FontWeight.bold, color: _ink)),
                  const SizedBox(height: 2),
                  Text(order.formattedDate,
                      style: TextStyle(fontSize: 11, color: _slate)),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(order.status.displayLabel,
                    style: TextStyle(fontSize: 11, color: statusColor,
                        fontWeight: FontWeight.w600)),
              ),
            ]),
          ),

          // Items preview
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...order.items.take(2).map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: item.productImage != null
                          ? CachedNetworkImage(imageUrl: item.productImage!,
                              width: 44, height: 44, fit: BoxFit.cover,
                              memCacheWidth: 88,
                              placeholder: (_, url) => Container(width: 44, height: 44, color: _border),
                              errorWidget: (_, url, err) =>
                                  Container(width: 44, height: 44, color: _border))
                          : Container(width: 44, height: 44, color: _border,
                              child: Icon(Icons.image_outlined, size: 20, color: _slate)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(item.productName,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12,
                              fontWeight: FontWeight.w500, color: _ink)),
                    ),
                    Text('x${item.quantity}',
                        style: TextStyle(fontSize: 11, color: _slate)),
                  ]),
                )),
                if (order.items.length > 2)
                  Text('+${order.items.length - 2} more item(s)',
                      style: TextStyle(fontSize: 11, color: _teal,
                          fontWeight: FontWeight.w500)),
              ],
            ),
          ),

          // Footer
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('${order.items.length} item(s)',
                  style: TextStyle(fontSize: 12, color: _slate)),
              Text(order.formattedTotal,
                  style: const TextStyle(fontSize: 14,
                      fontWeight: FontWeight.bold, color: _ink)),
            ]),
          ),

          // Tracking bar (only for active orders)
          if (order.status != OrderStatus.cancelled &&
              order.status != OrderStatus.returned &&
              order.status != OrderStatus.returnRequested)
            _buildTrackingBar(order),
        ]),
      ),
    );
  }

  Widget _buildTrackingBar(OrderModel order) {
    final steps = ['Placed', 'Confirmed', 'Packed', 'Shipped', 'Out for\nDelivery', 'Delivered'];
    final currentStep = order.status.trackingStep;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Row(
        children: List.generate(steps.length, (i) {
          final isDone = i <= currentStep;
          final isActive = i == currentStep;
          return Expanded(
            child: Row(children: [
              Expanded(
                child: Column(children: [
                  // Step dot
                  Container(
                    width: 20, height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDone ? _teal : _border,
                      border: isActive
                          ? Border.all(color: _teal, width: 2.5)
                          : null,
                    ),
                    child: isDone && !isActive
                        ? const Icon(Icons.check, color: Colors.white, size: 12)
                        : isActive
                            ? Container(
                                margin: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                    color: Colors.white, shape: BoxShape.circle))
                            : null,
                  ),
                  const SizedBox(height: 4),
                  Text(steps[i],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 9,
                        color: isDone ? _teal : _slate,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                        height: 1.2,
                      )),
                ]),
              ),
              // Connector line (not after last)
              if (i < steps.length - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.only(bottom: 20),
                    color: i < currentStep ? _teal : _border,
                  ),
                ),
            ]),
          );
        }),
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.error_outline_rounded, size: 56,
              color: Colors.redAccent.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          const Text('Could not load orders',
              style: TextStyle(fontSize: 17,
                  fontWeight: FontWeight.w600, color: _ink)),
          const SizedBox(height: 8),
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: _slate)),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => context.read<OrderProvider>().loadOrders(force: true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_teal, _green]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('Retry',
                  style: TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w600, fontSize: 14)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.receipt_long_outlined, size: 64,
            color: _slate.withValues(alpha: 0.25)),
        const SizedBox(height: 16),
        const Text('No orders yet',
            style: TextStyle(fontSize: 17,
                fontWeight: FontWeight.w600, color: _ink)),
        const SizedBox(height: 8),
        Text('Your orders will appear here',
            style: TextStyle(fontSize: 13, color: _slate)),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_teal, _green]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('Start Shopping',
                style: TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w600, fontSize: 14)),
          ),
        ),
      ]),
    );
  }

  Color _hexToColor(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }
}
