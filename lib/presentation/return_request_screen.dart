import 'package:flutter/material.dart';
import '../data/return_service.dart';
import '../models/order_model.dart';

class ReturnRequestScreen extends StatefulWidget {
  final OrderModel order;
  const ReturnRequestScreen({super.key, required this.order});

  @override
  State<ReturnRequestScreen> createState() => _ReturnRequestScreenState();
}

class _ReturnRequestScreenState extends State<ReturnRequestScreen> {
  final _returnService   = ReturnService();
  final _descController  = TextEditingController();
  final _formKey         = GlobalKey<FormState>();

  String?  _selectedReason;
  bool     _isSubmitting = false;
  bool     _submitted    = false;
  String?  _existingReturn;

  static const Color _ink     = Color(0xFF0F172A);
  static const Color _teal    = Color(0xFF0D9488);
  static const Color _slate   = Color(0xFF64748B);
  static const Color _border  = Color(0xFFE2E8F0);
  static const Color _surface = Color(0xFFF8FAFC);
  static const Color _red     = Color(0xFFEF4444);

  static const List<String> _reasons = [
    'Wrong item received',
    'Item damaged or defective',
    'Item not as described',
    'Size/fit issue',
    'Changed my mind',
    'Item arrived too late',
    'Missing parts or accessories',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _checkExisting();
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _checkExisting() async {
    final existing = await _returnService.getReturnForOrder(widget.order.id);
    if (existing != null && mounted) {
      setState(() => _existingReturn = existing['status'] as String?);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a return reason')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final error = await _returnService.submitReturn(
      orderId: widget.order.id,
      reason:  _selectedReason!,
      notes:   _descController.text.trim().isEmpty
          ? null : _descController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: _red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } else {
      setState(() => _submitted = true);
    }
  }

  String _statusLabel(String status) {
    const labels = {
      'requested':        'Submitted',
      'under_review':     'Under Review',
      'approved':         'Approved',
      'rejected':         'Rejected',
      'pickup_scheduled': 'Pickup Scheduled',
      'picked_up':        'Picked Up',
      'refund_initiated': 'Refund Initiated',
      'refund_completed': 'Refund Completed',
    };
    return labels[status] ?? status;
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
      case 'refund_completed': return const Color(0xFF10B981);
      case 'rejected':         return _red;
      case 'refund_initiated': return const Color(0xFF6366F1);
      default:                 return _teal;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          _buildTopBar(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _existingReturn != null
                  ? _buildExistingReturn()
                  : _submitted
                      ? _buildSuccess()
                      : _buildForm(),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildTopBar() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
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
      const Text('Request Return',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _ink)),
    ]),
  );

  Widget _buildExistingReturn() => Column(
    children: [
      const SizedBox(height: 24),
      Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
          color: _teal.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.assignment_turned_in_outlined, size: 36, color: _teal),
      ),
      const SizedBox(height: 16),
      Text('Return Request Submitted',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _ink)),
      const SizedBox(height: 8),
      Text('for Order ${widget.order.orderNumber}',
          style: TextStyle(fontSize: 13, color: _slate)),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: _statusColor(_existingReturn!).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          'Status: ${_statusLabel(_existingReturn!)}',
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: _statusColor(_existingReturn!)),
        ),
      ),
      const SizedBox(height: 24),
      Text('Our team will review your request and update you via notifications.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: _slate, height: 1.5)),
    ],
  );

  Widget _buildSuccess() => Column(
    children: [
      const SizedBox(height: 40),
      Container(
        width: 80, height: 80,
        decoration: BoxDecoration(
          color: const Color(0xFFDCFCE7),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_circle_outline_rounded, size: 44, color: Color(0xFF16A34A)),
      ),
      const SizedBox(height: 20),
      const Text('Return Requested!',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _ink)),
      const SizedBox(height: 10),
      Text(
        'Your return request for Order ${widget.order.orderNumber} has been submitted.\n\nOur team will review it within 24–48 hours.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13, color: _slate, height: 1.6),
      ),
      const SizedBox(height: 32),
      GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF0D9488), Color(0xFF10B981)]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Center(
            child: Text('Back to Orders',
                style: TextStyle(color: Colors.white,
                    fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        ),
      ),
    ],
  );

  Widget _buildForm() => Form(
    key: _formKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Order info
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: Row(children: [
            const Icon(Icons.shopping_bag_outlined, size: 18, color: _teal),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.order.orderNumber,
                    style: const TextStyle(fontWeight: FontWeight.bold,
                        fontSize: 13, color: _teal)),
                Text('₹${widget.order.total.toStringAsFixed(0)} · ${widget.order.items.length} item(s)',
                    style: TextStyle(fontSize: 11, color: _slate)),
              ],
            )),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(8)),
              child: const Text('Delivered',
                  style: TextStyle(fontSize: 10, color: Color(0xFF16A34A),
                      fontWeight: FontWeight.w600)),
            ),
          ]),
        ),

        const SizedBox(height: 20),

        // Reason
        const Text('Reason for Return *',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _ink)),
        const SizedBox(height: 10),
        ...List.generate(_reasons.length, (i) {
          final reason = _reasons[i];
          final selected = _selectedReason == reason;
          return GestureDetector(
            onTap: () => setState(() => _selectedReason = reason),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: selected ? _teal.withValues(alpha: 0.08) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? _teal : _border,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Row(children: [
                Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    size: 18, color: selected ? _teal : _slate),
                const SizedBox(width: 10),
                Text(reason,
                    style: TextStyle(
                        fontSize: 13,
                        color: selected ? _teal : _ink,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
              ]),
            ),
          );
        }),

        const SizedBox(height: 16),

        // Description
        const Text('Additional Details (Optional)',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _ink)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _descController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Describe the issue in detail...',
            hintStyle: TextStyle(color: _slate.withValues(alpha: 0.5), fontSize: 13),
            contentPadding: const EdgeInsets.all(14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _teal),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Info box
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFED7AA)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.info_outline, size: 16, color: Color(0xFFD97706)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Returns are accepted within 7 days of delivery. Our team will review and respond within 24–48 hours.',
                style: const TextStyle(fontSize: 11, color: Color(0xFF92400E), height: 1.4),
              ),
            ),
          ]),
        ),

        const SizedBox(height: 24),

        // Submit button
        GestureDetector(
          onTap: _isSubmitting ? null : _submit,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              gradient: _isSubmitting
                  ? null
                  : const LinearGradient(
                      colors: [Color(0xFF0D9488), Color(0xFF10B981)]),
              color: _isSubmitting ? _border : null,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Submit Return Request',
                      style: TextStyle(color: Colors.white,
                          fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
        ),

        const SizedBox(height: 20),
      ],
    ),
  );
}
