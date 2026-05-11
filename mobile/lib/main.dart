import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'services/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/buyer_home_screen.dart';
import 'screens/seller_dashboard_screen.dart';
import 'screens/rider_dashboard_screen.dart';
import 'theme.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthProvider()..checkAuth(),
      child: const ModeApp(),
    ),
  );
}

class ModeApp extends StatelessWidget {
  const ModeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mode S7vn',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: Consumer<AuthProvider>(
        builder: (ctx, auth, _) {
          if (auth.initializing) return const _SplashScreen();
          if (!auth.isLoggedIn) return const LoginScreen();
          return _homeForRole(auth.user?['role']);
        },
      ),
    );
  }

  Widget _homeForRole(String? role) {
    switch (role) {
      case 'seller':
        return const SellerDashboardScreen();
      case 'rider':
        return const RiderDashboardScreen();
      default:
        return const BuyerHomeScreen();
    }
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ShaderMask(
              shaderCallback: (b) => goldGradient.createShader(b),
              child: Text('MODE S7VN',
                  style: GoogleFonts.orbitron(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 2)),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(color: AppColors.gold),
          ],
        ),
      ),
    );
  }
}
