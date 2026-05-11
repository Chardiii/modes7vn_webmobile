import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../services/api_service.dart';
import '../services/auth_provider.dart';
import '../theme.dart';
import 'login_screen.dart';
import 'profile_screen.dart';

class RiderDashboardScreen extends StatefulWidget {
  const RiderDashboardScreen({super.key});

  @override
  State<RiderDashboardScreen> createState() => _RiderDashboardScreenState();
}

class _RiderDashboardScreenState extends State<RiderDashboardScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  Map<String, dynamic>? _data;
  bool _loading = true;
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _api.getRiderOrders();
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

  Future<void> _claim(int orderId) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.border)),
        title: Text('Claim Order',
            style: GoogleFonts.orbitron(
                color: AppColors.gold, fontSize: 16)),
        content: Text(
            'Are you sure you want to claim this order for delivery?',
            style: GoogleFonts.inter(
                color: AppColors.textMuted, fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.background),
            child: const Text('Claim'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.claimOrder(orderId);
      messenger.showSnackBar(
          const SnackBar(content: Text('✨ Order claimed! Go pick it up.')));
      _load();
      _tabs.animateTo(1); // Switch to Active tab
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _pickup(int orderId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _api.pickupOrder(orderId);
      messenger.showSnackBar(
          const SnackBar(content: Text('✨ Marked as picked up!')));
      _load();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _deliver(int orderId) async {
    final messenger = ScaffoldMessenger.of(context);

    // Step 1: Pick proof photo
    final picker = ImagePicker();
    File? proofFile;

    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Proof of Delivery',
                  style: GoogleFonts.orbitron(
                      color: AppColors.gold,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('Take or upload a photo as proof before marking delivered.',
                  style: GoogleFonts.inter(
                      color: AppColors.textMuted, fontSize: 13)),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined,
                    color: AppColors.gold),
                title: Text('Take Photo',
                    style: GoogleFonts.inter(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600)),
                onTap: () async {
                  final picked = await picker.pickImage(
                      source: ImageSource.camera, imageQuality: 80);
                  if (picked != null) proofFile = File(picked.path);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined,
                    color: AppColors.gold),
                title: Text('Choose from Gallery',
                    style: GoogleFonts.inter(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600)),
                onTap: () async {
                  final picked = await picker.pickImage(
                      source: ImageSource.gallery, imageQuality: 80);
                  if (picked != null) proofFile = File(picked.path);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );

    if (proofFile == null) return; // user cancelled

    // Step 2: Preview + confirm
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.border)),
        title: Text('Confirm Delivery',
            style: GoogleFonts.orbitron(
                color: AppColors.gold, fontSize: 15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(proofFile!,
                  height: 200, fit: BoxFit.cover),
            ),
            const SizedBox(height: 12),
            Text('Submit this photo as proof of delivery?',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    color: AppColors.textMuted, fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Retake',
                  style: GoogleFonts.inter(color: AppColors.textMuted))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white),
            child: const Text('Confirm & Deliver'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Step 3: Upload and mark delivered
    try {
      await _api.deliverOrder(orderId, proofImagePath: proofFile!.path);
      messenger.showSnackBar(
          const SnackBar(content: Text('✨ Order delivered! Proof saved.')));
      _load();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user      = context.watch<AuthProvider>().user;
    final available = (_data?['available'] as List?) ?? [];
    final active    = (_data?['active']    as List?) ?? [];
    final delivered = (_data?['delivered'] as List?) ?? [];
    final stats     = (_data?['stats']     as Map?)  ?? {};

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
              icon: const Icon(Icons.person_outline),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) =>
                          const ProfileScreen(standalone: true)))),
          IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                final nav = Navigator.of(context);
                await context.read<AuthProvider>().logout();
                nav.pushReplacement(
                    MaterialPageRoute(builder: (_) => const LoginScreen()));
              }),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.gold,
          labelColor: AppColors.gold,
          unselectedLabelColor: AppColors.textMuted,
          labelStyle:
              GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
          tabs: [
            Tab(text: 'Available (${available.length})'),
            Tab(text: 'Active (${active.length})'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.gold))
          : RefreshIndicator(
              color: AppColors.gold,
              backgroundColor: AppColors.surface,
              onRefresh: _load,
              child: TabBarView(
                controller: _tabs,
                children: [
                  // ── Available tab ──────────────────────────────────────
                  _AvailableTab(
                    available: available,
                    onClaim: _claim,
                  ),
                  // ── Active tab ─────────────────────────────────────────
                  _ActiveTab(
                    user: user,
                    active: active,
                    stats: stats,
                    onPickup: _pickup,
                    onDeliver: _deliver,
                  ),
                  // ── History tab ────────────────────────────────────────
                  _HistoryTab(delivered: delivered, stats: stats),
                ],
              ),
            ),
    );
  }
}

