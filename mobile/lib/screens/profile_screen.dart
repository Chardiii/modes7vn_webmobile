import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';
import '../theme.dart';

class ProfileScreen extends StatefulWidget {
  final bool standalone;
  const ProfileScreen({super.key, this.standalone = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _streetCtrl;
  late final TextEditingController _barangayCtrl;
  late final TextEditingController _municipalityCtrl;
  late final TextEditingController _provinceCtrl;
  late final TextEditingController _regionCtrl;
  late final TextEditingController _zipCtrl;
  late final TextEditingController _shopNameCtrl;
  late final TextEditingController _shopDescCtrl;
  late final TextEditingController _vehicleTypeCtrl;
  late final TextEditingController _plateNumberCtrl;
  bool _editing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user ?? {};
    _firstNameCtrl    = TextEditingController(text: user['first_name'] ?? '');
    _lastNameCtrl     = TextEditingController(text: user['last_name'] ?? '');
    _phoneCtrl        = TextEditingController(text: user['phone'] ?? '');
    _streetCtrl       = TextEditingController(text: user['street'] ?? '');
    _barangayCtrl     = TextEditingController(text: user['barangay'] ?? '');
    _municipalityCtrl = TextEditingController(text: user['municipality'] ?? '');
    _provinceCtrl     = TextEditingController(text: user['province'] ?? '');
    _regionCtrl       = TextEditingController(text: user['region'] ?? '');
    _zipCtrl          = TextEditingController(text: user['zip_code'] ?? '');
    _shopNameCtrl     = TextEditingController(text: user['shop_name'] ?? '');
    _shopDescCtrl     = TextEditingController(text: user['shop_description'] ?? '');
    _vehicleTypeCtrl  = TextEditingController(text: user['vehicle_type'] ?? '');
    _plateNumberCtrl  = TextEditingController(text: user['plate_number'] ?? '');
  }

  void _syncControllersFromUser(Map user) {
    _firstNameCtrl.text    = user['first_name'] ?? '';
    _lastNameCtrl.text     = user['last_name'] ?? '';
    _phoneCtrl.text        = user['phone'] ?? '';
    _streetCtrl.text       = user['street'] ?? '';
    _barangayCtrl.text     = user['barangay'] ?? '';
    _municipalityCtrl.text = user['municipality'] ?? '';
    _provinceCtrl.text     = user['province'] ?? '';
    _regionCtrl.text       = user['region'] ?? '';
    _zipCtrl.text          = user['zip_code'] ?? '';
    _shopNameCtrl.text     = user['shop_name'] ?? '';
    _shopDescCtrl.text     = user['shop_description'] ?? '';
    _vehicleTypeCtrl.text  = user['vehicle_type'] ?? '';
    _plateNumberCtrl.text  = user['plate_number'] ?? '';
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _streetCtrl.dispose();
    _barangayCtrl.dispose();
    _municipalityCtrl.dispose();
    _provinceCtrl.dispose();
    _regionCtrl.dispose();
    _zipCtrl.dispose();
    _shopNameCtrl.dispose();
    _shopDescCtrl.dispose();
    _vehicleTypeCtrl.dispose();
    _plateNumberCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final user = context.read<AuthProvider>().user ?? {};
    final payload = <String, dynamic>{
      'first_name':   _firstNameCtrl.text.trim(),
      'last_name':    _lastNameCtrl.text.trim(),
      'phone':        _phoneCtrl.text.trim(),
      'street':       _streetCtrl.text.trim(),
      'barangay':     _barangayCtrl.text.trim(),
      'municipality': _municipalityCtrl.text.trim(),
      'province':     _provinceCtrl.text.trim(),
      'region':       _regionCtrl.text.trim(),
      'zip_code':     _zipCtrl.text.trim(),
    };
    if (user['role'] == 'seller') {
      payload['shop_name']        = _shopNameCtrl.text.trim();
      payload['shop_description'] = _shopDescCtrl.text.trim();
    }
    if (user['role'] == 'rider') {
      payload['vehicle_type'] = _vehicleTypeCtrl.text.trim();
      payload['plate_number'] = _plateNumberCtrl.text.trim();
    }
    final ok = await context.read<AuthProvider>().updateProfile(payload);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok) _editing = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? '✨ Profile updated!' : 'Update failed')));
  }

  Widget _field(String label, TextEditingController ctrl,
      {TextInputType? keyboard}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: ctrl,
        enabled: _editing,
        keyboardType: keyboard,
        style: TextStyle(
            color: _editing ? AppColors.textPrimary : AppColors.textMuted),
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Widget _buildBody(Map user) {
    // Sync controllers whenever not actively editing
    if (!_editing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_editing) _syncControllersFromUser(user);
      });
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: goldGradient,
                    ),
                    child: Center(
                      child: Text(
                        (user['username'] ?? 'U').substring(0, 1).toUpperCase(),
                        style: GoogleFonts.orbitron(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: AppColors.background),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(user['username'] ?? '',
                      style: GoogleFonts.orbitron(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(user['email'] ?? '',
                      style: GoogleFonts.inter(
                          color: AppColors.textMuted, fontSize: 13)),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withAlpha(30),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.gold.withAlpha(80)),
                    ),
                    child: Text(
                        (user['role'] ?? '').toString().toUpperCase(),
                        style: GoogleFonts.inter(
                            color: AppColors.gold,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            _sectionLabel('PERSONAL INFO'),
            Row(children: [
              Expanded(child: _field('First Name', _firstNameCtrl)),
              const SizedBox(width: 12),
              Expanded(child: _field('Last Name', _lastNameCtrl)),
            ]),
            _field('Phone', _phoneCtrl, keyboard: TextInputType.phone),
            const SizedBox(height: 8),
            _sectionLabel('ADDRESS'),
            _field('Street / House No.', _streetCtrl),
            _field('Barangay', _barangayCtrl),
            _field('Municipality / City', _municipalityCtrl),
            _field('Province', _provinceCtrl),
            _field('Region', _regionCtrl),
            _field('ZIP Code', _zipCtrl, keyboard: TextInputType.number),
            const SizedBox(height: 8),
            if (user['role'] == 'seller') ...[
              _sectionLabel('SHOP INFO'),
              _field('Store Name', _shopNameCtrl),
              _field('Store Description', _shopDescCtrl),
              const SizedBox(height: 8),
            ],
            if (user['role'] == 'rider') ...[
              _sectionLabel('RIDER INFO'),
              _field('Vehicle Type', _vehicleTypeCtrl),
              _field('Plate Number', _plateNumberCtrl),
              const SizedBox(height: 8),
            ],
            if (_editing) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() {
                        _editing = false;
                      }),
                      child: Text('Cancel',
                          style: GoogleFonts.inter(
                              color: AppColors.textMuted)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _saving
                        ? const Center(
                            child: CircularProgressIndicator(
                                color: AppColors.gold))
                        : Container(
                            decoration: BoxDecoration(
                              gradient: goldGradient,
                              borderRadius: BorderRadius.circular(40),
                            ),
                            child: ElevatedButton(
                              onPressed: _save,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: AppColors.background,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(40)),
                              ),
                              child: Text('SAVE',
                                  style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      letterSpacing: 1.5)),
                            ),
                          ),
                  ),
                ],
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => setState(() => _editing = true),
                  child: Text('Edit Profile',
                      style: GoogleFonts.inter(
                          color: AppColors.gold,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user ?? {};
    if (widget.standalone) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: _buildBody(user),
      );
    }
    return Material(
      color: AppColors.background,
      child: _buildBody(user),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(label,
          style: GoogleFonts.inter(
              color: AppColors.textMuted,
              fontSize: 10,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w600)),
    );
  }
}
