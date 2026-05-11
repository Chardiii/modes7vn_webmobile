import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';
import '../services/auth_provider.dart';
import '../theme.dart';

class OrderDetailScreen extends StatefulWidget {
  final int orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final _api = ApiService();
  Map<String, dynamic>? _order;
  bool _cancelling = false;
  bool _payingNow = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await _api.getOrder(widget.orderId);
    if (!mounted) return;
    setState(() => _order = data);
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

  bool _canCancel(String status) =>
      status == 'pending' || status == 'verified';

  Future<void> _payNow(int orderId) async {
    setState(() => _payingNow = true);
    try {
      final result = await _api.createPaymentLink(orderId);
      final checkoutUrl = result['checkout_url'] as String?;
      if (checkoutUrl == null) throw Exception('No checkout URL returned');
      final uri = Uri.parse(checkoutUrl);
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      }
      if (!mounted) return;
      // After returning from browser, verify payment
      final verify = await _api.verifyPayment(orderId);
      if (!mounted) return;
      final paid = verify['paid'] == true;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(paid
              ? '✨ Payment confirmed!'
              : 'Payment pending. Pull to refresh to check status.')));
      _load(); // Refresh order
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _payingNow = false);
    }
  }

  Future<void> _showCancelDialog() async {
    final reasonCtrl = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.border)),
        title: Text('Cancel Order',
            style: GoogleFonts.orbitron(color: AppColors.error, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Please provide a reason for cancellation.',
                style: GoogleFonts.inter(
                    color: AppColors.textMuted, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(hintText: 'Enter reason...'),
            ),
          ],
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
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (reasonCtrl.text.trim().isEmpty) {
      messenger
          .showSnackBar(const SnackBar(content: Text('Please enter a reason')));
      return;
    }

    setState(() => _cancelling = true);
    try {
      await _api.cancelOrder(widget.orderId, reason: reasonCtrl.text.trim());
      if (!mounted) return;
      messenger.showSnackBar(
          const SnackBar(content: Text('Cancellation request submitted')));
      _load();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_order == null) {
      return const Scaffold(
          body:
              Center(child: CircularProgressIndicator(color: AppColors.gold)));
    }

    final o = _order!;
    final items = o['items'] as List? ?? [];
    final status = o['status'] ?? '';
    final statusColor = _statusColor(status);
    final user = context.read<AuthProvider>().user;
    final isBuyer = user?['role'] == 'buyer';

    return Scaffold(
      appBar: AppBar(title: Text(o['order_number'])),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Status badge ──────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: statusColor.withAlpha(100)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('ORDER STATUS',
                          style: GoogleFonts.inter(
                              color: AppColors.textMuted,
                              fontSize: 10,
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.w600)),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: statusColor.withAlpha(30),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: statusColor.withAlpha(100)),
                        ),
                        child: Text(status.toUpperCase(),
                            style: GoogleFonts.inter(
                                color: statusColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(o['order_number'],
                      style: GoogleFonts.orbitron(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(o['created_at']?.toString().substring(0, 10) ?? '',
                      style: GoogleFonts.inter(
                          color: AppColors.textMuted, fontSize: 12)),
                  if (o['cancel_reason'] != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.error.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: AppColors.error.withAlpha(60)),
                      ),
                      child: Text('Reason: ${o['cancel_reason']}',
                          style: GoogleFonts.inter(
                              color: AppColors.error, fontSize: 12)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Visual Timeline ───────────────────────────────────────
            if (status != 'cancelled') ...[
              _OrderTimeline(status: status),
              const SizedBox(height: 16),
            ],

            // ── Delivery info ─────────────────────────────────────────
            _InfoCard(
              title: 'DELIVERY ADDRESS',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(o['delivery_address'] ?? '',
                      style: GoogleFonts.inter(
                          color: AppColors.textPrimary, fontSize: 13)),
                  Text(
                    [o['delivery_city'], o['delivery_province']]
                        .where((s) => s != null && s.toString().isNotEmpty)
                        .join(', '),
                    style: GoogleFonts.inter(
                        color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Buyer / Seller info card ────────────────────────────────
            if (user?['role'] != 'buyer' && o['buyer_name'] != null)
              _PersonCard(
                icon: Icons.person_outline,
                label: 'BUYER',
                name: o['buyer_name'] ?? o['buyer'] ?? '',
                username: o['buyer'] ?? '',
                phone: o['buyer_phone'],
              ),
            if (user?['role'] != 'seller' && o['seller_name'] != null)
              _PersonCard(
                icon: Icons.storefront_outlined,
                label: 'SELLER',
                name: o['seller_name'] ?? o['seller'] ?? '',
                username: o['seller'] ?? '',
                phone: o['seller_phone'],
              ),
            const SizedBox(height: 12),

            // ── Items ─────────────────────────────────────────────────
            _InfoCard(
              title: 'ITEMS (${items.length})',
              child: Column(
                children: items.map<Widget>((item) {
                  final imageUrl = item['image_url'] as String?;
                  final size  = item['variant_size']  as String?;
                  final color = item['variant_color'] as String?;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Product image
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: imageUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  width: 64, height: 64,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => _imgPlaceholder())
                              : _imgPlaceholder(),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item['product_name'] ?? '',
                                  style: GoogleFonts.inter(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13)),
                              if (size != null || color != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Wrap(spacing: 4, children: [
                                    if (size != null) _Chip(size),
                                    if (color != null) _Chip(color),
                                  ]),
                                ),
                              const SizedBox(height: 4),
                              Text('₱${item['price']} × ${item['quantity']}',
                                  style: GoogleFonts.inter(
                                      color: AppColors.textMuted, fontSize: 11)),
                            ],
                          ),
                        ),
                        Text('₱${item['subtotal']}',
                            style: GoogleFonts.inter(
                                color: AppColors.gold,
                                fontWeight: FontWeight.w700,
                                fontSize: 14)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),

            // ── Payment info ──────────────────────────────────────────
            _InfoCard(
              title: 'PAYMENT',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    o['payment']?['method'] == 'online'
                        ? 'Online Payment'
                        : 'Cash on Delivery',
                    style: GoogleFonts.inter(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (o['payment']?['status'] == 'paid'
                              ? AppColors.success
                              : AppColors.goldMid)
                          .withAlpha(30),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      (o['payment']?['status'] ?? 'pending').toUpperCase(),
                      style: GoogleFonts.inter(
                          color: o['payment']?['status'] == 'paid'
                              ? AppColors.success
                              : AppColors.goldMid,
                          fontSize: 10,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Total ─────────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  if ((o['shipping_fee'] ?? 0) > 0) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Subtotal',
                            style: GoogleFonts.inter(
                                color: AppColors.textMuted, fontSize: 13)),
                        Text('₱${o['subtotal'] ?? o['total_amount']}',
                            style: GoogleFonts.inter(
                                color: AppColors.textMuted, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Shipping Fee',
                            style: GoogleFonts.inter(
                                color: AppColors.textMuted, fontSize: 13)),
                        Text('₱${o['shipping_fee']}',
                            style: GoogleFonts.inter(
                                color: AppColors.textMuted, fontSize: 13)),
                      ],
                    ),
                    const Divider(height: 16),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('TOTAL',
                          style: GoogleFonts.inter(
                              color: AppColors.textMuted,
                              fontSize: 12,
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.w600)),
                      ShaderMask(
                        shaderCallback: (b) => goldGradient.createShader(b),
                        child: Text('₱${o['total_amount']}',
                            style: GoogleFonts.inter(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Cancel button ─────────────────────────────────────────
            if (isBuyer &&
                o['payment']?['method'] == 'online' &&
                o['payment']?['status'] == 'pending') ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: _payingNow
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.gold))
                    : Container(
                        decoration: BoxDecoration(
                          gradient: goldGradient,
                          borderRadius: BorderRadius.circular(40),
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () => _payNow(o['id']),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: AppColors.background,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(40)),
                          ),
                          icon: const Icon(Icons.credit_card_outlined, size: 18),
                          label: Text('PAY NOW',
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  letterSpacing: 1.5)),
                        ),
                      ),
              ),
            ],
            if (isBuyer && _canCancel(status)) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: _cancelling
                    ? const Center(
                        child:
                            CircularProgressIndicator(color: AppColors.error))
                    : OutlinedButton.icon(
                        onPressed: _showCancelDialog,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(40)),
                        ),
                        icon: const Icon(Icons.cancel_outlined, size: 18),
                        label: Text('REQUEST CANCELLATION',
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                letterSpacing: 1)),
                      ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ── Visual Timeline ────────────────────────────────────────────────────────────

class _OrderTimeline extends StatelessWidget {
  final String status;
  const _OrderTimeline({required this.status});

  static const _steps = [
    {'key': 'pending',   'label': 'Pending',   'icon': Icons.hourglass_empty},
    {'key': 'verified',  'label': 'Verified',  'icon': Icons.verified_outlined},
    {'key': 'assigned',  'label': 'Assigned',  'icon': Icons.delivery_dining_outlined},
    {'key': 'shipped',   'label': 'Shipped',   'icon': Icons.local_shipping_outlined},
    {'key': 'delivered', 'label': 'Delivered', 'icon': Icons.check_circle_outline},
  ];

  int get _currentStep {
    switch (status) {
      case 'pending':   return 0;
      case 'verified':  return 1;
      case 'assigned':  return 2;
      case 'shipped':   return 3;
      case 'delivered': return 4;
      default:          return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _currentStep;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ORDER TRACKING',
              style: GoogleFonts.inter(
                  color: AppColors.textMuted,
                  fontSize: 10,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Row(
            children: List.generate(_steps.length * 2 - 1, (i) {
              if (i.isOdd) {
                // Connector line
                final stepIndex = i ~/ 2;
                final isCompleted = stepIndex < current;
                return Expanded(
                  child: Container(
                    height: 2,
                    color: isCompleted ? AppColors.gold : AppColors.border,
                  ),
                );
              }
              // Step circle
              final stepIndex = i ~/ 2;
              final isCompleted = stepIndex <= current;
              final isCurrent = stepIndex == current;
              final step = _steps[stepIndex];
              return Column(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isCompleted ? goldGradient : null,
                      color: isCompleted ? null : AppColors.surfaceLight,
                      border: Border.all(
                          color: isCompleted ? AppColors.gold : AppColors.border,
                          width: isCurrent ? 2.5 : 1.5),
                      boxShadow: isCurrent
                          ? [
                              BoxShadow(
                                  color: AppColors.gold.withAlpha(80),
                                  blurRadius: 8,
                                  spreadRadius: 1)
                            ]
                          : null,
                    ),
                    child: Icon(
                      step['icon'] as IconData,
                      size: 18,
                      color: isCompleted
                          ? AppColors.background
                          : AppColors.textMuted,
                    ),
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _steps.map((step) {
              final stepIndex = _steps.indexOf(step);
              final isCompleted = stepIndex <= current;
              return SizedBox(
                width: 52,
                child: Text(step['label'] as String,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                        color: isCompleted
                            ? AppColors.gold
                            : AppColors.textMuted,
                        fontSize: 10,
                        fontWeight: isCompleted
                            ? FontWeight.w700
                            : FontWeight.w400)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ── Info Card ──────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _InfoCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: GoogleFonts.inter(
                  color: AppColors.textMuted,
                  fontSize: 10,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

// ── Person Card (buyer / seller info) ─────────────────────────────────────────

class _PersonCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String name;
  final String username;
  final String? phone;
  const _PersonCard({
    required this.icon, required this.label,
    required this.name, required this.username, this.phone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: AppColors.gold.withAlpha(20),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.gold.withAlpha(80)),
          ),
          child: Icon(icon, color: AppColors.gold, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: GoogleFonts.inter(
                    color: AppColors.textMuted,
                    fontSize: 9,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(
              name.isNotEmpty ? name : username,
              style: GoogleFonts.inter(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13),
            ),
            if (name.isNotEmpty)
              Text('@$username',
                  style: GoogleFonts.inter(
                      color: AppColors.textMuted, fontSize: 11)),
            if (phone != null && phone!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('📞 $phone',
                    style: GoogleFonts.inter(
                        color: AppColors.textMuted, fontSize: 11)),
              ),
          ],
        )),
      ]),
    );
  }
}

// ── Chip ──────────────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  const _Chip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(label,
          style: GoogleFonts.inter(
              color: AppColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w600)),
    );
  }
}

// ── Image placeholder ─────────────────────────────────────────────────────────

Widget _imgPlaceholder() => Container(
  width: 64, height: 64,
  decoration: BoxDecoration(
    color: AppColors.surfaceLight,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: AppColors.border),
  ),
  child: const Icon(Icons.image_not_supported_outlined,
      color: AppColors.textMuted, size: 24),
);
