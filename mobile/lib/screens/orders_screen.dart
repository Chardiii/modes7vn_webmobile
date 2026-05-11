import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme.dart';
import 'order_detail_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => OrdersScreenState();
}

class OrdersScreenState extends State<OrdersScreen> {
  final _api = ApiService();
  List _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> load() => _load();

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _api.getOrders();
      if (!mounted) return;
      setState(() => _orders = data);
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.gold));
    }
    if (_orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.receipt_long_outlined,
                size: 64, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text('No orders yet',
                style: GoogleFonts.inter(
                    color: AppColors.textMuted, fontSize: 16)),
          ],
        ),
      );
    }
    return Material(
      color: AppColors.background,
      child: RefreshIndicator(
        color: AppColors.gold,
        backgroundColor: AppColors.surface,
        onRefresh: _load,
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _orders.length,
          separatorBuilder: (ctx, i) => const SizedBox(height: 10),
          itemBuilder: (ctx, i) {
            final o = _orders[i];
            final statusColor = _statusColor(o['status'] ?? '');
            return GestureDetector(
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          OrderDetailScreen(orderId: o['id']))),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(o['order_number'],
                            style: GoogleFonts.orbitron(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withAlpha(30),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: statusColor.withAlpha(100)),
                          ),
                          child: Text(
                              o['status'].toString().toUpperCase(),
                              style: GoogleFonts.inter(
                                  color: statusColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(o['delivery_city'] ?? '',
                            style: GoogleFonts.inter(
                                color: AppColors.textMuted, fontSize: 12)),
                        ShaderMask(
                          shaderCallback: (b) =>
                              goldGradient.createShader(b),
                          child: Text('₱${o['total_amount']}',
                              style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                            '${(o['items'] as List?)?.length ?? 0} item(s)',
                            style: GoogleFonts.inter(
                                color: AppColors.textMuted, fontSize: 11)),
                        Text('Tap to view details →',
                            style: GoogleFonts.inter(
                                color: AppColors.gold,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
