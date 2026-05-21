import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/api_service.dart';
import '../theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _api             = ApiService();
  final _formKey         = GlobalKey<FormState>();
  final _usernameCtrl    = TextEditingController();
  final _emailCtrl       = TextEditingController();
  final _passwordCtrl    = TextEditingController();
  final _confirmCtrl     = TextEditingController();
  final _firstNameCtrl   = TextEditingController();
  final _lastNameCtrl    = TextEditingController();
  final _phoneCtrl       = TextEditingController();
  final _shopNameCtrl    = TextEditingController();
  final _shopDescCtrl    = TextEditingController();
  final _plateCtrl       = TextEditingController();
  final _serviceAreaCtrl = TextEditingController();
  final _regionCtrl      = TextEditingController();
  final _provinceCtrl    = TextEditingController();
  final _municipalityCtrl = TextEditingController();
  final _barangayCtrl    = TextEditingController();

  String _role        = 'buyer';
  String _vehicleType = 'Motorcycle';
  bool   _loading        = false;
  bool   _obscure        = true;
  bool   _obscureConfirm = true;

  bool _reqLen     = false;
  bool _reqUpper   = false;
  bool _reqNum     = false;
  bool _reqSpecial = false;

  int get _pwScore => [_reqLen, _reqUpper, _reqNum, _reqSpecial].where((b) => b).length;

  void _onPasswordChanged(String v) {
    setState(() {
      _reqLen     = v.length >= 8;
      _reqUpper   = v.contains(RegExp(r'[A-Z]'));
      _reqNum     = v.contains(RegExp(r'[0-9]'));
      _reqSpecial = v.contains(RegExp(r'[^A-Za-z0-9]'));
    });
  }

  File? _validIdFile;
  File? _businessPermitFile;
  File? _driversLicenseFile;

  final _picker       = ImagePicker();
  final _vehicleTypes = ['Motorcycle', 'Bicycle', 'Car', 'Van'];

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _shopNameCtrl.dispose();
    _shopDescCtrl.dispose();
    _plateCtrl.dispose();
    _serviceAreaCtrl.dispose();
    _regionCtrl.dispose();
    _provinceCtrl.dispose();
    _municipalityCtrl.dispose();
    _barangayCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile(String type) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppColors.gold),
              title: Text('Take Photo', style: GoogleFonts.inter(color: AppColors.textPrimary)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.gold),
              title: Text('Choose from Gallery', style: GoogleFonts.inter(color: AppColors.textPrimary)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picked = await _picker.pickImage(source: source, imageQuality: 85);
    if (picked == null || !mounted) return;
    setState(() {
      final file = File(picked.path);
      if (type == 'valid_id')        _validIdFile        = file;
      if (type == 'business_permit') _businessPermitFile = file;
      if (type == 'drivers_license') _driversLicenseFile = file;
    });
  }

  Widget _filePicker(String label, File? file, String type, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label + (required ? ' *' : ''),
              style: GoogleFonts.inter(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => _pickFile(type),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: file != null ? AppColors.gold : AppColors.border,
                    width: file != null ? 1.5 : 1),
              ),
              child: file != null
                  ? Row(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(file, width: 56, height: 56, fit: BoxFit.cover),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(file.path.split('/').last,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                                color: AppColors.textPrimary, fontSize: 12)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppColors.textMuted, size: 18),
                        onPressed: () => setState(() {
                          if (type == 'valid_id')        _validIdFile        = null;
                          if (type == 'business_permit') _businessPermitFile = null;
                          if (type == 'drivers_license') _driversLicenseFile = null;
                        }),
                      ),
                    ])
                  : Row(children: [
                      const Icon(Icons.upload_file_outlined, color: AppColors.gold, size: 22),
                      const SizedBox(width: 10),
                      Text('Tap to upload photo',
                          style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13)),
                    ]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_validIdFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please upload a valid ID')));
      return;
    }
    if (_role == 'seller' && _businessPermitFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please upload your business permit')));
      return;
    }
    if (_role == 'rider' && _driversLicenseFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please upload your driver's license")));
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _loading = true);
    try {
      await _api.register(
        username:           _usernameCtrl.text.trim(),
        email:              _emailCtrl.text.trim(),
        password:           _passwordCtrl.text,
        role:               _role,
        firstName:          _firstNameCtrl.text.trim(),
        lastName:           _lastNameCtrl.text.trim(),
        phone:              _phoneCtrl.text.trim(),
        region:             _regionCtrl.text.trim(),
        province:           _provinceCtrl.text.trim(),
        municipality:       _municipalityCtrl.text.trim(),
        barangay:           _barangayCtrl.text.trim(),
        shopName:           _shopNameCtrl.text.trim(),
        shopDescription:    _shopDescCtrl.text.trim(),
        vehicleType:        _vehicleType,
        plateNumber:        _plateCtrl.text.trim(),
        serviceArea:        _serviceAreaCtrl.text.trim(),
        validIdPath:        _validIdFile?.path,
        businessPermitPath: _businessPermitFile?.path,
        driversLicensePath: _driversLicenseFile?.path,
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
              style: GoogleFonts.orbitron(color: AppColors.gold, fontSize: 16)),
          content: Text(
              'Please verify your email, then wait for admin approval before logging in.',
              style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13)),
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
                  style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12)),
              const SizedBox(height: 24),

              Text('I AM A...',
                  style: GoogleFonts.inter(
                      color: AppColors.textMuted,
                      fontSize: 10,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              _RoleSelector(selected: _role, onChanged: (r) => setState(() => _role = r)),
              const SizedBox(height: 24),

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
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null),
              _field(_emailCtrl, 'Email *',
                  keyboard: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (!v.contains('@')) return 'Enter a valid email';
                    return null;
                  }),
              _field(_phoneCtrl, 'Phone', keyboard: TextInputType.phone),

              const Divider(),
              const SizedBox(height: 8),
              Text('ADDRESS',
                  style: GoogleFonts.inter(
                      color: AppColors.textMuted,
                      fontSize: 10,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              _field(_regionCtrl, 'Region'),
              _field(_provinceCtrl, 'Province'),
              _field(_municipalityCtrl, 'City / Municipality'),
              _field(_barangayCtrl, 'Barangay'),

              // ── Password with strength indicator ──
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: _obscure,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Password *',
                        suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                              color: AppColors.textMuted),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      onChanged: _onPasswordChanged,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (!_reqLen)     return 'At least 8 characters';
                        if (!_reqUpper)   return 'Add an uppercase letter (A–Z)';
                        if (!_reqNum)     return 'Add a number (0–9)';
                        if (!_reqSpecial) return r'Add a special character (!@#$…)';
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: _pwScore / 4,
                        minHeight: 4,
                        backgroundColor: AppColors.border,
                        valueColor: AlwaysStoppedAnimation(
                          [Colors.transparent, AppColors.error, Colors.orange,
                           AppColors.goldMid, AppColors.success][_pwScore],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('REQUIREMENTS',
                              style: GoogleFonts.inter(
                                  color: AppColors.textMuted,
                                  fontSize: 9,
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          _PwReq('At least 8 characters', _reqLen),
                          _PwReq('One uppercase letter (A–Z)', _reqUpper),
                          _PwReq('One number (0–9)', _reqNum),
                          _PwReq(r'One special character (!@#$…)', _reqSpecial),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _field(_confirmCtrl, 'Confirm Password *',
                  obscure: _obscureConfirm,
                  suffix: IconButton(
                    icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility,
                        color: AppColors.textMuted),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                  validator: (v) => v != _passwordCtrl.text ? 'Passwords do not match' : null),

              const Divider(),
              const SizedBox(height: 8),
              Text('IDENTITY VERIFICATION',
                  style: GoogleFonts.inter(
                      color: AppColors.textMuted,
                      fontSize: 10,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              _filePicker('Valid ID', _validIdFile, 'valid_id', required: true),

              // Seller section
              if (_role == 'seller') _SellerSection(
                shopNameCtrl: _shopNameCtrl,
                shopDescCtrl: _shopDescCtrl,
                businessPermitFile: _businessPermitFile,
                onPickFile: _pickFile,
                onClearFile: () => setState(() => _businessPermitFile = null),
              ),

              // Rider section
              if (_role == 'rider') _RiderSection(
                plateCtrl: _plateCtrl,
                serviceAreaCtrl: _serviceAreaCtrl,
                vehicleType: _vehicleType,
                vehicleTypes: _vehicleTypes,
                driversLicenseFile: _driversLicenseFile,
                onVehicleTypeChanged: (v) => setState(() => _vehicleType = v),
                onPickFile: _pickFile,
                onClearFile: () => setState(() => _driversLicenseFile = null),
              ),

              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
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
                            padding: const EdgeInsets.symmetric(vertical: 16),
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

// ── Seller section ────────────────────────────────────────────────────────────

class _SellerSection extends StatelessWidget {
  final TextEditingController shopNameCtrl;
  final TextEditingController shopDescCtrl;
  final File? businessPermitFile;
  final Future<void> Function(String) onPickFile;
  final VoidCallback onClearFile;

  const _SellerSection({
    required this.shopNameCtrl,
    required this.shopDescCtrl,
    required this.businessPermitFile,
    required this.onPickFile,
    required this.onClearFile,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 8),
        Text('SHOP INFO',
            style: GoogleFonts.inter(
                color: AppColors.textMuted,
                fontSize: 10,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextFormField(
            controller: shopNameCtrl,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(labelText: 'Shop Name *'),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Shop name is required' : null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextFormField(
            controller: shopDescCtrl,
            maxLines: 3,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(labelText: 'Shop Description'),
          ),
        ),
        _FilePickerTile(
          label: 'Business Permit',
          file: businessPermitFile,
          type: 'business_permit',
          required: true,
          onPick: onPickFile,
          onClear: onClearFile,
        ),
      ],
    );
  }
}

// ── Rider section ─────────────────────────────────────────────────────────────

class _RiderSection extends StatelessWidget {
  final TextEditingController plateCtrl;
  final TextEditingController serviceAreaCtrl;
  final String vehicleType;
  final List<String> vehicleTypes;
  final File? driversLicenseFile;
  final ValueChanged<String> onVehicleTypeChanged;
  final Future<void> Function(String) onPickFile;
  final VoidCallback onClearFile;

  const _RiderSection({
    required this.plateCtrl,
    required this.serviceAreaCtrl,
    required this.vehicleType,
    required this.vehicleTypes,
    required this.driversLicenseFile,
    required this.onVehicleTypeChanged,
    required this.onPickFile,
    required this.onClearFile,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            value: vehicleType,
            dropdownColor: AppColors.surfaceLight,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              labelText: 'Vehicle Type',
              labelStyle: const TextStyle(color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.surfaceLight,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border)),
            ),
            items: vehicleTypes
                .map((t) => DropdownMenuItem(
                    value: t,
                    child: Text(t,
                        style: const TextStyle(color: AppColors.textPrimary))))
                .toList(),
            onChanged: (v) {
              if (v != null) onVehicleTypeChanged(v);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextFormField(
            controller: plateCtrl,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(labelText: 'Plate Number *'),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Plate number is required' : null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: TextFormField(
            controller: serviceAreaCtrl,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(labelText: 'Service Area *'),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Service area is required' : null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
              'City or municipality you will deliver in (e.g. Calamba, Laguna)',
              style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11)),
        ),
        _FilePickerTile(
          label: "Driver's License",
          file: driversLicenseFile,
          type: 'drivers_license',
          required: true,
          onPick: onPickFile,
          onClear: onClearFile,
        ),
      ],
    );
  }
}

// ── Shared file picker tile ───────────────────────────────────────────────────

class _FilePickerTile extends StatelessWidget {
  final String label;
  final File? file;
  final String type;
  final bool required;
  final Future<void> Function(String) onPick;
  final VoidCallback onClear;

  const _FilePickerTile({
    required this.label,
    required this.file,
    required this.type,
    required this.onPick,
    required this.onClear,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label + (required ? ' *' : ''),
              style: GoogleFonts.inter(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => onPick(type),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: file != null ? AppColors.gold : AppColors.border,
                    width: file != null ? 1.5 : 1),
              ),
              child: file != null
                  ? Row(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(file!, width: 56, height: 56, fit: BoxFit.cover),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(file!.path.split('/').last,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                                color: AppColors.textPrimary, fontSize: 12)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppColors.textMuted, size: 18),
                        onPressed: onClear,
                      ),
                    ])
                  : Row(children: [
                      const Icon(Icons.upload_file_outlined, color: AppColors.gold, size: 22),
                      const SizedBox(width: 10),
                      Text('Tap to upload photo',
                          style: GoogleFonts.inter(
                              color: AppColors.textMuted, fontSize: 13)),
                    ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Password requirement row ────────────────────────────────────────────────────────────

class _PwReq extends StatelessWidget {
  final String label;
  final bool met;
  const _PwReq(this.label, this.met);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Icon(
            met ? Icons.circle : Icons.circle_outlined,
            size: 8,
            color: met ? AppColors.success : AppColors.textMuted,
          ),
          const SizedBox(width: 6),
          Text(label,
              style: GoogleFonts.inter(
                  color: met ? AppColors.success : AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: met ? FontWeight.w600 : FontWeight.w400)),
        ],
      ),
    );
  }
}

// ── Role selector ─────────────────────────────────────────────────────────────

class _RoleSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _RoleSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _RoleChip(
          label: 'Buyer',
          icon: Icons.shopping_bag_outlined,
          selected: selected == 'buyer',
          onTap: () => onChanged('buyer'),
        ),
        const SizedBox(width: 10),
        _RoleChip(
          label: 'Seller',
          icon: Icons.storefront_outlined,
          selected: selected == 'seller',
          onTap: () => onChanged('seller'),
        ),
        const SizedBox(width: 10),
        _RoleChip(
          label: 'Rider',
          icon: Icons.delivery_dining_outlined,
          selected: selected == 'rider',
          onTap: () => onChanged('rider'),
        ),
      ],
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
            border: Border.all(color: selected ? AppColors.gold : AppColors.border),
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 22,
                  color: selected ? AppColors.background : AppColors.textMuted),
              const SizedBox(height: 4),
              Text(label,
                  style: GoogleFonts.inter(
                      color: selected ? AppColors.background : AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
