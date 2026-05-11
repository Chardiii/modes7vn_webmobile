import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
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

class EditProductScreen extends StatefulWidget {
  final int productId;
  const EditProductScreen({super.key, required this.productId});

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  final _api = ApiService();
  final _formKey   = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _descCtrl  = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();

  String _category = _kCategories[0];
  bool _loading = true;
  bool _saving = false;

  // Existing images from server: {id, url, is_primary}
  List<Map<String, dynamic>> _existingImages = [];
  // IDs of existing images marked for deletion
  final Set<int> _removeIds = {};
  // New images picked from gallery
  List<XFile> _newImages = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data =
          await _api.getSellerProductForEdit(widget.productId);
      if (!mounted) return;
      _nameCtrl.text  = data['name'] ?? '';
      _descCtrl.text  = data['description'] ?? '';
      _priceCtrl.text = data['price'].toString();
      _stockCtrl.text = data['stock'].toString();
      final cat = data['category'] ?? _kCategories[0];
      setState(() {
        _category = _kCategories.contains(cat) ? cat : _kCategories[0];
        _existingImages = List<Map<String, dynamic>>.from(
            data['images'] as List? ?? []);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error loading: $e')));
      Navigator.pop(context);
    }
  }

  Future<void> _pickImages() async {
    final total = (_existingImages.length - _removeIds.length) +
        _newImages.length;
    if (total >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maximum 5 images allowed')));
      return;
    }
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 80);
    if (picked.isNotEmpty) {
      final remaining = 5 - total;
      setState(() {
        _newImages = [
          ..._newImages,
          ...picked.take(remaining)
        ];
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() => _saving = true);
    try {
      await _api.editProduct(
        productId:      widget.productId,
        name:           _nameCtrl.text.trim(),
        price:          double.parse(_priceCtrl.text.trim()),
        category:       _category,
        description:    _descCtrl.text.trim(),
        stock:          int.tryParse(_stockCtrl.text.trim()) ?? 0,
        newImagePaths:  _newImages.map((x) => x.path).toList(),
        removeImageIds: _removeIds.toList(),
      );
      if (!mounted) return;
      messenger.showSnackBar(
          const SnackBar(content: Text('✨ Product updated!')));
      nav.pop(true);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
          body: Center(
              child: CircularProgressIndicator(color: AppColors.gold)));
    }

    final visibleExisting = _existingImages
        .where((img) => !_removeIds.contains(img['id'] as int))
        .toList();
    final totalImages = visibleExisting.length + _newImages.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Product')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Images section
              _sectionLabel('PRODUCT IMAGES (max 5)'),
              const SizedBox(height: 10),
              SizedBox(
                height: 110,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    // Add button
                    GestureDetector(
                      onTap: totalImages < 5 ? _pickImages : null,
                      child: Container(
                        width: 100,
                        height: 100,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: totalImages < 5
                                  ? AppColors.gold
                                  : AppColors.border),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined,
                                color: totalImages < 5
                                    ? AppColors.gold
                                    : AppColors.textMuted,
                                size: 28),
                            const SizedBox(height: 4),
                            Text('Add Photo',
                                style: GoogleFonts.inter(
                                    color: totalImages < 5
                                        ? AppColors.gold
                                        : AppColors.textMuted,
                                    fontSize: 10)),
                          ],
                        ),
                      ),
                    ),

                    // Existing images
                    ...visibleExisting.asMap().entries.map((e) {
                      final img = e.value;
                      final isPrimary = img['is_primary'] as bool? ?? false;
                      return Stack(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: isPrimary
                                      ? AppColors.gold
                                      : AppColors.border,
                                  width: isPrimary ? 2 : 1),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: CachedNetworkImage(
                                imageUrl: img['url'],
                                fit: BoxFit.cover,
                                errorWidget: (ctx, url, err) =>
                                    const Icon(Icons.image_not_supported,
                                        color: AppColors.textMuted),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 14,
                            child: GestureDetector(
                              onTap: () => setState(
                                  () => _removeIds.add(img['id'] as int)),
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: const BoxDecoration(
                                    color: AppColors.error,
                                    shape: BoxShape.circle),
                                child: const Icon(Icons.close,
                                    color: Colors.white, size: 14),
                              ),
                            ),
                          ),
                          if (isPrimary)
                            Positioned(
                              bottom: 4,
                              left: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                    color: AppColors.gold,
                                    borderRadius: BorderRadius.circular(4)),
                                child: Text('Cover',
                                    style: GoogleFonts.inter(
                                        color: AppColors.background,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ),
                        ],
                      );
                    }),

                    // New images
                    ..._newImages.asMap().entries.map((e) {
                      return Stack(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.gold),
                              image: DecorationImage(
                                image: FileImage(File(e.value.path)),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 14,
                            child: GestureDetector(
                              onTap: () => setState(
                                  () => _newImages.removeAt(e.key)),
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: const BoxDecoration(
                                    color: AppColors.error,
                                    shape: BoxShape.circle),
                                child: const Icon(Icons.close,
                                    color: Colors.white, size: 14),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 4,
                            left: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                  color: AppColors.goldMid,
                                  borderRadius: BorderRadius.circular(4)),
                              child: Text('New',
                                  style: GoogleFonts.inter(
                                      color: AppColors.background,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Product info
              _sectionLabel('PRODUCT INFO'),
              const SizedBox(height: 12),
              _field(_nameCtrl, 'Product Name *',
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Required'
                      : null),
              _field(_descCtrl, 'Description', maxLines: 4),

              // Category
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: DropdownButtonFormField<String>(
                  initialValue: _category,
                  dropdownColor: AppColors.surfaceLight,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Category *',
                    labelStyle:
                        const TextStyle(color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.surfaceLight,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.border)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: AppColors.gold, width: 1.5)),
                  ),
                  items: _kCategories
                      .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c,
                              style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 13))))
                      .toList(),
                  onChanged: (v) => setState(
                      () => _category = v ?? _kCategories[0]),
                ),
              ),

              // Price & Stock
              Row(
                children: [
                  Expanded(
                    child: _field(_priceCtrl, 'Price (₱) *',
                        keyboard: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Required';
                          }
                          if (double.tryParse(v.trim()) == null) {
                            return 'Invalid number';
                          }
                          if (double.parse(v.trim()) <= 0) {
                            return 'Must be > 0';
                          }
                          return null;
                        }),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(_stockCtrl, 'Stock *',
                        keyboard: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Required';
                          }
                          if (int.tryParse(v.trim()) == null) {
                            return 'Invalid number';
                          }
                          return null;
                        }),
                  ),
                ],
              ),

              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: _saving
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
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: AppColors.background,
                            padding: const EdgeInsets.symmetric(
                                vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(40)),
                          ),
                          icon: const Icon(Icons.save_outlined, size: 18),
                          label: Text('SAVE CHANGES',
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  letterSpacing: 1.5)),
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

  Widget _sectionLabel(String label) => Text(label,
      style: GoogleFonts.inter(
          color: AppColors.textMuted,
          fontSize: 10,
          letterSpacing: 1.5,
          fontWeight: FontWeight.w600));

  Widget _field(TextEditingController ctrl, String label,
      {TextInputType? keyboard,
      int maxLines = 1,
      String? Function(String?)? validator}) {
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
