import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';
import '../theme.dart';
import 'buyer_home_screen.dart';
import 'seller_dashboard_screen.dart';
import 'rider_dashboard_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _googleLoading = false;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _googleSignIn() async {
    final auth = context.read<AuthProvider>();
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _googleLoading = true);
    final ok = await auth.googleLogin();
    if (!mounted) return;
    setState(() => _googleLoading = false);
    if (ok) {
      final role = auth.user?['role'];
      Widget home;
      if (role == 'seller') {
        home = const SellerDashboardScreen();
      } else if (role == 'rider') {
        home = const RiderDashboardScreen();
      } else {
        home = const BuyerHomeScreen();
      }
      nav.pushReplacement(MaterialPageRoute(builder: (_) => home));
    } else {
      messenger.showSnackBar(
          SnackBar(content: Text(auth.error ?? 'Google sign-in failed')));
    }
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    final nav  = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await auth.login(
        _usernameCtrl.text.trim(), _passwordCtrl.text);
    if (!mounted) return;
    if (ok) {
      final role = auth.user?['role'];
      Widget home;
      if (role == 'seller') {
        home = const SellerDashboardScreen();
      } else if (role == 'rider') {
        home = const RiderDashboardScreen();
      } else {
        home = const BuyerHomeScreen();
      }
      nav.pushReplacement(
          MaterialPageRoute(builder: (_) => home));
    } else {
      messenger.showSnackBar(
          SnackBar(content: Text(auth.error ?? 'Login failed')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = context.watch<AuthProvider>().loading;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              // Brand logo
              ShaderMask(
                shaderCallback: (b) => goldGradient.createShader(b),
                child: Text('MODE S7VN',
                    style: GoogleFonts.orbitron(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                        color: Colors.white)),
              ),
              const SizedBox(height: 6),
              Text('Men\'s Apparel • Y2K ERA',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textMuted,
                      letterSpacing: 2)),
              const SizedBox(height: 48),
              Text('Welcome back',
                  style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text('Sign in to your account',
                  style: GoogleFonts.inter(
                      fontSize: 14, color: AppColors.textMuted)),
              const SizedBox(height: 32),
              TextField(
                controller: _usernameCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Username',
                  prefixIcon:
                      Icon(Icons.person_outline, color: AppColors.textMuted),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordCtrl,
                obscureText: _obscure,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline,
                      color: AppColors.textMuted),
                  suffixIcon: IconButton(
                    icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility,
                        color: AppColors.textMuted),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: loading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.gold))
                    : _GoldButton(
                        label: 'LOGIN',
                        onPressed: _submit,
                      ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(child: Divider(color: AppColors.border)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('OR',
                        style: GoogleFonts.inter(
                            color: AppColors.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1)),
                  ),
                  const Expanded(child: Divider(color: AppColors.border)),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: _googleLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.gold))
                    : OutlinedButton.icon(
                        onPressed: _googleSignIn,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: const BorderSide(color: AppColors.border),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(40)),
                          backgroundColor: AppColors.surfaceLight,
                        ),
                        icon: Image.network(
                          'https://www.google.com/favicon.ico',
                          width: 20,
                          height: 20,
                          errorBuilder: (_, _, _) =>
                              const Icon(Icons.g_mobiledata, size: 22),
                        ),
                        label: Text('Continue with Google',
                            style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                      ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Don't have an account? ",
                      style: GoogleFonts.inter(
                          color: AppColors.textMuted, fontSize: 13)),
                  GestureDetector(
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const RegisterScreen())),
                    child: Text('Register',
                        style: GoogleFonts.inter(
                            color: AppColors.gold,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoldButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const _GoldButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
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
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: AppColors.background,
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(40)),
        ),
        child: Text(label,
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                letterSpacing: 1.5)),
      ),
    );
  }
}
