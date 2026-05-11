import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme.dart';

class SellerOrdersScreen extends StatefulWidget {
  final int? initialOrderId;
  const SellerOrdersScreen({super.key, this.initialOrderId});

  @override
  State<SellerOrdersScreen> createState() => _SellerOrdersScreenState();
}

class _SellerOrdersScreenState extends State<SellerOrdersScreen> {
  final _api = ApiService();
  List _orders = [];
  bool _loading = true;
  String _filter = '';

  final _filters = [
    {'value': '',                'label': 'All'},
    {'value': 'pending',         'label': 'Pending'},
    {'value': 'cancel_requested','label': 'Cancel Req'},
    {'value': 'verified',        'label': 'Verified'},
    {'value': 'shipped',         'label': 'Shipped'},
    {'value': 'delivered',       'label': 'Delivered'},
    {'value': 'cancelled',       'label': 'Cancelled'},
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _api.getSellerOrders(status: _filter);
      if (!mounted) return;
      setState(() => _orders = data);
      // If opened from dashboard with a specific order, scroll to it
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'delivered':        return AppColors.success;
      case 'cancelled':        return AppColors.error;
      case 'pending':          return AppColors.goldMid;
      case 'verified':         return AppColors.gold;
      case 'shipped':          return Colors.blue;
      case 'cancel_requested': return Colors.orange;
      default:                 return AppColors.textMuted;
    }
  }

  void _showOrderDetail(Map o) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _OrderDetailSheet(
        order: o,
        onAction: _load,
        api: _api,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Orders')),
      body: Column(
        children: [
          // Filter chips
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _filters.length,
              separatorBuilder: (ctx, i) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final f = _filters[i];
                final selected = _filter == f['value'];
                return GestureDetector(
                  onTap: () {
                    setState(() => _filter = f['value']!);
                    _load();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.gold : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: selected ? AppColors.gold : AppColors.border),
                    ),
                    child: Text(f['label']!,
                        style: GoogleFonts.inter(
                            color: selected
                                ? AppColors.background
                                : AppColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.gold))
                : _orders.isEmpty
                    ? Center(
                        child: Text('No orders found',
                            style: GoogleFonts.inter(
                                color: AppColors.textMuted, fontSize: 14)))
                    : RefreshIndicator(
                        color: AppColors.gold,
                        backgroundColor: AppColors.surface,
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _orders.length,
                          separatorBuilder: (ctx, i) =>
                              const SizedBox(height: 10),
                          itemBuilder: (ctx, i) {
                            final o = _orders[i];
                            final statusColor =
                                _statusColor(o['status'] ?? '');
                            final isCancelReq =
                                o['status'] == 'cancel_requested';
                            return GestureDetector(
                              onTap: () => _showOrderDetail(o),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: isCancelReq
                                          ? Colors.orange.withAlpha(150)
                                          : AppColors.border),
                                ),
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(o['order_number'],
                                            style: GoogleFonts.orbitron(
                                                color: AppColors.textPrimary,
                                                fontSize: 12,
                                                fontWeight:
                                                    FontWeight.w700)),
                                        Container(
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 3),
                                          decoration: BoxDecoration(
                                            color:
                                                statusColor.withAlpha(30),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            border: Border.all(
                                                color: statusColor
                                                    .withAlpha(100)),
                                          ),
                                          child: Text(
                                              o['status']
                                                  .toString()
                                                  .toUpperCase(),
                                              style: GoogleFonts.inter(
                                                  color: statusColor,
                                                  fontSize: 9,
                                                  fontWeight:
                                                      FontWeight.w700,
                                                  letterSpacing: 0.5)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                            'Buyer: ${o['buyer'] ?? ''}',
                                            style: GoogleFonts.inter(
                                                color: AppColors.textMuted,
                                                fontSize: 12)),
                                        Text('₱${o['total_amount']}',
                                            style: GoogleFonts.inter(
                                                color: AppColors.gold,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14)),
                                      ],
                                    ),
                                    if (isCancelReq &&
                                        o['cancel_reason'] != null) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                          '⚠️ Cancel reason: ${o['cancel_reason']}',
                                          style: GoogleFonts.inter(
                                              color: Colors.orange,
                                              fontSize: 11)),
                                    ],
                                    const SizedBox(height: 8),
                                    Text('Tap to manage →',
                                        style: GoogleFonts.inter(
                                            color: AppColors.gold,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

// ── Order detail bottom sheet with seller actions ─────────────────────────────

class _OrderDetailSheet extends StatefulWidget {
  final Map order;
  final VoidCallback onAction;
  final ApiService api;
  const _OrderDetailSheet(
      {required this.order, required this.onAction, required this.api});

  @override
  State<_OrderDetailSheet> createState() => _OrderDetailSheetState();
}

class _OrderDetailSheetState extends State<_OrderDetailSheet> {
  bool _busy = false;

  Future<void> _act(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      Navigator.pop(context);
      widget.onAction();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showCancelDialog() async {
    final ctrl = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.border)),
        title: Text('Cancel Order',
            style: GoogleFonts.orbitron(
                color: AppColors.error, fontSize: 15)),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration:
              const InputDecoration(hintText: 'Reason for cancellation...'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Back')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white),
            child: const Text('Cancel Order'),
          ),
        ],
      ),
    );
    if (confirmed != true || ctrl.text.trim().isEmpty) return;
    await _act(() async {
      await widget.api
          .cancelOrder(widget.order['id'], reason: ctrl.text.trim());
      messenger.showSnackBar(
          const SnackBar(content: Text('Order cancelled')));
    });
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final status = o['status'] ?? '';
    final items = o['items'] as List? ?? [];

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (ctx, scroll) => SingleChildScrollView(
        controller: scroll,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text(o['order_number'],
                style: GoogleFonts.orbitron(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Buyer: ${o['buyer'] ?? ''}  •  ₱${o['total_amount']}',
                style: GoogleFonts.inter(
                    color: AppColors.textMuted, fontSize: 13)),
            const SizedBox(height: 4),
            Text('${o['delivery_address'] ?? ''}, ${o['delivery_city'] ?? ''}',
                style: GoogleFonts.inter(
                    color: AppColors.textMuted, fontSize: 12)),
            const Divider(height: 20),

            // Items
            ...items.map<Widget>((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                            '${item['product_name']}${item['variant_size'] != null ? ' (${item['variant_size']})' : ''} x${item['quantity']}',
                            style: GoogleFonts.inter(
                                color: AppColors.textPrimary,
                                fontSize: 13)),
                      ),
                      Text('₱${item['subtotal']}',
                          style: GoogleFonts.inter(
                              color: AppColors.gold,
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                    ],
                  ),
                )),
            const Divider(height: 20),

            if (_busy)
              const Center(
                  child: CircularProgressIndicator(color: AppColors.gold))
            else
              Column(
                children: [
                  // Verify
                  if (status == 'pending')
                    _SheetButton(
                      label: 'VERIFY ORDER',
                      icon: Icons.check_circle_outline,
                      color: AppColors.success,
                      onTap: () {
                        final messenger = ScaffoldMessenger.of(context);
                        _act(() async {
                          await widget.api.verifyOrder(o['id']);
                          messenger.showSnackBar(
                              const SnackBar(content: Text('Order verified!')));
                        });
                      },
                    ),

                  // Approve / Reject cancel request
                  if (status == 'cancel_requested') ...[
                    if (o['cancel_reason'] != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withAlpha(20),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.orange.withAlpha(80)),
                        ),
                        child: Text(
                            'Buyer reason: ${o['cancel_reason']}',
                            style: GoogleFonts.inter(
                                color: Colors.orange, fontSize: 12)),
                      ),
                    _SheetButton(
                      label: 'APPROVE CANCELLATION',
                      icon: Icons.check_circle_outline,
                      color: AppColors.success,
                      onTap: () {
                        final messenger = ScaffoldMessenger.of(context);
                        _act(() async {
                          await widget.api.approveCancelOrder(o['id']);
                          messenger.showSnackBar(const SnackBar(
                              content: Text('Cancellation approved')));
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    _SheetButton(
                      label: 'REJECT CANCELLATION',
                      icon: Icons.cancel_outlined,
                      color: AppColors.error,
                      onTap: () {
                        final messenger = ScaffoldMessenger.of(context);
                        _act(() async {
                          await widget.api.rejectCancelOrder(o['id']);
                          messenger.showSnackBar(const SnackBar(
                              content: Text('Cancellation rejected')));
                        });
                      },
                    ),
                  ],

                  // Cancel (seller)
                  if (status == 'pending' || status == 'verified') ...[
                    const SizedBox(height: 8),
                    _SheetButton(
                      label: 'CANCEL ORDER',
                      icon: Icons.cancel_outlined,
                      color: AppColors.error,
                      outlined: true,
                      onTap: _showCancelDialog,
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool outlined;
  const _SheetButton(
      {required this.label,
      required this.icon,
      required this.color,
      required this.onTap,
      this.outlined = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: outlined
          ? OutlinedButton.icon(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(40)),
              ),
              icon: Icon(icon, size: 18),
              label: Text(label,
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      letterSpacing: 1)),
            )
          : ElevatedButton.icon(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(40)),
              ),
              icon: Icon(icon, size: 18),
              label: Text(label,
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      letterSpacing: 1)),
            ),
    );
  }
}
