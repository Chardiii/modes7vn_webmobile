import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';
import '../theme.dart';
import 'product_detail_screen.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => WishlistScreenState();
}

class WishlistScreenState extends State<WishlistScreen> {
  final _api = ApiService();
  List _items = [];
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
      final data = await _api.getWishlist();
      if (!mounted) return;
      setState(() => _items = data);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _remove(int productId) async {
    await _api.toggleWishlist(productId);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.gold));
    }

    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.favorite_border,
                size: 64, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text('Your wishlist is empty',
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
          itemCount: _items.length,
          separatorBuilder: (ctx, i) => const SizedBox(height: 10),
          itemBuilder: (ctx, i) {
            final item = _items[i];
            return GestureDetector(
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => ProductDetailScreen(
                          productId: item['product_id']))),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(14)),
                      child: item['image_url'] != null
                          ? CachedNetworkImage(
                              imageUrl: item['image_url'],
                              width: 90,
                              height: 90,
                              fit: BoxFit.cover)
                          : Container(
                              width: 90,
                              height: 90,
                              color: AppColors.surfaceLight,
                              child: const Icon(Icons.image_not_supported,
                                  color: AppColors.textMuted)),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                (item['category'] ?? '')
                                    .toString()
                                    .toUpperCase(),
                                style: GoogleFonts.inter(
                                    fontSize: 9,
                                    color: AppColors.gold,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1)),
                            const SizedBox(height: 2),
                            Text(item['name'],
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                            const SizedBox(height: 4),
                            Text('₱${item['price']}',
                                style: GoogleFonts.inter(
                                    color: AppColors.gold,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14)),
                            if (!(item['in_stock'] as bool))
                              Text('Out of stock',
                                  style: GoogleFonts.inter(
                                      color: AppColors.error, fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.favorite,
                          color: Colors.redAccent),
                      onPressed: () => _remove(item['product_id']),
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
