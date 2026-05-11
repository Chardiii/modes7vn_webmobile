import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_provider.dart';
import '../theme.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'messages_screen.dart';
import 'seller_orders_screen.dart';
import 'seller_products_screen.dart';

class SellerDashboardScreen extends StatefulWidget {
  const SellerDashboardScreen({super.key});

  @override
  State<SellerDashboardScreen> createState() => _SellerDashboardScreenState();
}

class _SellerDashboardScreenState extends State<SellerDashboardScreen> {
  final _api = ApiService();
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _api.getSellerDashboard();
      if (!mounted) return;
      setState(() => _data = data);
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
    final user = context.watch<AuthProvider>().user;
    final stats = _data?['stats'] as Map? ?? {};
    final recentOrders = _data?['recent_orders'] as List? ?? [];

    return Scaffold(
      appBar: AppBar(
        title: ShaderMask(
          shaderCallback: (b) => goldGradient.createShader(b),
          child: Text('MODE S7VN',
              style: GoogleFonts.orbitron(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.chat_bubble_outline),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const MessagesScreen()))),
          IconButton(
              icon: const Icon(Icons.person_outline),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen(standalone: true)))),
          IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                final nav = Navigator.of(context);
                await context.read<AuthProvider>().logout();
                nav.pushReplacement(
                    MaterialPageRoute(builder: (_) => const LoginScreen()));
              }),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.gold))
          : RefreshIndicator(
              color: AppColors.gold,
              backgroundColor: AppColors.surface,
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Greeting
                    Text(
                        'Welcome back,',
                        style: GoogleFonts.inter(
                            color: AppColors.textMuted, fontSize: 13)),
                    Text(
                        user?['username'] ?? 'Seller',
                        style: GoogleFonts.orbitron(
                            color: AppColors.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 20),

                    // Revenue card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: goldGradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.goldMid.withAlpha(80),
                              blurRadius: 16,
                              offset: const Offset(0, 6))
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('TOTAL REVENUE',
                              style: GoogleFonts.inter(
                                  color: AppColors.background,
                                  fontSize: 10,
                                  letterSpacing: 1.5,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Text('₱${stats['revenue'] ?? 0}',
                              style: GoogleFonts.orbitron(
                                  color: AppColors.background,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text('${stats['delivered_orders'] ?? 0} delivered orders',
                              style: GoogleFonts.inter(
                                  color: AppColors.background.withAlpha(180),
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Stats grid
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.6,
                      children: [
                        _StatCard(
                            label: 'Pending Orders',
                            value: '${stats['pending_orders'] ?? 0}',
                            icon: Icons.pending_outlined,
                            color: AppColors.goldMid),
                        _StatCard(
                            label: 'Cancel Requests',
                            value: '${stats['cancel_requests'] ?? 0}',
                            icon: Icons.cancel_outlined,
                            color: AppColors.error),
                        _StatCard(
                            label: 'Total Products',
                            value: '${stats['total_products'] ?? 0}',
                            icon: Icons.inventory_2_outlined,
                            color: AppColors.gold),
                        _StatCard(
                            label: 'Low Stock',
                            value: '${stats['low_stock'] ?? 0}',
                            icon: Icons.warning_amber_outlined,
                            color: Colors.orange),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Quick actions
                    Text('QUICK ACTIONS',
                        style: GoogleFonts.inter(
                            color: AppColors.textMuted,
                            fontSize: 10,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _ActionButton(
                            label: 'My Orders',
                            icon: Icons.receipt_long_outlined,
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const SellerOrdersScreen())),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ActionButton(
                            label: 'My Products',
                            icon: Icons.inventory_2_outlined,
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const SellerProductsScreen())),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Recent orders
                    Text('RECENT ORDERS',
                        style: GoogleFonts.inter(
                            color: AppColors.textMuted,
                            fontSize: 10,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    if (recentOrders.isEmpty)
                      Text('No orders yet',
                          style: GoogleFonts.inter(
                              color: AppColors.textMuted, fontSize: 13))
                    else
                      ...recentOrders.map<Widget>((o) {
                        final statusColor =
                            _statusColor(o['status'] ?? '');
                        return GestureDetector(
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => SellerOrdersScreen(
                                      initialOrderId: o['id']))),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(o['order_number'],
                                          style: GoogleFonts.inter(
                                              color:
                                                  AppColors.textPrimary,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13)),
                                      Text(
                                          'by ${o['buyer'] ?? ''}  •  ₱${o['total_amount']}',
                                          style: GoogleFonts.inter(
                                              color: AppColors.textMuted,
                                              fontSize: 11)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusColor.withAlpha(30),
                                    borderRadius:
                                        BorderRadius.circular(20),
                                    border: Border.all(
                                        color:
                                            statusColor.withAlpha(100)),
                                  ),
                                  child: Text(
                                      o['status']
                                          .toString()
                                          .toUpperCase(),
                                      style: GoogleFonts.inter(
                                          color: statusColor,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.5)),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 22),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: GoogleFonts.orbitron(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700)),
              Text(label,
                  style: GoogleFonts.inter(
                      color: AppColors.textMuted, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _ActionButton(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.gold, size: 26),
            const SizedBox(height: 6),
            Text(label,
                style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
