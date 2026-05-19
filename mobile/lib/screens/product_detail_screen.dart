import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../services/api_service.dart';
import '../services/auth_provider.dart';
import '../theme.dart';
import 'checkout_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final int productId;
  const ProductDetailScreen({super.key, required this.productId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final _api = ApiService();
  Map<String, dynamic>? _product;
  int? _selectedVariantId;
  String? _selectedColor;
  int _qty = 1;
  bool _addingToCart = false;
  bool _inWishlist = false;
  bool _togglingWishlist = false;

  // Review — one per delivered order
  int _reviewRating = 0;
  final _reviewCtrl = TextEditingController();
  bool _submittingReview = false;
  List<Map<String, dynamic>> _reviewableOrders = [];
  int? _selectedOrderId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reviewCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final data = await _api.getProduct(widget.productId);
    if (!mounted) return;
    setState(() => _product = data);

    final user = context.read<AuthProvider>().user;
    if (user?['role'] != 'buyer') return;

    // Wishlist check
    try {
      final wl = await _api.getWishlist();
      if (!mounted) return;
      setState(() =>
          _inWishlist = wl.any((w) => w['product_id'] == widget.productId));
    } catch (_) {}

    // Build reviewable orders — delivered orders with this product
    // that the user hasn't reviewed yet for that specific order
    try {
      final reviews = (data['reviews'] as List? ?? []);
      final reviewedOrderIds = reviews
          .where((r) => r['reviewer'] == user?['username'])
          .map((r) => r['order_id'])
          .toSet();

      final orders = await _api.getOrders();
      final reviewable = <Map<String, dynamic>>[];
      for (final o in orders) {
        if (o['status'] == 'delivered') {
          final items = o['items'] as List? ?? [];
          if (items.any((i) => i['product_id'] == widget.productId)) {
            if (!reviewedOrderIds.contains(o['id'])) {
              reviewable.add({
                'id': o['id'],
                'order_number': o['order_number'],
              });
            }
          }
        }
      }
      if (mounted) {
        setState(() {
          _reviewableOrders = reviewable;
          _selectedOrderId =
              reviewable.isNotEmpty ? reviewable.first['id'] : null;
        });
      }
    } catch (_) {}
  }

  void _showSizeGuide(String category) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (ctx, scroll) => SingleChildScrollView(
          controller: scroll,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('📏 Size Guide & Measurements',
                  style: GoogleFonts.orbitron(
                      color: AppColors.gold,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              if (['Suits & Blazers', 'Casual Shirts & Pants',
                  'Outerwear & Jackets',
                  'Activewear & Fitness Gear'].contains(category)) ...[
                _sgSection('Apparel Sizes (chest / waist in inches)'),
                _sgTable(
                  headers: ['Size', 'Chest', 'Waist', 'Hip'],
                  rows: [
                    ['XS', '32–34"', '26–28"', '34–36"'],
                    ['S',  '35–37"', '29–31"', '37–39"'],
                    ['M',  '38–40"', '32–34"', '40–42"'],
                    ['L',  '41–43"', '35–37"', '43–45"'],
                    ['XL', '44–46"', '38–40"', '46–48"'],
                    ['XXL','47–49"', '41–43"', '49–51"'],
                  ],
                ),
              ],
              if (category == 'Casual Shirts & Pants') ...[
                const SizedBox(height: 16),
                _sgSection('Pants — Waist Sizes'),
                _sgTable(
                  headers: ['Waist (in)', 'Waist (cm)', 'Inseam'],
                  rows: [
                    ['28"', '71 cm', '30"'],
                    ['30"', '76 cm', '30"'],
                    ['32"', '81 cm', '32"'],
                    ['34"', '86 cm', '32"'],
                    ['36"', '91 cm', '32"'],
                    ['38"', '97 cm', '34"'],
                    ['40"', '102 cm', '34"'],
                  ],
                ),
              ],
              if (category == 'Shoes & Accessories') ...[
                _sgSection('Shoe Sizes (EU / US / CM)'),
                _sgTable(
                  headers: ['EU', 'US', 'Foot Length (cm)'],
                  rows: [
                    ['38', '6',   '24.0'],
                    ['39', '6.5', '24.7'],
                    ['40', '7',   '25.3'],
                    ['41', '8',   '26.0'],
                    ['42', '9',   '26.7'],
                    ['43', '10',  '27.3'],
                    ['44', '11',  '28.0'],
                    ['45', '12',  '28.7'],
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Text('All measurements are approximate. If between sizes, size up.',
                  style: GoogleFonts.inter(
                      color: AppColors.textMuted, fontSize: 11)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sgSection(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title,
            style: GoogleFonts.inter(
                color: AppColors.textMuted,
                fontSize: 10,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w700)),
      );

  Widget _sgTable({required List<String> headers, required List<List<String>> rows}) {
    return Table(
      border: TableBorder.all(color: AppColors.border, width: 0.5),
      columnWidths: const {0: IntrinsicColumnWidth()},
      children: [
        TableRow(
          decoration: const BoxDecoration(color: AppColors.surfaceLight),
          children: headers.map((h) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Text(h,
                    style: GoogleFonts.inter(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 11)),
              )).toList(),
        ),
        ...rows.map((row) => TableRow(
              children: row.map((cell) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    child: Text(cell,
                        style: GoogleFonts.inter(
                            color: AppColors.textMuted, fontSize: 11)),
                  )).toList(),
            )),
      ],
    );
  }

  Future<void> _toggleWishlist() async {
    setState(() => _togglingWishlist = true);
    try {
      final status = await _api.toggleWishlist(widget.productId);
      if (!mounted) return;
      setState(() => _inWishlist = status == 'added');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _togglingWishlist = false);
    }
  }

  Future<void> _addToCart() async {
    final variants = _product?['variants'] as List? ?? [];
    if (variants.isNotEmpty && _selectedVariantId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a size')));
      return;
    }
    setState(() => _addingToCart = true);
    try {
      await _api.addToCart(widget.productId,
          variantId: _selectedVariantId, quantity: _qty);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('✨ Added to cart!')));
    } on DioException catch (e) {
      if (!mounted) return;
      final body = e.response?.data;
      final msg = (body is Map && body['error'] != null)
          ? body['error'].toString()
          : 'Failed to add to cart. Please try again.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _addingToCart = false);
    }
  }

  void _buyNow() {
    final p        = _product!;
    final variants = p['variants'] as List? ?? [];

    // Validate: must select size if variants exist
    if (variants.isNotEmpty && _selectedVariantId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a size before buying')));
      return;
    }

    // Validate: must select color if colors exist and none selected
    final hasColors = variants
        .any((v) => (v['color'] as String?)?.isNotEmpty == true);
    if (hasColors && _selectedColor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a color before buying')));
      return;
    }

    // Build the selected variant info
    final variant = _selectedVariantId != null
        ? variants.firstWhere(
            (v) => v['id'] == _selectedVariantId,
            orElse: () => <String, dynamic>{},
          )
        : <String, dynamic>{};

    final price    = (p['price'] as num).toDouble() +
        ((variant['price_adj'] as num?)?.toDouble() ?? 0.0);
    final subtotal = price * _qty;

    final item = {
      'product_id':    p['id'],
      'variant_id':    _selectedVariantId,
      'name':          p['name'],
      'variant_size':  variant['size'] ?? '',
      'variant_color': _selectedColor ?? '',
      'quantity':      _qty,
      'price':         price,
      'subtotal':      subtotal,
      'seller_id':     p['seller_id'],
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CheckoutScreen(
          items: [item],
          total: subtotal,
          isBuyNow: true,
        ),
      ),
    );
  }

  Future<void> _submitReview() async {
    if (_reviewRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a star rating')));
      return;
    }
    setState(() => _submittingReview = true);
    try {
      await _api.submitReview(
        widget.productId,
        rating: _reviewRating,
        comment: _reviewCtrl.text.trim(),
        orderId: _selectedOrderId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✨ Review submitted!')));
      _reviewCtrl.clear();
      setState(() => _reviewRating = 0);
      _load();
    } on DioException catch (e) {
      if (!mounted) return;
      final body = e.response?.data;
      final msg = (body is Map && body['error'] != null)
          ? body['error'].toString()
          : 'Failed to submit review.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _submittingReview = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_product == null) {
      return const Scaffold(
          body: Center(
              child: CircularProgressIndicator(color: AppColors.gold)));
    }

    final p = _product!;
    final variants = p['variants'] as List? ?? [];
    final images = p['images'] as List? ?? [];
    final reviews = p['reviews'] as List? ?? [];
    final user = context.read<AuthProvider>().user;
    final isBuyer = user?['role'] == 'buyer';

    return Scaffold(
      appBar: AppBar(
        title: Text(p['name']),
        actions: [
          if (isBuyer)
            _togglingWishlist
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: AppColors.gold, strokeWidth: 2)))
                : IconButton(
                    icon: Icon(
                        _inWishlist ? Icons.favorite : Icons.favorite_border,
                        color: _inWishlist
                            ? Colors.redAccent
                            : AppColors.textMuted),
                    onPressed: _toggleWishlist),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Images
            if (images.isNotEmpty)
              SizedBox(
                height: 300,
                child: PageView.builder(
                  itemCount: images.length,
                  itemBuilder: (ctx, i) => CachedNetworkImage(
                    imageUrl: images[i],
                    fit: BoxFit.cover,
                    placeholder: (ctx, url) => const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.gold)),
                    errorWidget: (ctx, url, err) => const Center(
                        child: Icon(Icons.image_not_supported,
                            color: AppColors.textMuted, size: 60)),
                  ),
                ),
              )
            else
              Container(
                height: 300,
                color: AppColors.surface,
                child: const Center(
                    child: Icon(Icons.image_not_supported,
                        color: AppColors.textMuted, size: 60)),
              ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text((p['category'] ?? '').toString().toUpperCase(),
                      style: GoogleFonts.inter(
                          fontSize: 10,
                          color: AppColors.gold,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2)),
                  const SizedBox(height: 6),
                  Text(p['name'],
                      style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ShaderMask(
                        shaderCallback: (b) => goldGradient.createShader(b),
                        child: Text('₱${p['price']}',
                            style: GoogleFonts.inter(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                      ),
                      const Spacer(),
                      Text('⭐ ${p['rating']}',
                          style: GoogleFonts.inter(
                              color: AppColors.gold, fontSize: 14)),
                      const SizedBox(width: 4),
                      Text('(${p['review_count']})',
                          style: GoogleFonts.inter(
                              color: AppColors.textMuted, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Sold by ${p['seller']}',
                      style: GoogleFonts.inter(
                          color: AppColors.textMuted, fontSize: 12)),
                  const Divider(height: 28),

                  if (p['description'] != null &&
                      p['description'].toString().isNotEmpty) ...[
                    Text(p['description'],
                        style: GoogleFonts.inter(
                            color: AppColors.textMuted,
                            fontSize: 13,
                            height: 1.6)),
                    const SizedBox(height: 20),
                  ],

                  // Variants
                  if (variants.isNotEmpty) ...[
                    // ── Color selector ──────────────────────────────
                    Builder(builder: (context) {
                      final colors = variants
                          .map((v) => v['color'] as String?)
                          .where((c) => c != null && c.isNotEmpty)
                          .toSet()
                          .toList();
                      if (colors.isEmpty) return const SizedBox();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('COLOR: ',
                                  style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textMuted,
                                      letterSpacing: 1.5)),
                              Text(
                                  _selectedColor ?? '—',
                                  style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: colors.map<Widget>((color) {
                              final selected = _selectedColor == color;
                              return GestureDetector(
                                onTap: () => setState(() {
                                  _selectedColor = color;
                                  _selectedVariantId = null;
                                }),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? AppColors.gold
                                        : AppColors.surfaceLight,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: selected
                                            ? AppColors.gold
                                            : AppColors.border),
                                  ),
                                  child: Text(color!,
                                      style: GoogleFonts.inter(
                                          color: selected
                                              ? AppColors.background
                                              : AppColors.textPrimary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12)),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                        ],
                      );
                    }),

                    // ── Size selector with stock count ───────────────
                    Builder(builder: (context) {
                      // Get unique sizes, filtered by selected color if any
                      final filteredVariants = _selectedColor != null
                          ? variants
                              .where((v) => v['color'] == _selectedColor)
                              .toList()
                          : variants;
                      final sizes = filteredVariants
                          .map((v) => v['size'] as String)
                          .toSet()
                          .toList();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('SIZE: ',
                                  style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textMuted,
                                      letterSpacing: 1.5)),
                              Text(
                                  _selectedVariantId != null
                                      ? (variants.firstWhere(
                                              (v) =>
                                                  v['id'] ==
                                                  _selectedVariantId,
                                              orElse: () => {})['size'] ??
                                          '—')
                                      : '—',
                                  style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: sizes.map<Widget>((size) {
                              final v = filteredVariants.firstWhere(
                                  (v) => v['size'] == size,
                                  orElse: () => {});
                              final stock = v['stock'] as int? ?? 0;
                              final inStock = stock > 0;
                              final selected = _selectedVariantId == v['id'];
                              return GestureDetector(
                                onTap: inStock
                                    ? () => setState(
                                        () => _selectedVariantId = v['id'])
                                    : null,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? AppColors.gold
                                        : inStock
                                            ? AppColors.surfaceLight
                                            : AppColors.surfaceLight
                                                .withAlpha(100),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: selected
                                            ? AppColors.gold
                                            : AppColors.border,
                                        width: selected ? 2 : 1),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(size,
                                          style: GoogleFonts.inter(
                                              color: selected
                                                  ? AppColors.background
                                                  : inStock
                                                      ? AppColors.textPrimary
                                                      : AppColors.textMuted,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                              decoration: inStock
                                                  ? null
                                                  : TextDecoration
                                                      .lineThrough)),
                                      Text(
                                          inStock ? '$stock' : 'OOS',
                                          style: GoogleFonts.inter(
                                              color: selected
                                                  ? AppColors.background
                                                      .withAlpha(180)
                                                  : AppColors.textMuted,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 8),
                        ],
                      );
                    }),

                    // ── Size Guide button ────────────────────────────
                    if (p['category'] != 'Grooming Products')
                      GestureDetector(
                        onTap: () => _showSizeGuide(p['category'] ?? ''),
                        child: Row(
                          children: [
                            const Icon(Icons.straighten,
                                color: AppColors.textMuted, size: 14),
                            const SizedBox(width: 6),
                            Text('Size Guide / Measurement Chart',
                                style: GoogleFonts.inter(
                                    color: AppColors.textMuted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.underline)),
                          ],
                        ),
                      ),
                    const SizedBox(height: 20),
                  ],

                  // Qty
                  Text('QUANTITY',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                          letterSpacing: 1.5)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _QtyButton(
                          icon: Icons.remove,
                          onTap: _qty > 1
                              ? () => setState(() => _qty--)
                              : null),
                      const SizedBox(width: 16),
                      Text('$_qty',
                          style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary)),
                      const SizedBox(width: 16),
                      _QtyButton(
                          icon: Icons.add,
                          onTap: () => setState(() => _qty++)),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Add to cart + Buy Now
                  if (isBuyer) ...[
                    SizedBox(
                      width: double.infinity,
                      child: _addingToCart
                          ? const Center(
                              child: CircularProgressIndicator(
                                  color: AppColors.gold))
                          : Container(
                              decoration: BoxDecoration(
                                gradient: goldGradient,
                                borderRadius: BorderRadius.circular(40),
                                boxShadow: [
                                  BoxShadow(
                                      color: AppColors.goldMid.withAlpha(80),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6))
                                ],
                              ),
                              child: ElevatedButton.icon(
                                onPressed: _addToCart,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  foregroundColor: AppColors.background,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 16),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(40)),
                                ),
                                icon: const Icon(
                                    Icons.shopping_bag_outlined, size: 18),
                                label: Text('ADD TO CART',
                                    style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                        letterSpacing: 1.5)),
                              ),
                            ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _buyNow,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.gold,
                          side: const BorderSide(
                              color: AppColors.gold, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(40)),
                        ),
                        icon: const Icon(Icons.bolt, size: 18),
                        label: Text('BUY NOW',
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                letterSpacing: 1.5)),
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Reviews section header
                  Text('REVIEWS',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                          letterSpacing: 1.5)),
                  const SizedBox(height: 12),

                  // Review box — shown once per unreviewed delivered order
                  if (isBuyer && _reviewableOrders.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.gold.withAlpha(80)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Leave a Review',
                              style: GoogleFonts.inter(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14)),
                          const SizedBox(height: 6),
                          // Order selector if multiple reviewable orders
                          if (_reviewableOrders.length > 1) ...[
                            Text('For order:',
                                style: GoogleFonts.inter(
                                    color: AppColors.textMuted, fontSize: 11)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<int>(
                              initialValue: _selectedOrderId,
                              dropdownColor: AppColors.surfaceLight,
                              style: const TextStyle(
                                  color: AppColors.textPrimary),
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                        color: AppColors.border)),
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                        color: AppColors.border)),
                              ),
                              items: _reviewableOrders
                                  .map((o) => DropdownMenuItem<int>(
                                        value: o['id'],
                                        child: Text(o['order_number'],
                                            style: const TextStyle(
                                                color: AppColors.textPrimary,
                                                fontSize: 13)),
                                      ))
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _selectedOrderId = v),
                            ),
                            const SizedBox(height: 10),
                          ] else ...[
                            Text(
                                'Order: ${_reviewableOrders.first['order_number']}',
                                style: GoogleFonts.inter(
                                    color: AppColors.textMuted, fontSize: 11)),
                            const SizedBox(height: 10),
                          ],
                          // Star rating
                          Row(
                            children: List.generate(5, (i) {
                              return GestureDetector(
                                onTap: () =>
                                    setState(() => _reviewRating = i + 1),
                                child: Icon(
                                  i < _reviewRating
                                      ? Icons.star
                                      : Icons.star_border,
                                  color: AppColors.gold,
                                  size: 32,
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _reviewCtrl,
                            maxLines: 3,
                            style: const TextStyle(
                                color: AppColors.textPrimary),
                            decoration: const InputDecoration(
                                hintText: 'Write your review...'),
                          ),
                          const SizedBox(height: 4),
                          Text('⚠ Keep it respectful — foul language will be rejected.',
                              style: GoogleFonts.inter(
                                  color: AppColors.textMuted, fontSize: 10)),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: _submittingReview
                                ? const Center(
                                    child: CircularProgressIndicator(
                                        color: AppColors.gold))
                                : ElevatedButton(
                                    onPressed: _submitReview,
                                    child: const Text('SUBMIT REVIEW'),
                                  ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else if (isBuyer && _reviewableOrders.isEmpty) ...[
                    // Show message if buyer hasn't purchased yet
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lock_outline,
                              color: AppColors.textMuted, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                                'Purchase this product to leave a review.',
                                style: GoogleFonts.inter(
                                    color: AppColors.textMuted, fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Existing reviews
                  if (reviews.isEmpty)
                    Text('No reviews yet.',
                        style: GoogleFonts.inter(
                            color: AppColors.textMuted, fontSize: 13))
                  else
                    ...reviews.map<Widget>((r) => _ReviewTile(review: r)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final Map review;
  const _ReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(review['reviewer'] ?? '',
                  style: GoogleFonts.inter(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
              Row(
                children: List.generate(
                    5,
                    (i) => Icon(
                          i < (review['rating'] ?? 0)
                              ? Icons.star
                              : Icons.star_border,
                          color: AppColors.gold,
                          size: 14,
                        )),
              ),
            ],
          ),
          if (review['comment'] != null &&
              review['comment'].toString().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(review['comment'],
                style: GoogleFonts.inter(
                    color: AppColors.textMuted, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _QtyButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon,
            size: 18,
            color: onTap != null
                ? AppColors.textPrimary
                : AppColors.textMuted),
      ),
    );
  }
}