// ── Available Orders tab ──────────────────────────────────────────────────────

class _AvailableTab extends StatelessWidget {
  final List available;
  final void Function(int) onClaim;

  const _AvailableTab({required this.available, required this.onClaim});

  @override
  Widget build(BuildContext context) {
    if (available.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inbox_outlined,
                size: 56, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text('No orders available to claim',
                style: GoogleFonts.inter(
                    color: AppColors.textMuted, fontSize: 14)),
            const SizedBox(height: 4),
            Text('Pull down to refresh',
                style: GoogleFonts.inter(
                    color: AppColors.textMuted, fontSize: 12)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: available.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final o = available[i];
        final items = o['items'] as List? ?? [];
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.gold.withAlpha(80)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
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
                        color: AppColors.success.withAlpha(30),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppColors.success.withAlpha(100)),
                      ),
                      child: Text('AVAILABLE',
                          style: GoogleFonts.inter(
                              color: AppColors.success,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5)),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on_outlined,
                            color: AppColors.gold, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                              '${o['delivery_address'] ?? ''}, ${o['delivery_city'] ?? ''}',
                              style: GoogleFonts.inter(
                                  color: AppColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.shopping_bag_outlined,
                            color: AppColors.textMuted, size: 15),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                              '${items.length} item(s): ${items.map((i) => i['product_name']).join(', ')}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                  color: AppColors.textMuted,
                                  fontSize: 11)),
                        ),
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
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: goldGradient,
                          borderRadius: BorderRadius.circular(40),
                          boxShadow: [
                            BoxShadow(
                                color: AppColors.goldMid.withAlpha(80),
                                blurRadius: 12,
                                offset: const Offset(0, 4))
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () => onClaim(o['id']),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: AppColors.background,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(40)),
                          ),
                          icon: const Icon(
                              Icons.delivery_dining_outlined,
                              size: 18),
                          label: Text('CLAIM ORDER',
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  letterSpacing: 1)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Active deliveries tab ─────────────────────────────────────────────────────

class _ActiveTab extends StatelessWidget {
  final Map? user;
  final List active;
  final Map stats;
  final void Function(int) onPickup;
  final void Function(int) onDeliver;

