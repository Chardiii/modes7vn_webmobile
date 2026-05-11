import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _api = ApiService();
  final _formKey          = GlobalKey<FormState>();
  final _usernameCtrl     = TextEditingController();
  final _emailCtrl        = TextEditingController();
  final _passwordCtrl     = TextEditingController();
  final _confirmCtrl      = TextEditingController();
  final _firstNameCtrl    = TextEditingController();
  final _lastNameCtrl     = TextEditingController();
  final _phoneCtrl        = TextEditingController();
  final _shopNameCtrl     = TextEditingController();
  final _shopDescCtrl     = TextEditingController();
  final _plateCtrl        = TextEditingController();

  String _role = 'buyer';
  String _vehicleType = 'Motorcycle';
  bool _loading = false;
  bool _obscure = true;

  final _vehicleTypes = ['Motorcycle', 'Bicycle', 'Car', 'Van'];

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _loading = true);
    try {
      await _api.register(
        username:        _usernameCtrl.text.trim(),
        email:           _emailCtrl.text.trim(),
        password:        _passwordCtrl.text,
        role:            _role,
        firstName:       _firstNameCtrl.text.trim(),
        lastName:        _lastNameCtrl.text.trim(),
        phone:           _phoneCtrl.text.trim(),
        shopName:        _shopNameCtrl.text.trim(),
        shopDescription: _shopDescCtrl.text.trim(),
        vehicleType:     _vehicleType,
        plateNumber:     _plateCtrl.text.trim(),
      );
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppColors.border)),
          title: Text('✨ Registration Submitted',
              style: GoogleFonts.orbitron(
                  color: AppColors.gold, fontSize: 16)),
          content: Text(
              'Please verify your email, then wait for admin approval before logging in.',
              style: GoogleFonts.inter(
                  color: AppColors.textMuted, fontSize: 13)),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('Go to Login'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().contains('409')
          ? 'Username or email already taken'
          : e.toString().replaceAll(RegExp(r'DioException.*:'), '').trim();
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _field(TextEditingController ctrl, String label,
      {TextInputType? keyboard,
      bool obscure = false,
      Widget? suffix,
      int maxLines = 1,
      String? Function(String?)? validator}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: ctrl,
        obscureText: obscure,
        keyboardType: keyboard,
        maxLines: obscure ? 1 : maxLines,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(labelText: label, suffixIcon: suffix),
        validator: validator,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Join Mode S7vn',
                  style: GoogleFonts.orbitron(
                      color: AppColors.gold,
                      fontSize: 20,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Choose your role to get started',
                  style: GoogleFonts.inter(
                      color: AppColors.textMuted, fontSize: 12)),
              const SizedBox(height: 24),

              // Role selector
              Text('I AM A...',
                  style: GoogleFonts.inter(
                      color: AppColors.textMuted,
                      fontSize: 10,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Row(
                children: [
                  _RoleChip(
                    label: 'Buyer',
                    icon: Icons.shopping_bag_outlined,
                    selected: _role == 'buyer',
                    onTap: () => setState(() => _role = 'buyer'),
                  ),
                  const SizedBox(width: 10),
                  _RoleChip(
                    label: 'Seller',
                    icon: Icons.storefront_outlined,
                    selected: _role == 'seller',
                    onTap: () => setState(() => _role = 'seller'),
                  ),
                  const SizedBox(width: 10),
                  _RoleChip(
                    label: 'Rider',
                    icon: Icons.delivery_dining_outlined,
                    selected: _role == 'rider',
                    onTap: () => setState(() => _role = 'rider'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Basic info
              Text('BASIC INFO',
                  style: GoogleFonts.inter(
                      color: AppColors.textMuted,
                      fontSize: 10,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _field(_firstNameCtrl, 'First Name')),
                const SizedBox(width: 12),
                Expanded(child: _field(_lastNameCtrl, 'Last Name')),
              ]),
              _field(_usernameCtrl, 'Username *',
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Required'
                      : null),
              _field(_emailCtrl, 'Email *',
                  keyboard: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (!v.contains('@')) return 'Enter a valid email';
                    return null;
                  }),
              _field(_phoneCtrl, 'Phone',
                  keyboard: TextInputType.phone),
              _field(_passwordCtrl, 'Password *',
                  obscure: _obscure,
                  suffix: IconButton(
                    icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility,
                        color: AppColors.textMuted),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (v.length < 8) return 'At least 8 characters';
                    return null;
                  }),
              _field(_confirmCtrl, 'Confirm Password *',
                  obscure: _obscure,
                  validator: (v) => v != _passwordCtrl.text
                      ? 'Passwords do not match'
                      : null),

              // Seller fields
              if (_role == 'seller') ...[
                const Divider(),
                const SizedBox(height: 8),
                Text('SHOP INFO',
                    style: GoogleFonts.inter(
                        color: AppColors.textMuted,
                        fontSize: 10,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                _field(_shopNameCtrl, 'Shop Name *',
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Shop name is required'
                        : null),
                _field(_shopDescCtrl, 'Shop Description',
                    maxLines: 3),
              ],

              // Rider fields
              if (_role == 'rider') ...[
                const Divider(),
                const SizedBox(height: 8),
                Text('VEHICLE INFO',
                    style: GoogleFonts.inter(
                        color: AppColors.textMuted,
                        fontSize: 10,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: DropdownButtonFormField<String>(
                    initialValue: _vehicleType,
                    dropdownColor: AppColors.surfaceLight,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Vehicle Type',
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
                    ),
                    items: _vehicleTypes
                        .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(t,
                                style: const TextStyle(
                                    color: AppColors.textPrimary))))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _vehicleType = v ?? 'Motorcycle'),
                  ),
                ),
                _field(_plateCtrl, 'Plate Number *',
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Plate number is required'
                        : null),
              ],

              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: _loading
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
                        child: ElevatedButton(
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: AppColors.background,
                            padding:
                                const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(40)),
                          ),
                          child: Text('REGISTER AS ${_role.toUpperCase()}',
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
}

class _RoleChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _RoleChip(
      {required this.label,
      required this.icon,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: selected ? goldGradient : null,
            color: selected ? null : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: selected ? AppColors.gold : AppColors.border),
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 22,
                  color: selected
                      ? AppColors.background
                      : AppColors.textMuted),
              const SizedBox(height: 4),
              Text(label,
                  style: GoogleFonts.inter(
                      color: selected
                          ? AppColors.background
                          : AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
