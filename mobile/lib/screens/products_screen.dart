import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';
import '../theme.dart';
import 'product_detail_screen.dart';

const _kCategories = [
  '', 'Suits & Blazers', 'Casual Shirts & Pants',
  'Outerwear & Jackets', 'Activewear & Fitness Gear',
  'Shoes & Accessories', 'Grooming Products',
];

const _kSortOptions = [
  {'value': 'newest',     'label': 'Newest'},
  {'value': 'price_asc',  'label': 'Price ↑'},
  {'value': 'price_desc', 'label': 'Price ↓'},
  {'value': 'rating',     'label': 'Top Rated'},
];

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _api = ApiService();
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List _products = [];
  bool _loading = true;
  bool _loadingMore = false;
  int _page = 1;
  int _totalPages = 1;
  String _category = '';
  String _sort = 'newest';

  @override
  void initState() {
    super.initState();
    _load();
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >=
              _scrollCtrl.position.maxScrollExtent - 200 &&
          !_loadingMore &&
          !_loading &&
          _page < _totalPages) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    _page++;
    try {
      final data = await _api.getProducts(
        page: _page,
        search: _searchCtrl.text.trim(),
        category: _category,
        sort: _sort,
      );
      if (!mounted) return;
      setState(() {
        _products = [..._products, ...data['products']];
        _totalPages = data['pages'];
      });
    } catch (_) {
      _page--;
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) _page = 1;
    setState(() => _loading = true);
    try {
      final data = await _api.getProducts(
        page: _page,
        search: _searchCtrl.text.trim(),
        category: _category,
        sort: _sort,
      );
      if (!mounted) return;
      setState(() {
        _products = reset
            ? data['products']
            : [..._products, ...data['products']];
        _totalPages = data['pages'];
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('FILTERS',
                  style: GoogleFonts.orbitron(
                      color: AppColors.gold,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              Text('CATEGORY',
                  style: GoogleFonts.inter(
                      color: AppColors.textMuted,
                      fontSize: 10,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _kCategories.map((c) {
                  final label = c.isEmpty ? 'All' : c;
                  final selected = _category == c;
                  return GestureDetector(
                    onTap: () => setModal(() => _category = c),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
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
                      child: Text(label,
                          style: GoogleFonts.inter(
                              color: selected
                                  ? AppColors.background
                                  : AppColors.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              Text('SORT BY',
                  style: GoogleFonts.inter(
                      color: AppColors.textMuted,
                      fontSize: 10,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _kSortOptions.map((s) {
                  final selected = _sort == s['value'];
                  return GestureDetector(
                    onTap: () => setModal(() => _sort = s['value']!),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
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
                      child: Text(s['label']!,
                          style: GoogleFonts.inter(
                              color: selected
                                  ? AppColors.background
                                  : AppColors.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _load(reset: true);
                  },
                  child: const Text('APPLY'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search products...',
                      prefixIcon: const Icon(Icons.search,
                          color: AppColors.textMuted),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear,
                                  color: AppColors.textMuted),
                              onPressed: () {
                                _searchCtrl.clear();
                                _load(reset: true);
                              })
                          : null,
                    ),
                    onSubmitted: (v) => _load(reset: true),
                    onChanged: (v) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _showFilters,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: (_category.isNotEmpty || _sort != 'newest')
                          ? AppColors.gold
                          : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Icon(Icons.tune,
                        size: 20,
                        color: (_category.isNotEmpty || _sort != 'newest')
                            ? AppColors.background
                            : AppColors.textMuted),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading && _products.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.gold))
                : RefreshIndicator(
                    color: AppColors.gold,
                    backgroundColor: AppColors.surface,
                    onRefresh: () => _load(reset: true),
                    child: GridView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.65,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: _products.length + (_loadingMore ? 1 : 0),
                      itemBuilder: (ctx, i) {
                        if (i == _products.length) {
                          return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(
                                    color: AppColors.gold)));
                        }
                        return _ProductCard(product: _products[i]);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Map product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final p = product;
    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ProductDetailScreen(productId: p['id']))),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: p['image_url'] != null
                    ? CachedNetworkImage(
                        imageUrl: p['image_url'],
                        fit: BoxFit.cover,
                        width: double.infinity,
                        placeholder: (ctx, url) => const Center(
                            child: CircularProgressIndicator(
                                color: AppColors.gold, strokeWidth: 2)),
                        errorWidget: (ctx, url, err) => const Center(
                            child: Icon(Icons.image_not_supported,
                                color: AppColors.textMuted)),
                      )
                    : const Center(
                        child: Icon(Icons.image_not_supported,
                            color: AppColors.textMuted, size: 40)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p['category'] ?? '',
                      style: GoogleFonts.inter(
                          fontSize: 9,
                          color: AppColors.gold,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1)),
                  const SizedBox(height: 2),
                  Text(p['name'],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('₱${p['price']}',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.gold)),
                      Text('⭐ ${p['rating']}',
                          style: GoogleFonts.inter(
                              fontSize: 10, color: AppColors.textMuted)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
