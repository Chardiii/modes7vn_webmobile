import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../theme.dart';

const _kCategories = [
  'Suits & Blazers',
  'Casual Shirts & Pants',
  'Outerwear & Jackets',
  'Activewear & Fitness Gear',
  'Shoes & Accessories',
  'Grooming Products',
];

const _kSizeMap = {
  'Suits & Blazers':           ['XS', 'S', 'M', 'L', 'XL', 'XXL'],
  'Casual Shirts & Pants':     ['XS', 'S', 'M', 'L', 'XL', 'XXL', '28', '30', '32', '34', '36', '38', '40'],
  'Outerwear & Jackets':       ['XS', 'S', 'M', 'L', 'XL', 'XXL'],
  'Activewear & Fitness Gear': ['XS', 'S', 'M', 'L', 'XL', 'XXL'],
  'Shoes & Accessories':       ['38', '39', '40', '41', '42', '43', '44', '45'],
};

// Variant row model
class _VariantRow {
  String size;
  String color;
  int stock;
  double priceAdj;
  int? id; // null for new rows
  _VariantRow({this.size = '', this.color = '', this.stock = 0, this.priceAdj = 0, this.id});
}

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _api      = ApiService();
  final _formKey  = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _descCtrl  = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _stockCtrl = TextEditingController(text: '0');

  String _category = _kCategories[0];
  List<XFile> _images = [];
  List<_VariantRow> _variants = [];
  bool _loading = false;

  bool get _hasVariantSizes => _kSizeMap.containsKey(_category);

  List<String> get _sizeOptions => _kSizeMap[_category] ?? [];

  void _onCategoryChanged(String cat) {
    setState(() {
      _category = cat;
      _variants.clear();
    });
  }

  void _addVariant() {
    setState(() => _variants.add(_VariantRow(
      size: _sizeOptions.isNotEmpty ? _sizeOptions[0] : '',
    )));
  }

  void _removeVariant(int i) => setState(() => _variants.removeAt(i));

  Future<void> _pickImages() async {
    final picked = await ImagePicker().pickMultiImage(imageQuality: 80);
    if (picked.isNotEmpty) {
      setState(() => _images = [..._images, ...picked].take(5).toList());
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_variants.isNotEmpty && _variants.any((v) => v.size.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All variants must have a size selected.')));
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() => _loading = true);
    try {
      await _api.addProduct(
        name:        _nameCtrl.text.trim(),
        price:       double.parse(_priceCtrl.text.trim()),
        category:    _category,
        description: _descCtrl.text.trim(),
        stock:       _variants.isEmpty ? (int.tryParse(_stockCtrl.text.trim()) ?? 0) : 0,
        imagePaths:  _images.map((x) => x.path).toList(),
        variants:    _variants.map((v) => {
          'size': v.size, 'color': v.color,
          'stock': v.stock, 'price_adj': v.priceAdj,
        }).toList(),
      );
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('✨ Product added successfully!')));
      nav.pop(true);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Product')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel('PRODUCT IMAGES (max 5)'),
              const SizedBox(height: 10),
              _imagesRow(),
              const SizedBox(height: 20),

              _sectionLabel('PRODUCT INFO'),
              const SizedBox(height: 12),
              _field(_nameCtrl, 'Product Name *',
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null),
              _field(_descCtrl, 'Description', maxLines: 4),

              // Category
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: DropdownButtonFormField<String>(
                  value: _category,
                  dropdownColor: AppColors.surfaceLight,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: _dropDecor('Category *'),
                  items: _kCategories
                      .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13))))
                      .toList(),
                  onChanged: (v) => _onCategoryChanged(v ?? _kCategories[0]),
                ),
              ),

              // Price row — stock only shown when no variants
              Row(children: [
                Expanded(child: _field(_priceCtrl, 'Price (₱) *',
                    keyboard: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (double.tryParse(v.trim()) == null) return 'Invalid';
                      if (double.parse(v.trim()) <= 0) return 'Must be > 0';
                      return null;
                    })),
                if (_variants.isEmpty) ...[
                  const SizedBox(width: 12),
                  Expanded(child: _field(_stockCtrl, 'Stock *',
                      keyboard: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        if (int.tryParse(v.trim()) == null) return 'Invalid';
                        return null;
                      })),
                ],
              ]),

              const SizedBox(height: 4),
              _sectionLabel('VARIANTS & STOCK'),
              const SizedBox(height: 10),
              _variantsSection(),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
                    : Container(
                        decoration: BoxDecoration(
                          gradient: goldGradient,
                          borderRadius: BorderRadius.circular(40),
                          boxShadow: [BoxShadow(color: AppColors.goldMid.withAlpha(80), blurRadius: 16, offset: const Offset(0, 6))],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: AppColors.background,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
                          ),
                          icon: const Icon(Icons.add_circle_outline, size: 18),
                          label: Text('ADD PRODUCT',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1.5)),
                        ),
                      ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imagesRow() {
    return SizedBox(
      height: 110,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          GestureDetector(
            onTap: _images.length < 5 ? _pickImages : null,
            child: Container(
              width: 100, height: 100,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _images.length < 5 ? AppColors.gold : AppColors.border),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.add_photo_alternate_outlined,
                    color: _images.length < 5 ? AppColors.gold : AppColors.textMuted, size: 28),
                const SizedBox(height: 4),
                Text('Add Photo', style: GoogleFonts.inter(
                    color: _images.length < 5 ? AppColors.gold : AppColors.textMuted, fontSize: 10)),
              ]),
            ),
          ),
          ..._images.asMap().entries.map((e) => Stack(children: [
            Container(
              width: 100, height: 100,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
                image: DecorationImage(image: FileImage(File(e.value.path)), fit: BoxFit.cover),
              ),
            ),
            Positioned(top: 4, right: 14, child: GestureDetector(
              onTap: () => setState(() => _images.removeAt(e.key)),
              child: Container(width: 22, height: 22,
                  decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                  child: const Icon(Icons.close, color: Colors.white, size: 14)),
            )),
            if (e.key == 0)
              Positioned(bottom: 4, left: 4, child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(4)),
                child: Text('Cover', style: GoogleFonts.inter(color: AppColors.background, fontSize: 9, fontWeight: FontWeight.w700)),
              )),
          ])),
        ],
      ),
    );
  }

  Widget _variantsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_variants.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline, color: AppColors.textMuted, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(
                _hasVariantSizes
                    ? 'Add variants to set stock per size/color. Or use the Stock field above for a single stock.'
                    : 'This category uses a flat stock (no size variants).',
                style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12),
              )),
            ]),
          ),

        ..._variants.asMap().entries.map((e) => _variantCard(e.key, e.value)),

        if (_hasVariantSizes) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _addVariant,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.gold,
              side: const BorderSide(color: AppColors.gold),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            icon: const Icon(Icons.add, size: 16),
            label: Text('Add Variant', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ],
    );
  }

  Widget _variantCard(int i, _VariantRow v) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withAlpha(60)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Variant ${i + 1}', style: GoogleFonts.inter(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w700)),
          GestureDetector(
            onTap: () => _removeVariant(i),
            child: const Icon(Icons.delete_outline, color: AppColors.error, size: 18),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          // Size dropdown
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _sizeOptions.contains(v.size) ? v.size : _sizeOptions.first,
              dropdownColor: AppColors.surface,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              decoration: _dropDecor('Size'),
              items: _sizeOptions.map((s) => DropdownMenuItem(
                  value: s, child: Text(s, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)))).toList(),
              onChanged: (s) => setState(() => v.size = s ?? ''),
            ),
          ),
          const SizedBox(width: 10),
          // Color field
          Expanded(
            child: TextFormField(
              initialValue: v.color,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              decoration: _dropDecor('Color (opt.)'),
              onChanged: (s) => v.color = s,
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          // Stock
          Expanded(
            child: TextFormField(
              initialValue: v.stock.toString(),
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              decoration: _dropDecor('Stock'),
              validator: (val) => int.tryParse(val ?? '') == null ? 'Invalid' : null,
              onChanged: (s) => v.stock = int.tryParse(s) ?? 0,
            ),
          ),
          const SizedBox(width: 10),
          // Price adjustment
          Expanded(
            child: TextFormField(
              initialValue: v.priceAdj == 0 ? '' : v.priceAdj.toString(),
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              decoration: _dropDecor('Price Adj. (₱)'),
              onChanged: (s) => v.priceAdj = double.tryParse(s) ?? 0,
            ),
          ),
        ]),
      ]),
    );
  }

  InputDecoration _dropDecor(String label) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
    filled: true,
    fillColor: AppColors.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.gold, width: 1.5)),
  );

  Widget _sectionLabel(String label) => Text(label,
      style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.w600));

  Widget _field(TextEditingController ctrl, String label,
      {TextInputType? keyboard, int maxLines = 1, String? Function(String?)? validator}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboard,
        maxLines: maxLines,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(labelText: label),
        validator: validator,
      ),
    );
  }
}
