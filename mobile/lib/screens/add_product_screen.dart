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

// Each variant owns its own controllers + a unique id for stable keys
class _Variant {
  final int uid; // unique id for Key
  int? serverId;
  String size;
  final TextEditingController colorCtrl;
  final TextEditingController stockCtrl;
  final TextEditingController priceAdjCtrl;

  _Variant({required this.uid, this.serverId, String? size, String color = '', int stock = 0, double priceAdj = 0})
      : size = size ?? '',
        colorCtrl    = TextEditingController(text: color),
        stockCtrl    = TextEditingController(text: stock.toString()),
        priceAdjCtrl = TextEditingController(text: priceAdj == 0 ? '' : priceAdj.toString());

  void dispose() {
    colorCtrl.dispose();
    stockCtrl.dispose();
    priceAdjCtrl.dispose();
  }

  Map<String, dynamic> toMap() => {
    'id':        serverId,
    'size':      size,
    'color':     colorCtrl.text.trim(),
    'stock':     int.tryParse(stockCtrl.text.trim()) ?? 0,
    'price_adj': double.tryParse(priceAdjCtrl.text.trim()) ?? 0.0,
  };
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
  final List<_Variant> _variants = [];
  bool _loading = false;
  int _uidCounter = 0;

  bool get _hasVariants => _kSizeMap.containsKey(_category);
  List<String> get _sizes => _kSizeMap[_category] ?? [];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _stockCtrl.dispose();
    for (final v in _variants) v.dispose();
    super.dispose();
  }

  void _onCategoryChanged(String cat) {
    for (final v in _variants) v.dispose();
    setState(() {
      _category = cat;
      _variants.clear();
    });
  }

  void _addVariant() {
    final sizes = _sizes;
    setState(() => _variants.add(_Variant(
      uid:  _uidCounter++,
      size: sizes.isNotEmpty ? sizes[0] : '',
    )));
  }

  void _removeVariant(int i) {
    _variants[i].dispose();
    setState(() => _variants.removeAt(i));
  }

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
        variants:    _variants.map((v) => v.toMap()).toList(),
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
              _label('PRODUCT IMAGES (max 5)'),
              const SizedBox(height: 10),
              _imagesRow(),
              const SizedBox(height: 20),

              _label('PRODUCT INFO'),
              const SizedBox(height: 12),
              _field(_nameCtrl, 'Product Name *',
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null),
              _field(_descCtrl, 'Description', maxLines: 4),

              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: DropdownButtonFormField<String>(
                  value: _category,
                  dropdownColor: AppColors.surfaceLight,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: _dec('Category *'),
                  items: _kCategories.map((c) => DropdownMenuItem(
                      value: c,
                      child: Text(c, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)))).toList(),
                  onChanged: (v) => _onCategoryChanged(v ?? _kCategories[0]),
                ),
              ),

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
              _label('VARIANTS & STOCK'),
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
                _hasVariants
                    ? 'Tap "Add Variant" to add stock per size/color. Or use the Stock field above.'
                    : 'This category uses a flat stock (no size variants).',
                style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12),
              )),
            ]),
          ),

        // Each card gets a ValueKey(v.uid) so Flutter never reuses the wrong state
        for (int i = 0; i < _variants.length; i++)
          _VariantCard(
            key: ValueKey(_variants[i].uid),
            index: i,
            variant: _variants[i],
            sizeOptions: _sizes,
            onRemove: () => _removeVariant(i),
            onSizeChanged: (s) => setState(() => _variants[i].size = s),
          ),

        if (_hasVariants) ...[
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

  InputDecoration _dec(String label) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
    filled: true, fillColor: AppColors.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.gold, width: 1.5)),
  );

  Widget _label(String t) => Text(t,
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

// ── Variant card as its own StatefulWidget with stable key ────────────────────

class _VariantCard extends StatefulWidget {
  final int index;
  final _Variant variant;
  final List<String> sizeOptions;
  final VoidCallback onRemove;
  final ValueChanged<String> onSizeChanged;

  const _VariantCard({
    super.key,
    required this.index,
    required this.variant,
    required this.sizeOptions,
    required this.onRemove,
    required this.onSizeChanged,
  });

  @override
  State<_VariantCard> createState() => _VariantCardState();
}

class _VariantCardState extends State<_VariantCard> {
  late String _selectedSize;

  @override
  void initState() {
    super.initState();
    final opts = widget.sizeOptions;
    _selectedSize = opts.contains(widget.variant.size)
        ? widget.variant.size
        : (opts.isNotEmpty ? opts[0] : '');
    // Sync back in case it defaulted
    widget.variant.size = _selectedSize;
  }

  InputDecoration _dec(String label) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
    filled: true, fillColor: AppColors.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.gold, width: 1.5)),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey(widget.variant.uid),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withAlpha(60)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Variant ${widget.index + 1}',
              style: GoogleFonts.inter(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w700)),
          GestureDetector(
            onTap: widget.onRemove,
            child: const Icon(Icons.delete_outline, color: AppColors.error, size: 18),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _selectedSize.isNotEmpty ? _selectedSize : null,
              dropdownColor: AppColors.surface,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              decoration: _dec('Size'),
              items: widget.sizeOptions.map((s) => DropdownMenuItem(
                  value: s,
                  child: Text(s, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)))).toList(),
              onChanged: (s) {
                if (s == null) return;
                setState(() => _selectedSize = s);
                widget.onSizeChanged(s);
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              controller: widget.variant.colorCtrl,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              decoration: _dec('Color (opt.)'),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: TextFormField(
              controller: widget.variant.stockCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              decoration: _dec('Stock'),
              validator: (v) => int.tryParse(v ?? '') == null ? 'Invalid' : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              controller: widget.variant.priceAdjCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              decoration: _dec('Price Adj. (₱)'),
            ),
          ),
        ]),
      ]),
    );
  }
}