  const _ActiveTab({
    required this.user,
    required this.active,
    required this.stats,
    required this.onPickup,
    required this.onDeliver,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Welcome back,',
            style: GoogleFonts.inter(
                color: AppColors.textMuted, fontSize: 13)),
        Text(user?['username'] ?? 'Rider',
            style: GoogleFonts.orbitron(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Completed',
                value: '${stats['completed'] ?? 0}',
                icon: Icons.check_circle_outline,
                color: AppColors.success,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'Earnings',
                value: '₱${stats['earnings'] ?? 0}',
                icon: Icons.payments_outlined,
                color: AppColors.gold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text('MY ACTIVE DELIVERIES',
            style: GoogleFonts.inter(
                color: AppColors.textMuted,
                fontSize: 10,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        if (active.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                const Icon(Icons.delivery_dining_outlined,
                    size: 48, color: AppColors.textMuted),
                const SizedBox(height: 12),
                Text('No active deliveries',
                    style: GoogleFonts.inter(
                        color: AppColors.textMuted, fontSize: 14)),
                const SizedBox(height: 4),
                Text('Claim an order from the Available tab',
                    style: GoogleFonts.inter(
                        color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          )
        else
          ...active.map<Widget>((o) => _ActiveOrderCard(
                order: o,
                onPickup: onPickup,
                onDeliver: onDeliver,
              )),
      ],
    );
  }
}

class _ActiveOrderCard extends StatelessWidget {
  final Map order;
  final void Function(int) onPickup;
  final void Function(int) onDeliver;

  const _ActiveOrderCard({
    required this.order,
    required this.onPickup,
    required this.onDeliver,
  });

  @override
  Widget build(BuildContext context) {
    final o = order;
    final status = o['status'] ?? '';
    final isAssigned = status == 'assigned';
    final isShipped = status == 'shipped';
    final items = o['items'] as List? ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isShipped
                ? AppColors.gold.withAlpha(150)
                : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isShipped
                  ? AppColors.gold.withAlpha(20)
                  : AppColors.surfaceLight,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
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
                    color: isShipped
                        ? AppColors.gold.withAlpha(30)
                        : Colors.blue.withAlpha(30),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: isShipped
                            ? AppColors.gold.withAlpha(100)
                            : Colors.blue.withAlpha(100)),
                  ),
                  child: Text(
                      isShipped ? 'PICKED UP' : 'ASSIGNED',
                      style: GoogleFonts.inter(
                          color:
                              isShipped ? AppColors.gold : Colors.blue,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_outlined,
                        color: AppColors.gold, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                          '${o['delivery_address'] ?? ''}, ${o['delivery_city'] ?? ''}',
                          style: GoogleFonts.inter(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.person_outline,
                        color: AppColors.textMuted, size: 15),
                    const SizedBox(width: 6),
                    Text('Buyer: ${o['buyer'] ?? ''}',
                        style: GoogleFonts.inter(
                            color: AppColors.textMuted, fontSize: 12)),
                    const Spacer(),
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
                const SizedBox(height: 8),
                Text(
                    '${items.length} item(s): ${items.map((i) => i['product_name']).join(', ')}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        color: AppColors.textMuted, fontSize: 11)),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: isAssigned
                      ? ElevatedButton.icon(
                          onPressed: () => onPickup(o['id']),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(40)),
                          ),
                          icon: const Icon(
                              Icons.local_shipping_outlined,
                              size: 18),
                          label: Text('MARK AS PICKED UP',
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  letterSpacing: 1)),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            gradient: goldGradient,
                            borderRadius: BorderRadius.circular(40),
                            boxShadow: [
                              BoxShadow(
                                  color: AppColors.goldMid.withAlpha(80),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4))
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: () => onDeliver(o['id']),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: AppColors.background,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(40)),
                            ),
                            icon: const Icon(
                                Icons.check_circle_outline,
                                size: 18),
                            label: Text('MARK AS DELIVERED',
                                style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    letterSpacing: 1)),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── History tab ───────────────────────────────────────────────────────────────

class _HistoryTab extends StatelessWidget {
  final List delivered;
  final Map stats;
  const _HistoryTab({required this.delivered, required this.stats});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
              Text('TOTAL EARNINGS',
                  style: GoogleFonts.inter(
                      color: AppColors.background,
                      fontSize: 10,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text('₱${stats['earnings'] ?? 0}',
                  style: GoogleFonts.orbitron(
                      color: AppColors.background,
                      fontSize: 28,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('${stats['completed'] ?? 0} deliveries completed',
                  style: GoogleFonts.inter(
                      color: AppColors.background.withAlpha(180),
                      fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('DELIVERY HISTORY',
            style: GoogleFonts.inter(
                color: AppColors.textMuted,
                fontSize: 10,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        if (delivered.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Text('No deliveries yet',
                  style: GoogleFonts.inter(
                      color: AppColors.textMuted, fontSize: 14)),
            ),
          )
        else
          ...delivered.map<Widget>((o) {
            final deliveredAt =
                o['delivered_at']?.toString().substring(0, 10) ?? '';
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.success.withAlpha(20),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppColors.success.withAlpha(80)),
                    ),
                    child: const Icon(Icons.check,
                        color: AppColors.success, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(o['order_number'],
                            style: GoogleFonts.inter(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                        Text(
                            '${o['delivery_city'] ?? ''}  •  $deliveredAt',
                            style: GoogleFonts.inter(
                                color: AppColors.textMuted,
                                fontSize: 11)),
                      ],
                    ),
                  ),
                  Text('₱${o['total_amount']}',
                      style: GoogleFonts.inter(
                          color: AppColors.gold,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                ],
              ),
            );
          }),
      ],
    );
  }
}

// ── Stat card ─────────────────────────────────────────────────────────────────

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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
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
    );
  }
}
