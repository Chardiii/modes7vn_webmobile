import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../services/auth_provider.dart';
import '../theme.dart';

class CheckoutScreen extends StatefulWidget {
  final List items;
  final double total;
  const CheckoutScreen({super.key, required this.items, required this.total});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _api        = ApiService();
  final _formKey    = GlobalKey<FormState>();
  final _addressCtrl  = TextEditingController();
  final _cityCtrl     = TextEditingController();
  final _provinceCtrl = TextEditingController();
  final _zipCtrl      = TextEditingController();

  bool   _placing             = false;
  bool   _useDifferentAddress = false;
  String _paymentMethod       = 'cod';

  // Saved profile address
  String _savedAddress  = '';
  String _savedCity     = '';
  String _savedProvince = '';
  String _savedZip      = '';
  bool   _hasSavedAddress = false;

  // Shipping estimate
  double? _shippingFee;
  String  _shippingZone = '';
  bool    _estimating   = false;

  @override
  void initState() {
    super.initState();
    _loadProfileAddress();
  }

  void _loadProfileAddress() {
    final user       = context.read<AuthProvider>().user ?? {};
    final street     = user['street']       ?? '';
    final barangay   = user['barangay']     ?? '';
    final municipality = user['municipality'] ?? '';
    final province   = user['province']     ?? '';
    final zip        = user['zip_code']     ?? '';

    final parts = [street, barangay].where((s) => s.isNotEmpty).toList();
    _savedAddress  = parts.join(', ');
    _savedCity     = municipality;
    _savedProvince = province;
    _savedZip      = zip;
    _hasSavedAddress = _savedAddress.isNotEmpty && _savedCity.isNotEmpty && _savedProvince.isNotEmpty;

    _addressCtrl.text  = _savedAddress;
    _cityCtrl.text     = _savedCity;
    _provinceCtrl.text = _savedProvince;
    _zipCtrl.text      = _savedZip;

    // Auto-estimate on load if we have a saved address with province
    if (_hasSavedAddress) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _estimateShipping());
    }
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _provinceCtrl.dispose();
    _zipCtrl.dispose();
    super.dispose();
  }

  String get _deliveryAddress  => _useDifferentAddress ? _addressCtrl.text.trim()  : _savedAddress;
  String get _deliveryCity     => _useDifferentAddress ? _cityCtrl.text.trim()     : _savedCity;
  String get _deliveryProvince => _useDifferentAddress ? _provinceCtrl.text.trim() : _savedProvince;
  String get _deliveryZip      => _useDifferentAddress ? _zipCtrl.text.trim()      : _savedZip;

  int? get _sellerId {
    if (widget.items.isEmpty) return null;
    return widget.items.first['seller_id'] as int?;
  }

  Future<void> _estimateShipping() async {
    final city     = _deliveryCity;
    final province = _deliveryProvince;
    final sellerId = _sellerId;
    if (city.isEmpty || province.isEmpty || sellerId == null) return;

    setState(() => _estimating = true);
    try {
      final result = await _api.estimateShipping(
        sellerId: sellerId,
        deliveryCity: city,
        deliveryProvince: province,
      );
      if (!mounted) return;
      setState(() {
        _shippingFee  = (result['fee'] as num).toDouble();
        _shippingZone = result['zone'] ?? '';
      });
    } catch (_) {
      // silently fail — user can still place order
    } finally {
      if (mounted) setState(() => _estimating = false);
    }
  }

  double get _grandTotal => widget.total + (_shippingFee ?? 0.0);

  String get _zoneLabel {
    switch (_shippingZone) {
      case 'same_city':      return 'Same City';
      case 'same_province':  return 'Same Province';
      case 'inter_province': return 'Inter-Province';
      default:               return '';
    }
  }

  Future<void> _placeOrder() async {
    if (_useDifferentAddress && !_formKey.currentState!.validate()) return;
    if (!_useDifferentAddress && !_hasSavedAddress) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please add a delivery address with province in your profile first.')));
      return;
    }
    if (_deliveryProvince.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Province is required for shipping calculation.')));
      return;
    }

    setState(() => _placing = true);
    try {
      final result = await _api.checkout(
        address:       _deliveryAddress,
        city:          _deliveryCity,
        province:      _deliveryProvince,
        zip:           _deliveryZip,
        paymentMethod: _paymentMethod,
        selectedItems: widget.items.map<Map<String, dynamic>>((i) => {
          'product_id': i['product_id'],
          'variant_id': i['variant_id'],
        }).toList(),
      );

      if (!mounted) return;
      final orders = result['orders'] as List? ?? [];

      if (_paymentMethod == 'online' && orders.isNotEmpty) {
        for (final order in orders) {
          try {
            final linkResult = await _api.createPaymentLink(order['id']);
            final checkoutUrl = linkResult['checkout_url'] as String?;
            if (checkoutUrl != null) await _launchPayMongo(checkoutUrl, order['id']);
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment link error: $e')));
            return;
          }
        }
      } else {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✨ Order placed successfully!')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  Future<void> _launchPayMongo(String url, int orderId) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    }
    if (!mounted) return;
    _showPaymentConfirmDialog(orderId);
  }

  void _showPaymentConfirmDialog(int orderId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.border)),
        title: Text('Payment Confirmation',
            style: GoogleFonts.orbitron(color: AppColors.gold, fontSize: 15)),
        content: Text('Have you completed the payment on PayMongo?',
            style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final result = await _api.verifyPayment(orderId);
                if (!mounted) return;
                Navigator.pop(context, true);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(result['paid'] == true
                        ? '✨ Payment confirmed! Order is now active.'
                        : 'Payment pending. Check your orders.')));
              } catch (_) {
                if (!mounted) return;
                Navigator.pop(context, true);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Order placed! Payment will be verified shortly.')));
              }
            },
            child: Text('Yes, I paid', style: GoogleFonts.inter(color: AppColors.gold)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _api.createPaymentLink(orderId).then((r) {
                final url = r['checkout_url'] as String?;
                if (url != null) _launchPayMongo(url, orderId);
              });
            },
            child: Text('Pay Again', style: GoogleFonts.inter(color: AppColors.textMuted)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Delivery Address ──────────────────────────────────────
              _SectionCard(
                icon: Icons.location_on_outlined,
                title: 'Delivery Address',
                trailing: _hasSavedAddress
                    ? GestureDetector(
                        onTap: () {
                          setState(() => _useDifferentAddress = !_useDifferentAddress);
                          _estimateShipping();
                        },
                        child: Text(
                          _useDifferentAddress ? 'Use Saved Address' : 'Use Different Address',
                          style: GoogleFonts.inter(
                              color: AppColors.gold, fontSize: 12,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline),
                        ),
                      )
                    : null,
                child: _useDifferentAddress || !_hasSavedAddress
                    ? _buildAddressForm()
                    : _buildSavedAddress(),
              ),
              const SizedBox(height: 16),

              // ── Order Items ───────────────────────────────────────────
              _SectionCard(
                icon: Icons.shopping_bag_outlined,
                title: 'Order Items (${widget.items.length})',
                child: Column(
                  children: widget.items.map<Widget>((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(children: [
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item['name'],
                              style: GoogleFonts.inter(color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600, fontSize: 13)),
                          if ((item['variant_size'] ?? '').isNotEmpty)
                            Text('Size: ${item['variant_size']}',
                                style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11)),
                          Text('x${item['quantity']}',
                              style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11)),
                        ],
                      )),
                      Text('₱${item['subtotal']}',
                          style: GoogleFonts.inter(color: AppColors.gold,
                              fontWeight: FontWeight.w700, fontSize: 14)),
                    ]),
                  )).toList(),
                ),
              ),
              const SizedBox(height: 16),

              // ── Payment Method ────────────────────────────────────────
              _SectionCard(
                icon: Icons.payments_outlined,
                title: 'Payment Method',
                child: Column(children: [
                  _PaymentOption(
                    value: 'cod', groupValue: _paymentMethod,
                    icon: Icons.money, label: 'Cash on Delivery',
                    subtitle: 'Pay the rider when your order arrives.',
                    color: AppColors.success,
                    onChanged: (v) => setState(() => _paymentMethod = v!),
                  ),
                  const SizedBox(height: 10),
                  _PaymentOption(
                    value: 'online', groupValue: _paymentMethod,
                    icon: Icons.credit_card_outlined, label: 'Online Payment',
                    subtitle: 'Pay via GCash, Maya, or Credit/Debit Card through PayMongo.',
                    color: Colors.blue,
                    onChanged: (v) => setState(() => _paymentMethod = v!),
                  ),
                ]),
              ),
              const SizedBox(height: 16),

              // ── Order Summary ─────────────────────────────────────────
              _SectionCard(
                icon: Icons.receipt_outlined,
                title: 'Order Summary',
                child: Column(children: [
                  ...widget.items.map<Widget>((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text('${item['name']} x${item['quantity']}',
                              style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12),
                              overflow: TextOverflow.ellipsis),
                        ),
                        Text('₱${item['subtotal']}',
                            style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12)),
                      ],
                    ),
                  )),
                  const Divider(height: 20),

                  // Subtotal row
                  _SummaryRow(
                    label: 'Subtotal',
                    value: '₱${widget.total.toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 6),

                  // Shipping row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Shipping Fee',
                              style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13)),
                          if (_zoneLabel.isNotEmpty)
                            Text(_zoneLabel,
                                style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 10)),
                        ],
                      ),
                      _estimating
                          ? const SizedBox(width: 16, height: 16,
                              child: CircularProgressIndicator(color: AppColors.gold, strokeWidth: 2))
                          : Text(
                              _shippingFee != null
                                  ? '₱${_shippingFee!.toStringAsFixed(2)}'
                                  : '—',
                              style: GoogleFonts.inter(
                                  color: _shippingFee != null ? AppColors.textPrimary : AppColors.textMuted,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                    ],
                  ),

                  if (_shippingFee == null && !_estimating) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(children: [
                        const Icon(Icons.info_outline, color: AppColors.textMuted, size: 14),
                        const SizedBox(width: 6),
                        Expanded(child: Text(
                          'Enter your city and province to see the shipping fee.',
                          style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11),
                        )),
                      ]),
                    ),
                  ],

                  const Divider(height: 20),

                  // Grand total
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total',
                          style: GoogleFonts.inter(color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700, fontSize: 15)),
                      ShaderMask(
                        shaderCallback: (b) => goldGradient.createShader(b),
                        child: Text('₱${_grandTotal.toStringAsFixed(2)}',
                            style: GoogleFonts.inter(fontSize: 20,
                                fontWeight: FontWeight.w800, color: Colors.white)),
                      ),
                    ],
                  ),
                ]),
              ),
              const SizedBox(height: 24),

              // ── Place Order Button ─────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: _placing
                    ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
                    : Container(
                        decoration: BoxDecoration(
                          gradient: goldGradient,
                          borderRadius: BorderRadius.circular(40),
                          boxShadow: [BoxShadow(
                              color: AppColors.goldMid.withAlpha(80),
                              blurRadius: 16, offset: const Offset(0, 6))],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _placeOrder,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: AppColors.background,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
                          ),
                          icon: Icon(
                            _paymentMethod == 'online' ? Icons.open_in_new : Icons.check_circle_outline,
                            size: 20),
                          label: Text(
                            _paymentMethod == 'online' ? 'PLACE ORDER & PAY ONLINE' : 'PLACE ORDER',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w800,
                                fontSize: 13, letterSpacing: 1.5)),
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

  Widget _buildSavedAddress() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.gold.withAlpha(80)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.home_outlined, color: AppColors.gold, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_savedAddress,
              style: GoogleFonts.inter(color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 2),
          Text(
            [_savedCity, if (_savedProvince.isNotEmpty) _savedProvince,
             if (_savedZip.isNotEmpty) _savedZip].join(', '),
            style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.gold.withAlpha(30),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('Saved Address',
                style: GoogleFonts.inter(color: AppColors.gold,
                    fontSize: 10, fontWeight: FontWeight.w700)),
          ),
        ])),
      ]),
    );
  }

  Widget _buildAddressForm() {
    return Column(children: [
      TextFormField(
        controller: _addressCtrl,
        maxLines: 2,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: const InputDecoration(labelText: 'Street Address / Barangay *'),
        validator: (v) => v == null || v.trim().isEmpty ? 'Address is required' : null,
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
          child: TextFormField(
            controller: _cityCtrl,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(labelText: 'City / Municipality *'),
            validator: (v) => v == null || v.trim().isEmpty ? 'City is required' : null,
            onEditingComplete: _estimateShipping,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextFormField(
            controller: _provinceCtrl,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(labelText: 'Province *'),
            validator: (v) => v == null || v.trim().isEmpty ? 'Province is required' : null,
            onEditingComplete: _estimateShipping,
          ),
        ),
      ]),
      const SizedBox(height: 12),
      TextFormField(
        controller: _zipCtrl,
        keyboardType: TextInputType.number,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: const InputDecoration(labelText: 'ZIP Code'),
      ),
    ]);
  }
}

