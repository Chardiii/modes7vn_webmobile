import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';
import '../theme.dart';
import 'products_screen.dart';
import 'cart_screen.dart';
import 'orders_screen.dart';
import 'wishlist_screen.dart';
import 'profile_screen.dart';
import 'messages_screen.dart';
import 'login_screen.dart';

class BuyerHomeScreen extends StatefulWidget {
  const BuyerHomeScreen({super.key});

  @override
  State<BuyerHomeScreen> createState() => _BuyerHomeScreenState();
}

class _BuyerHomeScreenState extends State<BuyerHomeScreen> {
  int _currentIndex = 0;
  // Track which tabs have been visited so we only rebuild when needed
  final Set<int> _visited = {0};

  final _titles = ['MODE S7VN', 'Cart', 'My Orders', 'Wishlist', 'Profile'];

  Future<void> _logout() async {
    final nav = Navigator.of(context);
    await context.read<AuthProvider>().logout();
    nav.pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  void _onTabTapped(int i) {
    setState(() {
      _currentIndex = i;
      _visited.add(i);
    });
  }

  Widget _buildTab(int index) {
    switch (index) {
      case 0: return const ProductsScreen();
      case 1: return CartScreen(key: ValueKey('cart_$_currentIndex'));
      case 2: return OrdersScreen(key: ValueKey('orders_$_currentIndex'));
      case 3: return WishlistScreen(key: ValueKey('wishlist_$_currentIndex'));
      case 4: return const ProfileScreen();
      default: return const SizedBox();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHome = _currentIndex == 0;

    return Scaffold(
      appBar: AppBar(
        title: isHome
            ? ShaderMask(
                shaderCallback: (b) => goldGradient.createShader(b),
                child: Text('MODE S7VN',
                    style: GoogleFonts.orbitron(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
              )
            : Text(_titles[_currentIndex]),
        actions: [
          if (isHome)
            IconButton(
                icon: const Icon(Icons.chat_bubble_outline),
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const MessagesScreen()))),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: _buildTab(_currentIndex),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.gold,
          unselectedItemColor: AppColors.textMuted,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle:
              const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 10),
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.storefront_outlined),
              activeIcon: Icon(Icons.storefront),
              label: 'Shop',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.shopping_bag_outlined),
              activeIcon: Icon(Icons.shopping_bag),
              label: 'Cart',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long),
              label: 'Orders',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.favorite_border),
              activeIcon: Icon(Icons.favorite),
              label: 'Wishlist',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
