import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../utils/orientation_lock.dart';
import 'home_page.dart';
import 'login_page.dart';

class LoginOptionPage extends StatefulWidget {
  const LoginOptionPage({Key? key}) : super(key: key);

  @override
  State<LoginOptionPage> createState() => _LoginOptionPageState();
}

class _LoginOptionPageState extends State<LoginOptionPage> {
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final isLoggedIn = await _authService.isLoggedIn();
    if (!isLoggedIn || !mounted) return;

    final userData = await _authService.getUserData();
    String userRole = '';
    if (userData != null) {
      userRole = (userData['roleID'] ??
              userData['RoleID'] ??
              userData['role'] ??
              userData['Role'] ??
              userData['userRole'] ??
              userData['UserRole'] ??
              userData['position'] ??
              userData['Position'] ??
              '')
          .toString()
          .toUpperCase();
    }

    if (userRole == 'CRF_TL') {
      await OrientationLock.portrait();
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/tl_home');
    } else {
      await OrientationLock.landscape();
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    }
  }

  void _goToLogin(String loginSebagai) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => LoginPage(loginSebagai: loginSebagai),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isNarrow = size.width < 700;

    return Scaffold(
      backgroundColor: const Color(0xFF0056A4),
      body: SafeArea(
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/bg-login.png'),
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Login Sebagai :',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF003E78),
                  ),
                ),
                const SizedBox(height: 36),
                isNarrow
                    ? Column(
                        children: [
                          _buildOptionButton(
                            label: 'TL',
                            icon: Icons.badge_outlined,
                            onTap: () => _goToLogin('TL'),
                          ),
                          const SizedBox(height: 16),
                          _buildOptionButton(
                            label: 'KASIR/OPR',
                            icon: Icons.point_of_sale_outlined,
                            onTap: () => _goToLogin('OPR'),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildOptionButton(
                            label: 'TL',
                            icon: Icons.badge_outlined,
                            onTap: () => _goToLogin('TL'),
                          ),
                          const SizedBox(width: 20),
                          _buildOptionButton(
                            label: 'KASIR/OPR',
                            icon: Icons.point_of_sale_outlined,
                            onTap: () => _goToLogin('OPR'),
                          ),
                        ],
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 220,
      height: 200,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          elevation: 1,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade300),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 88, color: Colors.black87),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