// ── Summary Row ───────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13)),
        Text(value, style: GoogleFonts.inter(color: AppColors.textPrimary,
            fontWeight: FontWeight.w600, fontSize: 13)),
      ],
    );
  }
}

// ── Payment Option ────────────────────────────────────────────────────────────

class _PaymentOption extends StatelessWidget {
  final String value, groupValue, label, subtitle;
  final IconData icon;
  final Color color;
  final ValueChanged<String?> onChanged;

  const _PaymentOption({
    required this.value, required this.groupValue,
    required this.icon, required this.label, required this.subtitle,
    required this.color, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? color.withAlpha(20) : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? color.withAlpha(150) : AppColors.border,
              width: selected ? 1.5 : 1),
        ),
        child: Row(children: [
          Icon(icon, color: selected ? color : AppColors.textMuted, size: 26),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: GoogleFonts.inter(color: AppColors.textPrimary,
                fontWeight: FontWeight.w700, fontSize: 13)),
            Text(subtitle, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11)),
          ])),
          Radio<String>(value: value, groupValue: groupValue,
              onChanged: onChanged, activeColor: color),
        ]),
      ),
    );
  }
}

// ── Section Card ──────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;
  const _SectionCard({required this.icon, required this.title,
      required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
          ),
          child: Row(children: [
            Icon(icon, color: AppColors.gold, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(title,
                style: GoogleFonts.inter(color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700, fontSize: 13))),
            if (trailing != null) trailing!,
          ]),
        ),
        Padding(padding: const EdgeInsets.all(16), child: child),
      ]),
    );
  }
}
