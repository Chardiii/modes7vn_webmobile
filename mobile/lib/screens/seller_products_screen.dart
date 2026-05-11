import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';
import '../theme.dart';
import 'add_product_screen.dart';
import 'edit_product_screen.dart';

class SellerProductsScreen extends StatefulWidget {
  const SellerProductsScreen({super.key});

  @override
  State<SellerProductsScreen> createState() => _SellerProductsScreenState();
}

class _SellerProductsScreenState extends State<SellerProductsScreen> {
  final _api = ApiService();
  List _products = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _api.getSellerProducts();
      if (!mounted) return;
      setState(() => _products = data);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle(int productId, int index) async {
    try {
      final isActive = await _api.toggleSellerProduct(productId);
      if (!mounted) return;
      setState(() => _products[index]['is_active'] = isActive);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isActive ? 'Product activated' : 'Product deactivated')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Products'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final added = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AddProductScreen()));
              if (added == true) _load();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.gold))
          : _products.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.inventory_2_outlined,
                          size: 64, color: AppColors.textMuted),
                      const SizedBox(height: 16),
                      Text('No products yet',
                          style: GoogleFonts.inter(
                              color: AppColors.textMuted, fontSize: 16)),
                      const SizedBox(height: 8),
                      Text('Add products from the web dashboard',
                          style: GoogleFonts.inter(
                              color: AppColors.textMuted, fontSize: 12)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.gold,
                  backgroundColor: AppColors.surface,
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _products.length,
                    separatorBuilder: (ctx, i) =>
                        const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final p = _products[i];
                      final isActive = p['is_active'] as bool? ?? true;
                      final stock = p['stock'] as int? ?? 0;
                      final isLowStock = stock > 0 && stock <= 5;
                      final isOutOfStock = stock == 0;

                      return GestureDetector(
                        onTap: () async {
                          final updated = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => EditProductScreen(
                                      productId: p['id'])));
                          if (updated == true) _load();
                        },
                        child: Container(
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppColors.surface
                              : AppColors.surface.withAlpha(150),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: !isActive
                                  ? AppColors.border.withAlpha(80)
                                  : AppColors.border),
                        ),
                        child: Row(
                          children: [
                            // Image
                            ClipRRect(
                              borderRadius: const BorderRadius.horizontal(
                                  left: Radius.circular(14)),
                              child: p['image_url'] != null
                                  ? CachedNetworkImage(
                                      imageUrl: p['image_url'],
                                      width: 90,
                                      height: 90,
                                      fit: BoxFit.cover,
                                      errorWidget: (ctx, url, err) =>
                                          Container(
                                              width: 90,
                                              height: 90,
                                              color: AppColors.surfaceLight,
                                              child: const Icon(
                                                  Icons.image_not_supported,
                                                  color:
                                                      AppColors.textMuted)))
                                  : Container(
                                      width: 90,
                                      height: 90,
                                      color: AppColors.surfaceLight,
                                      child: const Icon(
                                          Icons.image_not_supported,
                                          color: AppColors.textMuted)),
                            ),
                            // Info
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(p['name'],
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13)),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text('₱${p['price']}',
                                            style: GoogleFonts.inter(
                                                color: AppColors.gold,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13)),
                                        const SizedBox(width: 8),
                                        // Stock badge
                                        Container(
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isOutOfStock
                                                ? AppColors.error
                                                    .withAlpha(30)
                                                : isLowStock
                                                    ? Colors.orange
                                                        .withAlpha(30)
                                                    : AppColors.success
                                                        .withAlpha(30),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                              isOutOfStock
                                                  ? 'Out of stock'
                                                  : isLowStock
                                                      ? 'Low: $stock'
                                                      : 'Stock: $stock',
                                              style: GoogleFonts.inter(
                                                  color: isOutOfStock
                                                      ? AppColors.error
                                                      : isLowStock
                                                          ? Colors.orange
                                                          : AppColors
                                                              .success,
                                                  fontSize: 10,
                                                  fontWeight:
                                                      FontWeight.w600)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                        '⭐ ${p['rating']}  •  ${p['review_count']} reviews',
                                        style: GoogleFonts.inter(
                                            color: AppColors.textMuted,
                                            fontSize: 11)),
                                  ],
                                ),
                              ),
                            ),
                            // Toggle switch
                            Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: Column(
                                children: [
                                  Switch(
                                    value: isActive,
                                    activeThumbColor: AppColors.gold,
                                    onChanged: (v) => _toggle(p['id'], i),
                                  ),
                                  Text(
                                      isActive ? 'Active' : 'Off',
                                      style: GoogleFonts.inter(
                                          color: isActive
                                              ? AppColors.gold
                                              : AppColors.textMuted,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
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
