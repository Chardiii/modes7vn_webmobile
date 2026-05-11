import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';
import '../theme.dart';
import 'checkout_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => CartScreenState();
}

class CartScreenState extends State<CartScreen> {
  final _api = ApiService();
  List _items = [];
  bool _loading = true;
  // Track selected items by index
  final Set<int> _selected = {};

  @override
  void initState() {
    super.initState();
    _load(resetSelection: true);
  }

  Future<void> load() => _load(resetSelection: true);

  Future<void> _load({bool resetSelection = false}) async {
    setState(() => _loading = true);
    try {
      final data = await _api.getCart();
      if (!mounted) return;
      final items = (data['items'] as List?) ?? [];
      setState(() {
        _items = items;
        if (resetSelection) {
          _selected.clear();
          for (int i = 0; i < items.length; i++) {
            _selected.add(i);
          }
        } else {
          // Keep existing selection but clamp to new item count
          _selected.removeWhere((i) => i >= items.length);
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _remove(int index) async {
    final item = _items[index];
    await _api.removeFromCart(item['product_id'], variantId: item['variant_id']);
    _load(resetSelection: false);
  }

  Future<void> _updateQty(int index, int newQty) async {
    if (newQty < 1) return;
    final item = _items[index];
    try {
      await _api.updateCartQty(item['product_id'],
          variantId: item['variant_id'], quantity: newQty);
      _load(resetSelection: false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  double get _selectedTotal {
    double total = 0;
    for (final i in _selected) {
      if (i < _items.length) {
        total += double.tryParse(_items[i]['subtotal'].toString()) ?? 0;
      }
    }
    return total;
  }

  List get _selectedItems => [
        for (int i = 0; i < _items.length; i++)
          if (_selected.contains(i)) _items[i]
      ];

  void _checkout() async {
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one item')));
      return;
    }
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CheckoutScreen(
          items: _selectedItems,
          total: _selectedTotal,
        ),
      ),
    );
    if (result == true) _load(resetSelection: true);
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
            const Icon(Icons.shopping_bag_outlined,
                size: 64, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text('Your cart is empty',
                style: GoogleFonts.inter(
                    color: AppColors.textMuted, fontSize: 16)),
          ],
        ),
      );
    }

    final allSelected = _selected.length == _items.length;

    return Material(
      color: AppColors.background,
      child: Column(
        children: [
          // Select all row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Checkbox(
                  value: allSelected,
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      _selected.addAll(
                          List.generate(_items.length, (i) => i));
                    } else {
                      _selected.clear();
                    }
                  }),
                  activeColor: AppColors.gold,
                  checkColor: AppColors.background,
                  side: const BorderSide(color: AppColors.textMuted),
                ),
                Text('Select All',
                    style: GoogleFonts.inter(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('${_selected.length} of ${_items.length} selected',
                    style: GoogleFonts.inter(
                        color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
          const Divider(height: 1),
          // Items list
          Expanded(
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
                  final isSelected = _selected.contains(i);
                  return Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: isSelected
                              ? AppColors.gold.withAlpha(150)
                              : AppColors.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Checkbox
                          Checkbox(
                            value: isSelected,
                            onChanged: (v) => setState(() {
                              if (v == true) {
                                _selected.add(i);
                              } else {
                                _selected.remove(i);
                              }
                            }),
                            activeColor: AppColors.gold,
                            checkColor: AppColors.background,
                            side: const BorderSide(color: AppColors.textMuted),
                          ),
                          // Image
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: item['image_url'] != null
                                ? CachedNetworkImage(
                                    imageUrl: item['image_url'],
                                    width: 64,
                                    height: 64,
                                    fit: BoxFit.cover)
                                : Container(
                                    width: 64,
                                    height: 64,
                                    color: AppColors.surfaceLight,
                                    child: const Icon(
                                        Icons.image_not_supported,
                                        color: AppColors.textMuted)),
                          ),
                          const SizedBox(width: 12),
                          // Info + qty controls
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item['name'],
                                    style: GoogleFonts.inter(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13)),
                                if ((item['variant_size'] ?? '').isNotEmpty)
                                  Text('Size: ${item['variant_size']}',
                                      style: GoogleFonts.inter(
                                          color: AppColors.textMuted,
                                          fontSize: 11)),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    // Qty controls
                                    _QtyBtn(
                                      icon: Icons.remove,
                                      onTap: item['quantity'] > 1
                                          ? () => _updateQty(
                                              i, item['quantity'] - 1)
                                          : null,
                                    ),
                                    const SizedBox(width: 10),
                                    Text('${item['quantity']}',
                                        style: GoogleFonts.inter(
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14)),
                                    const SizedBox(width: 10),
                                    _QtyBtn(
                                      icon: Icons.add,
                                      onTap: () =>
                                          _updateQty(i, item['quantity'] + 1),
                                    ),
                                    const Spacer(),
                                    Text('₱${item['subtotal']}',
                                        style: GoogleFonts.inter(
                                            color: AppColors.gold,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Delete
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: AppColors.error, size: 20),
                            onPressed: () => _remove(i),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          // Bottom bar
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('TOTAL (${_selected.length} items)',
                            style: GoogleFonts.inter(
                                color: AppColors.textMuted,
                                fontSize: 11,
                                letterSpacing: 1,
                                fontWeight: FontWeight.w600)),
                        ShaderMask(
                          shaderCallback: (b) =>
                              goldGradient.createShader(b),
                          child: Text('₱${_selectedTotal.toStringAsFixed(2)}',
                              style: GoogleFonts.inter(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                        ),
                      ],
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: _selected.isNotEmpty ? goldGradient : null,
                        color: _selected.isEmpty
                            ? AppColors.surfaceLight
                            : null,
                        borderRadius: BorderRadius.circular(40),
                      ),
                      child: ElevatedButton(
                        onPressed: _selected.isNotEmpty ? _checkout : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: _selected.isNotEmpty
                              ? AppColors.background
                              : AppColors.textMuted,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 28, vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(40)),
                        ),
                        child: Text('CHECKOUT',
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                letterSpacing: 1.5)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _QtyBtn({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon,
            size: 16,
            color: onTap != null ? AppColors.textPrimary : AppColors.textMuted),
      ),
    );
  }
}
